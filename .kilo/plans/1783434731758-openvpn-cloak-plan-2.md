# План: OpenVPN over Cloak Protocol

## Цель

Добавить протокол OpenVPN over Cloak (slug: `openvpn-cloak`) в админ-панель. QR-коды должны импортироваться в официальный клиент Amnezia VPN. Zero regressions.

---

## Ключевое понимание

### Где выполняются скрипты

Все скрипты выполняются на ХОСТЕ VPS через SSH:
```
runScript() → $server->executeCommand() → SSH на хост
```

Поэтому:
- `easyrsa`, `ck-server`, `ssserver` — недоступны на хосте
- Все операции с PKI → через `docker exec`
- Dockerfile собирает образ с инструментами внутри

### Persistent данные

Контейнер запускается с томом:
```
-v /opt/amnezia/openvpn-cloak/data:/data
```

Данные переживают пересоздание контейнера.

---

## Файлы для изменения

| Файл | Действие |
|------|----------|
| `migrations/074_add_openvpn_cloak_protocol.sql` | Создать заново |
| `migrations/075-078` | Удалить |
| `inc/VpnClient.php` | Не трогать |
| `inc/QrUtil.php` | Не трогать |

---

## Скрипты

### 1. Dockerfile (встроен в install_script)

```dockerfile
FROM alpine:3.18

ARG CLOAK_VERSION=v2.10.0
ARG SS_VERSION=v1.21.2

RUN apk add --no-cache openvpn easy-rsa bash curl iptables

# ck-server
RUN ARCH=$(case "$(uname -m)" in x86_64) echo "amd64";; aarch64) echo "arm64";; esac) && \
    curl -fsSL "https://github.com/cbeuw/Cloak/releases/download/${CLOAK_VERSION}/ck-server-linux-${ARCH}-${CLOAK_VERSION}" \
    -o /usr/local/bin/ck-server && chmod +x /usr/local/bin/ck-server

# shadowsocks-rust
RUN ARCH=$(case "$(uname -m)" in x86_64) echo "x86_64";; aarch64) echo "aarch64";; esac) && \
    curl -fsSL "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VERSION}/shadowsocks-${SS_VERSION}.${ARCH}-unknown-linux-musl.tar.xz" \
    | tar -xJf - -C /usr/local/bin ssserver && chmod +x /usr/local/bin/ssserver

ENV EASYRSA_PKI=/data/openvpn/pki
ENV EASYRSA_BATCH=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

### 2. entrypoint.sh (выполняется внутри контейнера)

```bash
#!/bin/bash
set -euo pipefail

# TUN device
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

# PKI - генерация при первом запуске
if [ ! -f /data/openvpn/pki/ca.crt ]; then
    cd /data/openvpn
    easyrsa init-pki
    easyrsa --batch --req-cn=AmneziaVPN build-ca nopass
    easyrsa gen-dh
    easyrsa --batch build-server-full server nopass
    openvpn --genkey secret /data/openvpn/pki/ta.key
fi

# Cloak ключи - генерация при первом запуске
if [ ! -f /data/cloak/public.key ]; then
    # ck-server -k выводит две строки: публичный и приватный ключ
    KEYS=$(ck-server -k 2>/dev/null || echo "")
    if [ -n "$KEYS" ]; then
        echo "$KEYS" | head -1 > /data/cloak/public.key
        echo "$KEYS" | tail -1 > /data/cloak/private.key
    else
        # Fallback через openssl
        openssl rand -hex 32 > /data/cloak/public.key
        openssl rand -hex 32 > /data/cloak/private.key
    fi
    ck-server -u > /data/cloak/bypass_uid 2>/dev/null || \
        openssl rand -hex 8 > /data/cloak/bypass_uid
fi

# Копируем сертификаты в рабочую директорию
cp /data/openvpn/pki/ca.crt /data/openvpn/
cp /data/openvpn/pki/issued/server.crt /data/openvpn/
cp /data/openvpn/pki/private/server.key /data/openvpn/
cp /data/openvpn/pki/dh.pem /data/openvpn/
cp /data/openvpn/pki/ta.key /data/openvpn/

