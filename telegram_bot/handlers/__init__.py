from __future__ import annotations

from aiogram import Router

from handlers.auth import router as auth_router
from handlers.client.ai_assist import router as ai_router
from handlers.client.config import router as config_router
from handlers.client.menu import router as menu_router
from handlers.client.stats import router as stats_router
from handlers.start import router as start_router


def build_router() -> Router:
    router = Router(name="root")
    router.include_router(start_router)
    router.include_router(auth_router)
    router.include_router(menu_router)
    router.include_router(stats_router)
    router.include_router(config_router)
    router.include_router(ai_router)
    return router
