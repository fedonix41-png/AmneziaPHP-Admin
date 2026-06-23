-- 014_consolidated.sql — PostgreSQL rewrite
-- Translations, protocol tables, DDL additions (idempotent via IF NOT EXISTS / DO NOTHING)

-- ───────────────────────────────────────────
-- Translations (server backup / config import)
-- ───────────────────────────────────────────
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en','servers','backup_upload_type','Backup type'),
('en','servers','backup_type_auto','Auto detect'),
('en','servers','backup_type_amnezia','Amnezia app (.backup)'),
('en','servers','backup_type_panel','Panel export (.json)'),
('en','servers','backup_upload_hint','Upload a .backup or .json file. After upload, pick a server entry above.'),
('ru','servers','backup_upload_type','Тип бэкапа'),
('ru','servers','backup_type_auto','Определить автоматически'),
('ru','servers','backup_type_amnezia','Приложение Amnezia (.backup)'),
('ru','servers','backup_type_panel','Экспорт панели (.json)'),
('ru','servers','backup_upload_hint','Загрузите файл .backup или .json. После загрузки выберите сервер выше.'),
('es','servers','backup_upload_type','Tipo de copia de seguridad'),
('es','servers','backup_type_auto','Detectar automáticamente'),
('es','servers','backup_type_amnezia','Aplicación Amnezia (.backup)'),
('es','servers','backup_type_panel','Exportación del panel (.json)'),
('es','servers','backup_upload_hint','Suba un archivo .backup o .json. Después seleccione el servidor arriba.'),
('de','servers','backup_upload_type','Backup-Typ'),
('de','servers','backup_type_auto','Automatisch erkennen'),
('de','servers','backup_type_amnezia','Amnezia-App (.backup)'),
('de','servers','backup_type_panel','Panel-Export (.json)'),
('de','servers','backup_upload_hint','Laden Sie eine .backup- oder .json-Datei hoch. Wählen Sie anschließend oben einen Server aus.'),
('fr','servers','backup_upload_type','Type de sauvegarde'),
('fr','servers','backup_type_auto','Détection automatique'),
('fr','servers','backup_type_amnezia','Application Amnezia (.backup)'),
('fr','servers','backup_type_panel','Export du panneau (.json)'),
('fr','servers','backup_upload_hint','Téléversez un fichier .backup ou .json, puis sélectionnez un serveur ci-dessus.'),
('zh','servers','backup_upload_type','备份类型'),
('zh','servers','backup_type_auto','自动检测'),
('zh','servers','backup_type_amnezia','Amnezia 应用 (.backup)'),
('zh','servers','backup_type_panel','面板导出 (.json)'),
('zh','servers','backup_upload_hint','上传 .backup 或 .json 文件，随后在上方选择服务器。')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'servers', 'config_import_title', 'Import configuration'),
('en', 'servers', 'config_import_hint', 'Upload a configuration backup to update this server and its clients.'),
('en', 'servers', 'config_import_type_label', 'Backup type'),
('en', 'servers', 'config_import_type_panel', 'Panel backup (.json)'),
('en', 'servers', 'config_import_type_amnezia', 'Amnezia app backup (.backup)'),
('en', 'servers', 'config_import_file_label', 'Configuration file'),
('en', 'servers', 'config_import_file_hint', 'Our panel uses .json files. The Amnezia app uses .backup files.'),
('en', 'servers', 'config_import_submit', 'Import configuration'),
('ru', 'servers', 'config_import_title', 'Импорт конфигурации'),
('ru', 'servers', 'config_import_hint', 'Загрузите файл бэкапа, чтобы обновить настройки сервера и список клиентов.'),
('ru', 'servers', 'config_import_type_label', 'Источник бэкапа'),
('ru', 'servers', 'config_import_type_panel', 'Бэкап панели (.json)'),
('ru', 'servers', 'config_import_type_amnezia', 'Бэкап приложения Amnezia (.backup)'),
('ru', 'servers', 'config_import_file_label', 'Файл конфигурации'),
('ru', 'servers', 'config_import_file_hint', 'Панель использует файлы .json. Приложение Amnezia — файлы .backup.'),
('ru', 'servers', 'config_import_submit', 'Импортировать конфигурацию'),
('es', 'servers', 'config_import_title', 'Importar configuración'),
('es', 'servers', 'config_import_hint', 'Cargue un respaldo para actualizar este servidor y sus clientes.'),
('es', 'servers', 'config_import_type_label', 'Tipo de backup'),
('es', 'servers', 'config_import_type_panel', 'Backup del panel (.json)'),
('es', 'servers', 'config_import_type_amnezia', 'Backup de la app Amnezia (.backup)'),
('es', 'servers', 'config_import_file_label', 'Archivo de configuración'),
('es', 'servers', 'config_import_file_hint', 'El panel usa archivos .json. La app Amnezia usa archivos .backup.'),
('es', 'servers', 'config_import_submit', 'Importar configuración'),
('de', 'servers', 'config_import_title', 'Konfiguration importieren'),
('de', 'servers', 'config_import_hint', 'Laden Sie eine Sicherung hoch, um diesen Server und seine Clients zu aktualisieren.'),
('de', 'servers', 'config_import_type_label', 'Backup-Typ'),
('de', 'servers', 'config_import_type_panel', 'Panel-Backup (.json)'),
('de', 'servers', 'config_import_type_amnezia', 'Amnezia-App-Backup (.backup)'),
('de', 'servers', 'config_import_file_label', 'Konfigurationsfile'),
('de', 'servers', 'config_import_file_hint', 'Die Panel-Backups sind .json. Die Amnezia-App nutzt .backup-Dateien.'),
('de', 'servers', 'config_import_submit', 'Konfiguration importieren'),
('fr', 'servers', 'config_import_title', 'Importer la configuration'),
('fr', 'servers', 'config_import_hint', 'Téléversez un fichier de sauvegarde pour mettre à jour ce serveur et ses clients.'),
('fr', 'servers', 'config_import_type_label', 'Type de sauvegarde'),
('fr', 'servers', 'config_import_type_panel', 'Sauvegarde du panneau (.json)'),
('fr', 'servers', 'config_import_type_amnezia', 'Sauvegarde de l''application Amnezia (.backup)'),
('fr', 'servers', 'config_import_file_label', 'Fichier de configuration'),
('fr', 'servers', 'config_import_file_hint', 'Notre panneau utilise des fichiers .json. L''application Amnezia utilise des fichiers .backup.'),
('fr', 'servers', 'config_import_submit', 'Importer la configuration'),
('zh', 'servers', 'config_import_title', '导入配置'),
('zh', 'servers', 'config_import_hint', '上传备份文件以更新此服务器及其客户端。'),
('zh', 'servers', 'config_import_type_label', '备份类型'),
('zh', 'servers', 'config_import_type_panel', '面板备份 (.json)'),
('zh', 'servers', 'config_import_type_amnezia', 'Amnezia 应用备份 (.backup)'),
('zh', 'servers', 'config_import_file_label', '配置文件'),
('zh', 'servers', 'config_import_file_hint', '面板使用 .json 文件，Amnezia 应用使用 .backup 文件。'),
('zh', 'servers', 'config_import_submit', '导入配置')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en','servers','creation_mode','Creation mode'),
('en','servers','creation_mode_manual','Manual setup'),
('en','servers','creation_mode_backup','Import from backup'),
('en','servers','upload_backup_file','Upload backup file'),
('en','servers','backup_server_entry','Select server entry'),
('en','servers','backup_summary_host','Host'),
('en','servers','backup_summary_clients','Clients'),
('ru','servers','creation_mode','Режим создания'),
('ru','servers','creation_mode_manual','Ручная настройка'),
('ru','servers','creation_mode_backup','Импорт из бэкапа'),
('ru','servers','upload_backup_file','Загрузите файл бэкапа'),
('ru','servers','backup_server_entry','Выберите запись сервера'),
('ru','servers','backup_summary_host','Хост'),
('ru','servers','backup_summary_clients','Клиенты'),
('ru','servers','config_import_file_hint','Файл хранится на сервере только во время импорта и удаляется сразу после завершения.'),
('ru','servers','config_import_submit','Импортировать конфигурацию')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

