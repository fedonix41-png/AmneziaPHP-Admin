DO $func$
BEGIN
    IF EXISTS (SELECT 1 FROM protocols WHERE slug = 'openvpn-cloak') THEN
        UPDATE protocols
        SET install_script = $tag$#!/bin/bash
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
#!/bin/bash

# Ensure required parameters are set
OPENVPN_PORT=${OPENVPN_PORT:-1194}
OPENVPN_SUBNET_IP=${OPENVPN_SUBNET_IP:-10.8.2.0}
OPENVPN_SUBNET_MASK=${OPENVPN_SUBNET_MASK:-255.255.255.0}
OPENVPN_SUBNET_CIDR=${OPENVPN_SUBNET_CIDR:-24}
OPENVPN_CIPHER=${OPENVPN_CIPHER:-AES-256-GCM}
OPENVPN_HASH=${OPENVPN_HASH:-SHA512}
SERVER_IP_ADDRESS=${SERVER_IP_ADDRESS:-10.8.2.1}

# Create openvpn server config
cat <<EOF > /opt/amnezia/openvpn/server.conf
port $OPENVPN_PORT
proto tcp
dev tun
ca /opt/amnezia/openvpn/ca.crt
cert /opt/amnezia/openvpn/pki/issued/AmneziaReq.crt
key /opt/amnezia/openvpn/pki/private/AmneziaReq.key
dh /opt/amnezia/openvpn/pki/dh.pem
server $OPENVPN_SUBNET_IP $OPENVPN_SUBNET_MASK
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
keepalive 10 120
tls-server
tls-version-min 1.2
tls-auth /opt/amnezia/openvpn/ta.key 0
$OPENVPN_NCP_DISABLE
cipher $OPENVPN_CIPHER
auth $OPENVPN_HASH
persist-key
persist-tun
status openvpn-status.log
verb 3
$OPENVPN_ADDITIONAL_SERVER_CONFIG
EOF

# Setup Shadowsocks
if [ ! -f /opt/amnezia/shadowsocks/shadowsocks.key ]; then
    head -c 24 /dev/urandom | base64 | tr -d '+' | tr -d '/' | tr -d '=' | head -c 24 > /opt/amnezia/shadowsocks/shadowsocks.key
fi
SS_PASSWORD=$(cat /opt/amnezia/shadowsocks/shadowsocks.key)

cat <<EOF > /opt/amnezia/shadowsocks/ss-config.json
{
    "server": "127.0.0.1",
    "server_port": $SHADOWSOCKS_SERVER_PORT,
    "password": "$SS_PASSWORD",
    "timeout": 300,
    "method": "$SHADOWSOCKS_CIPHER",
    "mode": "tcp_only"
}
EOF

# Setup Cloak
if [ ! -f /opt/amnezia/cloak/cloak_private.key ]; then
    ck-server -u > /opt/amnezia/cloak/cloak_bypass_uid.key
    ck-server -u > /opt/amnezia/cloak/cloak_admin_uid.key
    IFS=, read CLOAK_PUBLIC_KEY CLOAK_PRIVATE_KEY <<<$(ck-server -k)
    echo $CLOAK_PUBLIC_KEY > /opt/amnezia/cloak/cloak_public.key
    echo $CLOAK_PRIVATE_KEY > /opt/amnezia/cloak/cloak_private.key
fi

CK_PRIV=$(cat /opt/amnezia/cloak/cloak_private.key)
CK_UID=$(cat /opt/amnezia/cloak/cloak_bypass_uid.key)
CK_ADMIN=$(cat /opt/amnezia/cloak/cloak_admin_uid.key)

cat <<EOF > /opt/amnezia/cloak/ck-config.json
{
  "ProxyBook": {
    "openvpn": [
      "tcp",
      "127.0.0.1:$OPENVPN_PORT"
    ],
    "shadowsocks": [
      "tcp",
      "127.0.0.1:$SHADOWSOCKS_SERVER_PORT"
    ]
  },
  "BypassUID": [
    "$CK_UID"
  ],
  "BindAddr": [
    "0.0.0.0:$CLOAK_SERVER_PORT"
  ],
  "RedirAddr": "$FAKE_WEB_SITE_ADDRESS",
  "PrivateKey": "$CK_PRIV",
  "AdminUID": "$CK_ADMIN"
}
EOF
EOF_CONF

cat <<'EOF_START' > "$BUILD_DIR/start.sh"
#!/bin/bash
echo "Container startup"
ifconfig eth0:0 $SERVER_IP_ADDRESS netmask 255.255.255.255 up
if [ ! -c /dev/net/tun ]; then mkdir -p /dev/net; mknod /dev/net/tun c 10 200; fi

iptables -A INPUT -i tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT

iptables -A FORWARD -i tun0 -o eth0 -s $OPENVPN_SUBNET_IP/$OPENVPN_SUBNET_CIDR -j ACCEPT
iptables -A FORWARD -i tun0 -o eth1 -s $OPENVPN_SUBNET_IP/$OPENVPN_SUBNET_CIDR -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -t nat -A POSTROUTING -s $OPENVPN_SUBNET_IP/$OPENVPN_SUBNET_CIDR -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s $OPENVPN_SUBNET_IP/$OPENVPN_SUBNET_CIDR -o eth1 -j MASQUERADE

