# План: Интеграция протокола OpenVPN over Cloak в админ-панель

## Цель

Добавить протокол OpenVPN over Cloak как новый script-driven протокол панели. Клиентские конфиги (QR) должны импортироваться в официальный клиент Amnezia VPN без правок. Zero regressions для существующих протоколов.

## Архитектурное решение

Переиспользовать существующий скриптовый движок протоколов. Slug `openvpn-cloak` → `InstallProtocolManager::resolveHandler()` возвращает `'script'` (нет slug-match, нет `builtin_awg` engine) → install/uninstall/detect/add_client идут через `runScript()`. **PHP-диспетчер не правится.**

## Ключевые факты, установленные анализом upstream `amnezia-client` и кода панели

1. **Готового Docker-образа нет.** На Docker Hub (`amneziavpn` namespace) НЕТ комбинированного `amnezia-openvpn-cloak`. Клиент собирает образ сам: `build_container.sh` = `docker build --no-cache --pull -t $CONTAINER_NAME $DOCKERFILE_FOLDER --build-arg SERVER_ARCH=$(uname -m)`. Решено (согласовано): **собирать на сервере**, встраивая Dockerfile + configure-скрипты в install_script как heredoc'и (паттерн идентичен миграции `060_add_aivpn_protocol.sql`, где `git clone` + `docker build`).
2. **`generateQRCode()` (VpnClient.php:1432) диспетчирует по содержимому config, не по slug.** Не-vless → всегда `QrUtil::encodeOldPayloadFromConf()` (WireGuard-парсер). Для JSON/`.ovpn` даёт битый envelope. → QR генерируем **напрямую, обходя `generateQRCode()`**.
3. **Универсальный поток `create()` уже обрабатывает скриптовые протоколы** (`addClient` @523 → `output_template` @626 → `generateQRCode` @638). Ветка на строке 442 НЕ нужна. Нужен **один post-override блок сразу после строки 638**, переопределяющий `$config` и `$qrCode`.
4. **Формат Amnezia envelope** (из `QrUtil::buildOldEnvelopeFromConf`, `encodeXrayPayload`): `{containers:[{<proto>:{last_config,port,transport_proto},container:<name>}], defaultContainer, description, dns1, dns2, hostName}`. Сжатие через существующий `encodeOldPayloadFromJson()`.
5. **ck-client last_config** (из `cloak_configurator.cpp`): JSON-строка с `Transport:"direct"`, `ProxyMethod:"openvpn"`, `EncryptionMethod:"aes-gcm"`, `UID`, `PublicKey`, `ServerName`, `NumConn:1`, `BrowserSig:"chrome"`, `StreamTimeout:300`, `RemoteHost`, `RemotePort`.
6. **openvpn last_config** (из `openvpn_configurator.cpp`): JSON `{"config":"<.ovpn-текст>"}`. В `.ovpn` строка `remote 127.0.0.1 1194` (ck-client мостит локально), `route $REMOTE_HOST 255.255.255.255 net_gateway` (внешний IP сервера).

---

## Затрагиваемые файлы

