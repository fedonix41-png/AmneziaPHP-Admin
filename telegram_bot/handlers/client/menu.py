from __future__ import annotations

from aiogram import F, Router
from aiogram.types import CallbackQuery

from handlers.start import show_main_menu

router = Router(name="client.menu")


@router.callback_query(F.data == "menu:main")
async def cb_main(callback: CallbackQuery) -> None:
    await show_main_menu(callback.message, callback.message.chat.id, callback.from_user.id)
    await callback.answer()


@router.callback_query(F.data == "menu:my_configs")
async def cb_my_configs(callback: CallbackQuery) -> None:
    from services.users import users_repo
    from handlers.client.common import resolve_client, answer_unresolved
    
    await users_repo.set_client_id(callback.from_user.id, None)
    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return
    
    # If there is only one client, it gets auto-selected and answer_unresolved returns False
    await callback.message.answer(
        "У вас только одна подписка, она выбрана автоматически.",
    )
    await show_main_menu(callback.message, callback.message.chat.id, callback.from_user.id)
    await callback.answer()
