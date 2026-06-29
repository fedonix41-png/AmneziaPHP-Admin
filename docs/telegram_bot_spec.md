# Техническое задание (ТЗ) для AI-агента
## Telegram-бот и миграция AmneziaPHP-Admin на PostgreSQL

Этот документ описывает технические требования для реализации Telegram-бота и сопутствующей миграции базы данных веб-панели с MySQL на **PostgreSQL**.

---

## 🏗️ 1. Архитектура и контейнеризация (PostgreSQL-centric)

Вместо MySQL проект переводится на единый инстанс **PostgreSQL**, в котором разворачиваются две базы данных (или схемы):
1. `amnezia_panel` — для веб-панели управления.
2. `telegram_bot` — для локальных нужд Telegram-бота.

### Схема взаимодействия:
```mermaid
flowchart TD
    TG_User[Пользователь / Админ в TG] <-->|Интерфейс Telegram| TG_Bot[Telegram Bot (aiogram)]
    TG_Bot <-->|Аутентификация & Настройки| TG_DB[(PostgreSQL: telegram_bot)]
    TG_Bot <-->|REST API HTTPS| Panel_Web[AmneziaPHP-Admin Web]
    Panel_Web <-->|Данные панели| Panel_DB[(PostgreSQL: amnezia_panel)]
    Panel_Web <-->|SSH / Docker API| Servers[VPN-серверы]
```

---

## 💾 2. План миграции AmneziaPHP-Admin на PostgreSQL

Поскольку панель изначально написана под MySQL, перевод требует адаптации кода и SQL-миграций.

### А. Изменение `docker-compose.yml`
Удаляется сервис `db` (MySQL 8.0) и добавляется сервис `postgres:15`:
```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: amnezia-panel-postgres
    restart: unless-stopped
    env_file:
      - .env
    environment:
      POSTGRES_USER: ${DB_USERNAME:-amnezia}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-amnezia}
      POSTGRES_MULTIPLE_DATABASES: "amnezia_panel,telegram_bot" # Скрипт инициализации создаст две БД
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d # Скрипт автоматического создания баз
```

### Б. Инициализация нескольких баз данных
Для автоматического создания баз данных `amnezia_panel` и `telegram_bot` создается файл `docker-entrypoint-initdb.d/init-multiple-databases.sh`:
```bash
#!/bin/bash
set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "  Creating database '$database'"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	    CREATE DATABASE $database;
	    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created"
fi
```

### В. Модификация `inc/DB.php` в панели
PHP-код подключения переключается на драйвер `pgsql`:
```php
$dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', $host, $port, $db);
self::$pdo = new PDO($dsn, $user, $pass, $options);
```
*(Примечание: Запросы `SET NAMES utf8mb4` и `collation` в MySQL не нужны для PostgreSQL, так как PostgreSQL по умолчанию использует UTF-8 на уровне базы).*

