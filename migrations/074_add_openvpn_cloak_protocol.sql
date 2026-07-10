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
OPENVPN_PORT=1194
SS_PORT=8388
BUILD_DIR="/opt/amnezia/openvpn-cloak"
SERVER_ARCH="$(uname -m)"
EXTERNAL_IP="$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "${SERVER_HOST:-}")"
FAKE_SITE="${FAKE_SITE:-domain.ru}"

mkdir -p "$BUILD_DIR"

cat <<'EOF_DOCKER' > "$BUILD_DIR/Dockerfile"
FROM alpine:3.15
LABEL maintainer="AmneziaVPN"

ARG SS_RELEASE="v1.13.1"
ARG CLOAK_RELEASE="v2.5.5"
ARG SERVER_ARCH

RUN apk add --no-cache curl openvpn easy-rsa bash netcat-openbsd dumb-init rng-tools
RUN apk --update upgrade --no-cache

ENV EASYRSA_BATCH 1
ENV PATH="/usr/share/easy-rsa:${PATH}"

RUN mkdir -p /opt/amnezia
RUN echo -e "#!/bin/bash\ntail -f /dev/null" > /opt/amnezia/start.sh
RUN chmod a+x /opt/amnezia/start.sh

RUN if [ "$SERVER_ARCH" = "x86_64" ]; then CK_ARCH="amd64"; \
    elif [ "$SERVER_ARCH" = "i686" ]; then CK_ARCH="386"; \
    elif [ "$SERVER_ARCH" = "aarch64" ]; then CK_ARCH="arm64"; \
    elif [ "$SERVER_ARCH" = "arm" ]; then CK_ARCH="arm"; \
    else exit -1; fi && \
    curl -L https://github.com/cbeuw/Cloak/releases/download/${CLOAK_RELEASE}/ck-server-linux-${CK_ARCH}-${CLOAK_RELEASE} > /usr/bin/ck-server
RUN chmod a+x /usr/bin/ck-server

RUN curl -L https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_RELEASE}/shadowsocks-${SS_RELEASE}.${SERVER_ARCH}-unknown-linux-musl.tar.xz  > /usr/bin/ss.tar.xz
RUN tar -Jxvf /usr/bin/ss.tar.xz -C /usr/bin/
RUN chmod a+x /usr/bin/ssserver

RUN echo -e " \n\
  fs.file-max = 51200 \n\
  \n\
  net.core.rmem_max = 67108864 \n\
  net.core.wmem_max = 67108864 \n\
  net.core.netdev_max_backlog = 250000 \n\
  net.core.somaxconn = 4096 \n\
  \n\
  net.ipv4.tcp_syncookies = 1 \n\
  net.ipv4.tcp_tw_reuse = 1 \n\
  net.ipv4.tcp_tw_recycle = 0 \n\
  net.ipv4.tcp_fin_timeout = 30 \n\
  net.ipv4.tcp_keepalive_time = 1200 \n\
  net.ipv4.ip_local_port_range = 10000 65000 \n\
  net.ipv4.tcp_max_syn_backlog = 8192 \n\
  net.ipv4.tcp_max_tw_buckets = 5000 \n\
  net.ipv4.tcp_fastopen = 3 \n\
  net.ipv4.tcp_mem = 25600 51200 102400 \n\
  net.ipv4.tcp_rmem = 4096 87380 67108864 \n\
  net.ipv4.tcp_wmem = 4096 65536 67108864 \n\
  net.ipv4.tcp_mtu_probing = 1 \n\
  net.ipv4.tcp_congestion_control = hybla \n\
  " | sed -e 's/^\s\+//g' | tee -a /etc/sysctl.conf && \
  mkdir -p /etc/security && \
  echo -e " \n\
  * soft nofile 51200 \n\
  * hard nofile 51200 \n\
  " | sed -e 's/^\s\+//g' | tee -a /etc/security/limits.conf  

ENTRYPOINT [ "dumb-init", "/opt/amnezia/start.sh" ]
CMD [ "" ]
EOF_DOCKER

