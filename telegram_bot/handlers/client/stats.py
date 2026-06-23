from __future__ import annotations

from aiogram import F, Router
from aiogram.types import CallbackQuery

from handlers.client.common import answer_unresolved, resolve_client
from keyboards.client import back_to_main_kb
from utils.format import (
    humanize_bytes,
    humanize_date,
    online_label,
    status_label,
)

router = Router(name="client.stats")


@router.callback_query(F.data == "menu:stats")
async def cb_stats(callback: CallbackQuery) -> None:
    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return

    details = ctx.details or {}
    stats = details.get("stats") or {}

    name = details.get("name") or f"Клиент #{ctx.client_id}"
    status = status_label(details.get("status"))
    online = online_label(stats.get("is_online"))
    sent = humanize_bytes(stats.get("sent") or details.get("bytes_sent"))
    received = humanize_bytes(stats.get("received") or details.get("bytes_received"))
    total = humanize_bytes(stats.get("total"))
    last_seen = stats.get("last_seen") or "—"
    created = humanize_date(details.get("created_at"))
    expires = humanize_date(details.get("expires_at"))
    ip = details.get("client_ip") or "—"

    text = (
        f"📊 <b>Статистика подписки</b>\n\n"
        f"👤 <b>{name}</b>\n"
        f"Статус: {status}\n"
        f"Подключение: {online}\n"
        f"IP-адрес: <code>{ip}</code>\n\n"
        f"📥 Отдано серверу: <b>{sent}</b>\n"
        f"📤 Получено: <b>{received}</b>\n"
        f"Σ Всего трафика: <b>{total}</b>\n\n"
        f"🕒 Последнее подключение: {last_seen}\n"
        f"📅 Создан: {created}\n"
        f"⏰ Действует до: {expires}"
    )

    await callback.message.answer(text, reply_markup=back_to_main_kb())
    await callback.answer()
