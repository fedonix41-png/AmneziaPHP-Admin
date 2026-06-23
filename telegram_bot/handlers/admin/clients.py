from __future__ import annotations

import re
from io import BytesIO

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import BufferedInputFile, CallbackQuery, Message

from keyboards.admin import (
    add_client_duration_kb,
    admin_clients_menu_kb,
    admin_client_list_kb,
    back_to_admin_kb,
    client_action_kb,
    expiration_options_kb,
    simple_back_kb,
    traffic_limit_presets_kb,
)
from services.panel_api import PanelAPIError, panel_api
from states.admin import AddClientStates
from utils.format import humanize_bytes, humanize_date, status_label

router = Router(name="admin_clients")

# ── Client action dispatch ─────────────────────────────────────────

@router.callback_query(lambda cb: cb.data.startswith("admin:client:select:"))
async def cb_admin_client_select(callback: CallbackQuery) -> None:
    from config import settings as bot_settings
    try:
        client_id = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await callback.answer()
    token = bot_settings.panel_api_token
    try:
        details = await panel_api.client_details(token, client_id)
    except PanelAPIError as exc:
        await callback.message.edit_text(
            f"⚠ {exc.message}", reply_markup=back_to_admin_kb(), parse_mode=None
        )
        return

    name = details.get("name") or f"Клиент #{client_id}"
    ip = details.get("client_ip", "—")
    status = details.get("status", "")
    stats = details.get("stats", {})
    expires = details.get("expires_at")
    traffic_limit = details.get("traffic_limit")
    srv_name = details.get("server_name", "")

    lines = [
        f"👤 <b>{name}</b>",
        f"ID: {client_id} | IP: {ip}",
        f"Статус: {status_label(status)}",
    ]
    if srv_name:
        lines.append(f"Сервер: {srv_name}")
    if expires:
        lines.append(f"Истекает: {humanize_date(expires)}")
    if stats:
        sent = stats.get("sent", "—")
        recv = stats.get("received", "—")
        lines.append(f"Трафик: ⬆ {sent} / ⬇ {recv}")
    if traffic_limit:
        lines.append(f"Лимит: {humanize_bytes(traffic_limit)}")
    lines.append(f"Онлайн: {'🟢 Да' if stats.get('is_online') else '⚪ Нет'}")

    await callback.message.edit_text(
        "\n".join(lines), reply_markup=client_action_kb(client_id, status)
    )


