from __future__ import annotations

from io import BytesIO

from aiogram import Router
from aiogram.exceptions import TelegramBadRequest
from aiogram.types import BufferedInputFile, CallbackQuery

from keyboards.admin import (
    admin_servers_menu_kb,
    back_to_admin_kb,
    backup_action_kb,
    backup_list_kb,
)
from services.panel_api import PanelAPIError, panel_api
from utils.format import humanize_bytes, humanize_date

router = Router(name="admin_backups")


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

_stored_backup_server: dict[int, int] = {}


@router.callback_query(lambda cb: cb.data == "admin:srv:backups")
async def cb_admin_backups_menu(callback: CallbackQuery) -> None:
    from handlers.admin.menu import _get_server

    server_id = _get_server(callback.from_user.id)
    if not server_id:
        await callback.answer("⚠ Сначала выберите сервер", show_alert=True)
        return

    _stored_backup_server[callback.from_user.id] = server_id
    await _show_backup_list(callback, server_id)


async def _show_backup_list(callback: CallbackQuery, server_id: int) -> None:
    await callback.answer()  # acknowledge before API call
    try:
        data = await panel_api.list_backups(server_id)
    except PanelAPIError as exc:
        await _safe_edit(callback, f"⚠ {exc.message}", reply_markup=admin_servers_menu_kb(), parse_mode=None)
        return

    backups = data.get("backups", [])
    if not backups:
        await _safe_edit(
            callback,
            f"💾 <b>Бэкапы сервера #{server_id}</b>\n\nℹ Нет бэкапов.",
            reply_markup=backup_list_kb(server_id, []),
        )
        return

    lines = [f"💾 <b>Бэкапы сервера #{server_id} ({len(backups)})</b>:"]
    for b in backups[:10]:
        name = b.get("backup_name", "—")
        size_kb = (b.get("backup_size") or 0) // 1024
        ts = b.get("created_at", "")
        lines.append(f"  • {name} ({size_kb}KB, {humanize_date(ts)})")

    await _safe_edit(callback, "\n".join(lines), reply_markup=backup_list_kb(server_id, backups))


@router.callback_query(lambda cb: cb.data.startswith("admin:backup:select:"))
async def cb_admin_backup_select(callback: CallbackQuery) -> None:
    try:
        backup_id = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await _safe_edit(
        callback,
        f"💾 <b>Бэкап #{backup_id}</b>",
        reply_markup=backup_action_kb(backup_id),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:backup:create:"))
async def cb_admin_backup_create(callback: CallbackQuery) -> None:
    try:
        server_id = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await callback.answer("⏳ Создание бэкапа…")
    try:
        result = await panel_api.create_backup(server_id)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
        return

    backup = result.get("backup", {})
    bid = backup.get("id", "?")
    name = backup.get("backup_name", "")
    size = (backup.get("backup_size") or 0) // 1024

    await _safe_edit(
        callback,
        f"✅ <b>Бэкап создан!</b>\n#{bid} — {name} ({size}KB)",
        reply_markup=back_to_admin_kb(),
    )
    await _show_backup_list(callback, server_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:backup:download:"))
async def cb_admin_backup_download(callback: CallbackQuery) -> None:
    try:
        backup_id = int(callback.data.rsplit(":", 1)[1])
        await callback.answer("⏳ Скачивание…")
        content = await panel_api.download_backup(backup_id)
        buf = BytesIO(content)
        buf.name = f"backup_{backup_id}.json"
        await callback.message.answer_document(
            BufferedInputFile(content, filename=f"backup_{backup_id}.json"),
            caption=f"💾 Бэкап #{backup_id}",
        )
        await callback.answer()
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)


@router.callback_query(lambda cb: cb.data.startswith("admin:backup:delete:"))
async def cb_admin_backup_delete(callback: CallbackQuery) -> None:
    try:
        backup_id = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await callback.answer("⏳ Удаление…")
    try:
        await panel_api.delete_backup(backup_id)
        await callback.answer("✅ Бэкап удалён", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)

    server_id = _stored_backup_server.get(callback.from_user.id, 0)
    if server_id:
        await _show_backup_list(callback, server_id)


@router.callback_query(lambda cb: cb.data == "admin:backup:list")
async def cb_admin_backup_list_return(callback: CallbackQuery) -> None:
    server_id = _stored_backup_server.get(callback.from_user.id, 0)
    if server_id:
        await _show_backup_list(callback, server_id)
    else:
        await _safe_edit(callback, "ℹ Сервер не выбран.", reply_markup=back_to_admin_kb())
        await callback.answer()
