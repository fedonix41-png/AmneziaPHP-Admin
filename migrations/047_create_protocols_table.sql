-- 047_create_protocols_table.sql — PostgreSQL rewrite
-- Idempotent: uses IF NOT EXISTS and ON CONFLICT DO NOTHING

-- 1. Ensure columns exist on protocols table (idempotent)
ALTER TABLE protocols ADD COLUMN IF NOT EXISTS definition JSON NULL;
ALTER TABLE protocols ADD COLUMN IF NOT EXISTS show_text_content SMALLINT DEFAULT 0;

-- 2. Insert Data
INSERT INTO protocols (slug, name, description, definition, show_text_content, is_active) VALUES
('wireguard', 'WireGuard', 'Standard WireGuard', '{}', 0, true),
('openvpn', 'OpenVPN', 'Standard OpenVPN', '{}', 0, true),
('shadowsocks', 'Shadowsocks', 'Shadowsocks proxy', '{}', 0, true),
('cloak', 'Cloak', 'Cloak obfuscation', '{}', 0, true)
ON CONFLICT (slug) DO NOTHING;

-- 3. Add protocol_id to vpn_clients if missing
ALTER TABLE vpn_clients ADD COLUMN IF NOT EXISTS protocol_id INT NULL REFERENCES protocols(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_clients_protocol_id ON vpn_clients (protocol_id);

-- 4. Create server_protocols if not exists
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
