from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import httpx

from config import settings

logger = logging.getLogger(__name__)


class PanelAPIError(Exception):
    def __init__(self, message: str, status_code: int = 0, payload: Optional[dict] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.payload = payload or {}


class PanelAPI:
    def __init__(self, base_url: str, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self._client: Optional[httpx.AsyncClient] = None
        self.timeout = timeout

    async def start(self) -> None:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=self.timeout,
            )

    async def stop(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            raise RuntimeError("PanelAPI is not started")
        return self._client

    @staticmethod
    def _bearer(token: str) -> Dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    @staticmethod
    def _handle(response: httpx.Response, context: str) -> Dict[str, Any]:
        try:
            data = response.json()
        except ValueError:
            raise PanelAPIError(
                f"{context}: неверный JSON-ответ ({response.status_code})",
                status_code=response.status_code,
            )
        if response.status_code >= 400:
            message = data.get("error") or data.get("message") or f"{context}: HTTP {response.status_code}"
            raise PanelAPIError(message, status_code=response.status_code, payload=data)
        return data

    async def authenticate(self, email: str, password: str) -> Dict[str, Any]:
        context = "Авторизация"
        try:
            response = await self.client.post(
                "/api/auth/token",
                data={"email": email, "password": password},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        return self._handle(response, context)

    async def list_my_clients(self, token: str) -> List[Dict[str, Any]]:
        context = "Список подписок"
        try:
            response = await self.client.get("/api/clients", headers=self._bearer(token))
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        data = self._handle(response, context)
        return data.get("clients", []) or []

    async def client_details(self, token: str, client_id: int) -> Dict[str, Any]:
        context = "Данные подписки"
        try:
            response = await self.client.get(
                f"/api/clients/{client_id}/details",
                headers=self._bearer(token),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        data = self._handle(response, context)
        return data.get("client", {}) or {}

    async def client_qr(self, token: str, client_id: int) -> Dict[str, Any]:
        context = "QR-код"
        try:
            response = await self.client.get(
                f"/api/clients/{client_id}/qr",
                headers=self._bearer(token),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        data = self._handle(response, context)
        return data

    async def regenerate_config(self, token: str, client_id: int) -> Dict[str, Any]:
        context = "Сброс ключа"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/regenerate-config",
                headers=self._bearer(token),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        data = self._handle(response, context)
        return data.get("client", {}) or {}

    async def ai_assist(self, prompt: str, protocol_type: str = "") -> Dict[str, Any]:
        context = "AI-ассистент"
        if not settings.panel_api_token:
            raise PanelAPIError("AI-ассистент недоступен: не задан PANEL_API_TOKEN")
        payload: Dict[str, Any] = {"prompt": prompt}
        if protocol_type:
            payload["protocol_type"] = protocol_type
        try:
            response = await self.client.post(
                "/api/ai/assist",
                json=payload,
                headers=self._bearer(settings.panel_api_token),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({exc})") from exc
        return self._handle(response, context)


panel_api = PanelAPI(settings.panel_api_url, settings.request_timeout)