# server.conf
cat > /data/openvpn/server.conf <<EOF
port 1194
proto tcp
dev tun
ca /data/openvpn/ca.crt
cert /data/openvpn/server.crt
key /data/openvpn/server.key
dh /data/openvpn/dh.pem
server 10.8.2.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA512
tls-crypt /data/openvpn/ta.key
user nobody
group nogroup
persist-key
persist-tun
status /data/openvpn/status.log
verb 3
EOF

# ck-server.json
PUBLIC_KEY=$(cat /data/cloak/public.key)
BYPASS_UID=$(cat /data/cloak/bypass_uid)
FAKE_SITE="${FAKE_SITE:-www.google.com}"
PRIVATE_KEY=$(cat /data/cloak/private.key 2>/dev/null || echo "")

cat > /data/cloak/ck-server.json <<EOF
{
    "ProxyBook": {
        "openvpn": ["tcp", "127.0.0.1:1194"],
        "shadowsocks": ["tcp", "127.0.0.1:8388"]
    },
    "BindAddr": [":443"],
    "RedirAddr": "$FAKE_SITE",
    "PrivateKey": "$PRIVATE_KEY",
    "PublicKey": "$PUBLIC_KEY",
    "BypassUID": ["$BYPASS_UID"],
    "DatabasePath": "/data/cloak/userinfo.db"
}
EOF

# shadowsocks config
SS_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
cat > /data/shadowsocks/config.json <<EOF
{
    "server": "127.0.0.1",
    "server_port": 8388,
    "password": "$SS_PASSWORD",
    "method": "chacha20-ietf-poly1305",
    "timeout": 300
}
EOF

# NAT rules
iptables -t nat -A POSTROUTING -s 10.8.2.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -A INPUT -i tun0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT 2>/dev/null || true

# Запуск сервисов
openvpn --config /data/openvpn/server.conf --daemon
ck-server -c /data/cloak/ck-server.json &
ssserver -c /data/shadowsocks/config.json &

tail -f /dev/null
```

### 3. install_script (выполняется на хосте)

```bash
#!/bin/bash
set -euo pipefail

CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
PORT="${SERVER_PORT:-443}"
BUILD_DIR="/opt/amnezia/openvpn-cloak"
DATA_DIR="/opt/amnezia/openvpn-cloak/data"

mkdir -p "$BUILD_DIR" "$DATA_DIR"/{openvpn,cloak,shadowsocks}

# Dockerfile
cat > "$BUILD_DIR/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.18
ARG CLOAK_VERSION=v2.10.0
ARG SS_VERSION=v1.21.2
RUN apk add --no-cache openvpn easy-rsa bash curl iptables
RUN ARCH=$(case "$(uname -m)" in x86_64) echo "amd64";; aarch64) echo "arm64";; esac) && \
    curl -fsSL "https://github.com/cbeuw/Cloak/releases/download/${CLOAK_VERSION}/ck-server-linux-${ARCH}-${CLOAK_VERSION}" \
    -o /usr/local/bin/ck-server && chmod +x /usr/local/bin/ck-server
RUN ARCH=$(case "$(uname -m)" in x86_64) echo "x86_64";; aarch64) echo "aarch64";; esac) && \
    curl -fsSL "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VERSION}/shadowsocks-${SS_VERSION}.${ARCH}-unknown-linux-musl.tar.xz" \
    | tar -xJf - -C /usr/local/bin ssserver && chmod +x /usr/local/bin/ssserver
ENV EASYRSA_PKI=/data/openvpn/pki
ENV EASYRSA_BATCH=1
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE

