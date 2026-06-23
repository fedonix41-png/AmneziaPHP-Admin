from __future__ import annotations

import logging
import time
from typing import Any, Awaitable, Callable

from aiogram import BaseMiddleware
from aiogram.types import TelegramObject, Update

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
