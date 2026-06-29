from __future__ import annotations

import logging
import time
from typing import Any, Awaitable, Callable

from aiogram import BaseMiddleware
from aiogram.types import TelegramObject, Update, CallbackQuery, Message

from config import settings

logger = logging.getLogger(__name__)


class AccessLogMiddleware(BaseMiddleware):
    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        update: Update = data.get("update")  # type: ignore[assignment]
        user = data.get("event_from_user")
        start = time.perf_counter()
        try:
            return await handler(event, data)
        finally:
            elapsed = (time.perf_counter() - start) * 1000
            uid = user.id if user else "-"
            update_id = getattr(update, "update_id", "-") if update else "-"
            logger.debug("update_id=%s user=%s обработан за %.1f мс", update_id, uid, elapsed)


class AdminGuardMiddleware(BaseMiddleware):
    """Блокирует callback-запросы к admin:* и message-команды /add_client
    от пользователей, не входящих в BOT_ADMIN_TELEGRAM_IDS."""

    _ADMIN_PREFIXES = ("admin:",)

    async def __call__(
        self,
        handler: Callable[[TelegramObject, dict[str, Any]], Awaitable[Any]],
        event: TelegramObject,
        data: dict[str, Any],
    ) -> Any:
        user = data.get("event_from_user")
        if user is None:
            return await handler(event, data)

        needs_admin = False

        if isinstance(event, CallbackQuery):
            cdata = event.data or ""
            needs_admin = any(cdata.startswith(p) for p in self._ADMIN_PREFIXES)
        elif isinstance(event, Message):
            text = event.text or ""
            needs_admin = text.startswith("/add_client")

        if needs_admin:
            from services.users import users_repo
            role = await users_repo.get_role(user.id)
            if not (settings.is_admin(user.id) or role in ("admin", "manager")):
                logger.warning("Попытка админ-доступа от user_id=%s", user.id)
                if isinstance(event, CallbackQuery):
                    await event.answer("⛔ Доступ запрещён", show_alert=True)
                    return None
                if isinstance(event, Message):
                    await event.answer("⛔ Эта команда доступна только администраторам")
                    return None

        return await handler(event, data)
