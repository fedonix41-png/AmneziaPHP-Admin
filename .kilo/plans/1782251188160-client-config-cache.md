# Architectural fix: remove SSH from client view endpoint

## Problem
`GET /api/clients/{id}/details` в `public/index.php` делает **8–12 SSH-вызовов** при каждом просмотре клиента — даже если конфиг в БД актуален и не менялся. На проде с удалёнными серверами это десятки секунд задержки. Архитектурный антипаттерн.

## Root cause analysis

Два безусловных SSH-блока в `/details`:

1. **`regenerateConfigFromServer(true)`** (строка 2340) — для AWG-клиентов, всегда. 8–12 `shell_exec(ssh docker exec ...)`. Комментарий в коде: «AWG parameters должны быть всегда актуальны». Но параметры не меняются сами — только при переустановке протокола. Конфиг уже сохранён в `vpn_clients.config` при создании клиента.

2. **`syncStats()`** (строка 2352) — по умолчанию `?sync=1`. SSH для live-статистики. Бот уже передаёт `sync=0`, но дефолт должен быть `0`.

Для обоих случаев есть осознанные эндпоинты:
- `POST /regenerate-config` — когда нужно перегенерировать
- `?sync=1` — когда нужна live-статистика

Просмотр клиента не должен этого делать.

## Fix: `public/index.php` — 2 правки

### 1. Убрать `regenerateConfigFromServer()` из `/details`

**Строки 2337–2346** (current):
```php
        $isAwg = in_array($protocolSlug, ['amnezia-wg-advanced', 'wireguard-standard', 'amnezia-wg', 'awg2'], true);
        if ($isAwg) {
            try {
                $client->regenerateConfigFromServer(true);
                $client = new VpnClient($clientId);
                $clientData = $client->getData();
            } catch (Throwable $e) {
                error_log('Failed to regenerate client config in API /details: ' . $e->getMessage());
            }
        }
```

**Заменить на:**
```php
        // Config is already stored in vpn_clients.config from client creation.
        // No need to SSH-regenerate on every view — use POST /regenerate-config
        // when fresh server-side config is needed.
```

(Просто удалить блок — конфиг читается из БД, он всегда актуален.)

### 2. Сменить `syncStats()` дефолт с `1` на `0`

**Строка 2350** (current):
```php
        $shouldSync = ($_GET['sync'] ?? '1') !== '0';
```

**Заменить на:**
```php
        // Live stats from VPN server are opt-in (SSH, slow).
        // Pass ?sync=1 to pull fresh traffic data.
        $shouldSync = ($_GET['sync'] ?? '0') === '1';
```

Логика инвертирована: раньше `sync` был `1` по умолчанию (SSH всегда), теперь `0` по умолчанию (SSH только по явному запросу).

## Effect

| Сценарий | До | После |
|----------|-----|-------|
| Просмотр клиента через бота | 8–12 SSH (80–120s) | 0 SSH (<100ms) |
| Просмотр клиента через веб-панель | 8–12 SSH | 0 SSH |
| API `/details` без параметров | SSH всегда | 0 SSH |
| API `/details?sync=1` | SSH stats | SSH stats (как раньше) |
| `POST /regenerate-config` | SSH | SSH (без изменений) |

## No bot changes needed
Бот уже передаёт `sync=0` в `panel_api.client_details()`. С новым дефолтом `sync=0` на стороне PHP бот продолжит работать корректно без изменений.

## Files
- `public/index.php` — единственный изменяемый файл (2 строки)
