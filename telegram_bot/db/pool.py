from __future__ import annotations

import logging
from typing import Optional

import asyncpg

from config import settings

logger = logging.getLogger(__name__)

_pool: Optional[asyncpg.Pool] = None

# DDL for tables required by the Telegram bot.
# These tables live in the telegram_bot database and are normally created
# by docker-entrypoint-initdb.d/03-telegram-bot-schema.sql on first run.
# We re-apply them here with IF NOT EXISTS to survive init-script skip
# (e.g. when the PostgreSQL data volume already existed).
_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    telegram_id   BIGINT PRIMARY KEY,
    amnezia_client_id VARCHAR(255) NULL,
    email         VARCHAR(255) NULL,
    role          VARCHAR(50) DEFAULT 'user',
    jwt_token     TEXT NULL,
    jwt_expires_at TIMESTAMP NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tg_users_client_id ON users (amnezia_client_id);
CREATE INDEX IF NOT EXISTS idx_tg_users_role      ON users (role);

CREATE TABLE IF NOT EXISTS cached_configs (
    client_id   VARCHAR(255) PRIMARY KEY,
    config_text TEXT,
    qr_base64   TEXT,
    vpn_url_config TEXT,
    qr_code_vpn TEXT,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id      SERIAL PRIMARY KEY,
    telegram_id     BIGINT REFERENCES users(telegram_id) ON DELETE SET NULL,
    amount          NUMERIC(10, 2),
    currency        VARCHAR(10),
    status          VARCHAR(50) DEFAULT 'pending',
    provider        VARCHAR(50),
    provider_tx_id  VARCHAR(255) NULL,
    days_to_extend  INT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_telegram_id ON payments (telegram_id);
CREATE INDEX IF NOT EXISTS idx_payments_status      ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_provider_tx ON payments (provider_tx_id);
-- Идемпотичность исполнения: successful_payment может доставляться повторно
-- (краш/рестарт бота). Один charge_id — одна строка.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_provider_tx_uniq
    ON payments (provider_tx_id) WHERE provider_tx_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS fsm_states (
    chat_id   BIGINT NOT NULL,
    user_id   BIGINT NOT NULL,
    state     VARCHAR(255) NULL,
    data      JSON DEFAULT '{}',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id, user_id)
);
"""


async def _ensure_tables(conn: asyncpg.Connection) -> None:
    """Create required tables if they do not exist yet."""
    await conn.execute(_SCHEMA_SQL)
    # Add new columns if they are missing
    await conn.execute("ALTER TABLE cached_configs ADD COLUMN IF NOT EXISTS vpn_url_config TEXT")
    await conn.execute("ALTER TABLE cached_configs ADD COLUMN IF NOT EXISTS qr_code_vpn TEXT")
    logger.debug("Ensured schema tables exist")


async def init_db() -> asyncpg.Pool:
    global _pool
    if _pool is not None:
        return _pool

    _pool = await asyncpg.create_pool(
        dsn=settings.db_dsn,
        min_size=1,
        max_size=10,
        command_timeout=30,
    )
    async with _pool.acquire() as conn:
        await _ensure_tables(conn)
        await conn.execute("SELECT 1")
    logger.info("Database pool initialized (%s)", settings.tg_db_name)
    return _pool


async def close_db() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("Database pool closed")


def get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("Database pool is not initialized. Call init_db() first.")
    return _pool
