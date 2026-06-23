-- 012_add_user_roles.sql — PostgreSQL
-- Add user roles table and permissions

CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    permissions JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add role column to users table (idempotent)
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'viewer';
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- Insert default roles
INSERT INTO user_roles (name, display_name, description, permissions) VALUES
('admin',   'Administrator', 'Full access to all features',     '["*"]'),
('manager', 'Manager',       'Can manage servers and clients',   '["servers.view","servers.create","servers.edit","clients.view","clients.create","clients.edit","clients.delete"]'),
('viewer',  'Viewer',        'Can only view own clients',        '["clients.view_own","clients.download_own"]')
ON CONFLICT (name) DO NOTHING;

-- Insert default LDAP group mappings (examples)
INSERT INTO ldap_group_mappings (ldap_group, role_name, description) VALUES
('vpn-admins',   'admin',   'VPN administrators with full access'),
('vpn-managers', 'manager', 'VPN managers who can create and manage clients'),
('vpn-users',    'viewer',  'Regular VPN users with view-only access')
ON CONFLICT (ldap_group) DO NOTHING;

-- Update existing users to admin role (backward compatibility)
UPDATE users SET role = 'admin' WHERE role IS NULL OR role = '';
