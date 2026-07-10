DO $func$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'openvpn-cloak') THEN

        INSERT INTO protocols (
            name, slug, description, is_active,
            install_script, uninstall_script, definition
        ) VALUES (
            'OpenVPN over Cloak',
            'openvpn-cloak',
            'OpenVPN wrapped in Cloak for obfuscation',
            true,
            $tag$#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
CLOAK_PORT="${SERVER_PORT:-443}"
BUILD_DIR="/opt/amnezia/openvpn-cloak"
SERVER_ARCH="$(uname -m)"
EXTERNAL_IP="${SERVER_HOST:-$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo '')}"
FAKE_SITE="${FAKE_SITE:-www.google.com}"

mkdir -p "$BUILD_DIR"

cat <<'EOF_DOCKER' > "$BUILD_DIR/Dockerfile"
FROM alpine:3.18
LABEL maintainer="AmneziaVPN"

ARG CLOAK_VERSION=v2.10.0

RUN apk add --no-cache openvpn easy-rsa bash curl iptables

ENV EASYRSA_BATCH=1
ENV EASYRSA_PKI=/etc/openvpn/pki

RUN mkdir -p /etc/openvpn /etc/cloak /var/log/openvpn && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin/easyrsa && \
    ARCH=$(case "$(uname -m)" in x86_64) echo "amd64";; aarch64) echo "arm64";; armv7l) echo "arm";; i686) echo "386";; esac) && \
    curl -fsSL "https://github.com/cbeuw/Cloak/releases/download/${CLOAK_VERSION}/ck-server-linux-${ARCH}-${CLOAK_VERSION}" -o /usr/local/bin/ck-server && \
    chmod +x /usr/local/bin/ck-server

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 443/tcp
ENTRYPOINT ["/entrypoint.sh"]
EOF_DOCKER

cat <<'EOF_ENTRY' > "$BUILD_DIR/entrypoint.sh"
#!/bin/bash
set -euo pipefail

mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

if [ ! -f /etc/openvpn/pki/ca.crt ]; then
    cd /etc/openvpn
    easyrsa init-pki
    easyrsa --req-cn=AmneziaVPN build-ca nopass
    easyrsa gen-dh
    easyrsa build-server-full server nopass
    openvpn --genkey secret /etc/openvpn/pki/ta.key
fi

if [ ! -f /etc/cloak/ck-server.json ]; then
    KEYPAIR=$(ck-server -k)
    PUB=$(echo "$KEYPAIR" | head -1)
    PRIV=$(echo "$KEYPAIR" | tail -1)
    BYPASS=$(ck-server -u)
    
    cat > /etc/cloak/ck-server.json <<EOFCK
{
    "ProxyBook": {"openvpn": ["tcp", "127.0.0.1:1194"]},
    "BindAddr": [":443"],
    "RedirAddr": "$FAKE_SITE",
    "PrivateKey": "$PRIV",
    "PublicKey": "$PUB",
    "BypassUID": ["$BYPASS"],
    "DatabasePath": "/etc/cloak/userinfo.db"
}
EOFCK
    
    echo "$PUB" > /etc/cloak/public.key
    echo "$BYPASS" > /etc/cloak/bypass_uid
fi

cat > /etc/openvpn/server.conf <<EOFVPN
port 1194
proto tcp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.8.2.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA512
tls-crypt /etc/openvpn/pki/ta.key
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/status.log
verb 3
EOFVPN

iptables -t nat -A POSTROUTING -s 10.8.2.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -A INPUT -i tun0 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT 2>/dev/null || true

openvpn --config /etc/openvpn/server.conf --daemon 2>/dev/null || openvpn --config /etc/openvpn/server.conf &
ck-server -c /etc/cloak/ck-server.json &

tail -f /dev/null
EOF_ENTRY

chmod +x "$BUILD_DIR/entrypoint.sh"

docker build -t "$CONTAINER_NAME:latest" "$BUILD_DIR" 2>&1 | tail -5

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

docker run -d \
    --name "$CONTAINER_NAME" \
    --privileged \
    --cap-add=NET_ADMIN \
    --restart unless-stopped \
    -p "${CLOAK_PORT}:443/tcp" \
    "$CONTAINER_NAME:latest"

