from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from aiogram import F, Router
from aiogram.filters import StateFilter
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from config import settings
from handlers.start import show_main_menu
from keyboards.client import back_to_main_kb, cancel_kb, choose_client_kb, main_menu_kb
from services.panel_api import PanelAPIError, panel_api
from services.users import users_repo
from states.auth import AuthStates

router = Router(name="auth")


@router.callback_query(F.data == "auth:login")
async def cb_login(callback: CallbackQuery, state: FSMContext) -> None:
    await state.clear()
    await callback.message.answer(
        "🔑 <b>Авторизация</b>\n\nВведите email от аккаунта веб-панели:",
        reply_markup=cancel_kb(),
    )
    await state.set_state(AuthStates.waiting_email)
    await callback.answer()


@router.message(StateFilter(AuthStates.waiting_email))
async def on_email(message: Message, state: FSMContext) -> None:
    email = (message.text or "").strip()
    if "@" not in email:
        await message.answer("⚠ Неверный формат email. Попробуйте снова:", reply_markup=cancel_kb())
        return
    await state.update_data(email=email)
    await message.answer("🔑 Введите пароль:", reply_markup=cancel_kb())
    await state.set_state(AuthStates.waiting_password)


@router.message(StateFilter(AuthStates.waiting_password))
async def on_password(message: Message, state: FSMContext) -> None:
    password = (message.text or "").strip()
    try:
        await message.delete()
    except Exception:
        pass

    data: dict[str, Any] = await state.get_data()
    email = data.get("email", "")
    telegram_id = message.from_user.id

    await state.clear()

    if not password:
        await message.answer("⚠ Пароль пуст. Авторизация отменена.", reply_markup=back_to_main_kb())
        return

    try:
        result = await panel_api.authenticate(email, password)
    except PanelAPIError as exc:
        await message.answer(f"❌ Авторизация не удалась: {exc.message}", reply_markup=back_to_main_kb())
        return

    token = result.get("token")
    expires_in = int(result.get("expires_in") or 30 * 24 * 3600)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

    if not token:
        await message.answer("❌ Сервер не вернул токен.", reply_markup=back_to_main_kb())
        return

    await users_repo.upsert_auth(telegram_id, email, token, expires_at)

    try:
        clients = await panel_api.list_my_clients(token)
    except PanelAPIError as exc:
        await message.answer(
            f"✅ Авторизация прошла, но не удалось получить подписки: {exc.message}",
            reply_markup=back_to_main_kb(),
        )
        return

    if not clients:
        await message.answer(
            "✅ Вы авторизованы, но активных подписок не найдено.",
            reply_markup=main_menu_kb(True, settings.is_admin(message.from_user.id), settings.payments_enabled),
        )
        await show_main_menu(message, message.chat.id, telegram_id)
        return

    if len(clients) == 1:
        cid = clients[0].get("id")
        if cid:
            await users_repo.set_client_id(telegram_id, cid)
        await message.answer(
            "✅ Авторизация успешна! Подписка привязана.",
            reply_markup=main_menu_kb(True, settings.is_admin(telegram_id), settings.payments_enabled),
        )
        return

    await message.answer(
        "✅ Авторизация успешна! Найдено несколько подписок — выберите основную:",
        reply_markup=choose_client_kb(clients),
    )


@router.callback_query(F.data == "auth:logout")
async def cb_logout(callback: CallbackQuery) -> None:
    telegram_id = callback.from_user.id
    await users_repo.logout(telegram_id)
    await callback.message.answer("🚪 Вы вышли. Сессия очищена.")
    await show_main_menu(callback.message, callback.message.chat.id, telegram_id)
    await callback.answer()


@router.callback_query(F.data.startswith("client:pick:"))
async def cb_pick_client(callback: CallbackQuery) -> None:
    telegram_id = callback.from_user.id
    try:
        client_id = int(callback.data.split(":")[-1])
    except (ValueError, IndexError):
        await callback.answer("Неверный выбор", show_alert=True)
        return
    await users_repo.set_client_id(telegram_id, client_id)
    await callback.message.answer(
        "✅ Подписка выбрана.",
        reply_markup=main_menu_kb(True, settings.is_admin(telegram_id), settings.payments_enabled),
    )
    await callback.answer()
