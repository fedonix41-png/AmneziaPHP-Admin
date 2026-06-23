from __future__ import annotations

from aiogram import Router
from aiogram.exceptions import TelegramBadRequest
from aiogram.types import CallbackQuery

from keyboards.admin import admin_servers_menu_kb, simple_back_kb
from services.panel_api import PanelAPIError, panel_api
from utils.format import humanize_bytes, humanize_date


# ── helpers ────────────────────────────────────────────────────────────

async def _safe_edit(callback: CallbackQuery, text: str, **kwargs) -> bool:
    """Edit message, ignoring 'message is not modified' error (duplicate clicks)."""
    try:
        await callback.message.edit_text(text, **kwargs)
        return True
    except TelegramBadRequest as exc:
        if "message is not modified" in str(exc):
            return False
        raise


def _to_float(value) -> float | None:
    """Convert API value (may be str from PHP/PDO) to float."""
    if value is None:
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


def _to_int(value) -> int | None:
    """Convert API value (may be str from PHP/PDO) to int."""
    if value is None:
        return None
    try:
        return int(value)
    except (ValueError, TypeError):
        return None


router = Router(name="admin_servers")


@router.callback_query(lambda cb: cb.data == "admin:srv:monitor")
async def cb_admin_monitor(callback: CallbackQuery) -> None:
    from handlers.admin.menu import _get_server

    server_id = _get_server(callback.from_user.id)
    if not server_id:
        await callback.answer("⚠ Сначала выберите сервер", show_alert=True)
        return

    await callback.answer("⏳ Загрузка метрик…")

    try:
        metrics_list = await panel_api.server_metrics(server_id, hours=1)
        online = await panel_api.server_online(server_id)
    except PanelAPIError as exc:
        await _safe_edit(callback, f"⚠ {exc.message}", reply_markup=admin_servers_menu_kb(), parse_mode=None)
        return

    # latest metric
    latest = metrics_list[-1] if metrics_list else None

    lines = [f"📊 <b>Мониторинг сервера #{server_id}</b>\n"]
    if latest:
        cpu = _to_float(latest.get("cpu_percent"))
        ram_used = _to_int(latest.get("ram_used_mb"))
        ram_total = _to_int(latest.get("ram_total_mb"))
        disk_used = _to_float(latest.get("disk_used_gb"))
        disk_total = _to_float(latest.get("disk_total_gb"))
        rx = _to_float(latest.get("network_rx_mbps"))
        tx = _to_float(latest.get("network_tx_mbps"))
        ts = latest.get("collected_at")

        lines.append(f"🖥 CPU:  <b>{cpu:.1f}%</b>" if cpu is not None else "🖥 CPU: —")
        if ram_used is not None and ram_total is not None:
            ram_pct = ram_used / ram_total * 100
            lines.append(f"🧠 RAM:  <b>{ram_used} / {ram_total} МБ ({ram_pct:.0f}%)</b>")
        elif ram_used is not None:
            lines.append(f"🧠 RAM:  <b>{ram_used} МБ</b>")
        if disk_used is not None and disk_total is not None:
            disk_pct = disk_used / disk_total * 100
            lines.append(f"💾 Disk: <b>{disk_used:.1f} / {disk_total:.1f} ГБ ({disk_pct:.0f}%)</b>")
        if rx is not None:
            lines.append(f"⬇ RX:   <b>{rx:.2f} Mbps</b>")
        if tx is not None:
            lines.append(f"⬆ TX:   <b>{tx:.2f} Mbps</b>")
        if ts:
            lines.append(f"🕐 <i>{humanize_date(ts)}</i>")
    else:
        lines.append("ℹ Нет данных метрик за последний час.")

    lines.append(f"\n🟢 <b>Онлайн:</b> {len(online)}")
    if online:
        for name in online[:20]:
            lines.append(f"  • {name}")
        if len(online) > 20:
            lines.append(f"  … и ещё {len(online) - 20}")

    await _safe_edit(callback, "\n".join(lines), reply_markup=admin_servers_menu_kb())


@router.callback_query(lambda cb: cb.data == "admin:srv:diagnose")
async def cb_admin_diagnose(callback: CallbackQuery) -> None:
    from handlers.admin.menu import _get_server

    server_id = _get_server(callback.from_user.id)
    if not server_id:
        await callback.answer("⚠ Сначала выберите сервер", show_alert=True)
        return

    await callback.answer("⏳ Выполняется селф-тест…")
    try:
        selftest = await panel_api.server_selftest(server_id)
    except PanelAPIError as exc:
        await _safe_edit(
            callback,
            f"⚠ Селф-тест не удался: {exc.message}",
            reply_markup=admin_servers_menu_kb(),
            parse_mode=None,
        )
        return

    ok = selftest.get("success", False)
    mismatches = selftest.get("mismatches", [])
    checks = selftest.get("checks", {})

    lines = [f"🔧 <b>Диагностика сервера #{server_id}</b>\n"]
    if ok:
        lines.append("✅ Все проверки пройдены")
    else:
        lines.append("⚠ Обнаружены расхождения:")
        for m in mismatches:
            lines.append(f"  • {m}")

    if checks:
        lines.append("\n<b>Результаты проверок:</b>")
        for check_name, check_data in checks.items():
            if isinstance(check_data, dict):
                status = "✅" if check_data.get("ok") else "❌"
                lines.append(f"  {status} {check_name}")

    await _safe_edit(callback, "\n".join(lines), reply_markup=admin_servers_menu_kb())


@router.callback_query(lambda cb: cb.data.startswith("admin:handshake:"))
async def cb_admin_handshake(callback: CallbackQuery) -> None:
    from handlers.admin.menu import _get_server

    server_id = _get_server(callback.from_user.id)
    if not server_id:
        await callback.answer("⚠ Сначала выберите сервер", show_alert=True)
        return

    parts = callback.data.split(":")
    client_id = int(parts[2]) if len(parts) > 2 else 0

    await callback.answer("⏳ Диагностика рукопожатий (до 15 сек)…")
    try:
        result = await panel_api.server_diagnose_handshake(server_id, client_id=client_id, duration_seconds=5)
    except PanelAPIError as exc:
        await _safe_edit(callback, f"⚠ {exc.message}", reply_markup=admin_servers_menu_kb(), parse_mode=None)
        return

    hints = result.get("hints", [])
    lines = [f"🔧 <b>Диагностика сервера #{server_id}</b>\n"]
    if hints:
        for h in hints:
            lines.append(f"• {h}")
    else:
        lines.append("ℹ Явных проблем с рукопожатиями не обнаружено.")

    evidence = result.get("evidence", {})
    if evidence.get("docker_ps"):
        lines.append(f"\n📦 <code>{evidence['docker_ps'].strip()[:500]}</code>")

    await _safe_edit(callback, "\n".join(lines), reply_markup=admin_servers_menu_kb())
