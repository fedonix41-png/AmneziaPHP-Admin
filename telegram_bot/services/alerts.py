from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set

from aiogram import Bot
from aiogram.exceptions import TelegramRetryAfter, TelegramAPIError

from config import settings
from services.panel_api import PanelAPIError, panel_api
from utils.format import humanize_bytes, humanize_date

logger = logging.getLogger(__name__)

# Стартовая задержка (сек) перед первым циклом каждой задачи — даёт панели
# время прогреть соединения после старта контейнера.
_INITIAL_DELAY_SEC = 30
# Интервал опроса для ежедневной задачи (сек): короткий поллинг с защитой
# «раз в сутки» по дате, устойчив к перезапускам и DST.
_DAILY_POLL_SEC = 1800


def _to_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


def _to_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    try:
        return int(value)
    except (ValueError, TypeError):
        return None


async def send_alert_to_admins(bot: Bot, text: str) -> None:
    for admin_id in settings.admin_ids:
        try:
            await bot.send_message(chat_id=admin_id, text=text, parse_mode="HTML")
        except TelegramRetryAfter as exc:
            logger.warning("Rate limit: ждём %s сек перед отправкой админу %s", exc.retry_after, admin_id)
            await asyncio.sleep(exc.retry_after)
            try:
                await bot.send_message(chat_id=admin_id, text=text, parse_mode="HTML")
            except TelegramAPIError as retry_exc:
                logger.error("Не удалось отправить алерт админу %s: %s", admin_id, retry_exc)
        except TelegramAPIError as exc:
            logger.error("Не удалось отправить алерт админу %s: %s", admin_id, exc)
        await asyncio.sleep(0.05)


