-- 049_add_dns_servers.sql — PostgreSQL
-- Add dns_servers column to vpn_servers table if missing

ALTER TABLE vpn_servers ADD COLUMN IF NOT EXISTS dns_servers VARCHAR(255) DEFAULT '1.1.1.1, 1.0.0.1';
