from __future__ import annotations

import logging
from typing import Any, Dict

from aiogram import Router
from aiogram.types import CallbackQuery

from keyboards.admin import (
    admin_clients_menu_kb,
    admin_main_kb,
    admin_servers_menu_kb,
    admin_client_list_kb,
    server_list_kb,
    simple_back_kb,
)
from services.panel_api import PanelAPIError, panel_api

logger = logging.getLogger(__name__)
router = Router(name="admin_menu")

# shared persistent cache for the current server id per callback flow
_selected_server: Dict[int, int] = {}


def _uid(callback: CallbackQuery) -> int:
    return callback.from_user.id


def _store_server(user_id: int, server_id: int) -> None:
    _selected_server[user_id] = server_id


def _get_server(user_id: int) -> int:
    return _selected_server.get(user_id, 0)


@router.callback_query(lambda cb: cb.data == "admin:menu")
async def cb_admin_main(callback: CallbackQuery) -> None:
    await callback.message.edit_text(
        "🛠 <b>Админ-панель</b>\n\nВыберите раздел:",
        reply_markup=admin_main_kb(),
    )
    await callback.answer()


# ── Серверы → подменю ────────────────────────────────────────────────

@router.callback_query(lambda cb: cb.data == "admin:servers")
async def cb_admin_servers_menu(callback: CallbackQuery) -> None:
    servers: list = []
    error = None
    try:
        servers = await panel_api.list_servers()
    except PanelAPIError as exc:
        error = f"⚠ {exc.message}"

    if error:
        await callback.message.edit_text(error, reply_markup=admin_main_kb(), parse_mode=None)
        await callback.answer()
        return

    if not servers:
        await callback.message.edit_text(
            "ℹ Нет серверов.", reply_markup=admin_main_kb()
        )
        await callback.answer()
        return

    # show server list and let the admin pick one
    await callback.message.edit_text(
        "🖥 <b>Выберите сервер:</b>",
        reply_markup=server_list_kb(servers, "admin:srv:pick"),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:srv:pick:"))
async def cb_admin_pick_server(callback: CallbackQuery) -> None:
    try:
        server_id = int(callback.data.split(":")[3])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    _store_server(_uid(callback), server_id)
    await callback.message.edit_text(
        f"🖥 <b>Сервер #{server_id}</b>\n\nВыберите действие:",
        reply_markup=admin_servers_menu_kb(),
    )
    await callback.answer()


# ── Клиенты → подменю ────────────────────────────────────────────────

@router.callback_query(lambda cb: cb.data == "admin:clients")
async def cb_admin_clients_menu(callback: CallbackQuery) -> None:
    await callback.message.edit_text(
        "👥 <b>Управление клиентами</b>\n\nВыберите действие:",
        reply_markup=admin_clients_menu_kb(),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data == "admin:clients:manage")
async def cb_admin_clients_manage(callback: CallbackQuery) -> None:
    servers: list = []
    error: Any = None
    try:
        servers = await panel_api.list_servers()
    except PanelAPIError as exc:
        error = f"⚠ {exc.message}"

    if error:
        await callback.message.edit_text(error, reply_markup=admin_clients_menu_kb(), parse_mode=None)
        await callback.answer()
        return

    await callback.message.edit_text(
        "🖥 <b>Выберите сервер для просмотра клиентов:</b>",
        reply_markup=server_list_kb(servers, "admin:mgmt:srv"),
    )
    await callback.answer()


@router.callback_query(lambda cb: cb.data.startswith("admin:mgmt:srv:"))
async def cb_admin_mgmt_server(callback: CallbackQuery) -> None:
    try:
        server_id = int(callback.data.split(":")[3])
    except (IndexError, ValueError):
        await callback.answer("⚠ Ошибка", show_alert=True)
        return

    _store_server(_uid(callback), server_id)
    clients: list = []
    error = None
    try:
        clients = await panel_api.server_clients(server_id)
    except PanelAPIError as exc:
        error = f"⚠ {exc.message}"

    if error:
        await callback.message.edit_text(error, reply_markup=admin_clients_menu_kb(), parse_mode=None)
        await callback.answer()
        return

    if not clients:
        await callback.message.edit_text(
            "ℹ На сервере нет клиентов.", reply_markup=admin_clients_menu_kb()
        )
        await callback.answer()
        return

    await callback.message.edit_text(
        f"👥 <b>Клиенты сервера #{server_id}:</b>",
        reply_markup=admin_client_list_kb(clients),
    )
    await callback.answer()
