from __future__ import annotations

from aiogram import Router

from .backups import router as backups_router
from .clients import router as clients_router
from .menu import router as menu_router
from .servers import router as servers_router


def build_admin_router() -> Router:
    router = Router(name="admin")
    router.include_router(menu_router)
    router.include_router(servers_router)
    router.include_router(clients_router)
    router.include_router(backups_router)
    return router
