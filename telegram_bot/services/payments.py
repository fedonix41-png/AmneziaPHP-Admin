from __future__ import annotations

import logging
from typing import Optional

from db.pool import get_pool

logger = logging.getLogger(__name__)

# Имя провайдера для колонки payments.provider.
PAYMENT_PROVIDER_TELEGRAM = "telegram"

# Семантика статусов в payments.status:
#   completed         — оплата получена и подписка продлена
#   paid_unfulfilled  — оплата получена, но продление не удалось (требует ручной проверки)
STATUS_COMPLETED = "completed"
STATUS_PAID_UNFULFILLED = "paid_unfulfilled"


class PaymentsRepo:
    """Доступ к таблице payments (см. db/pool.py::_SCHEMA_SQL)."""

    async def create(
        self,
        *,
        telegram_id: int,
        amount,
        currency: str,
        status: str,
        provider: str,
        days_to_extend: int,
        provider_tx_id: Optional[str] = None,
    ) -> int:
        pool = get_pool()
        row = await pool.fetchrow(
            """
            INSERT INTO payments
                (telegram_id, amount, currency, status, provider,
                 provider_tx_id, days_to_extend, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING payment_id
            """,
            telegram_id,
            amount,
            currency,
            status,
            provider,
            provider_tx_id,
            days_to_extend,
        )
        return int(row["payment_id"])

    async def find_by_provider_tx(self, provider_tx_id: str) -> Optional[dict]:
        """Поиск платежа по идентификатору транзакции провайдера (для идемпотенности)."""
        pool = get_pool()
        return await pool.fetchrow(
            "SELECT * FROM payments WHERE provider_tx_id = $1",
            provider_tx_id,
        )

    async def mark_status(self, payment_id: int, status: str) -> None:
        pool = get_pool()
        await pool.execute(
            """
            UPDATE payments
               SET status = $1,
                   updated_at = CURRENT_TIMESTAMP
             WHERE payment_id = $2
            """,
            status,
            payment_id,
        )


payments_repo = PaymentsRepo()
