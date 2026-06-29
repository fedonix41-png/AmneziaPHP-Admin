from __future__ import annotations

from typing import Optional

from db.pool import get_pool


class UsersRepo:
    async def get(self, telegram_id: int) -> Optional[dict]:
        pool = get_pool()
        return await pool.fetchrow(
            "SELECT * FROM users WHERE telegram_id = $1",
            telegram_id,
        )

    async def get_jwt(self, telegram_id: int) -> Optional[str]:
        pool = get_pool()
        row = await pool.fetchrow(
            """
            SELECT jwt_token FROM users
            WHERE telegram_id = $1
              AND jwt_token IS NOT NULL
              AND (jwt_expires_at IS NULL OR jwt_expires_at > NOW())
            """,
            telegram_id,
        )
        return row["jwt_token"] if row else None

    async def get_client_id(self, telegram_id: int) -> Optional[int]:
        pool = get_pool()
        row = await pool.fetchrow(
            "SELECT amnezia_client_id FROM users WHERE telegram_id = $1",
            telegram_id,
        )
        return row["amnezia_client_id"] if row else None

    async def upsert_auth(
        self, telegram_id: int, email: str, jwt_token: str, jwt_expires_at: datetime, role: str = "user"
    ) -> None:
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO users (telegram_id, email, jwt_token, jwt_expires_at, role, updated_at)
            VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
            ON CONFLICT (telegram_id) DO UPDATE
              SET email = EXCLUDED.email,
                  jwt_token = EXCLUDED.jwt_token,
                  jwt_expires_at = EXCLUDED.jwt_expires_at,
                  role = EXCLUDED.role,
                  updated_at = CURRENT_TIMESTAMP
            """,
            telegram_id,
            email,
            jwt_token,
            jwt_expires_at,
            role,
        )

    async def get_role(self, telegram_id: int) -> str:
        pool = get_pool()
        val = await pool.fetchval(
            "SELECT role FROM users WHERE telegram_id = $1", telegram_id
        )
        return val or "user"

    async def set_client_id(self, telegram_id: int, client_id: Optional[int]) -> None:
        pool = get_pool()
        cid_str = str(client_id) if client_id is not None else None
        await pool.execute(
            """
            INSERT INTO users (telegram_id, amnezia_client_id, role, updated_at)
            VALUES ($1, $2, 'user', CURRENT_TIMESTAMP)
            ON CONFLICT (telegram_id) DO UPDATE
              SET amnezia_client_id = EXCLUDED.amnezia_client_id,
                  updated_at = CURRENT_TIMESTAMP
            """,
            telegram_id,
            cid_str,
        )

    async def logout(self, telegram_id: int) -> None:
        pool = get_pool()
        await pool.execute(
            """
            UPDATE users
               SET jwt_token = NULL,
                   jwt_expires_at = NULL,
                   amnezia_client_id = NULL,
                   updated_at = CURRENT_TIMESTAMP
             WHERE telegram_id = $1
            """,
            telegram_id,
        )

    async def mark_admin(self, telegram_id: int) -> None:
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO users (telegram_id, role, updated_at)
            VALUES ($1, 'admin', CURRENT_TIMESTAMP)
            ON CONFLICT (telegram_id) DO UPDATE
              SET role = 'admin', updated_at = CURRENT_TIMESTAMP
            """,
            telegram_id,
        )


users_repo = UsersRepo()


class ConfigCacheRepo:
    """Persistent config/QR cache backed by PostgreSQL cached_configs table."""

    async def get(self, client_id: int) -> dict | None:
        pool = get_pool()
        row = await pool.fetchrow(
            "SELECT config_text, qr_base64, vpn_url_config, qr_code_vpn FROM cached_configs WHERE client_id = $1",
            str(client_id),
        )
        if not row:
            return None
        return {
            "config": row["config_text"] or "",
            "qr_code": row["qr_base64"] or "",
            "vpn_url_config": row["vpn_url_config"] or "",
            "qr_code_vpn": row["qr_code_vpn"] or "",
        }

    async def save(self, client_id: int, config_text: str, qr_base64: str, vpn_url_config: str = "", qr_code_vpn: str = "") -> None:
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO cached_configs (client_id, config_text, qr_base64, vpn_url_config, qr_code_vpn, updated_at)
            VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
            ON CONFLICT (client_id) DO UPDATE
              SET config_text = EXCLUDED.config_text,
                  qr_base64 = EXCLUDED.qr_base64,
                  vpn_url_config = EXCLUDED.vpn_url_config,
                  qr_code_vpn = EXCLUDED.qr_code_vpn,
                  updated_at = CURRENT_TIMESTAMP
            """,
            str(client_id),
            config_text or "",
            qr_base64 or "",
            vpn_url_config or "",
            qr_code_vpn or "",
        )

    async def delete(self, client_id: int) -> None:
        pool = get_pool()
        await pool.execute(
            "DELETE FROM cached_configs WHERE client_id = $1",
            str(client_id),
        )


config_cache = ConfigCacheRepo()
