UPDATE protocols SET definition = $JSON${
  "engine": "shell",
  "metadata": {
    "container_name": "amnezia-openvpn-cloak",
    "config_dir": "/opt/amnezia/openvpn-cloak",
    "port_range": [443, 443]
  },
  "scripts": {
    "detect": "#!/bin/bash\nCONTAINER=\"${SERVER_CONTAINER:-amnezia-openvpn-cloak}\"\nif docker ps -a --format '{{.Names}}' | grep -Eq \"^${CONTAINER}$\"; then\n    if docker exec \"$CONTAINER\" test -f /etc/openvpn/server.conf 2>/dev/null; then\n        echo '{\"status\":\"existing\"}'\n        exit 0\n    fi\nfi\necho '{\"status\":\"absent\"}'",
    "restore": "#!/bin/bash\nCONTAINER=\"${SERVER_CONTAINER:-amnezia-openvpn-cloak}\"\nPUB=$(docker exec \"$CONTAINER\" cat /etc/cloak/public.key 2>/dev/null || echo \"\")\nBYPASS=$(docker exec \"$CONTAINER\" cat /etc/cloak/bypass_uid 2>/dev/null || echo \"\")\necho \"Variable: cloak_public_key=$PUB\"\necho \"Variable: cloak_bypass_uid=$BYPASS\"\necho \"Variable: vpn_port=${SERVER_PORT:-443}\"\necho '{\"success\":true,\"mode\":\"restore\"}'",
    "add_client": "#!/bin/bash\nLOGIN=\"{{options.login}}\"\nCONTAINER=\"${SERVER_CONTAINER:-amnezia-openvpn-cloak}\"\n[ -z \"$LOGIN\" ] && { echo \"Error: login required\" >&2; exit 1; }\ndocker exec \"$CONTAINER\" bash -c \"cd /etc/openvpn && easyrsa build-client-full '$LOGIN' nopass\" 2>&1\nCA=$(docker exec \"$CONTAINER\" cat /etc/openvpn/pki/ca.crt 2>/dev/null || echo \"\")\nCERT=$(docker exec \"$CONTAINER\" cat \"/etc/openvpn/pki/issued/${LOGIN}.crt\" 2>/dev/null || echo \"\")\nKEY=$(docker exec \"$CONTAINER\" cat \"/etc/openvpn/pki/private/${LOGIN}.key\" 2>/dev/null || echo \"\")\nTA=$(docker exec \"$CONTAINER\" cat /etc/openvpn/pki/ta.key 2>/dev/null || echo \"\")\nOVPN=\"client\ndev tun\nproto tcp\nremote ${SERVER_HOST} 443\nresolv-retry infinite\nnobind\npersist-key\npersist-tun\ncipher AES-256-GCM\nauth SHA512\ntls-client\nverb 3\nkey-direction 1\n<ca>\n${CA}\n</ca>\n<cert>\n${CERT}\n</cert>\n<key>\n${KEY}\n</key>\n<tls-auth>\n${TA}\n</tls-auth>\"\nPUB=$(docker exec \"$CONTAINER\" cat /etc/cloak/public.key 2>/dev/null || echo \"\")\nBYPASS=$(docker exec \"$CONTAINER\" cat /etc/cloak/bypass_uid 2>/dev/null || echo \"\")\nOVPN_B64=$(echo \"$OVPN\" | base64 -w0)\necho \"Variable: ovpn_config_b64=$OVPN_B64\"\necho \"Variable: cloak_public_key=$PUB\"\necho \"Variable: cloak_bypass_uid=$BYPASS\"\necho \"Variable: server_host=${SERVER_HOST}\"\necho \"Variable: vpn_port=${SERVER_PORT:-443}\"\necho \"Port: ${SERVER_PORT:-443}\""
  }
}$JSON$::jsonb WHERE slug = 'openvpn-cloak';