### Г. Адаптация SQL-миграций (`migrations/`)
Необходимо скорректировать SQL-скрипты под PostgreSQL:
*   Заменить `AUTO_INCREMENT` на `SERIAL` или `BIGSERIAL`.
*   Заменить обратные кавычки (`` ` ``) на двойные кавычки (`"`) или полностью удалить их.
*   Удалить MySQL-специфичные директивы, такие как `ENGINE=InnoDB`, `DEFAULT CHARSET=utf8mb4`, `COLLATE=...`.
*   Заменить функции вроде `NOW()` / `CURRENT_TIMESTAMP` на аналоги, если синтаксис различается.

---

## 🗄️ 3. База данных Telegram-бота (`telegram_bot`)

Бот использует СУБД PostgreSQL. Структура таблиц:

```sql
CREATE TABLE users (
    telegram_id BIGINT PRIMARY KEY,
    amnezia_client_id VARCHAR(255) NULL,
    email VARCHAR(255) NULL,
    role VARCHAR(50) DEFAULT 'user', -- 'user' | 'manager' | 'admin'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cached_configs (
    client_id VARCHAR(255) PRIMARY KEY,
    config_text TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    telegram_id BIGINT REFERENCES users(telegram_id),
    amount NUMERIC(10, 2),
    currency VARCHAR(10),
    status VARCHAR(50), -- 'pending', 'completed', 'failed'
    provider VARCHAR(50), -- 'telegram_invoice', 'yookassa', 'stripe', etc.
    days_to_extend INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 💳 4. Реализация системы оплаты (Встроенные и Сторонние провайдеры)

Бот должен поддерживать гибкую систему биллинга.

### А. Встроенные оплаты Telegram (Telegram Invoices)
Используются для оплаты картами (через Stripe, ЮKassa и др. внутри интерфейса Telegram) или через Telegram Stars:
1.  **Выставление счета:** Бот отправляет сообщение с методом `sendInvoice`.
2.  **Проверка возможности оплаты:** Обработка события `pre_checkout_query`. Бот проверяет статус клиента через API панели. Если клиент заблокирован окончательно или удален — отклоняет платеж.
3.  **Подтверждение оплаты:** После получения события `successful_payment` бот отправляет запрос:
    *   `POST /api/clients/{client_id}/extend` с параметром `{ "days": X }`.
    *   Создает запись в таблице `payments` со статусом `completed`.
    *   Отправляет пользователю сообщение об успешном продлении и обновленный статус подписки.

### Б. Сторонние провайдеры (Внешние ссылки / Webhooks)
Используются, когда пользователь платит через внешний сайт/эквайринг (например, CryptoPay, QIWI, LAVA):
1.  **Генерация счета:** Бот делает API-запрос к сторонней кассе, получает ссылку на оплату (`payment_url`) и уникальный `transaction_id`.
2.  **Запись в БД:** Бот создает в локальной таблице `payments` строку со статусом `pending`.
3.  **Переход на оплату:** Бот отправляет пользователю инлайн-кнопку со ссылкой на оплату и кнопкой `[🔄 Проверить оплату]`.
4.  **Обработка Webhook (Рекомендуется):**
    *   Бот запускает простейший HTTP-сервер (внутри `aiogram` через `aiohttp` на выделенном порту).
    *   При поступлении Webhook от платежной системы о зачислении средств:
        *   Находится транзакция в таблице `payments`.
        *   Выполняется запрос к API панели: `POST /api/clients/{client_id}/extend`.
        *   Пользователю в Telegram отправляется уведомление об успешной оплате.
5.  **Ручная проверка (Запасной вариант):** При нажатии кнопки `[Проверить оплату]` бот запрашивает статус транзакции у платежного API и, если она оплачена, производит продление.

> **Реализовано (А):** встроенные Telegram Invoices — `telegram_bot/handlers/client/payments.py` (роутер `client.payments`):
> `sendInvoice` → `pre_checkout_query` (проверка сессии и статуса клиента) → `successful_payment`
> (запись в `payments` со статусом `completed` + `POST /api/clients/{id}/extend`).
> Тарифы и провайдер настраиваются в `.env` (`PAYMENT_PROVIDER_TOKEN`, `PAYMENT_CURRENCY`, `PAYMENT_TARIFFS`),
> разбор — `config.py::Settings.tariffs`; репозиторий платежей — `services/payments.py::PaymentsRepo`.
> Кнопка «💳 Продлить подписку» появляется в главном меню только при заданном `PAYMENT_PROVIDER_TOKEN`
> (`keyboards/client.py::main_menu_kb`). При сбое продления платёж помечается `paid_unfulfilled`
> и админам уходит алерт (`services/alerts.py::send_alert_to_admins`).
>
> **Не реализовано (Б):** внешние провайдеры и приём webhook'ов от платёжных систем (опционально, см. план разработки).

---

## 🔔 5. Проактивный алертинг и рассылка администраторам

### А. Механизм рассылки
*   Все администраторы хранятся в конфигурации в виде списка `ADMIN_TELEGRAM_IDS` (считывается из `.env`).
*   При отправке любого критического алерта бот совершает прямую рассылку в цикле:
    ```python
    async def send_alert_to_admins(bot: Bot, text: str):
        for admin_id in settings.ADMIN_TELEGRAM_IDS:
            try:
                await bot.send_message(chat_id=admin_id, text=text, parse_mode="HTML")
            except Exception as e:
                logging.error(f"Не удалось отправить алерт админу {admin_id}: {e}")
    ```
*   Для предотвращения блокировок (Rate Limits) интервал между отправками — не менее 0.05 сек (`asyncio.sleep(0.05)`).

### Б. Источники алертов (периодический опрос API)

> **Реализовано** в `telegram_bot/services/alerts.py::AlertScheduler` (см. `.env.example` → «Proactive Alerting»). Запуск/остановка фоновых `asyncio`-задач — в `_on_startup`/`_on_shutdown` (`telegram_bot/bot.py`). Дедупликация: CPU/RAM алертит только при переходе в аварийное состояние и при возврате в норму; overlimit — только по новым клиентам; истекающие — раз в сутки.

*   **Авария на сервере:** `GET /api/servers/{id}/metrics` — CPU > 90% или RAM > 95% на протяжении 5 минут.
*   **Превышение лимита трафика:** `GET /api/clients/overlimit` — уведомление админа о клиентах, превысивших лимит, для ручного разбора или предложения платного пакета.
*   **Истекающие подписки:** раз в сутки `GET /api/clients/expiring` — отчет «У N пользователей завтра заканчивается доступ. Отправить напоминание?».

---

## 📋 6. Интерфейс и функции бота

> **Статус реализации (2026-06-24):** Клиент и админ-панель полностью реализованы. Платежи — в разработке. Алертинг (раздел 5) — **реализован** (`telegram_bot/services/alerts.py`, запуск в `telegram_bot/bot.py`).

### Функционал пользователя (VPN-клиента):
*   ✅ `Авторизация` по email/паролю веб-панели.
*   ✅ `Получение файлов` настроек (QR-код и `.conf`).
*   ✅ `Статистика`: трафик в реальном времени, лимиты, дата окончания.
*   ✅ `Сброс ключа`: перегенерация конфигурации.
*   ⬜ `Продление`: выбор тарифа и оплата (Telegram Invoices / внешняя ссылка).
*   ✅ `AI-ассистент`: решение проблем с подключением на базе ИИ (`POST /api/ai/assist` — рекомендации по выбору протоколов).

### Функционал Администратора:
*   ✅ `Мониторинг`: статус всех серверов, метрики (CPU/RAM/Диск/Сеть), количество клиентов онлайн.
*   ✅ `Управление клиентами`: поиск, блокировка (`revoke`), активация (`restore`), удаление, изменение срока и лимитов трафика, просмотр QR-кода и конфига.
*   ✅ `Быстрое создание клиента (Генератор инвайтов)`: команда `/add_client <name>`, выбор срока и лимита трафика через инлайн-кнопки. Бот создаёт клиента (`POST /api/clients/create`), устанавливает срок (`set-expiration`) и лимит (`set-traffic-limit`), присылает готовый конфиг и QR-код для пересылки клиенту.
*   ✅ `Управление серверами`: запуск селф-тестов и диагностики рукопожатий на серверах.
*   ✅ `Бэкап`: инициация создания резервной копии (`POST /api/servers/{id}/backup`), просмотр списка (`GET /api/servers/{id}/backups`) и отправка файла бэкапа в чат администратора.

---

## 🔐 7. Безопасность и архитектура интеграции

*   **Постоянный API-токен:** через `POST /api/tokens` создаётся постоянный токен с правами Admin. Прописывается в `.env` бота. Бот выполняет все операции от своего имени.
*   **Разделение прав (ACL) на уровне бота:** бот валидирует Telegram ID входящего пользователя. Если ID ∈ `ADMIN_TELEGRAM_IDS` — открывается админское меню; остальные видят только клиентское меню после авторизации по Email/Паролю (`POST /api/auth/token` → JWT).
*   **Связка аккаунтов:** после успешной авторизации бот сохраняет `telegram_id <-> client_id` в локальной БД. Основные данные всегда запрашиваются напрямую из REST API, чтобы избежать рассинхронизации.
*   **Логирование деструктивных действий:** удаление серверов/клиентов, сброс настроек, блокировки логируются в отдельный лог-файл бота и/или отправляются в специальный технический Telegram-канал.

> **Реализовано** в `telegram_bot/services/audit.py::audit.log` (вызывается из админ/клиентских хендлеров):
> блокировка клиента (`revoke`), удаление клиента (`delete`), удаление бэкапа, сброс ключа (`regenerate-config`).
> По умолчанию запись идёт в `audit`-логгер (общий поток stdout); при заданном `AUDIT_LOG_FILE`
> (`telegram_bot/bot.py::configure_logging`) подвешивается отдельный `FileHandler` (propagate=False).
> При `AUDIT_NOTIFY_ADMINS=true` действие дублируется рассылкой админам (`services/alerts.py::send_alert_to_admins`).
> Мастер-переключатель — `AUDIT_ENABLED` (см. `.env.example` → «Audit logging»).

### Рекомендуемый стек
*   **Язык/фреймворк:** Python + aiogram (асинхронность, FSM для цепочек создания клиентов).
*   **HTTP-клиент:** httpx (асинхронные запросы к REST API).
*   **БД бота:** PostgreSQL (схема `telegram_bot`) — только связки `telegram_id <-> client_id`, сессии авторизации, платежи, кэш конфигов.

---

## 🧪 8. Чек-лист тестирования (QA)
*   [x] База данных PostgreSQL успешно инициализирует схемы `amnezia_panel` и `telegram_bot`.
*   [x] Миграции веб-панели проходят без синтаксических ошибок в pgsql-драйвере.
*   [x] Бот корректно определяет роли пользователей (админ/клиент) — через `ADMIN_TELEGRAM_IDS`.
*   [x] При сбросе настроек старый QR/конфиг аннулируется, новый успешно работает.
*   [ ] При отправке платежа через встроенную форму Telegram Stars или Stripe подписка продлевается автоматически, транзакция фиксируется в БД.
*   [ ] Внешние вебхуки оплат обрабатываются корректно, бот мгновенно включает доступ и присылает сообщение.
*   [x] Алерты о высокой нагрузке CPU (>90%) на сервере доставляются всем администраторам напрямую.
