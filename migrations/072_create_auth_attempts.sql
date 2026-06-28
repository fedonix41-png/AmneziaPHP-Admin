-- 072_create_auth_attempts.sql
-- Brute-force protection for auth endpoints (see docs/security.md#rate-limiting).
-- One row per (ip, bucket). bucket = protected action, e.g. 'auth_token'.

CREATE TABLE IF NOT EXISTS auth_attempts (
    ip            VARCHAR(64)  NOT NULL,
    bucket        VARCHAR(64)  NOT NULL DEFAULT 'auth_token',
    failed_count  INTEGER      NOT NULL DEFAULT 0,
    last_failed_at TIMESTAMPTZ,
    locked_until  TIMESTAMPTZ,
    lockout_step  INTEGER      NOT NULL DEFAULT 0,
    PRIMARY KEY (ip, bucket)
);
