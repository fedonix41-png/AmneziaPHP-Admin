from __future__ import annotations

import base64

from aiogram import Bot, F, Router
from aiogram.types import BufferedInputFile, CallbackQuery

from handlers.client.common import answer_unresolved, resolve_client
from keyboards.client import back_to_main_kb, reset_confirm_kb
from services.audit import audit
from services.panel_api import PanelAPIError, panel_api
from services.users import users_repo

router = Router(name="client.config")

_QR_PREFIX = "data:image/png;base64,"


def _b64_to_bytes(data_uri: str | None) -> bytes | None:
    if not data_uri:
        return None
    if "," in data_uri:
        data_uri = data_uri.split(",", 1)[1]
    try:
        return base64.b64decode(data_uri)
    except (ValueError, TypeError):
        return None


async def _safe_answer(callback: CallbackQuery, text: str) -> None:
    await callback.message.answer(text, reply_markup=back_to_main_kb())
    await callback.answer()


@router.callback_query(F.data == "menu:qr")
async def cb_qr(callback: CallbackQuery) -> None:
    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return

    details = ctx.details or {}
    png = _b64_to_bytes(details.get("qr_code"))
    png_vpn = _b64_to_bytes(details.get("qr_code_vpn"))
    
    if not png:
        try:
            qr_resp = await panel_api.client_qr(ctx.jwt, ctx.client_id)
            png = _b64_to_bytes(qr_resp.get("qr_code"))
            png_vpn = _b64_to_bytes(qr_resp.get("qr_code_vpn"))
        except PanelAPIError as exc:
            await _safe_answer(callback, f"⚠ Не удалось получить QR-код: {exc.message}")
            return

    if not png and not png_vpn:
        await _safe_answer(callback, "⚠ QR-коды недоступны.")
        return

    name = details.get("name") or f"client_{ctx.client_id}"
    
    if png:
        await callback.message.answer_photo(
            BufferedInputFile(png, filename=f"qr_{name}.png"),
            caption=f"📱 QR-код для <b>{name}</b>\nОтсканируйте в приложении AmneziaVPN.",
        )
        
    if png_vpn:
        await callback.message.answer_photo(
            BufferedInputFile(png_vpn, filename=f"qr_vpn_{name}.png"),
            caption=f"📱 QR Code (vpn:// URL) для <b>{name}</b>\nДля других VPN клиентов.",
        )
        
    await callback.answer()


@router.callback_query(F.data == "menu:conf")
async def cb_conf(callback: CallbackQuery) -> None:
    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return

    details = ctx.details or {}
    config_text = details.get("config")
    vpn_url_config = details.get("vpn_url_config")
    
    if not config_text and not vpn_url_config:
        await _safe_answer(callback, "⚠ Файл конфигурации недоступен.")
        return

    name = details.get("name") or f"client_{ctx.client_id}"
    safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in str(name))
    
    if config_text:
        await callback.message.answer_document(
            BufferedInputFile(config_text.encode("utf-8"), filename=f"{safe_name}.conf"),
            caption=f"📄 Файл конфигурации для <b>{name}</b>",
        )
        
    if vpn_url_config:
        await callback.message.answer(
            f"📄 Строка конфигурации (vpn://) для <b>{name}</b>:\n\n<code>{vpn_url_config}</code>"
        )
        
    await callback.answer()


@router.callback_query(F.data == "menu:reset")
async def cb_reset(callback: CallbackQuery) -> None:
    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return

    await callback.message.answer(
        "⚠ <b>Сброс ключа</b>\n\n"
        "Старая конфигурация и QR-код будут аннулированы. "
        "Действие необратимо. Продолжить?",
        reply_markup=reset_confirm_kb(ctx.client_id),
    )
    await callback.answer()


@router.callback_query(F.data.startswith("menu:reset_confirm:"))
async def cb_reset_confirm(callback: CallbackQuery, bot: Bot) -> None:
    telegram_id = callback.from_user.id
    try:
        client_id = int(callback.data.split(":")[-1])
    except (ValueError, IndexError):
        await callback.answer("Ошибка", show_alert=True)
        return

    jwt = await users_repo.get_jwt(telegram_id)
    if not jwt:
        await _safe_answer(callback, "🔒 Сессия истекла. Авторизуйтесь снова.")
        return

    await callback.message.answer("🔄 Перегенерирую конфигурацию, это может занять время…")
    try:
        result = await panel_api.regenerate_config(jwt, client_id)
    except PanelAPIError as exc:
        await _safe_answer(callback, f"❌ Не удалось сбросить ключ: {exc.message}")
        return

    success = result.get("config") is not None
    if not success:
        await _safe_answer(callback, "❌ Сервер не вернул новую конфигурацию. Попробуйте позже.")
        return

    await audit.log(
        bot,
        action="regenerate_config",
        target=f"client:{client_id}",
        actor_id=telegram_id,
        actor_name=callback.from_user.full_name,
        details="(сброс ключа пользователем)",
    )

    name = result.get("name") or f"client_{client_id}"
    safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in str(name))

    png = _b64_to_bytes(result.get("qr_code"))
    png_vpn = _b64_to_bytes(result.get("qr_code_vpn"))
    
    if png:
        await callback.message.answer_photo(
            BufferedInputFile(png, filename=f"qr_{safe_name}.png"),
            caption=f"✅ Ключ сброшен. Новый QR-код для <b>{name}</b>.",
        )
        
    if png_vpn:
        await callback.message.answer_photo(
            BufferedInputFile(png_vpn, filename=f"qr_vpn_{safe_name}.png"),
            caption=f"📱 Новый QR Code (vpn:// URL) для <b>{name}</b>.",
        )

    config_text = result.get("config")
    vpn_url_config = result.get("vpn_url_config")
    
    if config_text:
        await callback.message.answer_document(
            BufferedInputFile(config_text.encode("utf-8"), filename=f"{safe_name}.conf"),
            caption="📄 Новый файл конфигурации:",
        )
        
    if vpn_url_config:
        await callback.message.answer(
            f"📄 Новая строка конфигурации (vpn://):\n\n<code>{vpn_url_config}</code>"
        )

    await callback.answer()