killall -KILL openvpn 2>/dev/null || true
killall -KILL ck-server 2>/dev/null || true
killall -KILL ssserver 2>/dev/null || true

if [ -f /opt/amnezia/openvpn/ca.crt ]; then (openvpn --config /opt/amnezia/openvpn/server.conf --daemon); fi
if [ -f /opt/amnezia/shadowsocks/ss-config.json ]; then (ssserver -c /opt/amnezia/shadowsocks/ss-config.json &); fi
if [ -f /opt/amnezia/cloak/ck-config.json ]; then (ck-server -c /opt/amnezia/cloak/ck-config.json &); fi

tail -f /dev/null
EOF_START

cat <<'EOF_OVPN' > "$BUILD_DIR/template.ovpn"
client
dev tun
proto tcp
resolv-retry infinite
nobind
persist-key
persist-tun
$OPENVPN_NCP_DISABLE
cipher $OPENVPN_CIPHER
auth $OPENVPN_HASH
verb 3
tls-client
tls-version-min 1.2
key-direction 1
remote-cert-tls server
redirect-gateway def1 bypass-dhcp

dhcp-option DNS $PRIMARY_DNS
dhcp-option DNS $SECONDARY_DNS
block-outside-dns

remote 127.0.0.1 1194

$OPENVPN_ADDITIONAL_CLIENT_CONFIG

<ca>
$OPENVPN_CA_CERT
</ca>
<cert>
$OPENVPN_CLIENT_CERT
</cert>
<key>
$OPENVPN_PRIV_KEY
</key>
<tls-auth>
$OPENVPN_TA_KEY
</tls-auth>
EOF_OVPN

docker build -t "$CONTAINER_NAME" "$BUILD_DIR" --build-arg SERVER_ARCH="$SERVER_ARCH"

docker network create amnezia-dns-net 2>/dev/null || true
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

DATA_DIR="/opt/amnezia/openvpn-cloak/data"
mkdir -p "$DATA_DIR/openvpn" "$DATA_DIR/cloak" "$DATA_DIR/shadowsocks"

cp "$BUILD_DIR/configure_container.sh" "$DATA_DIR/configure_container.sh"
cp "$BUILD_DIR/start.sh"              "$DATA_DIR/start.sh"
cp "$BUILD_DIR/template.ovpn"         "$DATA_DIR/openvpn/template.ovpn"
chmod +x "$DATA_DIR/start.sh" "$DATA_DIR/configure_container.sh"

docker run -d --privileged --cap-add=NET_ADMIN --restart always \
  -v "$DATA_DIR:/opt/amnezia" \
  -p "${CLOAK_PORT}:443/tcp" --name "$CONTAINER_NAME" "$CONTAINER_NAME"

sleep 3

docker exec -i "$CONTAINER_NAME" bash -c 'mkdir -p /dev/net; [ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200'

docker exec -i "$CONTAINER_NAME" bash -c 'cd /opt/amnezia/openvpn && [ -f ca.crt ] || { export EASYRSA_KEY_SIZE=2048; easyrsa init-pki && easyrsa gen-dh && \
  (echo yes | easyrsa build-ca nopass) && (echo yes | easyrsa gen-req AmneziaReq nopass) && \
  (echo yes | easyrsa sign-req server AmneziaReq) && openvpn --genkey --secret ta.key && \
  cp pki/dh.pem pki/ca.crt pki/issued/AmneziaReq.crt pki/private/AmneziaReq.key . && easyrsa gen-crl && cp pki/crl.pem crl.pem; }'

docker exec -i -e OPENVPN_PORT=1194 -e OPENVPN_SUBNET_IP=10.8.2.0 -e OPENVPN_SUBNET_MASK=255.255.255.0 \
  -e OPENVPN_SUBNET_CIDR=24 \
  -e OPENVPN_CIPHER=AES-256-GCM -e OPENVPN_HASH=SHA512 -e OPENVPN_NCP_DISABLE="" -e OPENVPN_TLS_AUTH="" \
  -e OPENVPN_ADDITIONAL_SERVER_CONFIG="" -e CLOAK_SERVER_PORT=443 -e SHADOWSOCKS_SERVER_PORT=8388 \
  -e SHADOWSOCKS_CIPHER=chacha20-ietf-poly1305 -e FAKE_WEB_SITE_ADDRESS="$FAKE_SITE" \
  -e SERVER_IP_ADDRESS="10.8.2.1" \
  "$CONTAINER_NAME" bash /opt/amnezia/configure_container.sh

docker restart "$CONTAINER_NAME"
sleep 3

PUB=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_public.key)
BYPASS=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/cloak/cloak_bypass_uid.key)
SS_PASSWORD=$(docker exec "$CONTAINER_NAME" cat /opt/amnezia/shadowsocks/shadowsocks.key)

echo "Variable: container_name=$CONTAINER_NAME"
echo "Variable: vpn_port=$CLOAK_PORT"
echo "Variable: cloak_public_key=$PUB"
echo "Variable: cloak_bypass_uid=$BYPASS"
echo "Variable: ss_password=$SS_PASSWORD"
echo "Variable: fake_site=$FAKE_SITE"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Port: $CLOAK_PORT"
$tag$
        WHERE slug = 'openvpn-cloak';
    END IF;
END
$func$;