class AlertScheduler:
    """Периодический опрос API панели и рассылка алертов администраторам.

    Источники (см. docs/telegram_bot_spec.md#5):
      * CPU/RAM — GET /api/servers/{id}/metrics, пороги ALERT_CPU_THRESHOLD / ALERT_RAM_THRESHOLD
      * Overlimit — GET /api/clients/overlimit
      * Истекающие подписки — GET /api/clients/expiring, раз в сутки
    """

    def __init__(self) -> None:
        self._tasks: List[asyncio.Task] = []
        # server_id, находящиеся в аварийном состоянии (для дедупликации CPU/RAM)
        self._cpu_alerted: Set[int] = set()
        # client_id, по которым уже отправлен overlimit-алерт
        self._overlimit_reported: Set[int] = set()
        # Дата последнего запуска ежедневного отчёта (UTC)
        self._last_expiry_run: Optional[datetime.date] = None

    @property
    def is_running(self) -> bool:
        return any(not t.done() for t in self._tasks)

    def start(self, bot: Bot) -> None:
        if not settings.alert_enabled:
            logger.info("Алертинг отключён (ALERT_ENABLED=false)")
            return
        if not settings.panel_api_token:
            logger.warning("Алертинг отключён: не задан PANEL_API_TOKEN в .env")
            return
        if not settings.admin_ids:
            logger.warning("Алертинг отключён: не заданы админы (BOT_ADMIN_TELEGRAM_IDS)")
            return

        self._tasks = [
            asyncio.create_task(self._run_loop(self._check_cpu_ram, settings.alert_cpu_interval, bot, _INITIAL_DELAY_SEC), name="alert:cpu"),
            asyncio.create_task(self._run_loop(self._check_overlimit, settings.alert_overlimit_interval, bot, _INITIAL_DELAY_SEC * 2), name="alert:overlimit"),
            asyncio.create_task(self._run_loop(self._maybe_check_expiring, _DAILY_POLL_SEC, bot, _INITIAL_DELAY_SEC * 3), name="alert:expiring"),
        ]
        logger.info(
            "Планировщик алертов запущен: CPU/RAM=%ss, overlimit=%ss, expiring~%02d:00 UTC",
            settings.alert_cpu_interval, settings.alert_overlimit_interval, settings.alert_expiring_hour,
        )

    async def stop(self) -> None:
        if not self._tasks:
            return
        for task in self._tasks:
            task.cancel()
        for task in self._tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception:  # noqa: BLE001 — логируем и глушим при остановке
                logger.exception("Ошибка при остановке фоновой задачи %s", task.get_name())
        self._tasks.clear()
        logger.info("Планировщик алертов остановлен")

    async def _run_loop(self, action, interval: int, bot: Bot, initial_delay: int) -> None:
        await asyncio.sleep(initial_delay)
        while True:
            try:
                await action(bot)
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001 — цикл не должен падать
                logger.exception("Сбой в цикле алертов %s", action.__name__)
            await asyncio.sleep(interval)

    # ── CPU / RAM ────────────────────────────────────────────────────

    async def _check_cpu_ram(self, bot: Bot) -> None:
        try:
            servers = await panel_api.list_servers()
        except PanelAPIError as exc:
            logger.warning("CPU/RAM: список серверов недоступен: %s", exc.message)
            return

        now_alerted: Set[int] = set()
        for srv in servers:
            sid = _to_int(srv.get("id"))
            if sid is None:
                continue
            name = srv.get("name") or f"#{sid}"

            try:
                metrics = await panel_api.server_metrics(sid, hours=1)
            except PanelAPIError as exc:
                logger.debug("CPU/RAM: метрики сервера %s недоступны: %s", sid, exc.message)
                continue
            if not metrics:
                continue

            latest = metrics[-1]
            cpu = _to_float(latest.get("cpu_percent"))
            ram_used = _to_int(latest.get("ram_used_mb"))
            ram_total = _to_int(latest.get("ram_total_mb"))
            ram_pct = (ram_used / ram_total * 100) if ram_used is not None and ram_total else None

            cpu_high = cpu is not None and cpu >= settings.alert_cpu_threshold
            ram_high = ram_pct is not None and ram_pct >= settings.alert_ram_threshold

            if cpu_high or ram_high:
                now_alerted.add(sid)
                if sid not in self._cpu_alerted:
                    lines = [f"🚨 <b>Высокая нагрузка: {name}</b> (сервер #{sid})"]
                    if cpu is not None:
                        lines.append(f"🖥 CPU: <b>{cpu:.0f}%</b>")
                    if ram_pct is not None:
                        lines.append(f"🧠 RAM: <b>{ram_pct:.0f}%</b>")
                    lines.append(f"🕐 <i>{humanize_date(latest.get('collected_at'))}</i>")
                    await send_alert_to_admins(bot, "\n".join(lines))
            elif sid in self._cpu_alerted:
                await send_alert_to_admins(bot, f"✅ <b>Нагрузка в норме: {name}</b> (сервер #{sid})")

        # Финальный снимок состояния: исчезнувшие серверы сбрасываются без алерта
        self._cpu_alerted = now_alerted

    # ── Overlimit ───────────────────────────────────────────────────

    async def _check_overlimit(self, bot: Bot) -> None:
        try:
            data = await panel_api.get_overlimit_clients()
        except PanelAPIError as exc:
            logger.warning("Overlimit: недоступен: %s", exc.message)
            return

        clients = data.get("clients", []) or []
        current_ids: Set[int] = set()
        new_clients: List[Dict[str, Any]] = []
        for c in clients:
            cid = _to_int(c.get("id"))
            if cid is None:
                continue
            current_ids.add(cid)
            if cid not in self._overlimit_reported:
                new_clients.append(c)

        if new_clients:
            lines = [f"🚨 <b>Превышение лимита: {len(new_clients)}</b>\n"]
            for c in new_clients[:15]:
                name = c.get("name") or f"#{c.get('id')}"
                limit = humanize_bytes(c.get("traffic_limit", 0))
                lines.append(f"• {name} (лимит: {limit})")
            if len(new_clients) > 15:
                lines.append(f"… и ещё {len(new_clients) - 15}")
            await send_alert_to_admins(bot, "\n".join(lines))

        # Обновляем снимок: только актуально превышающие лимит клиенты.
        # Если клиент восстановился и снова превысил — он будет оповещён повторно.
        self._overlimit_reported = current_ids

    # ── Истекающие подписки (раз в сутки) ────────────────────────────

    async def _maybe_check_expiring(self, bot: Bot) -> None:
        now = datetime.now(timezone.utc)
        if now.hour < settings.alert_expiring_hour:
            return
        today = now.date()
        if self._last_expiry_run == today:
            return
        self._last_expiry_run = today

        try:
            data = await panel_api.get_expiring_clients(days=settings.alert_expiring_days)
        except PanelAPIError as exc:
            logger.warning("Expiring: недоступен: %s", exc.message)
            return

        clients = data.get("clients", []) or []
        if not clients:
            return

        lines = [
            f"⏰ <b>Истекают подписки ({settings.alert_expiring_days} дн.): {len(clients)}</b>\n"
        ]
        for c in clients[:20]:
            name = c.get("name") or f"#{c.get('id')}"
            lines.append(f"• {name} — {humanize_date(c.get('expires_at'))}")
        if len(clients) > 20:
            lines.append(f"… и ещё {len(clients) - 20}")
        await send_alert_to_admins(bot, "\n".join(lines))


alert_scheduler = AlertScheduler()
