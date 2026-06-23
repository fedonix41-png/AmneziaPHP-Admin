-- 008_add_panel_imports.sql — PostgreSQL
-- Add panel imports tracking table

CREATE TABLE IF NOT EXISTS panel_imports (
  id SERIAL PRIMARY KEY,
  server_id INT NOT NULL,
  panel_type VARCHAR(50) NOT NULL,
  import_file_name VARCHAR(255) NOT NULL,
  clients_imported INT DEFAULT 0,
  import_data JSON NULL,
  status VARCHAR(50) DEFAULT 'pending',
  error_message TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by INT NULL,
  FOREIGN KEY (server_id) REFERENCES vpn_servers(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_panel_imports_server_id  ON panel_imports (server_id);
CREATE INDEX IF NOT EXISTS idx_panel_imports_panel_type ON panel_imports (panel_type);
CREATE INDEX IF NOT EXISTS idx_panel_imports_status     ON panel_imports (status);