-- ───────────────────────────────────────────
-- Protocols table (PostgreSQL)
-- ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS protocols (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    install_script TEXT,
    uninstall_script TEXT,
    password_command TEXT,
    output_template TEXT,
    ubuntu_compatible BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    definition JSON NULL,
    show_text_content SMALLINT DEFAULT 0,
    qr_code_template TEXT DEFAULT NULL,
    qr_code_format VARCHAR(50) DEFAULT 'amnezia_compressed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_protocols_slug ON protocols (slug);
CREATE INDEX IF NOT EXISTS idx_protocols_active ON protocols (is_active);

CREATE TABLE IF NOT EXISTS protocol_templates (
    id SERIAL PRIMARY KEY,
    protocol_id INT NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    template_content TEXT NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_protocol_templates_protocol ON protocol_templates (protocol_id);
CREATE INDEX IF NOT EXISTS idx_protocol_templates_default ON protocol_templates (is_default);

CREATE TABLE IF NOT EXISTS protocol_variables (
    id SERIAL PRIMARY KEY,
    protocol_id INT NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    variable_name VARCHAR(100) NOT NULL,
    variable_type VARCHAR(50) NOT NULL DEFAULT 'string',
    default_value TEXT,
    description TEXT,
    required BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_protocol_variables_protocol ON protocol_variables (protocol_id);
CREATE INDEX IF NOT EXISTS idx_protocol_variables_name ON protocol_variables (variable_name);

CREATE TABLE IF NOT EXISTS server_protocols (
    id SERIAL PRIMARY KEY,
    server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
    protocol_id INT NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    config_data JSON,
    applied_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (server_id, protocol_id)
);
CREATE INDEX IF NOT EXISTS idx_server_protocols_server ON server_protocols (server_id);
CREATE INDEX IF NOT EXISTS idx_server_protocols_protocol ON server_protocols (protocol_id);

CREATE TABLE IF NOT EXISTS ai_generations (
    id SERIAL PRIMARY KEY,
    protocol_id INT NULL REFERENCES protocols(id) ON DELETE SET NULL,
    model_used VARCHAR(100) NOT NULL,
    prompt TEXT NOT NULL,
    generated_script TEXT,
    suggestions JSON,
    ubuntu_compatible BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ai_generations_protocol ON ai_generations (protocol_id);
CREATE INDEX IF NOT EXISTS idx_ai_generations_model ON ai_generations (model_used);
CREATE INDEX IF NOT EXISTS idx_ai_generations_created ON ai_generations (created_at DESC);

-- Add protocol_id to vpn_clients if not already there (idempotent)
ALTER TABLE vpn_clients ADD COLUMN IF NOT EXISTS protocol_id INT NULL REFERENCES protocols(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_clients_protocol_id ON vpn_clients (protocol_id);

-- Add role column to users if missing
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user';
CREATE INDEX IF NOT EXISTS idx_users_role2 ON users (role);

-- Add optional columns to protocols if missing
ALTER TABLE protocols ADD COLUMN IF NOT EXISTS uninstall_script TEXT NULL;
ALTER TABLE protocols ADD COLUMN IF NOT EXISTS password_command TEXT NULL;

-- Add display_name to users if missing
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(255) NULL;
UPDATE users SET display_name = name WHERE (display_name IS NULL OR display_name = '') AND name IS NOT NULL;

-- Add install_protocol / install_options to vpn_servers if missing
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS install_protocol VARCHAR(100) NULL;
ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS install_options JSON NULL;

-- ───────────────────────────────────────────
-- Seed built-in protocols
-- ───────────────────────────────────────────
INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active)
SELECT 'AmneziaWG Advanced', 'amnezia-wg-advanced',
       'AmneziaWG protocol with advanced junk packet obfuscation parameters',
       '#!/bin/bash
echo "AmneziaWG Advanced installed"
',
       '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

Jc = {{jc}}
Jmin = {{jmin}}
Jmax = {{jmax}}
S1 = {{s1}}
S2 = {{s2}}
H1 = {{h1}}
H2 = {{h2}}
H3 = {{h3}}
H4 = {{h4}}',
       true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='amnezia-wg-advanced');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active)
SELECT 'WireGuard Standard', 'wireguard-standard',
       'Standard WireGuard VPN protocol',
       '#!/bin/bash
echo "WireGuard Standard installed"
',
       '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25',
       true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='wireguard-standard');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active)