# entrypoint.sh
cat > "$BUILD_DIR/entrypoint.sh" <<'ENTRYPOINT'
#!/bin/bash
set -euo pipefail
mkdir -p /dev/net; [ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
if [ ! -f /data/openvpn/pki/ca.crt ]; then
    cd /data/openvpn
    easyrsa init-pki
    easyrsa --batch --req-cn=AmneziaVPN build-ca nopass
    easyrsa gen-dh
    easyrsa --batch build-server-full server nopass
    openvpn --genkey secret /data/openvpn/pki/ta.key
fi
if [ ! -f /data/cloak/public.key ]; then
    KEYS=$(ck-server -k 2>/dev/null || echo "")
    if [ -n "$KEYS" ]; then
        echo "$KEYS" | head -1 > /data/cloak/public.key
        echo "$KEYS" | tail -1 > /data/cloak/private.key
    else
        openssl rand -hex 32 > /data/cloak/public.key
        openssl rand -hex 32 > /data/cloak/private.key
    fi
    ck-server -u > /data/cloak/bypass_uid 2>/dev/null || openssl rand -hex 8 > /data/cloak/bypass_uid
fi
cp /data/openvpn/pki/ca.crt /data/openvpn/
cp /data/openvpn/pki/issued/server.crt /data/openvpn/
cp /data/openvpn/pki/private/server.key /data/openvpn/
cp /data/openvpn/pki/dh.pem /data/openvpn/
cp /data/openvpn/pki/ta.key /data/openvpn/
cat > /data/openvpn/server.conf <<OPENVPN_CONF
port 1194
proto tcp
dev tun
ca /data/openvpn/ca.crt
cert /data/openvpn/server.crt
key /data/openvpn/server.key
dh /data/openvpn/dh.pem
server 10.8.2.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA512
tls-crypt /data/openvpn/ta.key
user nobody
group nogroup
persist-key
persist-tun
status /data/openvpn/status.log
verb 3
OPENVPN_CONF
PUBLIC_KEY=$(cat /data/cloak/public.key)
BYPASS_UID=$(cat /data/cloak/bypass_uid)
FAKE_SITE="${FAKE_SITE:-www.google.com}"
PRIVATE_KEY=$(cat /data/cloak/private.key 2>/dev/null || echo "")
cat > /data/cloak/ck-server.json <<CKSERVER
{"ProxyBook":{"openvpn":["tcp","127.0.0.1:1194"],"shadowsocks":["tcp","127.0.0.1:8388"]},"BindAddr":[":443"],"RedirAddr":"$FAKE_SITE","PrivateKey":"$PRIVATE_KEY","PublicKey":"$PUBLIC_KEY","BypassUID":["$BYPASS_UID"],"DatabasePath":"/data/cloak/userinfo.db"}
CKSERVER
SS_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
cat > /data/shadowsocks/config.json <<SSCONFIG
{"server":"127.0.0.1","server_port":8388,"password":"$SS_PASSWORD","method":"chacha20-ietf-poly1305","timeout":300}
SSCONFIG
iptables -t nat -A POSTROUTING -s 10.8.2.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -A INPUT -i tun0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT 2>/dev/null || true
openvpn --config /data/openvpn/server.conf --daemon
ck-server -c /data/cloak/ck-server.json &
ssserver -c /data/shadowsocks/config.json &
tail -f /dev/null
ENTRYPOINT
chmod +x "$BUILD_DIR/entrypoint.sh"

# Build
docker build -t "$CONTAINER" "$BUILD_DIR"

# Remove old container
docker rm -f "$CONTAINER" 2>/dev/null || true

# Run with volume
docker run -d \
    --name "$CONTAINER" \
    --privileged \
    --cap-add=NET_ADMIN \
    --restart unless-stopped \
    -v "$DATA_DIR:/data" \
    -e FAKE_SITE="${FAKE_SITE:-www.google.com}" \
    -p "${PORT}:443/tcp" \
    "$CONTAINER"

# Wait for initialization
sleep 5

# Check status
if [ "$(docker inspect --format='{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "ERROR: Container failed to start"
    docker logs "$CONTAINER" 2>&1 | tail -50
    exit 1
fi

# Read keys for panel
PUB=$(docker exec "$CONTAINER" cat /data/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER" cat /data/cloak/bypass_uid 2>/dev/null || echo "")
EXTERNAL_IP="${SERVER_HOST:-$(curl -s -4 ifconfig.me 2>/dev/null || echo "")}"

echo "Variable: container_name=$CONTAINER"
echo "Variable: vpn_port=$PORT"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Variable: fake_site=${FAKE_SITE:-www.google.com}"
echo "Port: $PORT"
```

### 4. uninstall_script

```bash
#!/bin/bash
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
docker stop "$CONTAINER" 2>/dev/null || true
docker rm -fv "$CONTAINER" 2>/dev/null || true
rm -rf /opt/amnezia/openvpn-cloak
echo '{"success":true}'
```

### 5. detect (definition.scripts.detect)

```bash
#!/bin/bash
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    if docker exec "$CONTAINER" test -f /data/openvpn/server.conf 2>/dev/null; then
        echo '{"status":"existing"}'
        exit 0
    fi
fi
echo '{"status":"absent"}'
```

### 6. restore (definition.scripts.restore)

```bash
#!/bin/bash
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
PUB=$(docker exec "$CONTAINER" cat /data/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER" cat /data/cloak/bypass_uid 2>/dev/null || echo "")
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo '{"success":true,"mode":"restore"}'
```

### 7. add_client (definition.scripts.add_client)

```bash
#!/bin/bash
LOGIN="{{options.login}}"
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"

# Validation
[ -z "$LOGIN" ] && { echo "Error: login required" >&2; exit 1; }
[[ "$LOGIN" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Error: invalid login" >&2; exit 1; }

# Generate certificate inside container
docker exec "$CONTAINER" easyrsa --batch --pki-dir=/data/openvpn/pki build-client-full "$LOGIN" nopass 2>&1

# Read certificates
CA=$(docker exec "$CONTAINER" cat /data/openvpn/pki/ca.crt 2>/dev/null || echo "")
CERT=$(docker exec "$CONTAINER" cat "/data/openvpn/pki/issued/${LOGIN}.crt" 2>/dev/null || echo "")
KEY=$(docker exec "$CONTAINER" cat "/data/openvpn/pki/private/${LOGIN}.key" 2>/dev/null || echo "")
TA=$(docker exec "$CONTAINER" cat /data/openvpn/pki/ta.key 2>/dev/null || echo "")

# Build .ovpn config
OVPN="client
dev tun
proto tcp
remote ${SERVER_HOST} 443
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA512
tls-client
verb 3
key-direction 1
<ca>
${CA}
</ca>
<cert>
${CERT}
</cert>
<key>
${KEY}
</key>
<tls-auth>
${TA}
</tls-auth>"

# Read cloak keys
PUB=$(docker exec "$CONTAINER" cat /data/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER" cat /data/cloak/bypass_uid 2>/dev/null || echo "")

# Output
echo "Variable: ovpn_config_b64=$(printf '%s' "$OVPN" | base64 -w0)"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: server_host=${SERVER_HOST}"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo "Port: ${SERVER_PORT:-443}"
```

---

## Структура SQL-миграции

```sql
DO $func$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'openvpn-cloak') THEN
        
        INSERT INTO protocols (
            name, slug, description, is_active,
            install_script, uninstall_script, definition
        ) VALUES (
            'OpenVPN over Cloak',
            'openvpn-cloak',
            'OpenVPN обёрнутый в Cloak для обхода DPI',
            true,
            $install$<скрипт 3>$install$,
            $uninstall$<скрипт 4>$uninstall$,
            '{"engine":"shell","metadata":{"container_name":"amnezia-openvpn-cloak","config_dir":"/opt/amnezia/openvpn-cloak","port_range":[443,443]},"scripts":{}}'::json
        );
        
        -- Добавить скрипты в definition через UPDATE
        -- detect
        -- restore
        -- add_client
        
        -- Добавить переменные протокола
        INSERT INTO protocol_variables ...
    END IF;
END $func$;
```

---

## Переменные протокола

| Имя | Тип | Обязательная | По умолчанию |
|-----|-----|---------------|--------------|
| server_host | string | да | |
| server_port | number | да | 443 |
| cloak_public_key | string | да | |
| cloak_bypass_uid | string | да | |
| fake_site | string | нет | www.google.com |

---

## Порядок выполнения

1. `git checkout c8077e8253b9a165e88e864a40c758be4e19fdda`
2. `rm migrations/074`-`078`
3. Создать `migrations/074_add_openvpn_cloak_protocol.sql`
4. `./update.sh`
5. Проверить БД
6. Установить на тестовый сервер
7. Создать клиента
8. Проверить QR

---

## Конфигурации (подробно)

### OpenVPN server.conf

Должен соответствовать формату Amnezia клиента:

```
port 1194                    # Внутренний порт (ck-server проксирует)
proto tcp                    # Только TCP (Cloak работает поверх TCP)
dev tun
ca /data/openvpn/ca.crt
cert /data/openvpn/server.crt
key /data/openvpn/server.key
dh /data/openvpn/dh.pem
server 10.8.2.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM           # Amnezia использует AES-256-GCM
auth SHA512
tls-crypt /data/openvpn/ta.key
user nobody
group nogroup
persist-key
persist-tun
status /data/openvpn/status.log
verb 3
```

### Cloak ck-server.json

Формат для Amnezia:

```json
{
    "ProxyBook": {
        "openvpn": ["tcp", "127.0.0.1:1194"],
        "shadowsocks": ["tcp", "127.0.0.1:8388"]
    },
    "BindAddr": [":443"],
    "RedirAddr": "www.google.com",
    "PrivateKey": "<32-byte-hex>",
    "PublicKey": "<32-byte-hex>",
    "BypassUID": ["<16-byte-hex>"],
    "DatabasePath": "/data/cloak/userinfo.db"
}
```

**Важно:**
- `ProxyBook.openvpn` — основной прокси для QR
- `ProxyBook.shadowsocks` — для внутренней маршрутизации
- `RedirAddr` — фейковый сайт для маскировки
- `BypassUID` — один на весь сервер (по дизайну Cloak/Amnezia)

### Shadowsocks config.json

Для внутренней маршрутизации между ck-server и ss:

```json
{
    "server": "127.0.0.1",
    "server_port": 8388,
    "password": "<24-char-random>",
    "method": "chacha20-ietf-poly1305",
    "timeout": 300
}
```

### Клиентский .ovpn

Формат для встраивания в QR (base64):

```
client
dev tun
proto tcp
remote <SERVER_HOST> 443
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA512
tls-client
verb 3
key-direction 1
<ca>
-----BEGIN CERTIFICATE-----
<CA_CERT_CONTENT>
-----END CERTIFICATE-----
</ca>
<cert>
-----BEGIN CERTIFICATE-----
<CLIENT_CERT_CONTENT>
-----END CERTIFICATE-----
</cert>
<key>
-----BEGIN PRIVATE KEY-----
<CLIENT_KEY_CONTENT>
-----END PRIVATE KEY-----
</key>
<tls-auth>
-----BEGIN OpenVPN Static key V1-----
<TA_KEY_CONTENT>
-----END OpenVPN Static key V1-----
</tls-auth>
```

**Нюансы:**
- `remote` указывает на внешний IP:порт Cloak
- В Amnezia клиенте `remote 127.0.0.1 1194` — ck-client локально мостит
- Мы генерируем для "raw" использования — Amnezia сама подставит localhost

---

## Валидация

- [ ] Контейнер собирается без ошибок
- [ ] PKI генерируется при первом запуске
- [ ] Ключи Cloak генерируются
- [ ] `detect` возвращает `existing` для работающего контейнера
- [ ] `add_client` возвращает `ovpn_config_b64`
- [ ] QR сканируется Amnezia клиентом
- [ ] Подключение работает