cat <<'EOF_CONF' > "$BUILD_DIR/configure_container.sh"
cat > /opt/amnezia/openvpn/server.conf <<EOF
port $OPENVPN_PORT
proto tcp
dev tun
ca /opt/amnezia/openvpn/ca.crt
cert /opt/amnezia/openvpn/AmneziaReq.crt
key /opt/amnezia/openvpn/AmneziaReq.key
dh /opt/amnezia/openvpn/dh.pem
server $OPENVPN_SUBNET_IP $OPENVPN_SUBNET_MASK
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $PRIMARY_DNS"
push "dhcp-option DNS $SECONDARY_DNS"
keepalive 10 120
cipher AES-256-GCM
auth SHA512
tls-crypt /opt/amnezia/openvpn/ta.key 0
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

cat > /opt/amnezia/cloak/ck-server.json <<EOF
{
    "ProxyBook": {
        "openvpn": ["tcp", "127.0.0.1:$OPENVPN_PORT"]
    },
    "BindAddr": ["0.0.0.0:$CLOAK_PORT"],
    "RedirAddr": ["127.0.0.1:80"],
    "PublicKey": "${CLOAK_PUBLIC_KEY}",
    "PrivateKey": "${CLOAK_PRIVATE_KEY}",
    "AdminUID": "${CLOAK_BYPASS_UID}",
    "BypassUID": ["${CLOAK_BYPASS_UID}"],
    "DatabasePath": "/opt/amnezia/cloak/user.db"
}
EOF

cat > /opt/amnezia/shadowsocks/config.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": $SS_PORT,
    "password": "${SS_PASSWORD}",
    "method": "chacha20-ietf-poly1305",
    "timeout": 300
}
EOF
EOF_CONF

docker build -t "$CONTAINER_NAME" "$BUILD_DIR" --build-arg SERVER_ARCH="$SERVER_ARCH" 2>&1 | grep -v "^#" | grep -v "^\[" | tail -20 || true

docker network create amnezia-dns-net 2>/dev/null || true
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

DATA_DIR="/opt/amnezia/openvpn-cloak/data"
mkdir -p "$DATA_DIR/openvpn" "$DATA_DIR/cloak" "$DATA_DIR/shadowsocks"

# Generate Easy-RSA PKI
cd "$DATA_DIR/openvpn"
export EASYRSA_BATCH=1
export EASYRSA_PKI="$DATA_DIR/openvpn/pki"

if [ ! -f "$EASYRSA_PKI/ca.crt" ]; then
    mkdir -p "$EASYRSA_PKI"
    cd "$DATA_DIR/openvpn"
    /usr/share/easy-rsa/easyrsa init-pki
    /usr/share/easy-rsa/easyrsa build-ca nopass
    /usr/share/easy-rsa/easyrsa gen-dh
    /usr/share/easy-rsa/easyrsa build-server-full AmneziaReq nopass
    /usr/share/easy-rsa/easyrsa gen-crypt
fi

# Copy certificates to container directory
cp "$EASYRSA_PKI/ca.crt" "$DATA_DIR/openvpn/ca.crt"
cp "$EASYRSA_PKI/issued/AmneziaReq.crt" "$DATA_DIR/openvpn/AmneziaReq.crt"
cp "$EASYRSA_PKI/private/AmneziaReq.key" "$DATA_DIR/openvpn/AmneziaReq.key"
cp "$EASYRSA_PKI/dh.pem" "$DATA_DIR/openvpn/dh.pem"
cp "$EASYRSA_PKI/ta.key" "$DATA_DIR/openvpn/ta.key"

# Generate Cloak keys
CLOAK_PUBLIC_KEY=$(echo -n "public" | ck-server -k | cut -d' ' -f1)
CLOAK_PRIVATE_KEY=$(echo -n "private" | ck-server -k | cut -d' ' -f2)
CLOAK_BYPASS_UID=$(ck-server -k | grep -oP '\K[0-9a-f]{16}')

