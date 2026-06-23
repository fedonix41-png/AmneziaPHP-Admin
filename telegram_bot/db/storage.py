from __future__ import annotations

import json
import logging
from typing import Any, Dict, Optional

from aiogram import Bot
from aiogram.fsm.state import State
from aiogram.fsm.storage.base import BaseStorage, StorageKey

from db.pool import get_pool

logger = logging.getLogger(__name__)


def _state_value(state: Optional[str | State]) -> Optional[str]:
    if state is None:
        return None
    if isinstance(state, State):
        return state.state
    return str(state)


class PostgresStorage(BaseStorage):
    """FSM storage backed by the `fsm_states` table in the telegram_bot DB."""

    async def get_state(self, bot: Bot, key: StorageKey) -> Optional[str]:
        pool = get_pool()
        row = await pool.fetchrow(
            "SELECT state FROM fsm_states WHERE chat_id = $1 AND user_id = $2",
            key.chat_id,
            key.user_id,
        )
        return row["state"] if row else None

    async def get_data(self, bot: Bot, key: StorageKey) -> Dict[str, Any]:
        pool = get_pool()
        row = await pool.fetchrow(
            "SELECT data FROM fsm_states WHERE chat_id = $1 AND user_id = $2",
            key.chat_id,
            key.user_id,
        )
        if not row or row["data"] is None:
            return {}
        raw = row["data"]
        if isinstance(raw, str):
            return json.loads(raw) if raw else {}
        if isinstance(raw, (dict, list)):
            return dict(raw)
        return {}

    async def set_state(self, bot: Bot, key: StorageKey, state: Optional[str | State] = None) -> None:
        value = _state_value(state)
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO fsm_states (chat_id, user_id, state, data, updated_at)
            VALUES ($1, $2, $3, '{}'::json, CURRENT_TIMESTAMP)
            ON CONFLICT (chat_id, user_id) DO UPDATE
              SET state = EXCLUDED.state, updated_at = CURRENT_TIMESTAMP
            """,
            key.chat_id,
            key.user_id,
            value,
        )

    async def set_data(self, bot: Bot, key: StorageKey, data: Dict[str, Any]) -> None:
        payload = json.dumps(data, ensure_ascii=False, default=str)
        pool = get_pool()
        await pool.execute(
            """
            INSERT INTO fsm_states (chat_id, user_id, state, data, updated_at)
            VALUES ($1, $2, NULL, $3::json, CURRENT_TIMESTAMP)
            ON CONFLICT (chat_id, user_id) DO UPDATE
              SET data = EXCLUDED.data, updated_at = CURRENT_TIMESTAMP
            """,
            key.chat_id,
            key.user_id,
            payload,
        )

    async def update_data(self, bot: Bot, key: StorageKey, data: Dict[str, Any]) -> Dict[str, Any]:
        current = await self.get_data(bot, key)
        current.update(data)
        await self.set_data(bot, key, current)
        return current

    async def close(self) -> None:
        pass
