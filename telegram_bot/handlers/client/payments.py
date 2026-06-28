from __future__ import annotations

import logging
from typing import Optional, Tuple

from aiogram import Bot, F, Router
from aiogram.types import CallbackQuery, LabeledPrice, Message, PreCheckoutQuery

from config import Tariff, settings
from handlers.client.common import answer_unresolved, resolve_client
from keyboards.client import back_to_main_kb, pay_tariffs_kb
from services.panel_api import PanelAPIError, panel_api
from services.payments import (
    PAYMENT_PROVIDER_TELEGRAM,
    STATUS_COMPLETED,
    STATUS_PAID_UNFULFILLED,
    payments_repo,
)
from services.users import users_repo
from utils.format import humanize_date

logger = logging.getLogger(__name__)

router = Router(name="client.payments")

# Payload инвойса: payv2:{client_id}:{days}. До 128 байт (лимит Telegram).
# days зашивается в payload авторитетно — на исполнении не зависит от позиционного
# индекса тарифа или текущих настроек PAYMENT_TARIFFS (см. ревью: тариф по позиции).
_PAYLOAD_PREFIX = "payv2:"

# Валюты без дробных единиц: amount — целое (Telegram Stars, японская иена и т.п.).
# Единое правило для выставления счёта и записи суммы, чтобы избежать расхождений.
_ZERO_DECIMAL_CURRENCIES = {"XTR", "JPY", "CLP", "KRW", "VND", "ISK", "PYG", "UGX"}


def _is_zero_decimal(currency: str) -> bool:
    return (currency or "").upper() in _ZERO_DECIMAL_CURRENCIES


def _build_payload(client_id: int, days: int) -> str:
    return f"{_PAYLOAD_PREFIX}{client_id}:{days}"


def _parse_payload(payload: str) -> Optional[Tuple[int, int]]:
    if not payload or not payload.startswith(_PAYLOAD_PREFIX):
        return None
    parts = payload[len(_PAYLOAD_PREFIX):].split(":")
    if len(parts) != 2:
        return None
    try:
        return int(parts[0]), int(parts[1])
    except ValueError:
        return None


def _amount_for(tariff: Tariff) -> int:
    # Telegram принимает сумму в минимальных единицах валюты
    # (копейки для RUB, центы для USD/EUR). Для бездробных валют — целое число.
    return tariff.price if _is_zero_decimal(settings.payment_currency) else tariff.price * 100


def _tariff_label_for_days(days: int) -> str:
    for t in settings.tariffs:
        if t.days == days:
            return t.label
    return f"{days} дн."


@router.callback_query(F.data == "menu:pay")
async def cb_pay_menu(callback: CallbackQuery) -> None:
    if not settings.payments_enabled:
        await callback.message.answer(
            "💳 Оплата временно недоступна. Обратитесь к администратору.",
            reply_markup=back_to_main_kb(),
        )
        await callback.answer()
        return

    tariffs = settings.tariffs
    if not tariffs:
        await callback.message.answer("⚠ Тарифы не настроены.", reply_markup=back_to_main_kb())
        await callback.answer()
        return

    await callback.message.answer(
        "💳 <b>Продление подписки</b>\nВыберите тариф:",
        reply_markup=pay_tariffs_kb(tariffs, settings.payment_currency),
    )
    await callback.answer()


@router.callback_query(F.data.startswith("pay:tariff:"))
async def cb_pay_tariff(callback: CallbackQuery, bot: Bot) -> None:
    if not settings.payments_enabled:
        await callback.answer("Оплата недоступна", show_alert=True)
        return

    try:
        tariff_idx = int(callback.data.rsplit(":", 1)[-1])
    except ValueError:
        await callback.answer("Ошибка", show_alert=True)
        return

    tariffs = settings.tariffs
    if tariff_idx < 0 or tariff_idx >= len(tariffs):
        await callback.answer("Тариф не найден", show_alert=True)
        return
    tariff = tariffs[tariff_idx]

    ctx = await resolve_client(callback.from_user.id)
    if await answer_unresolved(callback.message, ctx):
        await callback.answer()
        return

    client_id = ctx.client_id
    payload = _build_payload(client_id, tariff.days)
    try:
        await bot.send_invoice(
            chat_id=callback.message.chat.id,
            title=f"Продление VPN — {tariff.label}",
            description=f"Продление подписки на {tariff.days} дн.",
            payload=payload,
            provider_token=settings.payment_provider_token,
            currency=settings.payment_currency,
            prices=[LabeledPrice(label=tariff.label, amount=_amount_for(tariff))],
        )
    except Exception as exc:  # noqa: BLE001 — пользователю нужен понятный ответ
        logger.exception("send_invoice failed")
        await callback.message.answer(
            f"⚠ Не удалось выставить счёт: {exc}",
            reply_markup=back_to_main_kb(),
        )
    await callback.answer()