# Generate Shadowsocks password
SS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)

# Save keys
echo "$CLOAK_PUBLIC_KEY" > "$DATA_DIR/cloak/cloak_public.key"
echo "$CLOAK_PRIVATE_KEY" > "$DATA_DIR/cloak/cloak_private.key"
echo "$CLOAK_BYPASS_UID" > "$DATA_DIR/cloak/cloak_bypass_uid.key"
echo "$SS_PASSWORD" > "$DATA_DIR/shadowsocks/shadowsocks.key"

# Create startup script
cat > "$BUILD_DIR/start.sh" <<'EOF_START'
#!/bin/bash
set -euo pipefail

# Start Shadowsocks
ssserver -c /opt/amnezia/shadowsocks/config.json &

# Wait for Shadowsocks to start
sleep 2

# Start Cloak
ck-server -c /opt/amnezia/cloak/ck-server.json &

# Wait for Cloak to start
sleep 2

# Start OpenVPN
openvpn --config /opt/amnezia/openvpn/server.conf

wait
EOF_START

chmod +x "$BUILD_DIR/start.sh"

docker run -d --privileged --cap-add=NET_ADMIN --restart always \
  -v "$BUILD_DIR/start.sh:/opt/amnezia/start.sh" \
  -v "$DATA_DIR:/opt/amnezia" \
  -p "${CLOAK_PORT}:443/tcp" --name "$CONTAINER_NAME" "$CONTAINER_NAME"

sleep 5

docker exec "$CONTAINER_NAME" bash /opt/amnezia/start.sh &

sleep 3

PUB=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_bypass_uid.key 2>/dev/null || echo "")
SS_PASSWORD=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/shadowsocks/shadowsocks.key 2>/dev/null || echo "")

echo "Variable: container_name=$CONTAINER_NAME"
echo "Variable: vpn_port=$CLOAK_PORT"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: ss_password=$SS_PASSWORD"
echo "Variable: fake_site=$FAKE_SITE"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Port: $CLOAK_PORT"
$tag$,
            $tag$#!/bin/bash
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
rm -rf /opt/amnezia/openvpn-cloak
echo '{"success":true}'
$tag$,
            '{"engine":"shell","metadata":{"container_name":"amnezia-openvpn-cloak","config_dir":"/opt/amnezia/openvpn-cloak","port_range":[443,443],"openvpn_subnet":"10.8.2.0/24"},"scripts":{}}'::jsonb
        );

        -- Add restore script to definition
        UPDATE protocols SET definition = jsonb_set(
            definition,
            '{scripts,restore}',
            to_jsonb($tag$#!/bin/bash
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-openvpn-cloak}"
PUB=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_public.key 2>/dev/null || echo "")
BYPASS=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_bypass_uid.key 2>/dev/null || echo "")
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: vpn_port=${SERVER_PORT:-443}"
echo "Variable: container_name=$CONTAINER_NAME"
echo '{"success":true,"mode":"restore"}'
$tag$::text)
        )
        WHERE slug = 'openvpn-cloak';

        -- Insert protocol variables
        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'server_host', 'Server Host (IP or Domain)', 'string', '', true
        FROM protocols WHERE slug = 'openvpn-cloak';

        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'server_port', 'Cloak Port', 'number', '443', true
        FROM protocols WHERE slug = 'openvpn-cloak';

        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'cloak_public_key', 'Cloak Public Key', 'string', '', true
        FROM protocols WHERE slug = 'openvpn-cloak';

        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'cloak_bypass_uid', 'Cloak Bypass UID', 'string', '', true
        FROM protocols WHERE slug = 'openvpn-cloak';

        INSERT INTO protocol_variables (protocol_id, variable_name, description, variable_type, default_value, required)
        SELECT id, 'fake_site', 'Fake Site', 'string', 'domain.ru', true
        FROM protocols WHERE slug = 'openvpn-cloak';

        RAISE NOTICE 'OpenVPN over Cloak protocol added successfully';
    END IF;
END $func$;