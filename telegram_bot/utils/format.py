from __future__ import annotations

from datetime import datetime


def humanize_bytes(num) -> str:
    try:
        num = float(num)
    except (TypeError, ValueError):
        return "—"
    if num <= 0:
        return "0 Б"
    for unit in ("Б", "КБ", "МБ", "ГБ", "ТБ"):
        if abs(num) < 1024.0:
            return f"{num:3.1f} {unit}".strip()
        num /= 1024.0
    return f"{num:.1f} ПБ"


def humanize_date(value) -> str:
    if not value:
        return "—"
    if isinstance(value, datetime):
        return value.strftime("%d.%m.%Y %H:%M")
    try:
        return datetime.fromisoformat(str(value)).strftime("%d.%m.%Y %H:%M")
    except (ValueError, TypeError):
        return str(value)


def status_label(status) -> str:
    status = str(status or "").lower()
    mapping = {
        "active": "🟢 Активен",
        "revoked": "🔴 Заблокирован",
        "expired": "🟡 Истёк",
        "disabled": "⚪ Отключён",
    }
    return mapping.get(status, status or "—")


def online_label(is_online) -> str:
    return "🟢 Онлайн" if is_online else "⚪ Не в сети"
