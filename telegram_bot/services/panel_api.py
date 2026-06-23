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

    def _admin_token(self) -> str:
        token = settings.panel_api_token
        if not token:
            raise PanelAPIError("Админ-функции недоступны: не задан PANEL_API_TOKEN в .env")
        return token

    def _admin_headers(self) -> Dict[str, str]:
        return self._bearer(self._admin_token())

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

    # ── user auth ──────────────────────────────────────────────────

    async def authenticate(self, email: str, password: str) -> Dict[str, Any]:
        context = "Авторизация"
        try:
            response = await self.client.post(
                "/api/auth/token",
                data={"email": email, "password": password},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def list_my_clients(self, token: str) -> List[Dict[str, Any]]:
        context = "Список подписок"
        try:
            response = await self.client.get("/api/clients", headers=self._bearer(token))
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("clients", []) or []

    async def client_details(self, token: str, client_id: int, sync_stats: bool = False) -> Dict[str, Any]:
        """Fetch client details. Set sync_stats=True to pull live traffic from VPN server (slow, SSH)."""
        context = "Данные подписки"
        try:
            response = await self.client.get(
                f"/api/clients/{client_id}/details",
                headers=self._bearer(token),
                params={"sync": "1" if sync_stats else "0"},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
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
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def regenerate_config(self, token: str, client_id: int) -> Dict[str, Any]:
        context = "Сброс ключа"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/regenerate-config",
                headers=self._bearer(token),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("client", {}) or {}

    # ── AI ────────────────────────────────────────────────────────────

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
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    # ── admin: servers ────────────────────────────────────────────────

    async def list_servers(self) -> List[Dict[str, Any]]:
        context = "Список серверов"
        try:
            response = await self.client.get("/api/servers", headers=self._admin_headers())
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("servers", []) or []

    async def server_metrics(self, server_id: int, hours: int = 24) -> List[Dict[str, Any]]:
        context = "Метрики сервера"
        try:
            response = await self.client.get(
                f"/api/servers/{server_id}/metrics",
                headers=self._admin_headers(),
                params={"hours": hours},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("metrics", []) or []

    async def server_online(self, server_id: int) -> List[str]:
        context = "Онлайн клиенты"
        try:
            response = await self.client.get(
                f"/api/servers/{server_id}/online",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("online", []) or []

    async def server_selftest(
        self, server_id: int, protocol_id: int = 0, install: bool = False
    ) -> Dict[str, Any]:
        context = "Селф-тест сервера"
        payload: Dict[str, Any] = {"protocol_id": protocol_id, "install": install}
        try:
            response = await self.client.post(
                f"/api/servers/{server_id}/protocols/selftest",
                headers=self._admin_headers(),
                json=payload,
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def server_diagnose_handshake(
        self, server_id: int, client_id: int = 0, duration_seconds: int = 5
    ) -> Dict[str, Any]:
        context = "Диагностика рукопожатий"
        payload: Dict[str, Any] = {
            "client_id": client_id,
            "duration_seconds": duration_seconds,
        }
        try:
            response = await self.client.post(
                f"/api/servers/{server_id}/protocols/diagnose-handshake",
                headers=self._admin_headers(),
                json=payload,
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def server_clients(self, server_id: int) -> List[Dict[str, Any]]:
        context = "Клиенты сервера"
        try:
            response = await self.client.get(
                f"/api/servers/{server_id}/clients",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("clients", []) or []

    # ── admin: clients ───────────────────────────────────────────────

    async def create_client(
        self,
        server_id: int,
        name: str,
        expires_in_days: Optional[int] = None,
        protocol_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        context = "Создание клиента"
        payload: Dict[str, Any] = {"server_id": server_id, "name": name}
        if expires_in_days is not None:
            payload["expires_in_days"] = expires_in_days
        if protocol_id is not None:
            payload["protocol_id"] = protocol_id
        try:
            response = await self.client.post(
                "/api/clients/create",
                headers=self._admin_headers(),
                json=payload,
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        data = self._handle(response, context)
        return data.get("client", {}) or {}

    async def revoke_client(self, client_id: int) -> Dict[str, Any]:
        context = "Блокировка клиента"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/revoke",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def restore_client(self, client_id: int) -> Dict[str, Any]:
        context = "Разблокировка клиента"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/restore",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def delete_client(self, client_id: int) -> Dict[str, Any]:
        context = "Удаление клиента"
        try:
            response = await self.client.delete(
                f"/api/clients/{client_id}/delete",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def extend_client(self, client_id: int, days: int = 30) -> Dict[str, Any]:
        context = "Продление клиента"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/extend",
                headers=self._admin_headers(),
                json={"days": days},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def set_client_expiration(self, client_id: int, expires_at: Optional[str]) -> Dict[str, Any]:
        context = "Установка срока"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/set-expiration",
                headers=self._admin_headers(),
                json={"expires_at": expires_at},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def set_traffic_limit(self, client_id: int, limit_bytes: int) -> Dict[str, Any]:
        context = "Лимит трафика"
        try:
            response = await self.client.post(
                f"/api/clients/{client_id}/set-traffic-limit",
                headers=self._admin_headers(),
                json={"limit_bytes": limit_bytes},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def get_expiring_clients(self, days: int = 7) -> Dict[str, Any]:
        context = "Истекающие подписки"
        try:
            response = await self.client.get(
                "/api/clients/expiring",
                headers=self._admin_headers(),
                params={"days": days},
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def get_overlimit_clients(self) -> Dict[str, Any]:
        context = "Клиенты с превышением"
        try:
            response = await self.client.get(
                "/api/clients/overlimit",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    # ── admin: backups ────────────────────────────────────────────────

    async def create_backup(self, server_id: int) -> Dict[str, Any]:
        context = "Создание бэкапа"
        try:
            response = await self.client.post(
                f"/api/servers/{server_id}/backup",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def list_backups(self, server_id: int) -> Dict[str, Any]:
        context = "Список бэкапов"
        try:
            response = await self.client.get(
                f"/api/servers/{server_id}/backups",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def delete_backup(self, backup_id: int) -> Dict[str, Any]:
        context = "Удаление бэкапа"
        try:
            response = await self.client.delete(
                f"/api/backups/{backup_id}",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        return self._handle(response, context)

    async def download_backup(self, backup_id: int) -> bytes:
        """Returns raw file bytes for the backup JSON."""
        context = "Скачивание бэкапа"
        try:
            response = await self.client.get(
                f"/api/backups/{backup_id}/download",
                headers=self._admin_headers(),
            )
        except httpx.HTTPError as exc:
            raise PanelAPIError(f"{context}: нет связи с панелью ({str(exc) or type(exc).__name__})") from exc
        if response.status_code >= 400:
            self._handle(response, context)
        return response.content


panel_api = PanelAPI(settings.panel_api_url, settings.request_timeout)
