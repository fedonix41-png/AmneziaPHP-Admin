-- 009_add_server_metrics.sql — PostgreSQL
-- Add server_metrics and client_metrics tables

CREATE TABLE IF NOT EXISTS server_metrics (
  id BIGSERIAL PRIMARY KEY,
  server_id INT NOT NULL,
  cpu_percent DECIMAL(5,2) NULL,
  ram_used_mb INT NULL,
  ram_total_mb INT NULL,
  disk_used_gb DECIMAL(10,2) NULL,
  disk_total_gb DECIMAL(10,2) NULL,
  network_rx_mbps DECIMAL(10,2) NULL,
  network_tx_mbps DECIMAL(10,2) NULL,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (server_id) REFERENCES vpn_servers(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_server_metrics_server_time ON server_metrics (server_id, collected_at);

CREATE TABLE IF NOT EXISTS client_metrics (
  id BIGSERIAL PRIMARY KEY,
  client_id INT NOT NULL,
  bytes_sent BIGINT DEFAULT 0,
  bytes_received BIGINT DEFAULT 0,
  speed_up_kbps DECIMAL(10,2) NULL,
  speed_down_kbps DECIMAL(10,2) NULL,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (client_id) REFERENCES vpn_clients(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_client_metrics_client_time ON client_metrics (client_id, collected_at);
