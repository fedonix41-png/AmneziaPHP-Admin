from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional, Union

from aiogram.types import Message

from keyboards.client import back_to_main_kb, choose_client_kb
from services.panel_api import PanelAPIError, panel_api
from services.users import users_repo


@dataclass
class AuthContext:
    jwt: Optional[str]
    client_id: Optional[Union[int, str]]
    details: Optional[dict]
    clients: List[dict]
    need_select: bool
    error: Optional[str]


async def resolve_client(telegram_id: int, sync_stats: bool = False) -> AuthContext:
    jwt = await users_repo.get_jwt(telegram_id)
    if not jwt:
        return AuthContext(None, None, None, [], False, "🔒 Сначала авторизуйтесь — нажмите «🔑 Авторизация».")

    client_id = await users_repo.get_client_id(telegram_id)

    try:
        if client_id:
            details = await panel_api.client_details(jwt, client_id, sync_stats=sync_stats)
            return AuthContext(jwt, client_id, details, [], False, None)
        clients = await panel_api.list_my_clients(jwt)
    except PanelAPIError as exc:
        if exc.status_code == 401:
            await users_repo.logout(telegram_id)
            return AuthContext(None, None, None, [], False, "🔒 Сессия истекла. Авторизуйтесь снова.")
        return AuthContext(jwt, None, None, [], False, f"⚠ Не удалось получить данные: {exc.message}")

    if not clients:
        return AuthContext(jwt, None, None, [], False, "ℹ У вас нет активных подписок.")

    if len(clients) == 1:
        single_id = clients[0].get("id")
        if single_id:
            await users_repo.set_client_id(telegram_id, single_id)
            try:
                details = await panel_api.client_details(jwt, single_id, sync_stats=sync_stats)
            except PanelAPIError as exc:
                return AuthContext(jwt, single_id, None, [], False, f"⚠ Не удалось получить данные: {exc.message}")
            return AuthContext(jwt, single_id, details, [], False, None)
        return AuthContext(jwt, None, None, [], False, "ℹ Не удалось определить подписку.")

    return AuthContext(jwt, None, None, clients, True, None)


async def answer_unresolved(message: Message, ctx: AuthContext) -> bool:
    """Return True when the caller should abort because the context is not usable."""
    if ctx.error:
        await message.answer(ctx.error, reply_markup=back_to_main_kb())
        return True
    if ctx.need_select:
        await message.answer("Выберите подписку:", reply_markup=choose_client_kb(ctx.clients))
        return True
    if not ctx.details:
        await message.answer("⚠ Не удалось получить данные подписки.", reply_markup=back_to_main_kb())
        return True
    return False