SELECT 'OpenVPN', 'openvpn', 'OpenVPN protocol with TCP/UDP support',
       '#!/bin/bash
echo "OpenVPN installed"
',
       'client
dev tun
proto {{protocol}}
remote {{server_host}} {{server_port}}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3',
       true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='openvpn');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active)
SELECT 'Shadowsocks', 'shadowsocks', 'Shadowsocks proxy protocol',
       '#!/bin/bash
echo "Shadowsocks installed"
',
       '{
  "server": "{{server_host}}",
  "server_port": {{server_port}},
  "password": "{{password}}",
  "method": "{{method}}"
}',
       true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='shadowsocks');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active, created_at, updated_at)
SELECT 'SMB Server', 'smb',
       'Samba SMB file share inside Docker with random host port',
       E'#!/bin/bash\n\nset -euo pipefail\nset -x\n\nCONTAINER_NAME="${CONTAINER_NAME:-amnezia-smb}"\nPORT_RANGE_START=${PORT_RANGE_START:-30000}\nPORT_RANGE_END=${PORT_RANGE_END:-65000}\nSMB_PORT=$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))\n\ndocker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true\nmkdir -p /opt/amnezia/smb/share\ndocker run -d --name "$CONTAINER_NAME" -p "${SMB_PORT}:445" -v /opt/amnezia/smb/share:/share dperson/samba -p -u "amnezia;amnezia" -s "share;/share;yes;no;no;amnezia"\necho "Port: ${SMB_PORT}"\necho "Password: amnezia"\n',
       'smb://{{server_host}}:{{server_port}}/share