@router.pre_checkout_query()
async def pre_checkout(query: PreCheckoutQuery) -> None:
    """Проверка возможности оплаты (Telegram ждёт ответ ≤ 10 сек)."""
    parsed = _parse_payload(query.invoice_payload)
    if parsed is None:
        await query.answer(
            ok=False,
            error_message="Некорректные данные платежа. Обратитесь к администратору.",
        )
        return
    client_id, days = parsed
    if days <= 0:
        await query.answer(ok=False, error_message="Некорректный тариф.")
        return

    jwt = await users_repo.get_jwt(query.from_user.id)
    if not jwt:
        await query.answer(
            ok=False,
            error_message="Сессия истекла. Авторизуйтесь и попробуйте снова.",
        )
        return

    bound_id = await users_repo.get_client_id(query.from_user.id)
    if bound_id != client_id:
        await query.answer(
            ok=False,
            error_message="Подписка не подтверждена. Обновите меню и попробуйте снова.",
        )
        return

    # Проверяем статус клиента: удалён/недоступен — отклоняем.
    # Транзитные ошибки панели не блокируют оплату (логируются).
    try:
        await panel_api.client_details(jwt, client_id)
    except PanelAPIError as exc:
        if exc.status_code in (403, 404):
            await query.answer(ok=False, error_message="Подписка недоступна или удалена.")
            return
        logger.warning(
            "pre_checkout: не удалось проверить статус клиента %s: %s",
            client_id,
            exc.message,
        )

    await query.answer(ok=True)


@router.message(F.successful_payment)
async def on_successful_payment(message: Message, bot: Bot) -> None:
    payment = message.successful_payment
    parsed = _parse_payload(payment.invoice_payload)
    if parsed is None:
        logger.error("successful_payment: некорректный payload=%r", payment.invoice_payload)
        await message.answer(
            "✅ Оплата получена, но не удалось определить подписку. "
            "Обратитесь к администратору.",
            reply_markup=back_to_main_kb(),
        )
        return

    client_id, days = parsed
    if days <= 0:
        logger.error("successful_payment: некорректный days=%s (payload=%r)", days, payment.invoice_payload)
        await message.answer(
            "✅ Оплата получена, но тариф некорректен. Обратитесь к администратору.",
            reply_markup=back_to_main_kb(),
        )
        return

    provider_tx = (
        payment.telegram_payment_charge_id
        or payment.provider_payment_charge_id
        or ""
    )

    # Идемпотентность: Telegram может доставлять successful_payment повторно
    # (краш/рестарт). Один charge_id обрабатывается только один раз.
    if provider_tx:
        existing = await payments_repo.find_by_provider_tx(provider_tx)
        if existing:
            logger.info(
                "Повторная доставка successful_payment (charge=%s), уже обработан payment_id=%s",
                provider_tx,
                existing["payment_id"],
            )
            await message.answer(
                "✅ Этот платёж уже был обработан ранее.",
                reply_markup=back_to_main_kb(),
            )
            return

    amount = float(payment.total_amount) if _is_zero_decimal(payment.currency) else payment.total_amount / 100.0

    payment_id = await payments_repo.create(
        telegram_id=message.from_user.id,
        amount=amount,
        currency=payment.currency,
        status=STATUS_COMPLETED,
        provider=PAYMENT_PROVIDER_TELEGRAM,
        provider_tx_id=provider_tx or None,
        days_to_extend=days,
    )

    await message.answer("✅ <b>Оплата получена!</b>\nПродлеваю подписку…")

    try:
        result = await panel_api.extend_client(client_id, days=days)
    except PanelAPIError as exc:
        logger.error(
            "Продление не удалось (payment_id=%s, client=%s): %s",
            payment_id,
            client_id,
            exc.message,
        )
        await payments_repo.mark_status(payment_id, STATUS_PAID_UNFULFILLED)
        await message.answer(
            "⚠ Платёж получен, но не удалось автоматически продлить подписку.\n"
            "Администратор уже уведомлён и продлит доступ вручную.",
            reply_markup=back_to_main_kb(),
        )
        await _alert_admins_payment_failed(bot, payment_id, client_id, days, exc.message)
        return

    expires_at = result.get("expires_at") if isinstance(result, dict) else None
    label = _tariff_label_for_days(days)
    await message.answer(
        f"🎉 <b>Подписка продлена на {days} дн.!</b>\n"
        f"Действует до: <b>{humanize_date(expires_at)}</b>",
        reply_markup=back_to_main_kb(),
    )


async def _alert_admins_payment_failed(
    bot: Bot, payment_id: int, client_id: int, days: int, reason: str
) -> None:
    # Импорт здесь, чтобы избежать циклической зависимости services.alerts ↔ handlers.
    from services.alerts import send_alert_to_admins

    text = (
        "⚠ <b>Платёж получен без продления</b>\n"
        f"payment_id: <code>{payment_id}</code>\n"
        f"client_id: <code>{client_id}</code>\n"
        f"продление: {days} дн.\n"
        f"причина: <i>{reason}</i>"
    )
    try:
        await send_alert_to_admins(bot, text)
    except Exception:  # noqa: BLE001 — алерт не должен ронять обработчик
        logger.warning("Не удалось отправить алерт админам о сбое продления")
