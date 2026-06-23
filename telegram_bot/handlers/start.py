from __future__ import annotations

from config import settings
from keyboards.client import main_menu_kb
from services.users import users_repo

from aiogram import Router
from aiogram.filters import Command
from aiogram.types import Message

router = Router(name="start")

WELCOME = (
    "👋 Здравствуйте! Это бот <b>{name}</b>.\n\n"
    "Здесь вы можете управлять своей VPN-подпиской: получить конфигурацию, "
    "QR-код, посмотреть статистику, сбросить ключ и задать вопрос AI-помощнику."
)


async def show_main_menu(message: Message, chat_id: int, telegram_id: int) -> None:
    jwt = await users_repo.get_jwt(telegram_id)
    authorized = bool(jwt)
    is_admin = settings.is_admin(telegram_id)

    if authorized:
        text = "📋 <b>Главное меню</b>\nВыберите действие:"
    else:
        text = WELCOME.format(name=settings.panel_app_name)

    await message.answer(text, reply_markup=main_menu_kb(authorized, is_admin))


@router.message(Command("start"))
@router.message(Command("help"))
async def cmd_start(message: Message) -> None:
    telegram_id = message.from_user.id
    if settings.is_admin(telegram_id):
        await users_repo.mark_admin(telegram_id)
    await show_main_menu(message, message.chat.id, telegram_id)
