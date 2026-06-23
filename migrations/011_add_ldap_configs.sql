-- 011_add_ldap_configs.sql — PostgreSQL
-- LDAP configuration and group mapping tables

CREATE TABLE IF NOT EXISTS ldap_configs (
    id INT PRIMARY KEY,
    enabled BOOLEAN DEFAULT FALSE,
    host VARCHAR(255) NOT NULL,
    port INT DEFAULT 389,
    use_tls BOOLEAN DEFAULT FALSE,
    base_dn VARCHAR(255) NOT NULL,
    bind_dn VARCHAR(255) NOT NULL,
    bind_password VARCHAR(255) NOT NULL,
    user_search_filter VARCHAR(255) DEFAULT '(uid=%s)',
    group_search_filter VARCHAR(255) DEFAULT '(memberUid=%s)',
    sync_interval INT DEFAULT 30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ldap_group_mappings (
    id SERIAL PRIMARY KEY,
    ldap_group VARCHAR(255) NOT NULL UNIQUE,
    role_name VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add ldap_sync flag to users table (idempotent)
ALTER TABLE users ADD COLUMN IF NOT EXISTS ldap_synced BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ldap_dn VARCHAR(255) NULL;
CREATE INDEX IF NOT EXISTS idx_users_ldap_dn ON users (ldap_dn);

-- Insert default LDAP configuration (disabled by default)
INSERT INTO ldap_configs (id, enabled, host, port, base_dn, bind_dn, bind_password)
VALUES (1, FALSE, 'ldap.example.com', 389, 'dc=example,dc=com', 'cn=admin,dc=example,dc=com', '')
ON CONFLICT (id) DO NOTHING;
