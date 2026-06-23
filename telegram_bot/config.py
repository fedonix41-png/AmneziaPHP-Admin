from __future__ import annotations

from typing import List

from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


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
