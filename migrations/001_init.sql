-- Amnezia VPN Panel - Complete Database Schema (PostgreSQL)
-- Migrated from MySQL. Tables created IF NOT EXISTS to be idempotent.

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) DEFAULT 'user',
  preferred_language VARCHAR(10) DEFAULT 'en',
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP NULL
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_language ON users (preferred_language);

-- VPN Servers table
CREATE TABLE IF NOT EXISTS vpn_servers (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  host VARCHAR(255) NOT NULL,
  port INT NOT NULL,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  container_name VARCHAR(255) DEFAULT 'amnezia-awg',
  vpn_port INT NULL,
  vpn_subnet VARCHAR(50) DEFAULT '10.8.1.0/24',
  server_public_key TEXT NULL,
  preshared_key TEXT NULL,
  awg_params JSON NULL,
  status VARCHAR(50) DEFAULT 'deploying',
  deployed_at TIMESTAMP NULL,
  last_check_at TIMESTAMP NULL,
  error_message TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_servers_user_id ON vpn_servers (user_id);
CREATE INDEX IF NOT EXISTS idx_servers_status ON vpn_servers (status);

-- VPN Clients table
CREATE TABLE IF NOT EXISTS vpn_clients (
  id SERIAL PRIMARY KEY,
  server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  client_ip VARCHAR(50) NOT NULL,
  public_key TEXT NOT NULL,
  private_key TEXT NOT NULL,
  preshared_key TEXT NULL,
  config TEXT NULL,
  qr_code TEXT NULL,
  bytes_sent BIGINT DEFAULT 0,
  bytes_received BIGINT DEFAULT 0,
  last_handshake TIMESTAMP NULL,
  last_sync_at TIMESTAMP NULL,
  status VARCHAR(50) DEFAULT 'active',
  expires_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (server_id, client_ip)
);
CREATE INDEX IF NOT EXISTS idx_clients_server_id ON vpn_clients (server_id);
CREATE INDEX IF NOT EXISTS idx_clients_user_id ON vpn_clients (user_id);
CREATE INDEX IF NOT EXISTS idx_clients_status ON vpn_clients (status);
CREATE INDEX IF NOT EXISTS idx_clients_expires_at ON vpn_clients (expires_at);
CREATE INDEX IF NOT EXISTS idx_clients_last_handshake ON vpn_clients (last_handshake);

-- API Tokens table
CREATE TABLE IF NOT EXISTS api_tokens (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  last_used_at TIMESTAMP NULL,
  expires_at TIMESTAMP NULL,
  revoked_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_api_tokens_token ON api_tokens (token);
CREATE INDEX IF NOT EXISTS idx_api_tokens_user_id ON api_tokens (user_id);

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
  id SERIAL PRIMARY KEY,
  user_id INT NULL REFERENCES users(id) ON DELETE CASCADE,
  namespace VARCHAR(100) NOT NULL,
  "key" VARCHAR(100) NOT NULL,
  value JSON NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS unique_setting_global ON settings (namespace, "key") WHERE user_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unique_setting_user ON settings (user_id, namespace, "key") WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_settings_namespace ON settings (namespace);

-- Languages table
CREATE TABLE IF NOT EXISTS languages (
  id SERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  native_name VARCHAR(50) NOT NULL,
  is_active SMALLINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_languages_code ON languages (code);

-- Translations table
CREATE TABLE IF NOT EXISTS translations (
  id SERIAL PRIMARY KEY,
  locale VARCHAR(10) NOT NULL,
  category VARCHAR(50) NOT NULL,
  key_name VARCHAR(100) NOT NULL,
  translation TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (locale, category, key_name)
);
CREATE INDEX IF NOT EXISTS idx_translations_locale ON translations (locale);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
  id SERIAL PRIMARY KEY,
  service_name VARCHAR(50) NOT NULL UNIQUE,
  api_key TEXT NOT NULL,
  is_active SMALLINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Server Backups table
CREATE TABLE IF NOT EXISTS server_backups (
  id SERIAL PRIMARY KEY,
  server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
  backup_name VARCHAR(255) NOT NULL,
  backup_path VARCHAR(500) NOT NULL,
  backup_size BIGINT DEFAULT 0,
  clients_count INT DEFAULT 0,
  backup_type VARCHAR(50) DEFAULT 'manual',
  status VARCHAR(50) DEFAULT 'creating',
  error_message TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by INT NULL REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_server_backups_server_id ON server_backups (server_id);
CREATE INDEX IF NOT EXISTS idx_server_backups_status ON server_backups (status);
CREATE INDEX IF NOT EXISTS idx_server_backups_created_at ON server_backups (created_at);

-- Insert default admin user
INSERT INTO users (email, password_hash, name, role, status)
VALUES ('admin@amnez.ia', '$2y$10$SKEI6ogiWr2gsSG/nELLp.JcfpGhxsDLAAI7gdtTOI3ELz4zJzzPG', 'Administrator', 'admin', 'active')
ON CONFLICT (email) DO NOTHING;

-- Insert supported languages
INSERT INTO languages (code, name, native_name) VALUES
('en', 'English', 'English'),
('ru', 'Russian', 'Русский'),
('es', 'Spanish', 'Español'),
('de', 'German', 'Deutsch'),
('fr', 'French', 'Français'),
('zh', 'Chinese', '中文')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, native_name = EXCLUDED.native_name;

-- Insert English translations
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'auth', 'email', 'Email'),
('en', 'auth', 'login', 'Login'),
('en', 'auth', 'name', 'Name'),
('en', 'auth', 'password', 'Password'),
('en', 'auth', 'register', 'Register'),
('en', 'clients', 'actions', 'Actions'),
('en', 'clients', 'add', 'Add Client'),
('en', 'clients', 'create', 'Create Client'),
('en', 'clients', 'delete', 'Delete'),
('en', 'clients', 'delete_confirm', 'Delete this client permanently?'),
('en', 'clients', 'download_config', 'Download Config'),
('en', 'clients', 'expiration', 'Expiration'),
('en', 'clients', 'expired', 'Expired'),
('en', 'clients', 'never', 'Never'),
('en', 'clients', 'never_expires', 'Never expires'),
('en', 'clients', 'no_clients', 'No clients yet'),
('en', 'clients', 'ip', 'IP Address'),
('en', 'clients', 'last_handshake', 'Last Handshake'),
('en', 'clients', 'name', 'Client Name'),
('en', 'clients', 'qr_code', 'QR Code'),
('en', 'clients', 'received', 'Received'),
('en', 'clients', 'restore', 'Restore'),
('en', 'clients', 'revoke', 'Revoke'),
('en', 'clients', 'revoke_confirm', 'Revoke access for this client?'),
('en', 'clients', 'sent', 'Sent'),
('en', 'clients', 'server', 'Server'),
('en', 'clients', 'status', 'Status'),
('en', 'clients', 'sync_stats', 'Sync Stats'),
('en', 'clients', 'title', 'Clients'),
('en', 'clients', 'traffic', 'Traffic'),
('en', 'clients', 'traffic_limit', 'Traffic Limit'),
('en', 'clients', 'unlimited', 'Unlimited'),
('en', 'clients', 'overlimit', 'Over Limit'),
('en', 'clients', 'custom_seconds', 'Custom (seconds)'),
('en', 'clients', 'custom_mb', 'Custom (MB)'),
('en', 'clients', 'enter_seconds', 'Enter seconds'),
('en', 'clients', 'enter_megabytes', 'Enter megabytes'),
('en', 'backups', 'title', 'Server Backups'),
('en', 'backups', 'create', 'Create Backup'),
('en', 'backups', 'restore', 'Restore'),
('en', 'backups', 'no_backups', 'No backups yet'),
('en', 'backups', 'create_confirm', 'Create backup of all clients on this server?'),
('en', 'backups', 'restore_confirm', 'Restore clients from this backup? Existing clients will not be affected.'),
('en', 'backups', 'delete_confirm', 'Delete this backup permanently?'),
('en', 'backups', 'created_success', 'Backup created successfully'),
('en', 'backups', 'restored_success', 'Restored'),
('en', 'backups', 'deleted_success', 'Backup deleted successfully'),
('en', 'backups', 'login_required', 'Please login via API to manage backups'),
('en', 'common', 'days', 'days'),
('en', 'dashboard', 'active_clients', 'Active Clients'),
('en', 'dashboard', 'add_first_server', 'Add First Server'),
('en', 'dashboard', 'get_started', 'Get started by adding your first VPN server'),
('en', 'dashboard', 'no_servers', 'No servers yet'),
('en', 'dashboard', 'quick_actions', 'Quick Actions'),
('en', 'dashboard', 'recent_servers', 'Recent Servers'),
('en', 'dashboard', 'title', 'Dashboard'),
('en', 'dashboard', 'total_clients', 'Total Clients'),
('en', 'dashboard', 'total_servers', 'Total Servers'),
('en', 'dashboard', 'total_traffic', 'Total Traffic'),
('en', 'dashboard', 'welcome', 'Welcome to Amnezia VPN Management Panel'),
('en', 'form', 'cancel', 'Cancel'),
('en', 'form', 'close', 'Close'),
('en', 'form', 'create', 'Create'),
('en', 'form', 'loading', 'Loading...'),
('en', 'form', 'processing', 'Processing...'),
('en', 'form', 'save', 'Save'),
('en', 'form', 'submit', 'Submit'),
('en', 'form', 'update', 'Update'),
('en', 'menu', 'clients', 'Clients'),
('en', 'menu', 'dashboard', 'Dashboard'),
('en', 'menu', 'logout', 'Logout'),
('en', 'menu', 'servers', 'Servers'),
('en', 'menu', 'settings', 'Settings'),
('en', 'menu', 'users', 'Users'),
('en', 'message', 'confirm', 'Are you sure?'),
('en', 'message', 'deleted', 'Deleted successfully'),
('en', 'message', 'deployed', 'Deployed successfully'),
('en', 'message', 'error', 'An error occurred'),
('en', 'message', 'saved', 'Saved successfully'),
('en', 'message', 'success', 'Operation completed successfully'),
('en', 'servers', 'actions', 'Actions'),
('en', 'servers', 'add', 'Add Server'),
('en', 'servers', 'clients', 'Clients'),
('en', 'servers', 'delete', 'Delete'),
('en', 'servers', 'deploy', 'Deploy'),
('en', 'servers', 'edit', 'Edit'),
('en', 'servers', 'host', 'Host'),
('en', 'servers', 'name', 'Name'),
('en', 'servers', 'port', 'Port'),
('en', 'servers', 'status', 'Status'),
('en', 'servers', 'title', 'Servers'),
('en', 'servers', 'view', 'View'),
('en', 'settings', 'actions', 'Actions'),
('en', 'settings', 'api_keys', 'API Keys'),
('en', 'settings', 'api_keys_desc', 'Configure API keys for external services'),
('en', 'settings', 'auto_translate', 'Auto-translate'),
('en', 'settings', 'change_password', 'Change Password'),
('en', 'settings', 'confirm_password', 'Confirm Password'),
('en', 'settings', 'confirm_translate', 'Start automatic translation? This may take a few minutes.'),
('en', 'settings', 'current_password', 'Current Password'),
('en', 'settings', 'description', 'Manage panel configuration and API integrations'),
('en', 'settings', 'error_empty_key', 'API key cannot be empty'),
('en', 'settings', 'error_invalid_key', 'Invalid API key format'),
('en', 'settings', 'error_key_test', 'API key test failed'),
('en', 'settings', 'for_translation', 'for auto-translation'),
('en', 'settings', 'get_key_at', 'Get your API key at'),
('en', 'settings', 'key_saved', 'API key saved successfully'),
('en', 'settings', 'keys', 'keys'),
('en', 'settings', 'language', 'Language'),
('en', 'settings', 'min_6_chars', 'Minimum 6 characters'),
('en', 'settings', 'new_password', 'New Password'),
('en', 'settings', 'profile', 'Profile'),
('en', 'settings', 'progress', 'Progress'),
('en', 'settings', 'translations', 'Translations'),
('en', 'settings', 'translation_complete', 'Translation completed'),
('en', 'settings', 'translation_status', 'Translation Status'),
('en', 'settings', 'users', 'Users'),
('en', 'status', 'active', 'Active'),
('en', 'status', 'deploying', 'Deploying'),
('en', 'status', 'disabled', 'Disabled'),
('en', 'status', 'error', 'Error'),
('en', 'status', 'inactive', 'Inactive'),
('en', 'users', 'add_user', 'Add User'),
('en', 'users', 'all_users', 'All Users'),
('en', 'users', 'administrator', 'Administrator'),
('en', 'users', 'created', 'Created'),
('en', 'users', 'delete_confirm', 'Delete {0}?'),
('en', 'users', 'role', 'Role'),
('en', 'users', 'role_admin', 'Admin'),
('en', 'users', 'role_user', 'User'),
('en', 'settings', 'api_key_configured', 'API Key Configured'),
('en', 'settings', 'no_api_key', 'No API key configured. Auto-translation will not work.'),
('en', 'settings', 'skip_validation', 'Skip validation (save without testing)'),
('en', 'servers', 'import_from_panel', 'Import from existing panel'),
('en', 'servers', 'select_panel_type', 'Select panel type'),
('en', 'servers', 'panel_type_wgeasy', 'wg-easy'),
('en', 'servers', 'panel_type_3xui', '3x-ui'),
('en', 'servers', 'upload_backup_file', 'Upload backup file (JSON)'),
('en', 'servers', 'import_in_progress', 'Import in progress...'),
('en', 'servers', 'import_success', 'Successfully imported {0} clients'),
('en', 'servers', 'import_failed', 'Import failed'),
('en', 'servers', 'import_partial', 'Imported {0} of {1} clients'),
('en', 'servers', 'import_history', 'Import History')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;