Username: amnezia
Password: {{password}}',
       true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='smb');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active, created_at, updated_at)
SELECT 'XRay VLESS', 'xray-vless',
       'XRay VLESS server inside Docker with generated client UUID',
       E'#!/bin/bash\n\nset -euo pipefail\nset -x\n\nCONTAINER_NAME="${CONTAINER_NAME:-amnezia-xray}"\nPORT_RANGE_START=${PORT_RANGE_START:-30000}\nPORT_RANGE_END=${PORT_RANGE_END:-65000}\nXRAY_PORT=$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))\nCLIENT_ID=$(cat /proc/sys/kernel/random/uuid)\ndocker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true\nmkdir -p /opt/amnezia/xray\ndocker run -d --name "$CONTAINER_NAME" --restart always -p "${XRAY_PORT}:443" -v /opt/amnezia/xray:/etc/xray teddysun/xray\necho "Port: ${XRAY_PORT}"\necho "ClientID: ${CLIENT_ID}"\n',
       'vless://{{client_id}}@{{server_host}}:{{server_port}}?security=none&type=tcp',
       true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='xray-vless');

-- Protocol variables (AmneziaWG Advanced)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'private_key', 'string', '', 'Client private key', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='private_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'client_ip', 'string', '10.8.1.2', 'Client IP address', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='client_ip');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_public_key', 'string', '', 'Server public key', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_public_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'preshared_key', 'string', '', 'Pre-shared key', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='preshared_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '51820', 'Server port', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'jc', 'number', '4', 'Junk packet count', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='jc');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'jmin', 'number', '50', 'Minimum junk packet size', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='jmin');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'jmax', 'number', '1000', 'Maximum junk packet size', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='jmax');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 's1', 'number', '148', 'Junk packet size 1', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='s1');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 's2', 'number', '450', 'Junk packet size 2', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='s2');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'h1', 'number', '320121696', 'Junk packet header 1', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='h1');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'h2', 'number', '51525354', 'Junk packet header 2', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='h2');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'h3', 'number', '13141516', 'Junk packet header 3', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='h3');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'h4', 'number', '92435495', 'Junk packet header 4', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='h4');

