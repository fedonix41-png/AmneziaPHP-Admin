from __future__ import annotations

from typing import List

from aiogram.types import (
    InlineKeyboardButton,
    InlineKeyboardMarkup,
)


def main_menu_kb(authorized: bool, is_admin: bool, payments_enabled: bool = False) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []

    if not authorized:
        rows.append([InlineKeyboardButton(text="🔑 Авторизация", callback_data="auth:login")])
    else:
        rows.append([
            InlineKeyboardButton(text="📋 Мои подписки", callback_data="menu:my_configs"),
            InlineKeyboardButton(text="📊 Моя статистика", callback_data="menu:stats"),
        ])
        rows.append([
            InlineKeyboardButton(text="🚪 Выйти", callback_data="auth:logout"),
        ])
        rows.append([
            InlineKeyboardButton(text="📱 QR-код", callback_data="menu:qr"),
            InlineKeyboardButton(text="📄 Файл .conf", callback_data="menu:conf"),
        ])
        rows.append([InlineKeyboardButton(text="🔄 Сбросить ключ", callback_data="menu:reset")])
        if payments_enabled:
            rows.append([InlineKeyboardButton(text="💳 Продлить подписку", callback_data="menu:pay")])
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


_CURRENCY_SYMBOLS = {
    "RUB": "₽",
    "USD": "$",
    "EUR": "€",
    "UAH": "₴",
    "KZT": "₸",
    "GBP": "£",
    "XTR": "Stars",
}


def currency_label(code: str) -> str:
    code = (code or "").upper()
    return _CURRENCY_SYMBOLS.get(code, code)


def pay_tariffs_kb(tariffs, currency: str) -> InlineKeyboardMarkup:
    sym = currency_label(currency)
    rows: List[List[InlineKeyboardButton]] = []
    for i, t in enumerate(tariffs):
        price = f"{t.price} {sym}".strip()
        rows.append(
            [InlineKeyboardButton(text=f"{t.label} — {price}", callback_data=f"pay:tariff:{i}")]
        )
    rows.append([InlineKeyboardButton(text="🏠 Главное меню", callback_data="menu:main")])
    return InlineKeyboardMarkup(inline_keyboard=rows)
