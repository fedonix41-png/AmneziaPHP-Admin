from __future__ import annotations

import asyncio
import logging

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
from aiohttp import web

from config import settings
from db.pool import close_db, init_db
from db.storage import PostgresStorage
from handlers import build_router
from middlewares.access import AccessLogMiddleware, AdminGuardMiddleware
from services.alerts import alert_scheduler
from services.panel_api import panel_api

logger = logging.getLogger(__name__)
WEBHOOK_PATH = "/tg/webhook"


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    )
    # Отдельный лог-файл для аудита деструктивных действий (см. services/audit.py).
    if settings.audit_log_file:
        try:
            handler = logging.FileHandler(settings.audit_log_file, encoding="utf-8")
            handler.setFormatter(
                logging.Formatter("%(asctime)s | %(levelname)-8s | AUDIT | %(message)s")
            )
            audit_log = logging.getLogger("audit")
            audit_log.addHandler(handler)
            audit_log.propagate = False
            audit_log.setLevel(logging.INFO)
        except OSError as exc:
            logging.getLogger(__name__).warning(
                "AUDIT_LOG_FILE=%s недоступен для записи: %s", settings.audit_log_file, exc
            )


def build_dispatcher() -> Dispatcher:
    storage = PostgresStorage()
    dp = Dispatcher(storage=storage)
    dp.include_router(build_router())
    dp.message.middleware(AdminGuardMiddleware())
    dp.callback_query.middleware(AdminGuardMiddleware())
    dp.message.middleware(AccessLogMiddleware())
    dp.callback_query.middleware(AccessLogMiddleware())
    dp.startup.register(_on_startup)
    dp.shutdown.register(_on_shutdown)
    return dp


async def _on_startup(bot: Bot, **kwargs) -> None:
    await init_db()
    await panel_api.start()
    alert_scheduler.start(bot)
    if settings.bot_use_webhook and settings.bot_webhook_url:
        await bot.set_webhook(
            settings.bot_webhook_url,
            secret_token=settings.bot_webhook_secret or None,
        )
        logger.info("Webhook установлен: %s", settings.bot_webhook_url)
    logger.info("Бот запущен (%s)", "webhook" if settings.bot_use_webhook else "polling")


async def _on_shutdown(bot: Bot, **kwargs) -> None:
    logger.info("Остановка бота…")
    try:
        await bot.delete_webhook(drop_pending_updates=False)
    except Exception as exc:
        logger.warning("Не удалось снять webhook: %s", exc)
    await alert_scheduler.stop()
    await panel_api.stop()
    await close_db()


def make_bot() -> Bot:
    return Bot(
        token=settings.bot_token,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML),
    )


async def run_polling() -> None:
    bot = make_bot()
    dp = build_dispatcher()
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)


def run_webhook() -> None:
    bot = make_bot()
    dp = build_dispatcher()

    app = web.Application()
    SimpleRequestHandler(
        dispatcher=dp,
        bot=bot,
        secret_token=settings.bot_webhook_secret or None,
    ).register(app, path=WEBHOOK_PATH)
    setup_application(app, dp, bot=bot)

    web.run_app(app, host=settings.bot_webhook_host, port=settings.bot_webhook_port)


def main() -> None:
    configure_logging()
    if not settings.bot_token:
        raise SystemExit("BOT_TOKEN не задан в .env")
    if settings.bot_use_webhook and not settings.bot_webhook_url:
        raise SystemExit("BOT_USE_WEBHOOK=true, но BOT_WEBHOOK_URL не задан")

    if settings.bot_use_webhook:
        run_webhook()
    else:
        asyncio.run(run_polling())


if __name__ == "__main__":
    main()
