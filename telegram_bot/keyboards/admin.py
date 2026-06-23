from __future__ import annotations

from typing import Any, Dict, List

from aiogram.types import InlineKeyboardButton, InlineKeyboardMarkup


def admin_main_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🖥 Серверы", callback_data="admin:servers")],
        [InlineKeyboardButton(text="👥 Клиенты", callback_data="admin:clients")],
        [InlineKeyboardButton(text="📋 Истекающие подписки", callback_data="admin:expiring")],
        [InlineKeyboardButton(text="🚨 Превышение лимита", callback_data="admin:overlimit")],
        [InlineKeyboardButton(text="🔙 Главное меню", callback_data="menu:main")],
    ])


def admin_servers_menu_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📊 Мониторинг", callback_data="admin:srv:monitor")],
        [InlineKeyboardButton(text="🔧 Диагностика", callback_data="admin:srv:diagnose")],
        [InlineKeyboardButton(text="💾 Бэкапы", callback_data="admin:srv:backups")],
        [InlineKeyboardButton(text="🔙 В админ-меню", callback_data="admin:menu")],
    ])


def admin_clients_menu_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📋 Управление клиентами", callback_data="admin:clients:manage")],
        [InlineKeyboardButton(text="🚀 Быстрое создание", callback_data="admin:clients:add")],
        [InlineKeyboardButton(text="🔙 В админ-меню", callback_data="admin:menu")],
    ])


def server_list_kb(servers: List[Dict[str, Any]], prefix: str) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []
    for srv in servers:
        sid = srv.get("id")
        name = srv.get("name") or f"Сервер #{sid}"
        host = srv.get("host", "")
        label = f"{name} ({host})" if host else name
        rows.append([InlineKeyboardButton(text=label, callback_data=f"{prefix}:{sid}")])
    rows.append([InlineKeyboardButton(text="🔙 Назад", callback_data="admin:menu")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def admin_client_list_kb(clients: List[Dict[str, Any]]) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []
    for c in clients:
        cid = c.get("id")
        name = c.get("name") or f"Клиент #{cid}"
        ip = c.get("client_ip", "")
        label = f"{name} ({ip})" if ip else name
        rows.append([InlineKeyboardButton(text=label, callback_data=f"admin:client:select:{cid}")])
    rows.append([InlineKeyboardButton(text="🔙 Назад", callback_data="admin:menu")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def client_action_kb(client_id: int, status: str) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []
    cid = str(client_id)

    if status in ("active", "expired"):
        rows.append([InlineKeyboardButton(text="🔒 Заблокировать", callback_data=f"admin:client:revoke:{cid}")])
    if status == "revoked":
        rows.append([InlineKeyboardButton(text="🔓 Разблокировать", callback_data=f"admin:client:restore:{cid}")])
    if status != "disabled":
        rows.append([InlineKeyboardButton(text="⏱ Продлить на 30 дн.", callback_data=f"admin:client:extend:{cid}")])
    rows.append([
        InlineKeyboardButton(text="📅 Срок", callback_data=f"admin:client:setexp:{cid}"),
        InlineKeyboardButton(text="📊 Лимит", callback_data=f"admin:client:limit:{cid}"),
    ])
    rows.append([InlineKeyboardButton(text="🗑 Удалить", callback_data=f"admin:client:delete:{cid}")])
    rows.append([InlineKeyboardButton(text="🔙 К списку клиентов", callback_data="admin:clients:manage")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def expiration_options_kb(client_id: int) -> InlineKeyboardMarkup:
    cid = str(client_id)
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="7 дней", callback_data=f"admin:exp:set:{cid}:7")],
        [InlineKeyboardButton(text="30 дней", callback_data=f"admin:exp:set:{cid}:30")],
        [InlineKeyboardButton(text="90 дней", callback_data=f"admin:exp:set:{cid}:90")],
        [InlineKeyboardButton(text="365 дней", callback_data=f"admin:exp:set:{cid}:365")],
        [InlineKeyboardButton(text="♾ Бессрочно", callback_data=f"admin:exp:clear:{cid}")],
        [InlineKeyboardButton(text="🔙 Назад", callback_data=f"admin:client:select:{cid}")],
    ])


def traffic_limit_presets_kb(client_id: int) -> InlineKeyboardMarkup:
    cid = str(client_id)
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="100 МБ", callback_data=f"admin:traffic:{cid}:104857600")],
        [InlineKeyboardButton(text="500 МБ", callback_data=f"admin:traffic:{cid}:524288000")],
        [InlineKeyboardButton(text="1 ГБ", callback_data=f"admin:traffic:{cid}:1073741824")],
        [InlineKeyboardButton(text="5 ГБ", callback_data=f"admin:traffic:{cid}:5368709120")],
        [InlineKeyboardButton(text="10 ГБ", callback_data=f"admin:traffic:{cid}:10737418240")],
        [InlineKeyboardButton(text="♾ Без лимита", callback_data=f"admin:traffic:{cid}:0")],
        [InlineKeyboardButton(text="🔙 Назад", callback_data=f"admin:client:select:{cid}")],
    ])


def add_client_duration_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="7 дней", callback_data="admin:adddur:7")],
        [InlineKeyboardButton(text="30 дней", callback_data="admin:adddur:30")],
        [InlineKeyboardButton(text="90 дней", callback_data="admin:adddur:90")],
        [InlineKeyboardButton(text="365 дней", callback_data="admin:adddur:365")],
        [InlineKeyboardButton(text="♾ Бессрочно", callback_data="admin:adddur:0")],
        [InlineKeyboardButton(text="✖ Отмена", callback_data="admin:menu")],
    ])


def backup_list_kb(server_id: int, backups: List[Dict[str, Any]]) -> InlineKeyboardMarkup:
    rows: List[List[InlineKeyboardButton]] = []
    for b in backups:
        bid = b.get("id")
        name = b.get("backup_name") or f"Бэкап #{bid}"
        size_kb = (b.get("backup_size") or 0) // 1024
        created = b.get("created_at", "")[:10]
        label = f"{name} ({size_kb}KB, {created})"
        rows.append([InlineKeyboardButton(text=label, callback_data=f"admin:backup:select:{bid}")])
    rows.append([InlineKeyboardButton(text="📦 Создать бэкап", callback_data=f"admin:backup:create:{server_id}")])
    rows.append([InlineKeyboardButton(text="🔙 Назад", callback_data="admin:menu")])
    return InlineKeyboardMarkup(inline_keyboard=rows)


def backup_action_kb(backup_id: int) -> InlineKeyboardMarkup:
    bid = str(backup_id)
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="⬇ Скачать", callback_data=f"admin:backup:download:{bid}")],
        [InlineKeyboardButton(text="🗑 Удалить", callback_data=f"admin:backup:delete:{bid}")],
        [InlineKeyboardButton(text="🔙 К списку бэкапов", callback_data="admin:backup:list")],
    ])


def back_to_admin_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔙 В админ-меню", callback_data="admin:menu")]
    ])


def simple_back_kb(callback_data: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="🔙 Назад", callback_data=callback_data)]
    ])
