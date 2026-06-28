from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, List

from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


@dataclass
class Tariff:
    """Тариф продления подписки: срок в днях + цена в целых единицах валюты."""
    days: int
    price: int
    label: str


# Тарифы по умолчанию, если PAYMENT_TARIFFS не задан/некорректен.
_DEFAULT_TARIFFS_JSON = (
    '[{"days":30,"price":199,"label":"1 месяц"},'
    '{"days":90,"price":499,"label":"3 месяца"},'
    '{"days":180,"price":899,"label":"6 месяцев"},'
    '{"days":365,"price":1599,"label":"1 год"}]'
)


def _parse_tariffs(data: Any) -> List[Tariff]:
    tariffs: List[Tariff] = []
    if not isinstance(data, list):
        return tariffs
    for item in data:
        if not isinstance(item, dict):
            continue
        try:
            days = int(item.get("days", 0))
            price = int(item.get("price", 0))
        except (TypeError, ValueError):
            continue
        label = str(item.get("label") or f"{days} дн.")
        if days > 0 and price > 0:
            tariffs.append(Tariff(days=days, price=price, label=label))
    return tariffs


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    bot_token: str = Field("", validation_alias="BOT_TOKEN")
    bot_admin_telegram_ids: str = Field("", validation_alias="BOT_ADMIN_TELEGRAM_IDS")

    panel_api_url: str = Field("http://web:80", validation_alias="PANEL_API_URL")
    panel_api_token: str = Field("", validation_alias="PANEL_API_TOKEN")
    request_timeout: int = Field(30, validation_alias="REQUEST_TIMEOUT")

    bot_use_webhook: bool = Field(False, validation_alias="BOT_USE_WEBHOOK")
    bot_webhook_url: str = Field("", validation_alias="BOT_WEBHOOK_URL")
    bot_webhook_host: str = Field("0.0.0.0", validation_alias="BOT_WEBHOOK_HOST")
    bot_webhook_port: int = Field(8080, validation_alias="BOT_WEBHOOK_PORT")
    bot_webhook_secret: str = Field("", validation_alias="BOT_WEBHOOK_SECRET")

    tg_db_host: str = Field("db", validation_alias="TG_DB_HOST")
    tg_db_port: int = Field(5432, validation_alias="TG_DB_PORT")
    tg_db_name: str = Field("telegram_bot", validation_alias="TG_DB_NAME")
    tg_db_user: str = Field("amnezia", validation_alias="TG_DB_USER")
    tg_db_password: str = Field("amnezia", validation_alias="TG_DB_PASSWORD")

    panel_app_name: str = Field("Amnezia VPN", validation_alias="APP_NAME")

    # ── Proactive alerting (периодический опрос API панели) ──
    alert_enabled: bool = Field(True, validation_alias="ALERT_ENABLED")
    alert_cpu_threshold: float = Field(90.0, validation_alias="ALERT_CPU_THRESHOLD")
    alert_ram_threshold: float = Field(95.0, validation_alias="ALERT_RAM_THRESHOLD")
    alert_cpu_interval: int = Field(300, validation_alias="ALERT_CPU_INTERVAL")
    alert_overlimit_interval: int = Field(900, validation_alias="ALERT_OVERLIMIT_INTERVAL")
    alert_expiring_hour: int = Field(9, validation_alias="ALERT_EXPIRING_HOUR")
    alert_expiring_days: int = Field(1, validation_alias="ALERT_EXPIRING_DAYS")

    # ── Payments (Telegram Invoices) ──
    # Payments token от @BotFather (Payments). Пусто → оплата отключена.
    payment_provider_token: str = Field("", validation_alias="PAYMENT_PROVIDER_TOKEN")
    # ISO 4217 (RUB/USD/EUR/…) либо XTR для Telegram Stars.
    payment_currency: str = Field("RUB", validation_alias="PAYMENT_CURRENCY")
    # JSON-массив тарифов: [{"days":30,"price":199,"label":"1 месяц"}, …]
    # Пусто → используются тарифы по умолчанию.
    payment_tariffs: str = Field("", validation_alias="PAYMENT_TARIFFS")

    @property
    def tariffs(self) -> List[Tariff]:
        raw = self.payment_tariffs.strip() or _DEFAULT_TARIFFS_JSON
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            data = json.loads(_DEFAULT_TARIFFS_JSON)
        parsed = _parse_tariffs(data)
        return parsed or _parse_tariffs(json.loads(_DEFAULT_TARIFFS_JSON))

    @property
    def payments_enabled(self) -> bool:
        return bool(self.payment_provider_token)

    @computed_field
    @property
    def admin_ids(self) -> List[int]:
        result: List[int] = []
        for part in self.bot_admin_telegram_ids.split(","):
            part = part.strip()
            if part.lstrip("-").isdigit():
                result.append(int(part))
        return result

    @computed_field
    @property
    def db_dsn(self) -> str:
        return (
            f"postgresql://{self.tg_db_user}:{self.tg_db_password}"
            f"@{self.tg_db_host}:{self.tg_db_port}/{self.tg_db_name}"
        )

    def is_admin(self, telegram_id: int) -> bool:
        return telegram_id in self.admin_ids


settings = Settings()