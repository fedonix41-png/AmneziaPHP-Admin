-- Telegram Bot database schema
-- Applied automatically on first container start to the 'telegram_bot' database.
-- Connect to the correct database first:
\connect telegram_bot

-- ─────────────────────────────────────────────────────────────────
-- Users: telegram_id <-> amnezia_client_id mapping + roles
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    telegram_id   BIGINT PRIMARY KEY,
    amnezia_client_id VARCHAR(255) NULL,
    email         VARCHAR(255) NULL,
    role          VARCHAR(50) DEFAULT 'user',   -- 'user' | 'admin'
    jwt_token     TEXT NULL,                    -- cached JWT from panel
    jwt_expires_at TIMESTAMP NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tg_users_client_id ON users (amnezia_client_id);
CREATE INDEX IF NOT EXISTS idx_tg_users_role      ON users (role);

-- ─────────────────────────────────────────────────────────────────
-- Cached configs / QR-codes for quick retrieval
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cached_configs (
    client_id   VARCHAR(255) PRIMARY KEY,
    config_text TEXT,
    qr_base64   TEXT,
    vpn_url_config TEXT,
    qr_code_vpn TEXT,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────────────────────────
-- Payments: Telegram Invoices + external providers
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
    payment_id      SERIAL PRIMARY KEY,
    telegram_id     BIGINT REFERENCES users(telegram_id) ON DELETE SET NULL,
    amount          NUMERIC(10, 2),
    currency        VARCHAR(10),
    status          VARCHAR(50) DEFAULT 'pending',   -- 'completed' | 'paid_unfulfilled' (см. services/payments.py)
    provider        VARCHAR(50),                     -- 'telegram' | 'yookassa' | 'stripe' | etc.
    provider_tx_id  VARCHAR(255) NULL,               -- External transaction / invoice ID
    days_to_extend  INT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_telegram_id ON payments (telegram_id);
CREATE INDEX IF NOT EXISTS idx_payments_status      ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_provider_tx ON payments (provider_tx_id);
-- Идемпотичность исполнения (successful_payment может доставляться повторно).
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_provider_tx_uniq
    ON payments (provider_tx_id) WHERE provider_tx_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────
-- FSM sessions: aiogram finite-state machine persistent storage
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fsm_states (
    chat_id   BIGINT NOT NULL,
    user_id   BIGINT NOT NULL,
    state     VARCHAR(255) NULL,
    data      JSON DEFAULT '{}',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (chat_id, user_id)
);