@router.callback_query(lambda cb: cb.data.startswith("admin:client:revoke:"))
async def cb_admin_revoke(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    try:
        await panel_api.revoke_client(client_id)
        await callback.answer("✅ Клиент заблокирован", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:client:restore:"))
async def cb_admin_restore(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    try:
        await panel_api.restore_client(client_id)
        await callback.answer("✅ Клиент разблокирован", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:client:extend:"))
async def cb_admin_extend(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    try:
        result = await panel_api.extend_client(client_id, days=30)
        new_exp = result.get("expires_at", "")
        await callback.answer(f"✅ Продлено до {new_exp}", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:client:delete:"))
async def cb_admin_delete(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    try:
        await panel_api.delete_client(client_id)
        await callback.message.edit_text(
            f"✅ Клиент #{client_id} удалён.", reply_markup=admin_clients_menu_kb()
        )
        await callback.answer()
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)


@router.callback_query(lambda cb: cb.data.startswith("admin:client:setexp:"))
async def cb_admin_setexp(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    await callback.message.edit_text(
        f"📅 <b>Установите срок для клиента #{client_id}:</b>",
        reply_markup=expiration_options_kb(client_id),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:exp:set:"))
async def cb_admin_exp_set(callback: CallbackQuery) -> None:
    parts = callback.data.split(":")
    client_id = int(parts[3])
    days = int(parts[4])
    try:
        result = await panel_api.extend_client(client_id, days=days)
        new_exp = result.get("expires_at", "")
        await callback.answer(f"✅ Установлено {days} дн. ({new_exp})", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:exp:clear:"))
async def cb_admin_exp_clear(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    try:
        await panel_api.set_client_expiration(client_id, None)
        await callback.answer("✅ Срок убран (бессрочно)", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


@router.callback_query(lambda cb: cb.data.startswith("admin:client:limit:"))
async def cb_admin_limit(callback: CallbackQuery) -> None:
    client_id = int(callback.data.rsplit(":", 1)[1])
    await callback.message.edit_text(
        f"📊 <b>Установите лимит трафика для клиента #{client_id}:</b>",
        reply_markup=traffic_limit_presets_kb(client_id),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:traffic:"))
async def cb_admin_traffic(callback: CallbackQuery) -> None:
    parts = callback.data.split(":")
    client_id = int(parts[2])
    limit_bytes = int(parts[3])
    try:
        await panel_api.set_traffic_limit(client_id, limit_bytes)
        label = "♾ без лимита" if limit_bytes == 0 else humanize_bytes(limit_bytes)
        await callback.answer(f"✅ Лимит: {label}", show_alert=True)
    except PanelAPIError as exc:
        await callback.answer(f"⚠ {exc.message}", show_alert=True)
    await _refresh_client_view(callback, client_id)


async def _refresh_client_view(callback: CallbackQuery, client_id: int) -> None:
    from config import settings as bot_settings
    try:
        details = await panel_api.client_details(bot_settings.panel_api_token, client_id)
        name = details.get("name") or f"Клиент #{client_id}"
        ip = details.get("client_ip", "—")
        status = details.get("status", "")
        stats = details.get("stats", {})
        expires = details.get("expires_at")
        traffic_limit = details.get("traffic_limit")
        srv_name = details.get("server_name", "")

        lines = [
            f"👤 <b>{name}</b>",
            f"ID: {client_id} | IP: {ip}",
            f"Статус: {status_label(status)}",
        ]
        if srv_name:
            lines.append(f"Сервер: {srv_name}")
        if expires:
            lines.append(f"Истекает: {humanize_date(expires)}")
        if stats:
            sent = stats.get("sent", "—")
            recv = stats.get("received", "—")
            lines.append(f"Трафик: ⬆ {sent} / ⬇ {recv}")
        if traffic_limit:
            lines.append(f"Лимит: {humanize_bytes(traffic_limit)}")
        lines.append(f"Онлайн: {'🟢 Да' if stats.get('is_online') else '⚪ Нет'}")

        await callback.message.edit_text(
            "\n".join(lines), reply_markup=client_action_kb(client_id, status)
        )
    except PanelAPIError as exc:
        await callback.message.edit_text(
            f"⚠ {exc.message}", reply_markup=back_to_admin_kb(), parse_mode=None
        )


# ── Expiring / Overlimit quick views ───────────────────────────────

@router.callback_query(lambda cb: cb.data == "admin:expiring")
async def cb_admin_expiring(callback: CallbackQuery) -> None:
    await callback.answer("⏳ Загрузка…")
    try:
        data = await panel_api.get_expiring_clients(days=7)
    except PanelAPIError as exc:
        await callback.message.edit_text(
            f"⚠ {exc.message}", reply_markup=back_to_admin_kb(), parse_mode=None
        )
        return

    clients = data.get("clients", [])
    if not clients:
        await callback.message.edit_text(
            "ℹ Нет истекающих подписок на ближайшие 7 дней.",
            reply_markup=back_to_admin_kb(),
        )
        return

    lines = [f"📋 <b>Истекающие подписки (7 дн.): {len(clients)}</b>\n"]
    for c in clients[:15]:
        name = c.get("name") or f"#{c.get('id')}"
        exp = humanize_date(c.get("expires_at"))
        lines.append(f"• {name} — {exp}")
    if len(clients) > 15:
        lines.append(f"… и ещё {len(clients) - 15}")

    await callback.message.edit_text(
        "\n".join(lines), reply_markup=back_to_admin_kb()
    )


@router.callback_query(lambda cb: cb.data == "admin:overlimit")
async def cb_admin_overlimit(callback: CallbackQuery) -> None:
    await callback.answer("⏳ Загрузка…")
    try:
        data = await panel_api.get_overlimit_clients()
    except PanelAPIError as exc:
        await callback.message.edit_text(
            f"⚠ {exc.message}", reply_markup=back_to_admin_kb(), parse_mode=None
        )
        return

    clients = data.get("clients", [])
    if not clients:
        await callback.message.edit_text(
            "ℹ Нет клиентов с превышением лимита.",
            reply_markup=back_to_admin_kb(),
        )
        return

    lines = [f"🚨 <b>Превышение лимита: {len(clients)}</b>\n"]
    for c in clients[:15]:
        name = c.get("name") or f"#{c.get('id')}"
        limit = humanize_bytes(c.get("traffic_limit", 0))
        lines.append(f"• {name} (лимит: {limit})")
    if len(clients) > 15:
        lines.append(f"… и ещё {len(clients) - 15}")

    await callback.message.edit_text(
        "\n".join(lines), reply_markup=back_to_admin_kb()
    )


# ── /add_client FSM ─────────────────────────────────────────────────

from config import settings


@router.callback_query(lambda cb: cb.data == "admin:clients:add")
@router.message(F.text.startswith("/add_client"))
async def cmd_add_client(event: Message | CallbackQuery, state: FSMContext) -> None:
    if isinstance(event, CallbackQuery):
        msg = event.message
        await event.answer()
    else:
        msg = event

    # extract optional name from /add_client MyName
    if isinstance(event, Message) and event.text:
        name = event.text.removeprefix("/add_client").strip()
        if name:
            await state.update_data(client_name=name)
            await state.set_state(AddClientStates.waiting_server)
            try:
                servers = await panel_api.list_servers()
            except PanelAPIError as exc:
                await msg.answer(f"⚠ {exc.message}", reply_markup=back_to_admin_kb())
                await state.clear()
                return
            from keyboards.admin import server_list_kb
            await msg.answer(
                f"🖥 <b>Выберите сервер для «{name}»:</b>",
                reply_markup=server_list_kb(servers, "admin:add:srv"),
            )
            return

    await state.set_state(AddClientStates.waiting_name)
    await msg.answer(
        "🚀 <b>Быстрое создание клиента</b>\n\nВведите имя клиента:",
        reply_markup=simple_back_kb("admin:menu"),
    )


@router.message(AddClientStates.waiting_name)
async def step_add_name(message: Message, state: FSMContext) -> None:
    name = (message.text or "").strip()
    if not name or len(name) < 2:
        await message.answer("⚠ Имя должно быть не короче 2 символов. Попробуйте снова:")
        return
    await state.update_data(client_name=name)
    await state.set_state(AddClientStates.waiting_server)

    try:
        servers = await panel_api.list_servers()
    except PanelAPIError as exc:
        await message.answer(f"⚠ {exc.message}", reply_markup=back_to_admin_kb())
        await state.clear()
        return

    from keyboards.admin import server_list_kb
    await message.answer(
        f"🖥 <b>Выберите сервер для «{name}»:</b>",
        reply_markup=server_list_kb(servers, "admin:add:srv"),
    )


@router.callback_query(lambda cb: cb.data.startswith("admin:add:srv:"))
async def step_add_server(callback: CallbackQuery, state: FSMContext) -> None:
    try:
        server_id = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await state.update_data(server_id=server_id)
    await state.set_state(AddClientStates.waiting_duration)

    data = await state.get_data()
    name = data.get("client_name", "—")

    await callback.message.edit_text(
        f"⏱ <b>Срок действия для «{name}»:</b>",
        reply_markup=add_client_duration_kb(),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:adddur:"))
async def step_add_duration(callback: CallbackQuery, state: FSMContext) -> None:
    try:
        days = int(callback.data.rsplit(":", 1)[1])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    await state.update_data(days=days)
    data = await state.get_data()
    name = data.get("client_name", "")
    server_id = data.get("server_id", 0)
    days = data.get("days", 0)

    await callback.answer("⏳ Создание клиента…")

    try:
        result = await panel_api.create_client(
            server_id=server_id,
            name=name,
            expires_in_days=days if days > 0 else None,
        )
    except PanelAPIError as exc:
        await callback.message.edit_text(
            f"⚠ Не удалось создать: {exc.message}",
            reply_markup=back_to_admin_kb(),
            parse_mode=None,
        )
        await state.clear()
        return

    cid = result.get("id", "?")
    config_text = result.get("config", "")
    qr_b64 = result.get("qr_code", "")
    expires = result.get("expires_at")

    lines = [
        f"✅ <b>Клиент создан!</b>",
        f"ID: {cid} | Имя: {name}",
        f"Сервер: #{server_id}",
    ]
    if expires and days > 0:
        lines.append(f"Срок: {humanize_date(expires)} ({days} дн.)")
    elif days == 0:
        lines.append("Срок: ♾ бессрочно")

    await callback.message.edit_text("\n".join(lines), reply_markup=back_to_admin_kb())

    if qr_b64:
        try:
            raw = _b64_to_bytes(qr_b64)
            await callback.message.answer_photo(
                BufferedInputFile(raw, filename=f"qr_{cid}.png"),
                caption=f"QR-код для «{name}»",
            )
        except Exception:
            pass

    if config_text:
        buf = BytesIO(config_text.encode("utf-8"))
        buf.name = f"client_{cid}.conf"
        await callback.message.answer_document(
            BufferedInputFile(buf.read(), filename=f"client_{cid}.conf"),
            caption=f"⚙ Конфиг для «{name}»",
        )

    await state.clear()


def _b64_to_bytes(data_uri: str) -> bytes:
    import base64
    if "," in data_uri:
        data_uri = data_uri.split(",", 1)[1]
    return base64.b64decode(data_uri)
