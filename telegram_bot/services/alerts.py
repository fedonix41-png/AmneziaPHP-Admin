from __future__ import annotations

import asyncio
import logging

from aiogram import Bot
from aiogram.exceptions import TelegramRetryAfter, TelegramAPIError

from config import settings

logger = logging.getLogger(__name__)


async def send_alert_to_admins(bot: Bot, text: str) -> None:
    for admin_id in settings.admin_ids:
        try:
            await bot.send_message(chat_id=admin_id, text=text, parse_mode="HTML")
        except TelegramRetryAfter as exc:
            logger.warning("Rate limit: ждём %s сек перед отправкой админу %s", exc.retry_after, admin_id)
            await asyncio.sleep(exc.retry_after)
            try:
                await bot.send_message(chat_id=admin_id, text=text, parse_mode="HTML")
            except TelegramAPIError as retry_exc:
                logger.error("Не удалось отправить алерт админу %s: %s", admin_id, retry_exc)
        except TelegramAPIError as exc:
            logger.error("Не удалось отправить алерт админу %s: %s", admin_id, exc)
        await asyncio.sleep(0.05)