| Файл | Изменение | Что делаем |
|------|-----------|------------|
| `migrations/074_add_openvpn_cloak_protocol.sql` | **Новый** | INSERT протокола (install_script со встроенным Dockerfile/heredoc'ами), uninstall_script, detect, add_client-скрипт, переменные, шаблоны, переводы |
| `inc/QrUtil.php` | **Правка** | Новый метод `encodeOpenVpnCloakPayload(array $cfg): string` |
| `inc/VpnClient.php` | **Правка** | Один post-override блок в `create()` после строки 638 (slug `openvpn-cloak`) |
| `docs/api.md` | **Правка** | Протокол `openvpn-cloak` (SSOT) |
| `docs/architecture.md` | **Правка** | Handler `openvpn-cloak` (script-driven) |

**НЕ трогается:** `generateQRCode()`, `InstallProtocolManager.php`, `ProtocolService.php`, `controllers/*`, `telegram_bot/*`, все существующие миграции, Twig-шаблоны.

---

## Детали реализации

### 1. install_script (в миграции 074)

Один bash-скрипт, выполняемый через `runScript()` (heredoc-обёртка панели). Структура:

```
#!/bin/bash
set -euo pipefail
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
CLOAK_PORT="${SERVER_PORT:-443}"
OPENVPN_PORT=1194
SS_PORT=8388
BUILD_DIR="/opt/amnezia/openvpn-cloak"
SERVER_ARCH="$(uname -m)"
EXTERNAL_IP="$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "${SERVER_HOST}")"
FAKE_SITE="${FAKE_SITE:-domain.ru}"

# 1. Подготовка build-контекста
mkdir -p "$BUILD_DIR"
# (heredoc) записать Dockerfile (из client/server_scripts/openvpn_cloak/Dockerfile; фикс арх-детекции)
# (heredoc) записать configure_container.sh, start.sh, template.ovpn (из upstream без изменений)

# 2. Сборка образа (аналог build_container.sh). Образ содержит PLACEHOLDER start.sh.
docker build --pull -t "$CONTAINER_NAME" "$BUILD_DIR" --build-arg SERVER_ARCH="$SERVER_ARCH"

# 3. Запуск контейнера с монтированием тома для сохранения данных CA и ключей (адаптация run_container.sh)
docker network create amnezia-dns-net 2>/dev/null || true
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Создаем папку для персистентных данных на хосте
DATA_DIR="/opt/amnezia/openvpn-cloak/data"
mkdir -p "$DATA_DIR/openvpn" "$DATA_DIR/cloak" "$DATA_DIR/shadowsocks"

# Запуск контейнера с пробросом тома
docker run -d --privileged --cap-add=NET_ADMIN --restart always \
  -v "$DATA_DIR:/opt/amnezia" \
  -p "${CLOAK_PORT}:443/tcp" --name "$CONTAINER_NAME" "$CONTAINER_NAME"
docker exec -i "$CONTAINER_NAME" bash -c 'mkdir -p /dev/net; [ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200'

# 4. Копирование скриптов в смонтированную директорию (для персистентности)
cp "$BUILD_DIR/configure_container.sh" "$DATA_DIR/configure_container.sh"
cp "$BUILD_DIR/start.sh"              "$DATA_DIR/start.sh"
cp "$BUILD_DIR/template.ovpn"         "$DATA_DIR/openvpn/template.ovpn"

# PKI (easyrsa) внутри контейнера с проверкой на существование (не перезаписывать существующий CA при reinstall):
docker exec -i "$CONTAINER_NAME" bash -c 'cd /opt/amnezia/openvpn && [ -f ca.crt ] || { easyrsa init-pki && easyrsa gen-dh && \
  (echo yes | easyrsa build-ca nopass) && (echo yes | easyrsa gen-req AmneziaReq nopass) && \
  (echo yes | easyrsa sign-req server AmneziaReq) && openvpn --genkey --secret ta.key && \
  cp pki/dh.pem pki/ca.crt pki/issued/AmneziaReq.crt pki/private/AmneziaReq.key . && easyrsa gen-crl && cp pki/crl.pem crl.pem; }'

# 5. Настройка через upstream configure_container.sh (генерит server.conf, ck-config.json, ss-config.json, cloak/ss ключи)
docker exec -i -e OPENVPN_PORT=1194 -e OPENVPN_SUBNET_IP=10.8.2.0 -e OPENVPN_SUBNET_MASK=255.255.255.0 \
  -e OPENVPN_CIPHER=AES-256-GCM -e OPENVPN_HASH=SHA512 -e OPENVPN_NCP_DISABLE="" -e OPENVPN_TLS_AUTH="" \
  -e OPENVPN_ADDITIONAL_SERVER_CONFIG="" -e CLOAK_SERVER_PORT=443 -e SHADOWSOCKS_SERVER_PORT=8388 \
  -e SHADOWSOCKS_CIPHER=chacha20-ietf-poly1305 -e FAKE_WEB_SITE_ADDRESS="$FAKE_SITE" \
  "$CONTAINER_NAME" bash /opt/amnezia/configure_container.sh
# configure_container.sh создаёт: cloak_admin_uid.key, cloak_bypass_uid.key, cloak_public.key, cloak_private.key,
#   cloak/ck-config.json, shadowsocks/ss-config.json, openvpn/server.conf

# 6. Перезапуск контейнера → start.sh поднимает openvpn/ck-server/ssserver
docker restart "$CONTAINER_NAME"
sleep 3

# Чтение ключей для отчёта панели (ck-server -k выводит "PUB,PRIV" через запятую; читаем из файлов)
PUB=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_public.key)
BYPASS=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_bypass_uid.key)
SS_PASSWORD=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/shadowsocks/shadowsocks.key)

# Вывод для парсера панели
echo "Variable: container_name=$CONTAINER_NAME"
echo "Variable: vpn_port=$CLOAK_PORT"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: ss_password=$SS_PASSWORD"
echo "Variable: fake_site=$FAKE_SITE"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Port: $CLOAK_PORT"
```

**Замечания:**
- `SERVER_IP_ADDRESS` (eth0:0 alias в оригинале) — пропускаем; нужен только за NAT.
- Dockerfile upstream содержит баг арх-детекции (`[ $SERVER_ARCH="x86_64" ]` всегда true → CK_ARCH=amd64). В копии Dockerfile заменить на `[ "$SERVER_ARCH" = "x86_64" ]`. Для x86_64 нейтрально; для ARM критично.
- `ck-server -k` выводит `PUB,PRIV` через запятую (см. upstream `IFS=, read ... <<<$(ck-server -k)`); мы читаем готовые файлы `cloak_public.key`/`cloak_private.key` вместо парсинга вывода.
- `configure_container.sh` из upstream используется БЕЗ изменений (гарантия паритета с клиентом). Все его env-вары задаём явно в `docker exec -e`.
- Во время `docker build` с VPS качаются `ck-server` (cbeuw/Cloak releases) и `shadowsocks-rust`. Если GitHub недоступен — сборка упадёт (тот же риск, что у aivpn).

**metadata в `definition`:**
```json
{"engine":"shell","metadata":{"container_name":"amnezia-openvpn-cloak","config_dir":"/opt/amnezia/openvpn-cloak","port_range":[443,443],"openvpn_subnet":"10.8.2.0/24"}}
```

### 2. uninstall_script
```
docker stop $CONTAINER_NAME; docker rm -fv $CONTAINER_NAME; rm -rf /opt/amnezia/openvpn-cloak
echo {"success":true}
```
(Данные и ключи живут в смонтированной директории на хосте `/opt/amnezia/openvpn-cloak/data` — удаление папки `/opt/amnezia/openvpn-cloak` полностью сносит и данные, и сборочный контекст.)

### 3. detect + restore скрипты (фазы `detect`, `restore`)

**Контекст (проверено по `deploy()` @181 и `restore()` @396):** `deploy()` сначала вызывает `detect`. Если detect вернёт `existing`/`partial`, UI предлагает «Восстановить/Переустановить». При выборе «Восстановить» → `restore()` → для script-handler → `runScript('restore')` → **выбросит исключение «Скрипт restore не настроен» (@825), т.к. фаза restore не имеет fallback.** Значит detect и restore — связаны: либо detect всегда `absent` (restore не нужен, но re-deploy молча снесёт существующий контейнер через `docker rm -f`), либо detect умеет возвращать `existing` И есть restore-скрипт.

**Решение (включить restore для безопасности):** detect возвращает `existing` при наличии контейнера + `/opt/amnezia/openvpn/server.conf` + `/opt/amnezia/cloak/ck-config.json`, иначе `absent`. restore-скрипт перечитывает ключи из существующего контейнера и выводит `Variable:`-строки → `markServerActive` обновит `server_protocols`. Авто-импорт клиентов в restore НЕ делается (это awg-специфика; клиенты OpenVPN пересоздаются по запросу).

```
# restore: контейнер уже существует, перечитать ключи
PUB=$(docker exec "$SERVER_CONTAINER" cat /opt/amnezia/cloak/cloak_public.key)
BYPASS=$(docker exec "$SERVER_CONTAINER" cat /opt/amnezia/cloak/cloak_bypass_uid.key)
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo "Variable: container_name=$SERVER_CONTAINER"
echo "{\"success\":true,\"mode\":\"restore\"}"
```
Парсер `runScript()` понимает JSON-ответ (`@877`). detect возвращает `{"status":"existing","details":{...}}` / `absent`.

### 4. add_client скрипт (фаза `add_client`)

**ВАЖНО (механика скриптовых протоколов, проверено по `runScript()` @791):**
- `runScript()` читает фазу ИЗ `definition['scripts'][$phase]` (@794) ПЕРВЫМ; fallback на колонки `install_script`/`uninstall_script` — ТОЛЬКО для `install`/`uninstall` (@796-799). **`detect`/`add_client`/`restore` fallback'а не имеют**: их отсутствие → detect=`absent`, add_client=молча success без сертификата (@817-823, битый клиент), restore=исключение (@825).
- **Распределение скриптов (для совместимости с UI-редактором протоколов):**
  - `install_script` / `uninstall_script` → в **колонках** (UI их читает/пишет; `runScript` возьмёт колонку т.к. в `definition.scripts` этих ключей НЕТ).
  - `detect` / `add_client` / `restore` → в **`definition.scripts`** (колонок для них нет).
  - В `definition.scripts` НЕ дублировать install/uninstall — иначе UI-правки колонок будут игнорироваться (definition.scripts приоритетнее).
- `buildExports()` (@1086) экспортирует только `SERVER_HOST/SERVER_USER/SERVER_CONTAINER/SERVER_PORT` + `PROTOCOL_*`. **`LOGIN` НЕ экспортируется.** Но `renderTemplate()` (@829, @1183) подставляет `{{options.login}}` (context.options = `$vars`, где `login` установлен @503) текстово В скрипт ДО выполнения. Значит login передаётся через шаблонный плейсхолдер `{{options.login}}`, а не через env. Т.к. подстановка текстовая (shell-injection риск) — валидировать в bash: `[[ "$LOGIN" =~ ^[a-zA-Z0-9_-]+$ ]] || exit 1`.

```
LOGIN="{{options.login}}"          # шаблонная подстановка (buildExports login не экспортирует)
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
[[ "$LOGIN" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Invalid login" >&2; exit 1; }
# 1. docker exec ... easyrsa build-client-full <LOGIN> nopass (в /opt/amnezia/openvpn)
# 2. прочитать ca.crt, <LOGIN>.crt, <LOGIN>.key, ta.key из контейнера
# 3. собрать .ovpn по template.ovpn: remote 127.0.0.1 1194, route $REMOTE_HOST net_gateway,
#    подставить ca/cert/key/tls-auth, cipher AES-256-GCM, DNS 1.1.1.1/1.0.0.1
# 4. OVPN_B64=$(printf '%s' "$OVPN" | base64 -w 0)   # одна строка, без переносов
# 5. прочитать cloak_public_key, cloak_bypass_uid из /opt/amnezia/cloak/*.key
echo "Variable: ovpn_config_b64=$OVPN_B64"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$UID"
echo "Variable: server_host=$SERVER_HOST"
echo "Variable: vpn_port=$CLOAK_PORT"
echo "Variable: fake_site=$FAKE_SITE"
```
`base64 -w 0` обязателен (без переносов) — парсер `Variable: KEY=(.*)$` (`InstallProtocolManager.php:942`) берёт всю строку.

### 5. QrUtil::encodeOpenVpnCloakPayload() — новая правка

```php
public static function encodeOpenVpnCloakPayload(array $cfg): string
{
    $ckConfig = [
        'Transport' => 'direct',
        'ProxyMethod' => 'openvpn',
        'EncryptionMethod' => 'aes-gcm',
        'UID' => (string)($cfg['bypass_uid'] ?? ''),
        'PublicKey' => (string)($cfg['public_key'] ?? ''),
        'ServerName' => (string)($cfg['fake_site'] ?? 'domain.ru'),
        'NumConn' => 1,
        'BrowserSig' => 'chrome',
        'StreamTimeout' => 300,
        'RemoteHost' => (string)($cfg['server_host'] ?? ''),
        'RemotePort' => (string)($cfg['vpn_port'] ?? 443),
    ];
    $envelope = [
        'containers' => [
            ['cloak' => [
                'last_config' => json_encode($ckConfig, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES),
                'port' => (string)($cfg['vpn_port'] ?? 443),
                'transport_proto' => 'tcp',
            ], 'container' => 'amnezia-cloak'],
            ['openvpn' => [
                'last_config' => json_encode(['config' => (string)($cfg['ovpn'] ?? '')], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES),
                'port' => '1194',
                'transport_proto' => 'tcp',
            ], 'container' => 'amnezia-openvpn'],
        ],
        'defaultContainer' => 'amnezia-openvpn',
        'description' => (string)($cfg['server_host'] ?? ''),
        'dns1' => '1.1.1.1', 'dns2' => '1.0.0.1',
        'hostName' => (string)($cfg['server_host'] ?? ''),
    ];
    return self::encodeOldPayloadFromJson(
        json_encode($envelope, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
}
```
Переиспользует существующие `encodeOldPayloadFromJson()` + `urlsafe_b64_encode()`. Без новых зависимостей.

### 6. VpnClient::create() — единственная правка

Сразу **после строки 638** (`$qrCode = self::generateQRCode($config, $slug);`) вставить:
```php
if ($slug === 'openvpn-cloak') {
    require_once __DIR__ . '/QrUtil.php';
    $ovpn = base64_decode((string)($vars['ovpn_config_b64'] ?? ''), true) ?: '';
    $config = $ovpn;   // raw .ovpn — для .conf-выдачи/дебага
    $qrCode = QrUtil::pngBase64(QrUtil::encodeOpenVpnCloakPayload([
        'ovpn' => $ovpn,
        'public_key' => $vars['cloak_public_key'] ?? '',
        'bypass_uid' => $vars['cloak_bypass_uid'] ?? '',
        'server_host' => $vars['server_host'] ?? ($serverData['host'] ?? ''),
        'vpn_port' => $vars['vpn_port'] ?? 443,
        'fake_site' => $vars['fake_site'] ?? 'domain.ru',
    ]));
    $clientIP = $clientIP ?: '10.8.2.2';   // OpenVPN раздаёт IP сам; для БД-уникальности достаточно
}
```
Это переопределяет и `$config` (был пустым/placeholder из output_template @626), и `$qrCode` (битый из `generateQRCode` @638). Один компактный блок. **`generateQRCode()` и `output_template` не трогаются** (output_template = placeholder, т.к. переопределяется).

Далее INSERT в `vpn_clients` (строка 649) сохранит: `config` = raw `.ovpn`, `qr_code` = PNG data-URI envelope, `public_key`/`private_key` = заглушки (как в legacy-openvpn), `client_ip` = 10.8.2.x. Telegram-бот читает эти колонки без правок.

### 7. Хранение серверных секретов
`runScript()` install возвращает `Variable:`-строки → `markServerActive()` автоматически пишет их в `server_protocols.config_data.extras` (`cloak_public_key`, `cloak_bypass_uid`, `ss_password`, `fake_site`, `vpn_port`). При `create()` они читаются в `$vars` (строки 116–166). Доп. логики не нужно.

---

## Порядок выполнения

1. **Миграция 074** — `INSERT INTO protocols` (slug `openvpn-cloak`). **Экранирование (критично):** bash-скрипты содержат `$`, кавычки, backticks, переводы строк. Колонки `install_script`/`uninstall_script` — через dollar-quoting `$tag$...bash...$tag$`. Фазы `detect`/`add_client`/`restore` — в JSONB `definition.scripts.*` через `jsonb_set(definition, '{scripts,detect}', to_jsonb($tag$...bash...$tag$::text))`. В скриптах избегать литерала `$$` (PID bash) — иначе сломает dollar-quoting; тег-кавычки `$tag$` решают. install/uninstall — ТОЛЬКО в колонках (НЕ in definition.scripts) для UI-совместимости (см. §4). Содержимое: install (встроенный Dockerfile + configure/start/template как heredoc'и + `docker build` + run), uninstall, detect, add_client, restore. Плюс `protocol_variables` (server_host, server_port, cloak_public_key, cloak_bypass_uid), `protocol_templates`, `translations` (en/ru). Guard `WHERE NOT EXISTS`. Применить через `update.sh`.
2. **QrUtil.php** — добавить `encodeOpenVpnCloakPayload(array)`.
3. **VpnClient.php** — вставить post-638 override-блок.
4. **Документация** — `docs/api.md` (протокол + переменные + формат config), `docs/architecture.md` (handler `openvpn-cloak`).

## Проверка совместимости (zero regressions)
- [ ] `resolveHandler(['slug'=>'openvpn-cloak','definition'=>['engine'=>'shell']])` → `'script'` (не затрагивает awg/xray/warp slug-map @1263).
- [ ] `if ($slug==='openvpn')` @442 нетронут (legacy kylemanna).
- [ ] `generateQRCode()` @1432 нетронут — QR для всех прочих слагов идёт прежним путём.
- [ ] Новый метод `QrUtil::encodeOpenVpnCloakPayload()` аддитивен.
- [ ] Post-638 блок срабатывает ТОЛЬКО для `openvpn-cloak`.
- [ ] Миграция идемпотентна, schema-изменений нет.

## Валидация
1. `docker compose exec -T db psql -U amnezia -d amnezia_panel -c "SELECT slug FROM protocols WHERE slug='openvpn-cloak'"` → строка есть.
2. UI: сервер → протокол "OpenVPN over Cloak" → deploy. На VPS: `docker ps` → контейнер running, `:443/tcp` опубликован; `docker exec ... ls /opt/amnezia/openvpn/server.conf /opt/amnezia/cloak/ck-config.json`.
3. Создать клиента → БД `vpn_clients.config` = raw `.ovpn`, `qr_code` = PNG data-URI.
4. Сканировать QR официальным клиентом Amnezia → профиль с `amnezia-openvpn` + `amnezia-cloak`, подключение устанавливается.
5. Telegram-бот: `/start` → клиент → QR/`.conf` отображаются.
6. Uninstall: контейнер удалён, `/opt/amnezia/openvpn-cloak` очищен.

## Риски / mitigation
| Риск | Mitigation |
|------|------------|
| Build с VPS качает ck-server/ss с GitHub; при блокировке — падает | Тот же риск что у aivpn (git clone). Документировать; при необходимости — зеркало binaries в Dockerfile. |
| Баг арх-детекции в upstream Dockerfile (`[ $SERVER_ARCH="x86_64" ]` → всегда amd64) | В копии Dockerfile заменить на `[ "$SERVER_ARCH" = "x86_64" ]`. Для x86_64 нейтрально; для ARM — критично. |
| `ovpn_config_b64` ~5-8KB в одной строке | `base64 -w 0`; `executeCommand` (shell_exec) держит; regex `(.*)$` берёт строку целиком. |
| Cloak `BypassUID` общий на сервер (по дизайну Cloak) | Документировать: изоляция клиентов — через индивидуальные OpenVPN-сертификаты, не через cloak-UID (стандартное поведение Amnezia). |
| `getNextClientIP()` @874 пытается читать `wg0.conf` из openvpn-контейнера | try/catch @905 ловит; fallback на DB-only по subnet из metadata `openvpn_subnet`. Нейтрально. |
| `amnezia-dns-net` сеть отсутствует | `docker network create amnezia-dns-net 2>/dev/null \|\| true` в install. |
| UI-тестер скрипта (`apiTestInstallProtocolStream`, ubuntu:22.04) провалится на privileged-операциях | Известное ограничение тестера для сетевых протоколов; E2E — на реальном VPS. |
| Высокая плотность QR-кода делает его нечитаемым на некоторых камерах | Использовать RSA 2048 (или EC, если поддерживается) вместо RSA 4096 при генерации Easy-RSA ключей для клиентов и удалить все комментарии из `template.ovpn`. |

## Зафиксированные решения
1. **Образ**: собирать на сервере (`docker build` из встроенного Dockerfile). Согласовано.
2. **Порт**: фиксировать 443 (`port_range:[443,443]`).
3. **Shadowsocks в клиентском envelope**: НЕ включать (только `amnezia-cloak` + `amnezia-openvpn`). Сервер генерирует `ss-config.json` для внутренней маршрутизации ck-server; в QR не попадает.
4. **`config` в БД**: raw `.ovpn` (для `.conf`-выдачи/дебага); полный connection-конфиг несёт QR.

## Out of scope
- Per-client трафик-мониторинг для OpenVPN (нет API как у Xray) — только online/offline.
- Ротация cloak-ключей / revocation по cloak-UID.
- Третий контейнер `amnezia-shadowsocks` в QR (отдельная миграция, если потребуется).
- Backup/restore сервера с openvpn-cloak (через существующий BackupLibrary, формат не специфицируется).
