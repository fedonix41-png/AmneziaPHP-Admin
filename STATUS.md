# Состояние проекта — 2026-06-23 13:30 UTC

## Выполнено

### 1. Исправление ошибок контейнеров (бот перезапускался)
- `telegram_bot/db/pool.py` — добавлено автосоздание таблиц БД бота при старте (fsm_states, users, cached_configs, payments)
- `telegram_bot/db/storage.py` — убран устаревший параметр `bot` из методов `PostgresStorage` (aiogram 3.13)
- `inc/LdapSync.php` — `SHOW TABLES LIKE` заменён на `SELECT EXISTS FROM information_schema.tables` (PostgreSQL-совместимый)

### 2. Обновление документации (7 файлов)
- `docs/structure.md` — полная перезапись (MySQL→PostgreSQL, актуальная структура)
- `docs/setup.md` — перезапись (MySQL→PostgreSQL)
- `migrations/README.md` — перезапись (MySQL→PostgreSQL)
- `docs/guidelines.md` — ссылка MySQL doc → PostgreSQL doc
- `.agents/rules/AGENTS.md` — несуществующий README.md → docs/structure.md
- `Speed-up.txt` — удалён раздел MySQL reverse DNS
- `docs/telegram_bot_spec.md` — проставлены статусы реализации

### 3. Админ-панель Telegram-бота — 12 новых/изменённых файлов

**Новые файлы:**
- `telegram_bot/keyboards/admin.py` — все клавиатуры админ-панели
- `telegram_bot/states/admin.py` — FSM-состояния для /add_client
- `telegram_bot/handlers/admin/__init__.py` — сборка admin-роутера
- `telegram_bot/handlers/admin/menu.py` — навигация (главное меню, выбор сервера/клиента)
- `telegram_bot/handlers/admin/servers.py` — мониторинг (метрики CPU/RAM/Disk/Net + онлайн) + диагностика (selftest, handshake)
- `telegram_bot/handlers/admin/clients.py` — управление клиентами (revoke/restore/delete/extend/expire/limit), /add_client (FSM), истекающие/overlimit
- `telegram_bot/handlers/admin/backups.py` — CRUD бэкапов + скачивание

**Изменённые файлы:**
- `telegram_bot/services/panel_api.py` — +18 админских методов
- `telegram_bot/handlers/admin/__init__.py` — сборка admin-роутера
- `telegram_bot/handlers/__init__.py` — регистрация admin-роутера
- `telegram_bot/handlers/client/menu.py` — удалён старый stub
- `telegram_bot/middlewares/access.py` — добавлен AdminGuardMiddleware
- `telegram_bot/bot.py` — регистрация AdminGuardMiddleware
- `public/index.php` — добавлен `GET /api/backups/{id}/download`
- `.env` — добавлен `PANEL_API_TOKEN` (admin JWT)

### 4. Исправления MySQL→PostgreSQL (первая итерация)
- `inc/VpnClient.php:2535` — `DATE_ADD(NOW(), INTERVAL ? DAY)` → `NOW() + (?::int * INTERVAL '1 day')`
- `inc/VpnClient.php:2537,2558,2701` — `= "active"` → `= \'active\'`

### 5. Исправления boolean = integer (PostgreSQL strict typing)
- PostgreSQL не разрешает сравнивать `boolean` с `integer` (`operator does not exist: boolean = integer`)
- Исправлено **7 вхождений** `is_active = 1` / `ubuntu_compatible = 1` → `= true` в 3 файлах:
  - `inc/InstallProtocolManager.php:79` — `listActive()`: протоколы не отображались в форме создания сервера
  - `inc/Translator.php:30,232,525,614` — языки, API-ключи, статистика переводов
  - `inc/ProtocolService.php:293,384` — счётчики протоколов и AI-генераций
- **Критический баг:** выпадающий список «Installation Protocol» был пуст — `listActive()` падал и возвращал `[]`

### 6. Исправления MySQL→PostgreSQL (вторая итерация — 2026-06-23 13:30)
- `inc/VpnClient.php:2650` — `traffic_sent`/`traffic_received` → `bytes_sent`/`bytes_received` (в PHP $this->data)
- `inc/VpnClient.php:2697,2700` — `traffic_sent, traffic_received` → `bytes_sent, bytes_received` в SQL-запросе `getClientsOverLimit()`
- **Причина:** колонки в PostgreSQL называются `bytes_sent`/`bytes_received`, а не `traffic_sent`/`traffic_received`. Запрос `getClientsOverLimit()` падал с 500 ошибкой.

### 6. Исправление Telegram parse_mode (ошибка «Unsupported start tag =»)

### 7. Исправление DEFAULT_SLUG и fallbackProtocols (2026-06-23 14:21)
- `inc/InstallProtocolManager.php:65-70` — `getDefaultSlug()` теперь возвращает реальный slug первого активного протокола из БД, а не жёстко зашитый `'amnezia-wg'` (которого нет в таблице protocols)
- `inc/InstallProtocolManager.php:1324` — `fallbackProtocols()`: `'is_active' => 1` → `'is_active' => true` (мёртвый код, но исправлен превентивно)
- **Причина:** при сабмите формы без явного выбора протокола, `getDefaultSlug()` возвращал `'amnezia-wg'`, `getBySlug()` не находил его → ошибка «Selected protocol not found or inactive»