sleep 5

PUB=$(docker exec "$CONTAINER_NAME" cat /etc/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER_NAME" cat /etc/cloak/bypass_uid 2>/dev/null || echo "")

echo "Variable: container_name=$CONTAINER_NAME"
echo "Variable: vpn_port=$CLOAK_PORT"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Variable: fake_site=$FAKE_SITE"
echo "Port: $CLOAK_PORT"
$tag$,
            $tag$#!/bin/bash
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
rm -rf /opt/amnezia/openvpn-cloak
echo '{"success":true}'$tag$,
            '{"engine":"shell","metadata":{"container_name":"amnezia-openvpn-cloak","config_dir":"/opt/amnezia/openvpn-cloak","port_range":[443,443]},"scripts":{}}'::jsonb
        );
        
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'server_host', 'Server IP or Domain', 'string', '', true FROM protocols WHERE slug = 'openvpn-cloak';
        
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'server_port', 'Cloak Port', 'number', '443', true FROM protocols WHERE slug = 'openvpn-cloak';
        
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'cloak_public_key', 'Cloak Public Key', 'string', '', true FROM protocols WHERE slug = 'openvpn-cloak';
        
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'cloak_bypass_uid', 'Cloak Bypass UID', 'string', '', true FROM protocols WHERE slug = 'openvpn-cloak';
        
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'fake_site', 'Fake Website Domain', 'string', 'www.google.com', false FROM protocols WHERE slug = 'openvpn-cloak';
        
        RAISE NOTICE 'OpenVPN over Cloak protocol added successfully';
    END IF;
END $func$;

-- Add scripts using separate UPDATE with proper escaping
UPDATE protocols SET definition = jsonb_set(definition, '{scripts,detect}', to_jsonb($$#!/bin/bash
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER}$"; then
    if docker exec "$CONTAINER" test -f /etc/openvpn/server.conf 2>/dev/null; then
        echo '{"status":"existing"}'
        exit 0
    fi
fi
echo '{"status":"absent"}'$$)) WHERE slug = 'openvpn-cloak';

UPDATE protocols SET definition = jsonb_set(definition, '{scripts,restore}', to_jsonb($$#!/bin/bash
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
PUB=$(docker exec "$CONTAINER" cat /etc/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER" cat /etc/cloak/bypass_uid 2>/dev/null || echo "")
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo '{"success":true,"mode":"restore"}'$$)) WHERE slug = 'openvpn-cloak';

UPDATE protocols SET definition = jsonb_set(definition, '{scripts,add_client}', to_jsonb($$#!/bin/bash
LOGIN="{{options.login}}"
CONTAINER="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
[ -z "$LOGIN" ] && { echo "Error: login required" >&2; exit 1; }
[[ "$LOGIN" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "Error: invalid login" >&2; exit 1; }

docker exec "$CONTAINER" bash -c "cd /etc/openvpn && easyrsa build-client-full '$LOGIN' nopass" 2>&1

CA=$(docker exec "$CONTAINER" cat /etc/openvpn/pki/ca.crt 2>/dev/null || echo "")
CERT=$(docker exec "$CONTAINER" cat "/etc/openvpn/pki/issued/${LOGIN}.crt" 2>/dev/null || echo "")
KEY=$(docker exec "$CONTAINER" cat "/etc/openvpn/pki/private/${LOGIN}.key" 2>/dev/null || echo "")
TA=$(docker exec "$CONTAINER" cat /etc/openvpn/pki/ta.key 2>/dev/null || echo "")

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

PUB=$(docker exec "$CONTAINER" cat /etc/cloak/public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER" cat /etc/cloak/bypass_uid 2>/dev/null || echo "")
OVPN_B64=$(echo "$OVPN" | base64 -w0)

echo "Variable: ovpn_config_b64=$OVPN_B64"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: server_host=${SERVER_HOST}"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo "Variable: fake_site=${FAKE_SITE:-www.google.com}"
echo "Port: ${SERVER_PORT:-443}"$$)) WHERE slug = 'openvpn-cloak';
