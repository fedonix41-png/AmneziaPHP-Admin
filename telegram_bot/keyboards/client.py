from __future__ import annotations

from typing import List

from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
)


def main_menu_kb(authorized: bool, is_admin: bool) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []

    if not authorized:
        rows.append([InlineKeyboardButton(text="🔑 Авторизация", callback_data="auth:login")])
    else:
        rows.append([
            InlineKeyboardButton(text="📊 Моя статистика", callback_data="menu:stats"),
            InlineKeyboardButton(text="🚪 Выйти", callback_data="auth:logout"),
        ])
        rows.append([
            InlineKeyboardButton(text="📱 QR-код", callback_data="menu:qr"),
            InlineKeyboardButton(text="📄 Файл .conf", callback_data="menu:conf"),
        ])
        rows.append([InlineKeyboardButton(text="🔄 Сбросить ключ", callback_data="menu:reset")])
        rows.append([InlineKeyboardButton(text="🤖 AI-помощник", callback_data="menu:ai")])

    if not authorized:
        rows.append([InlineKeyboardButton(text="🤖 AI-помощник", callback_data="menu:ai")])

    rows.append([InlineKeyboardButton(text="🏠 Главное меню", callback_data="menu:main")])

    if is_admin:
        rows.append([InlineKeyboardButton(text="🛠 Админ-панель", callback_data="admin:menu")])

    return InlineKeyboardMarkup(inline_keyboard=rows)


def back_to_main_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[[InlineKeyboardButton(text="🏠 Главное меню", callback_data="menu:main")]]
    )


def cancel_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[[InlineKeyboardButton(text="✖ Отмена", callback_data="menu:main")]]
    )


def choose_client_kb(clients) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []
    for client in clients:
        cid = client.get("id")
        name = client.get("name") or f"Клиент #{cid}"
        rows.append([InlineKeyboardButton(text=name, callback_data=f"client:pick:{cid}")])
    rows.append([InlineKeyboardButton(text="✖ Отмена", callback_data="menu:main")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def reset_confirm_kb(client_id: int) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="⚠ Да, сбросить", callback_data=f"menu:reset_confirm:{client_id}")],
            [InlineKeyboardButton(text="✖ Отмена", callback_data="menu:main")],
        ]
    )
