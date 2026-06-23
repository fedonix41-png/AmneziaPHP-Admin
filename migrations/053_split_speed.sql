ALTER TABLE vpn_clients ADD COLUMN IF NOT EXISTS speed_up BIGINT DEFAULT 0;
ALTER TABLE vpn_clients ADD COLUMN IF NOT EXISTS speed_down BIGINT DEFAULT 0;
-- We can drop current_speed later or keep it as total