-- Protocol variables (WireGuard Standard)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'private_key', 'string', '', 'Client private key', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='private_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'client_ip', 'string', '10.8.2.2', 'Client IP address', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='client_ip');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_public_key', 'string', '', 'Server public key', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_public_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'preshared_key', 'string', '', 'Pre-shared key', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='preshared_key');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '51820', 'Server port', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');

-- Protocol variables (OpenVPN)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'protocol', 'string', 'udp', 'Connection protocol (udp/tcp)', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='protocol');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '1194', 'Server port', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');

-- Protocol variables (Shadowsocks)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '8388', 'Server port', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'password', 'string', '', 'Connection password', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='password');

-- Protocol variables (SMB)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_host', 'string', '127.0.0.1', 'Server hostname or IP', true FROM protocols WHERE slug='smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='smb') AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_port', 'number', '445', 'Server port', true FROM protocols WHERE slug='smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='smb') AND variable_name='server_port');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'password', 'string', '', 'Connection password', true FROM protocols WHERE slug='smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='smb') AND variable_name='password');

-- Protocol variables (XRay VLESS)
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_host', 'string', '127.0.0.1', 'Server hostname or IP', true FROM protocols WHERE slug='xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='server_host');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_port', 'number', '443', 'Server port', true FROM protocols WHERE slug='xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='server_port');
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'client_id', 'string', '', 'VLESS client ID (UUID)', true FROM protocols WHERE slug='xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='client_id');

-- Protocol templates
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default AmneziaWG',
'[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

Jc = {{jc}}
Jmin = {{jmin}}
Jmax = {{jmax}}
S1 = {{s1}}
S2 = {{s2}}
H1 = {{h1}}
H2 = {{h2}}
H3 = {{h3}}
H4 = {{h4}}', true
FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id=p.id AND template_name='Default AmneziaWG');

INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default WireGuard',
'[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25', true
FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id=p.id AND template_name='Default WireGuard');

