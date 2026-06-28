from __future__ import annotations

import logging
from typing import Optional

from aiogram import Bot

from config import settings

# Отдельный логгер аудита деструктивных действий (блокировки, удаления, сбросы).
# По умолчанию propagates в корневой логгер (stdout). Если задан AUDIT_LOG_FILE,
# в telegram_bot/bot.py::configure_logging к нему подвешивается FileHandler и
# propagate отключается — аудит пишется только в отдельный файл.
audit_logger = logging.getLogger("audit")


class AuditService:
    """Фиксирует деструктивные действия (см. docs/telegram_bot_spec.md#7, строка 216).

    Всегда пишет запись в `audit` логгер. При settings.audit_notify_admins
    дополнительно рассылает уведомление администраторам через send_alert_to_admins.
    """

    async def log(
        self,
        bot: Optional[Bot],
        *,
        action: str,
        target: str,
        actor_id: Optional[int] = None,
        actor_name: str = "",
        details: str = "",
    ) -> None:
        if not settings.audit_enabled:
            return

        actor = actor_name or (str(actor_id) if actor_id is not None else "—")
        line = f"action={action} target={target} actor={actor}"
        if details:
            line += f" {details}"
        audit_logger.warning(line)

        if settings.audit_notify_admins and bot is not None:
            # Ленивый импорт, чтобы избежать цикла services.alerts ↔ handlers.
            from services.alerts import send_alert_to_admins

            text = (
                f"📝 <b>Аудит: {action}</b>\n"
                f"Объект: <code>{target}</code>\n"
                f"Админ: {actor}"
            )
            if details:
                text += f"\n{details}"
            try:
                await send_alert_to_admins(bot, text)
            except Exception:  # noqa: BLE001 — аудит не должен ронять действие
                audit_logger.warning("audit: не удалось отправить уведомление админам")


audit = AuditService()