---

## Текущее состояние

- Все 4 контейнера стабильны (db, web, dind, telegram_bot)
- Бот `@AmnTun7777StableBot` запущен в polling-режиме, БД инициализирована
- PANEL_API_TOKEN установлен в .env
- Админские API-методы работают (list_servers, expiring, overlimit — возвращают 200)
- Создание сервера через веб-панель протестировано (POST /servers/create → 302 → /servers/{id}/deploy)
- Все 70 миграций schema_migrations накатились успешно

### Что протестировано
1. ✅ `panel_api.list_servers()` — успешно
2. ✅ `panel_api.get_expiring_clients(days=7)` — успешно (200, пустой ответ — серверов/клиентов нет)
3. ✅ `panel_api.get_overlimit_clients()` — успешно (200, пустой ответ — серверов/клиентов нет; БЫЛ 500 из-за `traffic_sent`)
4. ✅ PHP syntax check всех inc/*.php — без ошибок
5. ✅ Grep `= "` по inc/ — в SQL-строках нет двойных кавычек, все `'active'` с одинарными
6. ✅ Выпадающий список протоколов — 6 активных протоколов отображаются
7. ✅ Создание сервера — энд-ту-энд от формы до записи в БД
8. ✅ Страница деплоя — `/servers/{id}/deploy` грузится (200)
9. ✅ Все 70 миграций применены
6. ⬜ Функционал админ-панели в боте — не протестирован энд-ту-энд (требует серверов/клиентов в БД)
7. ⬜ Backup download — роут существует, Content-Type требует правки (application/json → application/octet-stream)

---

## Что осталось

### Тестирование админ-панели
Для энд-ту-энд теста нужен хотя бы один сервер с клиентами:
1. Зайти в веб-панель http://localhost:8082 (admin@amnez.ia / admin123)
2. Создать сервер (раздел Servers → Add Server)
3. Создать клиента на этом сервере
4. В Telegram боте нажать /start → Админ-панель
5. Проверить: мониторинг, управление клиентами, /add_client, бэкапы

### Backup download: минорная правка
`public/index.php:2272` — `Content-Type: application/json` должно быть `application/octet-stream` для скачивания файлов бэкапов (не блокирует работу Python-клиента, но некорректно для браузеров).

---

## Файлы, изменённые в этой сессии

| Файл | Статус |
|------|--------|
| `inc/VpnClient.php` | ✅ `traffic_sent`→`bytes_sent` (3 вхождения) |
| `inc/InstallProtocolManager.php` | ✅ `is_active = 1` → `= true` (listActive), `getDefaultSlug()` динамический, `fallbackProtocols()` is_active=true |
| `inc/Translator.php` | ✅ `is_active = 1` → `= true` (4 места) |
| `inc/ProtocolService.php` | ✅ `is_active = 1` + `ubuntu_compatible = 1` → `= true` (2 места) |
| `telegram_bot/handlers/admin/clients.py` | ✅ parse_mode=None (6 мест) |
| `telegram_bot/handlers/admin/servers.py` | ✅ parse_mode=None (3 места) |
| `telegram_bot/handlers/admin/menu.py` | ✅ parse_mode=None (3 места) |
| `telegram_bot/handlers/admin/backups.py` | ✅ parse_mode=None (1 место) |
| `STATUS.md` | ✅ обновлён |

### 8. Восстановление потерянных протоколов (2026-06-23 14:50)
- **AmneziaWG 2.0** (`awg2`), **MTProxy** (`mtproxy`), **AIVPN** (`aivpn`), **Cloudflare WARP** (`cf-warp`) — 4 протокола бесследно исчезли при миграции MySQL→PostgreSQL
- **Корень:** две PostgreSQL-несовместимости в файлах миграций 058, 059, 060, 066:
  1. `INSERT ... VALUES (..., 1, 1)` в boolean-колонки — implicit cast integer→boolean не работает для INSERT (только для WHERE)
  2. `JSON_OBJECT(...)`, `JSON_ARRAY(...)` — MySQL-функции. В PostgreSQL: `JSON_BUILD_OBJECT(...)`, `JSON_BUILD_ARRAY(...)`
- Исправлены 4 migration-файла, миграции перезапущены. Все 10 протоколов в БД и в выпадающем списке. |


+

Other bugs found (not yet fixed, informational)
Backup download Content-Type (public/index.php:2272): application/json should be application/octet-stream (mentioned in STATUS.md, not causing functional issues for the bot).
No rate limiting on /api/auth/token — brute-forceable.
SSH passwords stored in vpn_servers table in plaintext (or weakly obfuscated).
JWT secret stored in database rather than environment variable — if DB leaks, all tokens can be forged.