-- ───────────────────────────────────────────
-- Protocol editor translations
-- ───────────────────────────────────────────
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en','common','cancel','Cancel'),
('ru','common','cancel','Отмена'),
('es','common','cancel','Cancelar'),
('de','common','cancel','Abbrechen'),
('fr','common','cancel','Annuler'),
('zh','common','cancel','取消'),
('en','common','format','Format'),
('ru','common','format','Форматировать'),
('es','common','format','Formatear'),
('de','common','format','Formatieren'),
('fr','common','format','Formater'),
('zh','common','format','格式化'),
('en','common','clear','Clear'),
('ru','common','clear','Очистить'),
('es','common','clear','Borrar'),
('de','common','clear','Leeren'),
('fr','common','clear','Effacer'),
('zh','common','clear','清空'),
('en','protocols','template_editor_help','Use placeholders like {{variable}} and preview client output'),
('ru','protocols','template_editor_help','Используйте плейсхолдеры вида {{variable}} и просматривайте вывод клиента'),
('es','protocols','template_editor_help','Usa marcadores como {{variable}} y previsualiza la salida del cliente'),
('de','protocols','template_editor_help','Verwenden Sie Platzhalter wie {{variable}} und sehen Sie die Client-Ausgabe in der Vorschau'),
('fr','protocols','template_editor_help','Utilisez des placeholders comme {{variable}} et prévisualisez la sortie client'),
('zh','protocols','template_editor_help','使用如 {{variable}} 的占位符并预览客户端输出'),
('en','protocols','enter_protocol_name','Enter protocol name'),
('ru','protocols','enter_protocol_name','Введите имя протокола'),
('es','protocols','enter_protocol_name','Introduce el nombre del protocolo'),
('de','protocols','enter_protocol_name','Protokollnamen eingeben'),
('fr','protocols','enter_protocol_name','Saisissez le nom du protocole'),
('zh','protocols','enter_protocol_name','输入协议名称'),
('en','protocols','protocol_created_successfully','Protocol created successfully'),
('ru','protocols','protocol_created_successfully','Протокол успешно создан'),
('es','protocols','protocol_created_successfully','Protocolo creado correctamente'),
('de','protocols','protocol_created_successfully','Protokoll erfolgreich erstellt'),
('fr','protocols','protocol_created_successfully','Protocole créé avec succès'),
('zh','protocols','protocol_created_successfully','协议创建成功'),
('en','protocols','error_creating_protocol','Error creating protocol'),
('ru','protocols','error_creating_protocol','Ошибка создания протокола'),
('es','protocols','error_creating_protocol','Error al crear el protocolo'),
('de','protocols','error_creating_protocol','Fehler beim Erstellen des Protokolls'),
('fr','protocols','error_creating_protocol','Erreur lors de la création du protocole'),
('zh','protocols','error_creating_protocol','创建协议时出错'),
('en','settings','protocols','Protocols'),
('ru','settings','protocols','Протоколы'),
('es','settings','protocols','Protocolos'),
('de','settings','protocols','Protokolle'),
('fr','settings','protocols','Protocoles'),
('zh','settings','protocols','协议'),
('en','settings','protocol_management','Protocol Management'),
('ru','settings','protocol_management','Управление протоколами'),
('es','settings','protocol_management','Gestión de protocolos'),
('de','settings','protocol_management','Protokollverwaltung'),
('fr','settings','protocol_management','Gestion des protocoles'),
('zh','settings','protocol_management','协议管理'),
('en','protocols','test_install','Test install'),
('ru','protocols','test_install','Протестировать установку'),
('es','protocols','test_install','Probar instalación'),
('de','protocols','test_install','Installation testen'),
('fr','protocols','test_install','Tester l''installation'),
('zh','protocols','test_install','测试安装'),
('en','protocols','test_result','Test result'),
('ru','protocols','test_result','Результат теста'),
('es','protocols','test_result','Resultado de la prueba'),
('de','protocols','test_result','Testergebnis'),
('fr','protocols','test_result','Résultat du test'),
('zh','protocols','test_result','测试结果'),
('en','protocols','test_failed','Test failed'),
('ru','protocols','test_failed','Ошибка теста'),
('es','protocols','test_failed','La prueba falló'),
('de','protocols','test_failed','Test fehlgeschlagen'),
('fr','protocols','test_failed','Échec du test'),
('zh','protocols','test_failed','测试失败'),
('en','ai','enter_protocol_id_to_apply','Enter protocol ID to apply'),
('ru','ai','enter_protocol_id_to_apply','Введите ID протокола для применения'),
('es','ai','enter_protocol_id_to_apply','Introduce el ID de protocolo para aplicar'),
('de','ai','enter_protocol_id_to_apply','Protokoll-ID zum Anwenden eingeben'),
('fr','ai','enter_protocol_id_to_apply','Saisissez l''ID du protocole à appliquer'),
('zh','ai','enter_protocol_id_to_apply','输入要应用的协议 ID')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;