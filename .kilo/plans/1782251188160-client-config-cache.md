# План дальнейшего развития — июнь 2026

## Состояние на 2026-06-24 02:25

Клиентская и административная части Telegram-бота **полностью реализованы**. Архитектурные проблемы (SSH-задержки, потеря протоколов, in-memory кэш) исправлены. Веб-панель работает с 10 протоколами на PostgreSQL.

**Готово к проду:** управление клиентами, серверами, бэкапами, мониторинг, `/add_client`.

**Не реализовано:** платежи, автоматические алерты, критические уязвимости безопасности.

---

## Приоритет 1: Безопасность (до продакшена)

### 1.1 JWT secret в `.env`
`docs/security.md:95-98` — JWT signing key хранится в таблице `settings` БД. При утечке БД злоумышленник подписывает токены для любого пользователя.
- Перенести в `.env` (`JWT_SECRET`)
- Убрать из `settings` таблицы
- **Файлы:** `inc/JWT.php`, `public/index.php` (генерация токена), `inc/Config.php` (загрузка из `.env`)

### 1.2 Rate limiting на `/api/auth/token`
`docs/security.md:87-89` — нет защиты от brute-force.
- IP-based throttle: 5 попыток в минуту, экспоненциальная задержка
- **Файл:** `public/index.php` (роут `POST /api/auth/token`)

### 1.3 Шифрование SSH-паролей
`docs/security.md:91-93` — пароли в `vpn_servers` открытым текстом.
- `libsodium` encrypt/decrypt через `APP_KEY` из `.env`
- **Файлы:** `inc/VpnServer.php` (сохранение/чтение пароля), миграция для шифрования существующих

---

## Приоритет 2: Алертинг (периодический опрос)

Спек: `docs/telegram_bot_spec.md:154-173`

### 2.1 Фреймворк фоновых задач
Боту нужен периодический опрос API панели. Варианты:
- `aiogram` встроенный `asyncio.create_task()` с `while True: sleep(interval)`
- ИЛИ легковесный планировщик (без APScheduler — overkill)

**Интервалы:**
- Проверка CPU/RAM: каждые 5 минут
- Проверка overlimit: каждые 15 минут  
- Проверка истекающих подписок: раз в сутки (в 09:00 UTC)

**Файлы:** `telegram_bot/services/alerts.py` (уже есть skeleton), `telegram_bot/bot.py` (запуск задач при старте)

### 2.2 CPU/RAM алерт
- `GET /api/servers/{id}/metrics?hours=1` → последние метрики
- CPU > 90% или RAM > 95% → алерт админам
- Дедупликация: не слать повторно пока состояние не нормализуется
- **Файл:** `telegram_bot/services/alerts.py`

### 2.3 Overlimit алерт
- `GET /api/clients/overlimit` → список
- Уведомление админам с именами и лимитами
- **Уже реализован ручной просмотр** (`cb_admin_overlimit`). Нужен автоматический.

### 2.4 Истекающие подписки
- `GET /api/clients/expiring?days=1` → клиенты с истекающим сроком
- Ежедневный отчёт админам
- **Уже реализован ручной просмотр** (`cb_admin_expiring`). Нужен автоматический.

---

## Приоритет 3: Платежи

Спек: `docs/telegram_bot_spec.md:126-151`

### 3.1 Telegram Invoices (встроенные)
- Тарифы: конфигурация в `.env` или БД (дни + цена)
- `sendInvoice` → `pre_checkout_query` → `successful_payment`
- Автоматическое продление через `POST /api/clients/{id}/extend`
- Запись в таблицу `payments`
- **Файлы:** новый `telegram_bot/handlers/client/payments.py`, `telegram_bot/keyboards/client.py` (тарифные кнопки)

### 3.2 Внешние провайдеры (опционально)
- Генерация ссылки на внешнюю кассу
- Webhook для приёма подтверждений
- Кнопка «Проверить оплату» как fallback
- **Файлы:** `telegram_bot/handlers/client/payments.py`, `telegram_bot/services/payments.py`

### 3.3 Таблица `payments`
Уже создана в `03-telegram-bot-schema.sql` и `db/pool.py`. Колонки: `payment_id`, `telegram_id`, `amount`, `currency`, `status`, `provider`, `provider_tx_id`, `days_to_extend`.

---

## Приоритет 4: Мелкие правки

### 4.1 Backup download Content-Type
`public/index.php:2272` — `Content-Type: application/json` вместо `application/octet-stream`. Не блокирует Python-клиент, но некорректно для браузеров.

### 4.2 Деструктивное логирование
Спек: строка 202 — логирование удалений/блокировок в файл/канал.
**Файл:** `telegram_bot/middlewares/access.py` или новый `telegram_bot/services/audit.py`

### 4.3 End-to-end тестирование
Создать сервер → создать клиента → проверить все admin-фичи через бота.

---

## Порядок реализации

| # | Задача | Оценка сложности | Файлов |
|---|--------|-----------------|--------|
| 1 | JWT secret в `.env` | Средняя (нужна миграция users) | 3-4 |
| 2 | Rate limiting auth | Лёгкая | 1 |
| 3 | Шифрование SSH-паролей | Средняя (миграция + crypto) | 2-3 |
| 4 | Фреймворк фоновых задач | Лёгкая | 2 |
| 5 | Алерты (CPU, overlimit, expiry) | Средняя | 2-3 |
| 6 | Telegram Invoices | Средняя (FSM + Telegram API) | 3-4 |
| 7 | Внешние платёжки + webhook | Высокая (HTTP server) | 3-4 |
| 8 | Backup Content-Type | Тривиальная | 1 |
| 9 | Audit logging | Лёгкая | 1 |
| 10 | End-to-end тесты | Ручная | — |
