from __future__ import annotations

from aiogram import F, Router
from aiogram.types import CallbackQuery

from handlers.start import show_main_menu

router = Router(name="client.menu")


@router.callback_query(F.data == "menu:main")
async def cb_main(callback: CallbackQuery) -> None:
    await show_main_menu(callback.message, callback.message.chat.id, callback.from_user.id)
    await callback.answer()


@router.callback_query(F.data == "admin:menu")
async def cb_admin_menu(callback: CallbackQuery) -> None:
    await callback.message.answer(
        "🛠 <b>Админ-панель</b>\n\n"
        "Админский функционал (мониторинг серверов, управление клиентами, "
        "быстрое создание, бэкапы) будет добавлен в следующей итерации.",
        reply_markup=None,
    )
    await show_main_menu(callback.message, callback.message.chat.id, callback.from_user.id)
    await callback.answer()
