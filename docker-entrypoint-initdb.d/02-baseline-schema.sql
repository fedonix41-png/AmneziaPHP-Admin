-- Amnezia VPN Panel - Consolidated PostgreSQL Database Schema
-- Created dynamically from legacy migrations

-- Create implicit casts from integer/smallint to boolean for MySQL compatibility
CREATE OR REPLACE FUNCTION integer_to_boolean(i integer)
RETURNS boolean AS $$
    SELECT i <> 0;
$$ LANGUAGE sql IMMUTABLE STRICT;

DROP CAST IF EXISTS (integer AS boolean);
CREATE CAST (integer AS boolean) WITH FUNCTION integer_to_boolean(integer) AS IMPLICIT;

CREATE OR REPLACE FUNCTION smallint_to_boolean(s smallint)
RETURNS boolean AS $$
    SELECT s <> 0;
$$ LANGUAGE sql IMMUTABLE STRICT;

DROP CAST IF EXISTS (smallint AS boolean);
CREATE CAST (smallint AS boolean) WITH FUNCTION smallint_to_boolean(smallint) AS IMPLICIT;

-- Disable foreign key checks is not directly supported in Postgres, but we create tables in order.

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NULL,
  role VARCHAR(50) DEFAULT 'user',
  preferred_language VARCHAR(10) DEFAULT 'en',
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP NULL,
  ldap_synced SMALLINT DEFAULT 0,
  ldap_dn VARCHAR(255) NULL
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_language ON users (preferred_language);
CREATE INDEX IF NOT EXISTS idx_users_ldap_dn ON users (ldap_dn);

CREATE TABLE IF NOT EXISTS vpn_servers (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  host VARCHAR(255) NOT NULL,
  port INT NOT NULL,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  container_name VARCHAR(255) DEFAULT 'amnezia-awg',
  install_protocol VARCHAR(100) NULL,
  install_options JSON NULL,
  vpn_port INT NULL,
  vpn_subnet VARCHAR(50) DEFAULT '10.8.1.0/24',
  server_public_key TEXT NULL,
  preshared_key TEXT NULL,
  awg_params JSON NULL,
  status VARCHAR(50) DEFAULT 'deploying',
  deployed_at TIMESTAMP NULL,
  last_check_at TIMESTAMP NULL,
  error_message TEXT NULL,
  ssh_key TEXT NULL,
  dns_servers VARCHAR(255) DEFAULT '1.1.1.1, 1.0.0.1',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_servers_user_id ON vpn_servers (user_id);
CREATE INDEX IF NOT EXISTS idx_servers_status ON vpn_servers (status);

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

CREATE TABLE IF NOT EXISTS vpn_clients (
  id SERIAL PRIMARY KEY,
  server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  protocol_id INT NULL REFERENCES protocols(id) ON DELETE SET NULL,
  name VARCHAR(255) NOT NULL,
  client_ip VARCHAR(50) NOT NULL,
  public_key TEXT NOT NULL,
  private_key TEXT NOT NULL,
  preshared_key TEXT NULL,
  config TEXT NULL,
  qr_code TEXT NULL,
  bytes_sent BIGINT DEFAULT 0,
  bytes_received BIGINT DEFAULT 0,
  aivpn_raw_bytes_in BIGINT DEFAULT 0,
  aivpn_raw_bytes_out BIGINT DEFAULT 0,
  aivpn_offset_bytes_in BIGINT DEFAULT 0,
  aivpn_offset_bytes_out BIGINT DEFAULT 0,
  last_handshake TIMESTAMP NULL,
  last_sync_at TIMESTAMP NULL,
  status VARCHAR(50) DEFAULT 'active',
  expires_at TIMESTAMP NULL,
  traffic_limit BIGINT DEFAULT NULL,
  current_speed BIGINT DEFAULT 0,
  speed_up BIGINT DEFAULT 0,
  speed_down BIGINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (server_id, client_ip)
);
CREATE INDEX IF NOT EXISTS idx_clients_server_id ON vpn_clients (server_id);
CREATE INDEX IF NOT EXISTS idx_clients_user_id ON vpn_clients (user_id);
CREATE INDEX IF NOT EXISTS idx_clients_protocol_id ON vpn_clients (protocol_id);
CREATE INDEX IF NOT EXISTS idx_clients_status ON vpn_clients (status);
CREATE INDEX IF NOT EXISTS idx_clients_expires_at ON vpn_clients (expires_at);

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

CREATE TABLE IF NOT EXISTS languages (
  id SERIAL PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  name VARCHAR(50) NOT NULL,
  native_name VARCHAR(50) NOT NULL,
  is_active SMALLINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_languages_code ON languages (code);

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

CREATE TABLE IF NOT EXISTS api_keys (
  id SERIAL PRIMARY KEY,
  service_name VARCHAR(50) NOT NULL UNIQUE,
  api_key TEXT NOT NULL,
  is_active SMALLINT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TABLE IF NOT EXISTS panel_imports (
  id SERIAL PRIMARY KEY,
  server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
  panel_type VARCHAR(50) NOT NULL,
  import_file_name VARCHAR(255) NOT NULL,
  clients_imported INT DEFAULT 0,
  import_data JSON NULL,
  status VARCHAR(50) DEFAULT 'pending',
  error_message TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by INT NULL REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS server_metrics (
  id BIGSERIAL PRIMARY KEY,
  server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
  cpu_percent DECIMAL(5,2) NULL,
  ram_used_mb INT NULL,
  ram_total_mb INT NULL,
  disk_used_gb DECIMAL(10,2) NULL,
  disk_total_gb DECIMAL(10,2) NULL,
  network_rx_mbps DECIMAL(10,2) NULL,
  network_tx_mbps DECIMAL(10,2) NULL,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_server_metrics_server_time ON server_metrics (server_id, collected_at);

CREATE TABLE IF NOT EXISTS client_metrics (
  id BIGSERIAL PRIMARY KEY,
  client_id INT NOT NULL REFERENCES vpn_clients(id) ON DELETE CASCADE,
  bytes_sent BIGINT DEFAULT 0,
  bytes_received BIGINT DEFAULT 0,
  speed_up_kbps DECIMAL(10,2) NULL,
  speed_down_kbps DECIMAL(10,2) NULL,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_client_metrics_client_time ON client_metrics (client_id, collected_at);

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

CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    permissions JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS protocol_templates (
    id SERIAL PRIMARY KEY,
    protocol_id INT NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    template_content TEXT NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TABLE IF NOT EXISTS server_protocols (
    id SERIAL PRIMARY KEY,
    server_id INT NOT NULL REFERENCES vpn_servers(id) ON DELETE CASCADE,
    protocol_id INT NOT NULL REFERENCES protocols(id) ON DELETE CASCADE,
    config_data JSON,
    applied_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (server_id, protocol_id)
);

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

CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64)
);


-- Seeding baseline data and translations

INSERT INTO schema_migrations (filename, checksum) VALUES ('000_create_user.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('001_init.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Insert default admin user
INSERT INTO users (email, password_hash, name, role, status) 
VALUES ('admin@amnez.ia', '$2y$10$SKEI6ogiWr2gsSG/nELLp.JcfpGhxsDLAAI7gdtTOI3ELz4zJzzPG', 'Administrator', 'admin', 'active');

-- Insert supported languages
INSERT INTO languages (code, name, native_name) VALUES
('en', 'English', 'English'),
('ru', 'Russian', 'Русский'),
('es', 'Spanish', 'Español'),
('de', 'German', 'Deutsch'),
('fr', 'French', 'Français'),
('zh', 'Chinese', '中文')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, native_name = EXCLUDED.native_name;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('en', 'auth', 'email', 'Email'), ('en', 'auth', 'login', 'Login'), ('en', 'auth', 'name', 'Name'), ('en', 'auth', 'password', 'Password'), ('en', 'auth', 'register', 'Register'), ('en', 'clients', 'actions', 'Actions'), ('en', 'clients', 'add', 'Add Client'), ('en', 'clients', 'create', 'Create Client'), ('en', 'clients', 'delete', 'Delete'), ('en', 'clients', 'delete_confirm', 'Delete this client permanently?'), ('en', 'clients', 'download_config', 'Download Config'), ('en', 'clients', 'expiration', 'Expiration'), ('en', 'clients', 'expired', 'Expired'), ('en', 'clients', 'never', 'Never'), ('en', 'clients', 'never_expires', 'Never expires'), ('en', 'clients', 'no_clients', 'No clients yet'), ('en', 'clients', 'ip', 'IP Address'), ('en', 'clients', 'last_handshake', 'Last Handshake'), ('en', 'clients', 'name', 'Client Name'), ('en', 'clients', 'qr_code', 'QR Code'), ('en', 'clients', 'received', 'Received'), ('en', 'clients', 'restore', 'Restore'), ('en', 'clients', 'revoke', 'Revoke'), ('en', 'clients', 'revoke_confirm', 'Revoke access for this client?'), ('en', 'clients', 'sent', 'Sent'), ('en', 'clients', 'server', 'Server'), ('en', 'clients', 'status', 'Status'), ('en', 'clients', 'sync_stats', 'Sync Stats'), ('en', 'clients', 'title', 'Clients'), ('en', 'clients', 'traffic', 'Traffic'), ('en', 'clients', 'traffic_limit', 'Traffic Limit'), ('en', 'clients', 'unlimited', 'Unlimited'), ('en', 'clients', 'overlimit', 'Over Limit'), ('en', 'clients', 'custom_seconds', 'Custom (seconds)'), ('en', 'clients', 'custom_mb', 'Custom (MB)'), ('en', 'clients', 'enter_seconds', 'Enter seconds'), ('en', 'clients', 'enter_megabytes', 'Enter megabytes'), ('en', 'backups', 'title', 'Server Backups'), ('en', 'backups', 'create', 'Create Backup'), ('en', 'backups', 'restore', 'Restore'), ('en', 'backups', 'no_backups', 'No backups yet'), ('en', 'backups', 'create_confirm', 'Create backup of all clients on this server?'), ('en', 'backups', 'restore_confirm', 'Restore clients from this backup? Existing clients will not be affected.'), ('en', 'backups', 'delete_confirm', 'Delete this backup permanently?'), ('en', 'backups', 'created_success', 'Backup created successfully'), ('en', 'backups', 'restored_success', 'Restored'), ('en', 'backups', 'deleted_success', 'Backup deleted successfully'), ('en', 'backups', 'login_required', 'Please login via API to manage backups'), ('en', 'common', 'days', 'days'), ('en', 'dashboard', 'active_clients', 'Active Clients'), ('en', 'dashboard', 'add_first_server', 'Add First Server'), ('en', 'dashboard', 'get_started', 'Get started by adding your first VPN server'), ('en', 'dashboard', 'no_servers', 'No servers yet'), ('en', 'dashboard', 'quick_actions', 'Quick Actions'), ('en', 'dashboard', 'recent_servers', 'Recent Servers'), ('en', 'dashboard', 'title', 'Dashboard'), ('en', 'dashboard', 'total_clients', 'Total Clients'), ('en', 'dashboard', 'total_servers', 'Total Servers'), ('en', 'dashboard', 'total_traffic', 'Total Traffic'), ('en', 'dashboard', 'welcome', 'Welcome to Amnezia VPN Management Panel'), ('en', 'form', 'cancel', 'Cancel'), ('en', 'form', 'close', 'Close'), ('en', 'form', 'create', 'Create'), ('en', 'form', 'loading', 'Loading...'), ('en', 'form', 'processing', 'Processing...'), ('en', 'form', 'save', 'Save'), ('en', 'form', 'submit', 'Submit'), ('en', 'form', 'update', 'Update'), ('en', 'menu', 'clients', 'Clients'), ('en', 'menu', 'dashboard', 'Dashboard'), ('en', 'menu', 'logout', 'Logout'), ('en', 'menu', 'servers', 'Servers'), ('en', 'menu', 'settings', 'Settings'), ('en', 'menu', 'users', 'Users'), ('en', 'message', 'confirm', 'Are you sure?'), ('en', 'message', 'deleted', 'Deleted successfully'), ('en', 'message', 'deployed', 'Deployed successfully'), ('en', 'message', 'error', 'An error occurred'), ('en', 'message', 'saved', 'Saved successfully'), ('en', 'message', 'success', 'Operation completed successfully'), ('en', 'servers', 'actions', 'Actions'), ('en', 'servers', 'add', 'Add Server'), ('en', 'servers', 'clients', 'Clients'), ('en', 'servers', 'delete', 'Delete'), ('en', 'servers', 'deploy', 'Deploy'), ('en', 'servers', 'edit', 'Edit'), ('en', 'servers', 'host', 'Host'), ('en', 'servers', 'name', 'Name'), ('en', 'servers', 'port', 'Port'), ('en', 'servers', 'status', 'Status'), ('en', 'servers', 'title', 'Servers'), ('en', 'servers', 'view', 'View'), ('en', 'settings', 'actions', 'Actions'), ('en', 'settings', 'api_keys', 'API Keys'), ('en', 'settings', 'api_keys_desc', 'Configure API keys for external services'), ('en', 'settings', 'auto_translate', 'Auto-translate'), ('en', 'settings', 'change_password', 'Change Password'), ('en', 'settings', 'confirm_password', 'Confirm Password'), ('en', 'settings', 'confirm_translate', 'Start automatic translation? This may take a few minutes.'), ('en', 'settings', 'current_password', 'Current Password'), ('en', 'settings', 'description', 'Manage panel configuration and API integrations'), ('en', 'settings', 'error_empty_key', 'API key cannot be empty'), ('en', 'settings', 'error_invalid_key', 'Invalid API key format'), ('en', 'settings', 'error_key_test', 'API key test failed'), ('en', 'settings', 'for_translation', 'for auto-translation'), ('en', 'settings', 'get_key_at', 'Get your API key at'), ('en', 'settings', 'key_saved', 'API key saved successfully'), ('en', 'settings', 'keys', 'keys'), ('en', 'settings', 'language', 'Language'), ('en', 'settings', 'min_6_chars', 'Minimum 6 characters'), ('en', 'settings', 'new_password', 'New Password'), ('en', 'settings', 'profile', 'Profile'), ('en', 'settings', 'progress', 'Progress'), ('en', 'settings', 'translations', 'Translations'), ('en', 'settings', 'translation_complete', 'Translation completed'), ('en', 'settings', 'translation_status', 'Translation Status'), ('en', 'settings', 'users', 'Users'), ('en', 'status', 'active', 'Active'), ('en', 'status', 'deploying', 'Deploying'), ('en', 'status', 'disabled', 'Disabled'), ('en', 'status', 'error', 'Error'), ('en', 'status', 'inactive', 'Inactive'), ('en', 'users', 'add_user', 'Add User'), ('en', 'users', 'all_users', 'All Users'), ('en', 'users', 'administrator', 'Administrator'), ('en', 'users', 'created', 'Created'), ('en', 'users', 'delete_confirm', 'Delete {0}?'), ('en', 'users', 'role', 'Role'), ('en', 'users', 'role_admin', 'Admin'), ('en', 'users', 'role_user', 'User'), ('en', 'settings', 'api_key_configured', 'API Key Configured'), ('en', 'settings', 'no_api_key', 'No API key configured. Auto-translation will not work.'), ('en', 'settings', 'skip_validation', 'Skip validation (save without testing)'), ('en', 'servers', 'import_from_panel', 'Import from existing panel'), ('en', 'servers', 'select_panel_type', 'Select panel type'), ('en', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('en', 'servers', 'panel_type_3xui', '3x-ui'), ('en', 'servers', 'upload_backup_file', 'Upload backup file (JSON)'), ('en', 'servers', 'import_in_progress', 'Import in progress...'), ('en', 'servers', 'import_success', 'Successfully imported {0} clients'), ('en', 'servers', 'import_failed', 'Import failed'), ('en', 'servers', 'import_partial', 'Imported {0} of {1} clients'), ('en', 'servers', 'import_history', 'Import History') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('002_translations_ru.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('ru', 'auth', 'email', 'Email'), ('ru', 'auth', 'login', 'Вход'), ('ru', 'auth', 'name', 'Имя'), ('ru', 'auth', 'password', 'Пароль'), ('ru', 'auth', 'register', 'Регистрация'), ('ru', 'backups', 'create', 'Создать резервную копию'), ('ru', 'backups', 'create_confirm', 'Создать резервную копию всех клиентов на этом сервере?'), ('ru', 'backups', 'created_success', 'Резервная копия успешно создана'), ('ru', 'backups', 'delete_confirm', 'Удалить эту резервную копию навсегда?'), ('ru', 'backups', 'deleted_success', 'Резервная копия успешно удалена'), ('ru', 'backups', 'login_required', 'Пожалуйста, войдите через API для управления резервными копиями'), ('ru', 'backups', 'no_backups', 'Пока нет резервных копий'), ('ru', 'backups', 'restore', 'Восстановить'), ('ru', 'backups', 'restore_confirm', 'Восстановить клиентов из этой резервной копии? Существующие клиенты не будут затронуты.'), ('ru', 'backups', 'restored_success', 'Восстановлено'), ('ru', 'backups', 'title', 'Резервные копии сервера'), ('ru', 'clients', 'actions', 'Действия'), ('ru', 'clients', 'add', 'Добавить клиента'), ('ru', 'clients', 'create', 'Создать клиента'), ('ru', 'clients', 'delete', 'Удалить'), ('ru', 'clients', 'delete_confirm', 'Удалить этого клиента навсегда?'), ('ru', 'clients', 'download_config', 'Скачать конфигурацию'), ('ru', 'clients', 'expiration', 'Срок действия'), ('ru', 'clients', 'expired', 'Истек'), ('ru', 'clients', 'ip', 'IP-адрес'), ('ru', 'clients', 'last_handshake', 'Последнее соединение'), ('ru', 'clients', 'name', 'Имя клиента'), ('ru', 'clients', 'never', 'Никогда'), ('ru', 'clients', 'never_expires', 'Бессрочно'), ('ru', 'clients', 'no_clients', 'Пока нет клиентов'), ('ru', 'clients', 'overlimit', 'Превышен лимит'), ('ru', 'clients', 'qr_code', 'QR-код'), ('ru', 'clients', 'received', 'Получено'), ('ru', 'clients', 'restore', 'Восстановить'), ('ru', 'clients', 'revoke', 'Отозвать'), ('ru', 'clients', 'revoke_confirm', 'Отозвать доступ для этого клиента?'), ('ru', 'clients', 'sent', 'Отправлено'), ('ru', 'clients', 'server', 'Сервер'), ('ru', 'clients', 'status', 'Статус'), ('ru', 'clients', 'sync_stats', 'Синхронизировать статистику'), ('ru', 'clients', 'title', 'Клиенты'), ('ru', 'clients', 'traffic', 'Трафик'), ('ru', 'clients', 'traffic_limit', 'Лимит трафика'), ('ru', 'clients', 'unlimited', 'Безлимитно'), ('ru', 'clients', 'custom_seconds', 'Своё значение (секунды)'), ('ru', 'clients', 'custom_mb', 'Своё значение (МБ)'), ('ru', 'clients', 'enter_seconds', 'Введите секунды'), ('ru', 'clients', 'enter_megabytes', 'Введите мегабайты'), ('ru', 'common', 'days', 'дней'), ('ru', 'dashboard', 'active_clients', 'Активные клиенты'), ('ru', 'dashboard', 'add_first_server', 'Добавить первый сервер'), ('ru', 'dashboard', 'get_started', 'Начните с добавления вашего первого VPN-сервера'), ('ru', 'dashboard', 'no_servers', 'Пока нет серверов'), ('ru', 'dashboard', 'quick_actions', 'Быстрые действия'), ('ru', 'dashboard', 'recent_servers', 'Недавние серверы'), ('ru', 'dashboard', 'title', 'Панель управления'), ('ru', 'dashboard', 'total_clients', 'Всего клиентов'), ('ru', 'dashboard', 'total_servers', 'Всего серверов'), ('ru', 'dashboard', 'total_traffic', 'Общий трафик'), ('ru', 'dashboard', 'welcome', 'Добро пожаловать в панель управления Amnezia VPN'), ('ru', 'form', 'cancel', 'Отмена'), ('ru', 'form', 'close', 'Закрыть'), ('ru', 'form', 'create', 'Создать'), ('ru', 'form', 'loading', 'Загрузка...'), ('ru', 'form', 'processing', 'Обработка...'), ('ru', 'form', 'save', 'Сохранить'), ('ru', 'form', 'submit', 'Отправить'), ('ru', 'form', 'update', 'Обновить'), ('ru', 'menu', 'clients', 'Клиенты'), ('ru', 'menu', 'dashboard', 'Панель управления'), ('ru', 'menu', 'logout', 'Выход'), ('ru', 'menu', 'servers', 'Серверы'), ('ru', 'menu', 'settings', 'Настройки'), ('ru', 'menu', 'users', 'Пользователи'), ('ru', 'message', 'confirm', 'Вы уверены?'), ('ru', 'message', 'deleted', 'Успешно удалено'), ('ru', 'message', 'deployed', 'Успешно развернуто'), ('ru', 'message', 'error', 'Произошла ошибка'), ('ru', 'message', 'saved', 'Успешно сохранено'), ('ru', 'message', 'success', 'Операция успешно завершена'), ('ru', 'servers', 'actions', 'Действия'), ('ru', 'servers', 'add', 'Добавить сервер'), ('ru', 'servers', 'clients', 'Клиенты'), ('ru', 'servers', 'delete', 'Удалить'), ('ru', 'servers', 'deploy', 'Развернуть'), ('ru', 'servers', 'edit', 'Редактировать'), ('ru', 'servers', 'host', 'Хост'), ('ru', 'servers', 'name', 'Имя'), ('ru', 'servers', 'port', 'Порт'), ('ru', 'servers', 'status', 'Статус'), ('ru', 'servers', 'title', 'Серверы'), ('ru', 'servers', 'view', 'Просмотр'), ('ru', 'settings', 'actions', 'Действия'), ('ru', 'settings', 'api_key_configured', 'API-ключ настроен'), ('ru', 'settings', 'api_keys', 'API-ключи'), ('ru', 'settings', 'api_keys_desc', 'Настройка API-ключей для внешних сервисов'), ('ru', 'settings', 'auto_translate', 'Автоперевод'), ('ru', 'settings', 'change_password', 'Изменить пароль'), ('ru', 'settings', 'confirm_password', 'Подтвердите пароль'), ('ru', 'settings', 'confirm_translate', 'Начать автоматический перевод? Это может занять несколько минут.'), ('ru', 'settings', 'current_password', 'Текущий пароль'), ('ru', 'settings', 'description', 'Управление конфигурацией панели и интеграциями API'), ('ru', 'settings', 'error_empty_key', 'API-ключ не может быть пустым'), ('ru', 'settings', 'error_invalid_key', 'Неверный формат API-ключа'), ('ru', 'settings', 'error_key_test', 'Тест API-ключа не удался'), ('ru', 'settings', 'for_translation', 'для автоперевода'), ('ru', 'settings', 'get_key_at', 'Получите ваш API-ключ на'), ('ru', 'settings', 'key_saved', 'API-ключ успешно сохранен'), ('ru', 'settings', 'keys', 'ключи'), ('ru', 'settings', 'language', 'Язык'), ('ru', 'settings', 'min_6_chars', 'Минимум 6 символов'), ('ru', 'settings', 'new_password', 'Новый пароль'), ('ru', 'settings', 'no_api_key', 'API-ключ не настроен. Автоперевод не будет работать.'), ('ru', 'settings', 'profile', 'Профиль'), ('ru', 'settings', 'progress', 'Прогресс'), ('ru', 'settings', 'skip_validation', 'Пропустить проверку (сохранить без тестирования)'), ('ru', 'settings', 'translation_complete', 'Перевод завершен'), ('ru', 'settings', 'translation_status', 'Статус перевода'), ('ru', 'settings', 'translations', 'Переводы'), ('ru', 'settings', 'users', 'Пользователи'), ('ru', 'status', 'active', 'Активен'), ('ru', 'status', 'deploying', 'Развертывание'), ('ru', 'status', 'disabled', 'Отключен'), ('ru', 'status', 'error', 'Ошибка'), ('ru', 'status', 'inactive', 'Неактивен'), ('ru', 'users', 'add_user', 'Добавить пользователя'), ('ru', 'users', 'administrator', 'Администратор'), ('ru', 'users', 'all_users', 'Все пользователи'), ('ru', 'users', 'created', 'Создан'), ('ru', 'users', 'delete_confirm', 'Удалить {0}?'), ('ru', 'users', 'role', 'Роль'), ('ru', 'users', 'role_admin', 'Администратор'), ('ru', 'users', 'role_user', 'Пользователь'), ('ru', 'servers', 'import_from_panel', 'Импорт из другой панели'), ('ru', 'servers', 'select_panel_type', 'Выберите тип панели'), ('ru', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('ru', 'servers', 'panel_type_3xui', '3x-ui'), ('ru', 'servers', 'upload_backup_file', 'Загрузите файл резервной копии (JSON)'), ('ru', 'servers', 'import_in_progress', 'Импорт выполняется...'), ('ru', 'servers', 'import_success', 'Успешно импортировано клиентов: {0}'), ('ru', 'servers', 'import_failed', 'Ошибка импорта'), ('ru', 'servers', 'import_partial', 'Импортировано {0} из {1} клиентов'), ('ru', 'servers', 'import_history', 'История импорта') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('003_translations_es.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('es', 'auth', 'email', 'Correo electrónico'), ('es', 'auth', 'login', 'Iniciar sesión'), ('es', 'auth', 'name', 'Nombre'), ('es', 'auth', 'password', 'Contraseña'), ('es', 'auth', 'register', 'Registrarse'), ('es', 'backups', 'create', 'Crear copia de seguridad'), ('es', 'backups', 'create_confirm', '¿Crear copia de seguridad de todos los clientes en este servidor?'), ('es', 'backups', 'created_success', 'Copia de seguridad creada exitosamente'), ('es', 'backups', 'delete_confirm', '¿Eliminar esta copia de seguridad permanentemente?'), ('es', 'backups', 'deleted_success', 'Copia de seguridad eliminada exitosamente'), ('es', 'backups', 'login_required', 'Por favor inicie sesión vía API para gestionar copias de seguridad'), ('es', 'backups', 'no_backups', 'Aún no hay copias de seguridad'), ('es', 'backups', 'restore', 'Restaurar'), ('es', 'backups', 'restore_confirm', '¿Restaurar clientes desde esta copia de seguridad? Los clientes existentes no se verán afectados.'), ('es', 'backups', 'restored_success', 'Restaurado'), ('es', 'backups', 'title', 'Copias de seguridad del servidor'), ('es', 'clients', 'actions', 'Acciones'), ('es', 'clients', 'add', 'Agregar cliente'), ('es', 'clients', 'create', 'Crear cliente'), ('es', 'clients', 'delete', 'Eliminar'), ('es', 'clients', 'delete_confirm', '¿Eliminar este cliente permanentemente?'), ('es', 'clients', 'download_config', 'Descargar configuración'), ('es', 'clients', 'expiration', 'Vencimiento'), ('es', 'clients', 'expired', 'Vencido'), ('es', 'clients', 'ip', 'Dirección IP'), ('es', 'clients', 'last_handshake', 'Último contacto'), ('es', 'clients', 'name', 'Nombre del cliente'), ('es', 'clients', 'never', 'Nunca'), ('es', 'clients', 'never_expires', 'Nunca vence'), ('es', 'clients', 'no_clients', 'Aún no hay clientes'), ('es', 'clients', 'overlimit', 'Límite excedido'), ('es', 'clients', 'qr_code', 'Código QR'), ('es', 'clients', 'received', 'Recibido'), ('es', 'clients', 'restore', 'Restaurar'), ('es', 'clients', 'revoke', 'Revocar'), ('es', 'clients', 'revoke_confirm', '¿Revocar acceso para este cliente?'), ('es', 'clients', 'sent', 'Enviado'), ('es', 'clients', 'server', 'Servidor'), ('es', 'clients', 'status', 'Estado'), ('es', 'clients', 'sync_stats', 'Sincronizar estadísticas'), ('es', 'clients', 'title', 'Clientes'), ('es', 'clients', 'traffic', 'Tráfico'), ('es', 'clients', 'traffic_limit', 'Límite de tráfico'), ('es', 'clients', 'unlimited', 'Ilimitado'), ('es', 'clients', 'custom_seconds', 'Personalizado (segundos)'), ('es', 'clients', 'custom_mb', 'Personalizado (MB)'), ('es', 'clients', 'enter_seconds', 'Ingrese segundos'), ('es', 'clients', 'enter_megabytes', 'Ingrese megabytes'), ('es', 'common', 'days', 'días'), ('es', 'dashboard', 'active_clients', 'Clientes activos'), ('es', 'dashboard', 'add_first_server', 'Agregar primer servidor'), ('es', 'dashboard', 'get_started', 'Comience agregando su primer servidor VPN'), ('es', 'dashboard', 'no_servers', 'Aún no hay servidores'), ('es', 'dashboard', 'quick_actions', 'Acciones rápidas'), ('es', 'dashboard', 'recent_servers', 'Servidores recientes'), ('es', 'dashboard', 'title', 'Panel de control'), ('es', 'dashboard', 'total_clients', 'Total de clientes'), ('es', 'dashboard', 'total_servers', 'Total de servidores'), ('es', 'dashboard', 'total_traffic', 'Tráfico total'), ('es', 'dashboard', 'welcome', 'Bienvenido al Panel de Gestión de Amnezia VPN'), ('es', 'form', 'cancel', 'Cancelar'), ('es', 'form', 'close', 'Cerrar'), ('es', 'form', 'create', 'Crear'), ('es', 'form', 'loading', 'Cargando...'), ('es', 'form', 'processing', 'Procesando...'), ('es', 'form', 'save', 'Guardar'), ('es', 'form', 'submit', 'Enviar'), ('es', 'form', 'update', 'Actualizar'), ('es', 'menu', 'clients', 'Clientes'), ('es', 'menu', 'dashboard', 'Panel de control'), ('es', 'menu', 'logout', 'Cerrar sesión'), ('es', 'menu', 'servers', 'Servidores'), ('es', 'menu', 'settings', 'Configuración'), ('es', 'menu', 'users', 'Usuarios'), ('es', 'message', 'confirm', '¿Está seguro?'), ('es', 'message', 'deleted', 'Eliminado exitosamente'), ('es', 'message', 'deployed', 'Implementado exitosamente'), ('es', 'message', 'error', 'Ha ocurrido un error'), ('es', 'message', 'saved', 'Guardado exitosamente'), ('es', 'message', 'success', 'Operación completada exitosamente'), ('es', 'servers', 'actions', 'Acciones'), ('es', 'servers', 'add', 'Agregar servidor'), ('es', 'servers', 'clients', 'Clientes'), ('es', 'servers', 'delete', 'Eliminar'), ('es', 'servers', 'deploy', 'Implementar'), ('es', 'servers', 'edit', 'Editar'), ('es', 'servers', 'host', 'Host'), ('es', 'servers', 'name', 'Nombre'), ('es', 'servers', 'port', 'Puerto'), ('es', 'servers', 'status', 'Estado'), ('es', 'servers', 'title', 'Servidores'), ('es', 'servers', 'view', 'Ver'), ('es', 'settings', 'actions', 'Acciones'), ('es', 'settings', 'api_key_configured', 'Clave API configurada'), ('es', 'settings', 'api_keys', 'Claves API'), ('es', 'settings', 'api_keys_desc', 'Configurar claves API para servicios externos'), ('es', 'settings', 'auto_translate', 'Auto-traducir'), ('es', 'settings', 'change_password', 'Cambiar contraseña'), ('es', 'settings', 'confirm_password', 'Confirmar contraseña'), ('es', 'settings', 'confirm_translate', '¿Iniciar traducción automática? Esto puede tomar unos minutos.'), ('es', 'settings', 'current_password', 'Contraseña actual'), ('es', 'settings', 'description', 'Gestionar configuración del panel e integraciones API'), ('es', 'settings', 'error_empty_key', 'La clave API no puede estar vacía'), ('es', 'settings', 'error_invalid_key', 'Formato de clave API inválido'), ('es', 'settings', 'error_key_test', 'Prueba de clave API fallida'), ('es', 'settings', 'for_translation', 'para auto-traducción'), ('es', 'settings', 'get_key_at', 'Obtenga su clave API en'), ('es', 'settings', 'key_saved', 'Clave API guardada exitosamente'), ('es', 'settings', 'keys', 'claves'), ('es', 'settings', 'language', 'Idioma'), ('es', 'settings', 'min_6_chars', 'Mínimo 6 caracteres'), ('es', 'settings', 'new_password', 'Nueva contraseña'), ('es', 'settings', 'no_api_key', 'No hay clave API configurada. La auto-traducción no funcionará.'), ('es', 'settings', 'profile', 'Perfil'), ('es', 'settings', 'progress', 'Progreso'), ('es', 'settings', 'skip_validation', 'Omitir validación (guardar sin probar)'), ('es', 'settings', 'translation_complete', 'Traducción completada'), ('es', 'settings', 'translation_status', 'Estado de traducción'), ('es', 'settings', 'translations', 'Traducciones'), ('es', 'settings', 'users', 'Usuarios'), ('es', 'status', 'active', 'Activo'), ('es', 'status', 'deploying', 'Implementando'), ('es', 'status', 'disabled', 'Deshabilitado'), ('es', 'status', 'error', 'Error'), ('es', 'status', 'inactive', 'Inactivo'), ('es', 'users', 'add_user', 'Agregar usuario'), ('es', 'users', 'administrator', 'Administrador'), ('es', 'users', 'all_users', 'Todos los usuarios'), ('es', 'users', 'created', 'Creado'), ('es', 'users', 'delete_confirm', '¿Eliminar {0}?'), ('es', 'users', 'role', 'Rol'), ('es', 'users', 'role_admin', 'Administrador'), ('es', 'users', 'role_user', 'Usuario'), ('es', 'servers', 'import_from_panel', 'Importar desde panel existente'), ('es', 'servers', 'select_panel_type', 'Seleccione tipo de panel'), ('es', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('es', 'servers', 'panel_type_3xui', '3x-ui'), ('es', 'servers', 'upload_backup_file', 'Subir archivo de respaldo (JSON)'), ('es', 'servers', 'import_in_progress', 'Importación en progreso...'), ('es', 'servers', 'import_success', 'Se importaron {0} clientes correctamente'), ('es', 'servers', 'import_failed', 'Error de importación'), ('es', 'servers', 'import_partial', 'Importados {0} de {1} clientes'), ('es', 'servers', 'import_history', 'Historial de importación') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('004_translations_de.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('de', 'auth', 'email', 'E-Mail'), ('de', 'auth', 'login', 'Anmelden'), ('de', 'auth', 'name', 'Name'), ('de', 'auth', 'password', 'Passwort'), ('de', 'auth', 'register', 'Registrieren'), ('de', 'backups', 'create', 'Backup erstellen'), ('de', 'backups', 'create_confirm', 'Backup aller Clients auf diesem Server erstellen?'), ('de', 'backups', 'created_success', 'Backup erfolgreich erstellt'), ('de', 'backups', 'delete_confirm', 'Dieses Backup endgültig löschen?'), ('de', 'backups', 'deleted_success', 'Backup erfolgreich gelöscht'), ('de', 'backups', 'login_required', 'Bitte melden Sie sich über die API an, um Backups zu verwalten'), ('de', 'backups', 'no_backups', 'Noch keine Backups'), ('de', 'backups', 'restore', 'Wiederherstellen'), ('de', 'backups', 'restore_confirm', 'Clients aus diesem Backup wiederherstellen? Bestehende Clients bleiben unberührt.'), ('de', 'backups', 'restored_success', 'Wiederhergestellt'), ('de', 'backups', 'title', 'Server-Backups'), ('de', 'clients', 'actions', 'Aktionen'), ('de', 'clients', 'add', 'Client hinzufügen'), ('de', 'clients', 'create', 'Client erstellen'), ('de', 'clients', 'delete', 'Löschen'), ('de', 'clients', 'delete_confirm', 'Diesen Client dauerhaft löschen?'), ('de', 'clients', 'download_config', 'Konfiguration herunterladen'), ('de', 'clients', 'expiration', 'Ablaufdatum'), ('de', 'clients', 'expired', 'Abgelaufen'), ('de', 'clients', 'ip', 'IP-Adresse'), ('de', 'clients', 'last_handshake', 'Letzter Handshake'), ('de', 'clients', 'name', 'Client-Name'), ('de', 'clients', 'never', 'Niemals'), ('de', 'clients', 'never_expires', 'Läuft nie ab'), ('de', 'clients', 'no_clients', 'Noch keine Kunden'), ('de', 'clients', 'overlimit', 'Limit überschritten'), ('de', 'clients', 'qr_code', 'QR-Code'), ('de', 'clients', 'received', 'Empfangen'), ('de', 'clients', 'restore', 'Wiederherstellen'), ('de', 'clients', 'revoke', 'Widerrufen'), ('de', 'clients', 'revoke_confirm', 'Zugriff für diesen Client widerrufen?'), ('de', 'clients', 'sent', 'Gesendet'), ('de', 'clients', 'server', 'Server'), ('de', 'clients', 'status', 'Status'), ('de', 'clients', 'sync_stats', 'Statistiken synchronisieren'), ('de', 'clients', 'title', 'Clients'), ('de', 'clients', 'traffic', 'Datenverkehr'), ('de', 'clients', 'traffic_limit', 'Traffic-Limit'), ('de', 'clients', 'unlimited', 'Unbegrenzt'), ('de', 'clients', 'custom_seconds', 'Benutzerdefiniert (Sekunden)'), ('de', 'clients', 'custom_mb', 'Benutzerdefiniert (MB)'), ('de', 'clients', 'enter_seconds', 'Sekunden eingeben'), ('de', 'clients', 'enter_megabytes', 'Megabytes eingeben'), ('de', 'common', 'days', 'Tage'), ('de', 'dashboard', 'active_clients', 'Aktive Clients'), ('de', 'dashboard', 'add_first_server', 'Ersten Server hinzufügen'), ('de', 'dashboard', 'get_started', 'Beginnen Sie mit dem Hinzufügen Ihres ersten VPN-Servers'), ('de', 'dashboard', 'no_servers', 'Noch keine Server'), ('de', 'dashboard', 'quick_actions', 'Schnellaktionen'), ('de', 'dashboard', 'recent_servers', 'Aktuelle Server'), ('de', 'dashboard', 'title', 'Dashboard'), ('de', 'dashboard', 'total_clients', 'Gesamtzahl Clients'), ('de', 'dashboard', 'total_servers', 'Gesamtzahl Server'), ('de', 'dashboard', 'total_traffic', 'Gesamter Datenverkehr'), ('de', 'dashboard', 'welcome', 'Willkommen im Amnezia VPN Verwaltungspanel'), ('de', 'form', 'cancel', 'Abbrechen'), ('de', 'form', 'close', 'Schließen'), ('de', 'form', 'create', 'Erstellen'), ('de', 'form', 'loading', 'Lädt...'), ('de', 'form', 'processing', 'Verarbeitung...'), ('de', 'form', 'save', 'Speichern'), ('de', 'form', 'submit', 'Absenden'), ('de', 'form', 'update', 'Aktualisieren'), ('de', 'menu', 'clients', 'Clients'), ('de', 'menu', 'dashboard', 'Dashboard'), ('de', 'menu', 'logout', 'Abmelden'), ('de', 'menu', 'servers', 'Server'), ('de', 'menu', 'settings', 'Einstellungen'), ('de', 'menu', 'users', 'Benutzer'), ('de', 'message', 'confirm', 'Sind Sie sicher?'), ('de', 'message', 'deleted', 'Erfolgreich gelöscht'), ('de', 'message', 'deployed', 'Erfolgreich bereitgestellt'), ('de', 'message', 'error', 'Ein Fehler ist aufgetreten'), ('de', 'message', 'saved', 'Erfolgreich gespeichert'), ('de', 'message', 'success', 'Vorgang erfolgreich abgeschlossen'), ('de', 'servers', 'actions', 'Aktionen'), ('de', 'servers', 'add', 'Server hinzufügen'), ('de', 'servers', 'clients', 'Clients'), ('de', 'servers', 'delete', 'Löschen'), ('de', 'servers', 'deploy', 'Bereitstellen'), ('de', 'servers', 'edit', 'Bearbeiten'), ('de', 'servers', 'host', 'Host'), ('de', 'servers', 'name', 'Name'), ('de', 'servers', 'port', 'Port'), ('de', 'servers', 'status', 'Status'), ('de', 'servers', 'title', 'Server'), ('de', 'servers', 'view', 'Ansehen'), ('de', 'settings', 'actions', 'Aktionen'), ('de', 'settings', 'api_key_configured', 'API-Schlüssel konfiguriert'), ('de', 'settings', 'api_keys', 'API-Schlüssel'), ('de', 'settings', 'api_keys_desc', 'API-Schlüssel für externe Dienste konfigurieren'), ('de', 'settings', 'auto_translate', 'Automatische Übersetzung'), ('de', 'settings', 'change_password', 'Passwort ändern'), ('de', 'settings', 'confirm_password', 'Passwort bestätigen'), ('de', 'settings', 'confirm_translate', 'Automatische Übersetzung starten? Dies kann einige Minuten dauern.'), ('de', 'settings', 'current_password', 'Aktuelles Passwort'), ('de', 'settings', 'description', 'Panel-Konfiguration und API-Integrationen verwalten'), ('de', 'settings', 'error_empty_key', 'API-Schlüssel darf nicht leer sein'), ('de', 'settings', 'error_invalid_key', 'Ungültiges API-Schlüssel-Format'), ('de', 'settings', 'error_key_test', 'API-Schlüssel-Test fehlgeschlagen'), ('de', 'settings', 'for_translation', 'für automatische Übersetzung'), ('de', 'settings', 'get_key_at', 'Holen Sie sich Ihren API-Schlüssel bei'), ('de', 'settings', 'key_saved', 'API-Schlüssel erfolgreich gespeichert'), ('de', 'settings', 'keys', 'Schlüssel'), ('de', 'settings', 'language', 'Sprache'), ('de', 'settings', 'min_6_chars', 'Mindestens 6 Zeichen'), ('de', 'settings', 'new_password', 'Neues Passwort'), ('de', 'settings', 'no_api_key', 'Kein API-Schlüssel konfiguriert. Automatische Übersetzung wird nicht funktionieren.'), ('de', 'settings', 'profile', 'Profil'), ('de', 'settings', 'progress', 'Fortschritt'), ('de', 'settings', 'skip_validation', 'Validierung überspringen (ohne Test speichern)'), ('de', 'settings', 'translation_complete', 'Übersetzung abgeschlossen'), ('de', 'settings', 'translation_status', 'Übersetzungsstatus'), ('de', 'settings', 'translations', 'Übersetzungen'), ('de', 'settings', 'users', 'Benutzer'), ('de', 'status', 'active', 'Aktiv'), ('de', 'status', 'deploying', 'Wird bereitgestellt'), ('de', 'status', 'disabled', 'Deaktiviert'), ('de', 'status', 'error', 'Fehler'), ('de', 'status', 'inactive', 'Inaktiv'), ('de', 'users', 'add_user', 'Benutzer hinzufügen'), ('de', 'users', 'administrator', 'Administrator'), ('de', 'users', 'all_users', 'Alle Benutzer'), ('de', 'users', 'created', 'Erstellt'), ('de', 'users', 'delete_confirm', '{0} löschen?'), ('de', 'users', 'role', 'Rolle'), ('de', 'users', 'role_admin', 'Admin'), ('de', 'users', 'role_user', 'Benutzer'), ('de', 'servers', 'import_from_panel', 'Import aus bestehendem Panel'), ('de', 'servers', 'select_panel_type', 'Panel-Typ auswählen'), ('de', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('de', 'servers', 'panel_type_3xui', '3x-ui'), ('de', 'servers', 'upload_backup_file', 'Backup-Datei hochladen (JSON)'), ('de', 'servers', 'import_in_progress', 'Import läuft...'), ('de', 'servers', 'import_success', '{0} Clients erfolgreich importiert'), ('de', 'servers', 'import_failed', 'Import fehlgeschlagen'), ('de', 'servers', 'import_partial', '{0} von {1} Clients importiert'), ('de', 'servers', 'import_history', 'Import-Historie') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('005_translations_fr.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('fr', 'auth', 'email', 'Email'), ('fr', 'auth', 'login', 'Connexion'), ('fr', 'auth', 'name', 'Nom'), ('fr', 'auth', 'password', 'Mot de passe'), ('fr', 'auth', 'register', 'S''inscrire'), ('fr', 'backups', 'create', 'Créer une sauvegarde'), ('fr', 'backups', 'create_confirm', 'Créer une sauvegarde de tous les clients sur ce serveur ?'), ('fr', 'backups', 'created_success', 'Sauvegarde créée avec succès'), ('fr', 'backups', 'delete_confirm', 'Supprimer définitivement cette sauvegarde ?'), ('fr', 'backups', 'deleted_success', 'Sauvegarde supprimée avec succès'), ('fr', 'backups', 'login_required', 'Veuillez vous connecter via l''API pour gérer les sauvegardes'), ('fr', 'backups', 'no_backups', 'Aucune sauvegarde pour le moment'), ('fr', 'backups', 'restore', 'Restaurer'), ('fr', 'backups', 'restore_confirm', 'Restaurer les clients depuis cette sauvegarde ? Les clients existants ne seront pas affectés.'), ('fr', 'backups', 'restored_success', 'Restauré'), ('fr', 'backups', 'title', 'Sauvegardes du serveur'), ('fr', 'clients', 'actions', 'Actions'), ('fr', 'clients', 'add', 'Ajouter un client'), ('fr', 'clients', 'create', 'Créer un client'), ('fr', 'clients', 'delete', 'Supprimer'), ('fr', 'clients', 'delete_confirm', 'Supprimer ce client définitivement?'), ('fr', 'clients', 'download_config', 'Télécharger la configuration'), ('fr', 'clients', 'expiration', 'Expiration'), ('fr', 'clients', 'expired', 'Expiré'), ('fr', 'clients', 'ip', 'Adresse IP'), ('fr', 'clients', 'last_handshake', 'Dernière connexion'), ('fr', 'clients', 'name', 'Nom du client'), ('fr', 'clients', 'never', 'Jamais'), ('fr', 'clients', 'never_expires', 'N''expire jamais'), ('fr', 'clients', 'no_clients', 'Pas encore de clients'), ('fr', 'clients', 'overlimit', 'Limite dépassée'), ('fr', 'clients', 'qr_code', 'Code QR'), ('fr', 'clients', 'received', 'Reçu'), ('fr', 'clients', 'restore', 'Restaurer'), ('fr', 'clients', 'revoke', 'Révoquer'), ('fr', 'clients', 'revoke_confirm', 'Révoquer l''accès pour ce client?'), ('fr', 'clients', 'sent', 'Envoyé'), ('fr', 'clients', 'server', 'Serveur'), ('fr', 'clients', 'status', 'Statut'), ('fr', 'clients', 'sync_stats', 'Synchroniser les statistiques'), ('fr', 'clients', 'title', 'Clients'), ('fr', 'clients', 'traffic', 'Trafic'), ('fr', 'clients', 'traffic_limit', 'Limite de trafic'), ('fr', 'clients', 'unlimited', 'Illimité'), ('fr', 'clients', 'custom_seconds', 'Personnalisé (secondes)'), ('fr', 'clients', 'custom_mb', 'Personnalisé (MB)'), ('fr', 'clients', 'enter_seconds', 'Saisissez les secondes'), ('fr', 'clients', 'enter_megabytes', 'Saisissez les mégaoctets'), ('fr', 'common', 'days', 'jours'), ('fr', 'dashboard', 'active_clients', 'Clients actifs'), ('fr', 'dashboard', 'add_first_server', 'Ajouter le premier serveur'), ('fr', 'dashboard', 'get_started', 'Commencez par ajouter votre premier serveur VPN'), ('fr', 'dashboard', 'no_servers', 'Aucun serveur pour le moment'), ('fr', 'dashboard', 'quick_actions', 'Actions rapides'), ('fr', 'dashboard', 'recent_servers', 'Serveurs récents'), ('fr', 'dashboard', 'title', 'Tableau de bord'), ('fr', 'dashboard', 'total_clients', 'Total des clients'), ('fr', 'dashboard', 'total_servers', 'Total des serveurs'), ('fr', 'dashboard', 'total_traffic', 'Trafic total'), ('fr', 'dashboard', 'welcome', 'Bienvenue sur le panneau de gestion Amnezia VPN'), ('fr', 'form', 'cancel', 'Annuler'), ('fr', 'form', 'close', 'Fermer'), ('fr', 'form', 'create', 'Créer'), ('fr', 'form', 'loading', 'Chargement...'), ('fr', 'form', 'processing', 'Traitement...'), ('fr', 'form', 'save', 'Enregistrer'), ('fr', 'form', 'submit', 'Soumettre'), ('fr', 'form', 'update', 'Mettre à jour'), ('fr', 'menu', 'clients', 'Clients'), ('fr', 'menu', 'dashboard', 'Tableau de bord'), ('fr', 'menu', 'logout', 'Déconnexion'), ('fr', 'menu', 'servers', 'Serveurs'), ('fr', 'menu', 'settings', 'Paramètres'), ('fr', 'menu', 'users', 'Utilisateurs'), ('fr', 'message', 'confirm', 'Êtes-vous sûr ?'), ('fr', 'message', 'deleted', 'Supprimé avec succès'), ('fr', 'message', 'deployed', 'Déployé avec succès'), ('fr', 'message', 'error', 'Une erreur est survenue'), ('fr', 'message', 'saved', 'Enregistré avec succès'), ('fr', 'message', 'success', 'Opération terminée avec succès'), ('fr', 'servers', 'actions', 'Actions'), ('fr', 'servers', 'add', 'Ajouter un serveur'), ('fr', 'servers', 'clients', 'Clients'), ('fr', 'servers', 'delete', 'Supprimer'), ('fr', 'servers', 'deploy', 'Déployer'), ('fr', 'servers', 'edit', 'Modifier'), ('fr', 'servers', 'host', 'Hôte'), ('fr', 'servers', 'name', 'Nom'), ('fr', 'servers', 'port', 'Port'), ('fr', 'servers', 'status', 'Statut'), ('fr', 'servers', 'title', 'Serveurs'), ('fr', 'servers', 'view', 'Voir'), ('fr', 'settings', 'actions', 'Actions'), ('fr', 'settings', 'api_key_configured', 'Clé API configurée'), ('fr', 'settings', 'api_keys', 'Clés API'), ('fr', 'settings', 'api_keys_desc', 'Configurer les clés API pour les services externes'), ('fr', 'settings', 'auto_translate', 'Traduction automatique'), ('fr', 'settings', 'change_password', 'Changer le mot de passe'), ('fr', 'settings', 'confirm_password', 'Confirmer le mot de passe'), ('fr', 'settings', 'confirm_translate', 'Démarrer la traduction automatique ? Cela peut prendre quelques minutes.'), ('fr', 'settings', 'current_password', 'Mot de passe actuel'), ('fr', 'settings', 'description', 'Gérer la configuration du panneau et les intégrations API'), ('fr', 'settings', 'error_empty_key', 'La clé API ne peut pas être vide'), ('fr', 'settings', 'error_invalid_key', 'Format de clé API invalide'), ('fr', 'settings', 'error_key_test', 'Test de la clé API échoué'), ('fr', 'settings', 'for_translation', 'pour la traduction automatique'), ('fr', 'settings', 'get_key_at', 'Obtenez votre clé API sur'), ('fr', 'settings', 'key_saved', 'Clé API enregistrée avec succès'), ('fr', 'settings', 'keys', 'clés'), ('fr', 'settings', 'language', 'Langue'), ('fr', 'settings', 'min_6_chars', 'Minimum 6 caractères'), ('fr', 'settings', 'new_password', 'Nouveau mot de passe'), ('fr', 'settings', 'no_api_key', 'Aucune clé API configurée. La traduction automatique ne fonctionnera pas.'), ('fr', 'settings', 'profile', 'Profil'), ('fr', 'settings', 'progress', 'Progression'), ('fr', 'settings', 'skip_validation', 'Ignorer la validation (enregistrer sans tester)'), ('fr', 'settings', 'translation_complete', 'Traduction terminée'), ('fr', 'settings', 'translation_status', 'État de la traduction'), ('fr', 'settings', 'translations', 'Traductions'), ('fr', 'settings', 'users', 'Utilisateurs'), ('fr', 'status', 'active', 'Actif'), ('fr', 'status', 'deploying', 'Déploiement'), ('fr', 'status', 'disabled', 'Désactivé'), ('fr', 'status', 'error', 'Erreur'), ('fr', 'status', 'inactive', 'Inactif'), ('fr', 'users', 'add_user', 'Ajouter un utilisateur'), ('fr', 'users', 'administrator', 'Administrateur'), ('fr', 'users', 'all_users', 'Tous les utilisateurs'), ('fr', 'users', 'created', 'Créé'), ('fr', 'users', 'delete_confirm', 'Supprimer {0} ?'), ('fr', 'users', 'role', 'Rôle'), ('fr', 'users', 'role_admin', 'Administrateur'), ('fr', 'users', 'role_user', 'Utilisateur'), ('fr', 'servers', 'import_from_panel', 'Importer depuis un panel existant'), ('fr', 'servers', 'select_panel_type', 'Sélectionnez le type de panel'), ('fr', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('fr', 'servers', 'panel_type_3xui', '3x-ui'), ('fr', 'servers', 'upload_backup_file', 'Télécharger le fichier de sauvegarde (JSON)'), ('fr', 'servers', 'import_in_progress', 'Importation en cours...'), ('fr', 'servers', 'import_success', '{0} clients importés avec succès'), ('fr', 'servers', 'import_failed', 'Échec de l''importation'), ('fr', 'servers', 'import_partial', '{0} clients importés sur {1}'), ('fr', 'servers', 'import_history', 'Historique d''importation') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('006_translations_zh.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO translations (locale, category, key_name, translation) VALUES ('zh', 'auth', 'email', '邮箱'), ('zh', 'auth', 'login', '登录'), ('zh', 'auth', 'name', '姓名'), ('zh', 'auth', 'password', '密码'), ('zh', 'auth', 'register', '注册'), ('zh', 'backups', 'create', '创建备份'), ('zh', 'backups', 'create_confirm', '创建此服务器上所有客户端的备份？'), ('zh', 'backups', 'created_success', '备份创建成功'), ('zh', 'backups', 'delete_confirm', '永久删除此备份？'), ('zh', 'backups', 'deleted_success', '备份删除成功'), ('zh', 'backups', 'login_required', '请通过API登录以管理备份'), ('zh', 'backups', 'no_backups', '暂无备份'), ('zh', 'backups', 'restore', '恢复'), ('zh', 'backups', 'restore_confirm', '从此备份恢复客户端？现有客户端不会受到影响。'), ('zh', 'backups', 'restored_success', '已恢复'), ('zh', 'backups', 'title', '服务器备份'), ('zh', 'clients', 'actions', '操作'), ('zh', 'clients', 'add', '添加客户端'), ('zh', 'clients', 'create', '创建客户端'), ('zh', 'clients', 'delete', '删除'), ('zh', 'clients', 'delete_confirm', '永久删除此客户端？'), ('zh', 'clients', 'download_config', '下载配置'), ('zh', 'clients', 'expiration', '过期时间'), ('zh', 'clients', 'expired', '已过期'), ('zh', 'clients', 'ip', 'IP地址'), ('zh', 'clients', 'last_handshake', '最后握手'), ('zh', 'clients', 'name', '客户端名称'), ('zh', 'clients', 'never', '从不'), ('zh', 'clients', 'never_expires', '永不过期'), ('zh', 'clients', 'no_clients', '还没有客户'), ('zh', 'clients', 'overlimit', '超出限制'), ('zh', 'clients', 'qr_code', '二维码'), ('zh', 'clients', 'received', '已接收'), ('zh', 'clients', 'restore', '恢复'), ('zh', 'clients', 'revoke', '撤销'), ('zh', 'clients', 'revoke_confirm', '撤销此客户端的访问权限？'), ('zh', 'clients', 'sent', '已发送'), ('zh', 'clients', 'server', '服务器'), ('zh', 'clients', 'status', '状态'), ('zh', 'clients', 'sync_stats', '同步统计'), ('zh', 'clients', 'title', '客户端'), ('zh', 'clients', 'traffic', '流量'), ('zh', 'clients', 'traffic_limit', '流量限制'), ('zh', 'clients', 'unlimited', '无限制'), ('zh', 'clients', 'custom_seconds', '自定义（秒）'), ('zh', 'clients', 'custom_mb', '自定义（MB）'), ('zh', 'clients', 'enter_seconds', '输入秒数'), ('zh', 'clients', 'enter_megabytes', '输入兆字节'), ('zh', 'common', 'days', '天'), ('zh', 'dashboard', 'active_clients', '活跃客户端'), ('zh', 'dashboard', 'add_first_server', '添加第一个服务器'), ('zh', 'dashboard', 'get_started', '从添加第一个VPN服务器开始'), ('zh', 'dashboard', 'no_servers', '暂无服务器'), ('zh', 'dashboard', 'quick_actions', '快捷操作'), ('zh', 'dashboard', 'recent_servers', '最近的服务器'), ('zh', 'dashboard', 'title', '仪表板'), ('zh', 'dashboard', 'total_clients', '客户端总数'), ('zh', 'dashboard', 'total_servers', '服务器总数'), ('zh', 'dashboard', 'total_traffic', '总流量'), ('zh', 'dashboard', 'welcome', '欢迎使用Amnezia VPN管理面板'), ('zh', 'form', 'cancel', '取消'), ('zh', 'form', 'close', '关闭'), ('zh', 'form', 'create', '创建'), ('zh', 'form', 'loading', '加载中...'), ('zh', 'form', 'processing', '处理中...'), ('zh', 'form', 'save', '保存'), ('zh', 'form', 'submit', '提交'), ('zh', 'form', 'update', '更新'), ('zh', 'menu', 'clients', '客户端'), ('zh', 'menu', 'dashboard', '仪表板'), ('zh', 'menu', 'logout', '退出'), ('zh', 'menu', 'servers', '服务器'), ('zh', 'menu', 'settings', '设置'), ('zh', 'menu', 'users', '用户'), ('zh', 'message', 'confirm', '确定吗？'), ('zh', 'message', 'deleted', '删除成功'), ('zh', 'message', 'deployed', '部署成功'), ('zh', 'message', 'error', '发生错误'), ('zh', 'message', 'saved', '保存成功'), ('zh', 'message', 'success', '操作完成'), ('zh', 'servers', 'actions', '操作'), ('zh', 'servers', 'add', '添加服务器'), ('zh', 'servers', 'clients', '客户端'), ('zh', 'servers', 'delete', '删除'), ('zh', 'servers', 'deploy', '部署'), ('zh', 'servers', 'edit', '编辑'), ('zh', 'servers', 'host', '主机'), ('zh', 'servers', 'name', '名称'), ('zh', 'servers', 'port', '端口'), ('zh', 'servers', 'status', '状态'), ('zh', 'servers', 'title', '服务器'), ('zh', 'servers', 'view', '查看'), ('zh', 'settings', 'actions', '操作'), ('zh', 'settings', 'api_key_configured', 'API密钥已配置'), ('zh', 'settings', 'api_keys', 'API密钥'), ('zh', 'settings', 'api_keys_desc', '配置外部服务的API密钥'), ('zh', 'settings', 'auto_translate', '自动翻译'), ('zh', 'settings', 'change_password', '修改密码'), ('zh', 'settings', 'confirm_password', '确认密码'), ('zh', 'settings', 'confirm_translate', '开始自动翻译？这可能需要几分钟。'), ('zh', 'settings', 'current_password', '当前密码'), ('zh', 'settings', 'description', '管理面板配置和API集成'), ('zh', 'settings', 'error_empty_key', 'API密钥不能为空'), ('zh', 'settings', 'error_invalid_key', '无效的API密钥格式'), ('zh', 'settings', 'error_key_test', 'API密钥测试失败'), ('zh', 'settings', 'for_translation', '用于自动翻译'), ('zh', 'settings', 'get_key_at', '在此获取API密钥'), ('zh', 'settings', 'key_saved', 'API密钥保存成功'), ('zh', 'settings', 'keys', '密钥'), ('zh', 'settings', 'language', '语言'), ('zh', 'settings', 'min_6_chars', '最少6个字符'), ('zh', 'settings', 'new_password', '新密码'), ('zh', 'settings', 'no_api_key', '未配置API密钥。自动翻译将无法工作。'), ('zh', 'settings', 'profile', '个人资料'), ('zh', 'settings', 'progress', '进度'), ('zh', 'settings', 'skip_validation', '跳过验证（不测试直接保存）'), ('zh', 'settings', 'translation_complete', '翻译完成'), ('zh', 'settings', 'translation_status', '翻译状态'), ('zh', 'settings', 'translations', '翻译'), ('zh', 'settings', 'users', '用户'), ('zh', 'status', 'active', '活跃'), ('zh', 'status', 'deploying', '部署中'), ('zh', 'status', 'disabled', '已禁用'), ('zh', 'status', 'error', '错误'), ('zh', 'status', 'inactive', '不活跃'), ('zh', 'users', 'add_user', '添加用户'), ('zh', 'users', 'administrator', '管理员'), ('zh', 'users', 'all_users', '所有用户'), ('zh', 'users', 'created', '已创建'), ('zh', 'users', 'delete_confirm', '删除 {0}？'), ('zh', 'users', 'role', '角色'), ('zh', 'users', 'role_admin', '管理员'), ('zh', 'users', 'role_user', '用户'), ('zh', 'servers', 'import_from_panel', '从现有面板导入'), ('zh', 'servers', 'select_panel_type', '选择面板类型'), ('zh', 'servers', 'panel_type_wgeasy', 'wg-easy'), ('zh', 'servers', 'panel_type_3xui', '3x-ui'), ('zh', 'servers', 'upload_backup_file', '上传备份文件 (JSON)'), ('zh', 'servers', 'import_in_progress', '导入进行中...'), ('zh', 'servers', 'import_success', '成功导入 {0} 个客户端'), ('zh', 'servers', 'import_failed', '导入失败'), ('zh', 'servers', 'import_partial', '已导入 {0}/{1} 个客户端'), ('zh', 'servers', 'import_history', '导入历史') ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('007_add_traffic_limit.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('008_add_panel_imports.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('009_add_server_metrics.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('010_add_monitoring_translations.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Insert new translations (will skip duplicates)
INSERT INTO translations (locale, category, key_name, translation) VALUES 
-- Speed
('en', 'common', 'speed', 'Speed'),
('ru', 'common', 'speed', 'Скорость'),
('es', 'common', 'speed', 'Velocidad'),
('de', 'common', 'speed', 'Geschwindigkeit'),
('fr', 'common', 'speed', 'Vitesse'),
('zh', 'common', 'speed', '速度'),

-- Metrics
('en', 'common', 'metrics', 'Metrics'),
('ru', 'common', 'metrics', 'Метрики'),
('es', 'common', 'metrics', 'Métricas'),
('de', 'common', 'metrics', 'Metriken'),
('fr', 'common', 'metrics', 'Métriques'),
('zh', 'common', 'metrics', '指标'),

-- Server Info
('en', 'servers', 'server_info', 'Server Info'),
('ru', 'servers', 'server_info', 'Информация о сервере'),
('es', 'servers', 'server_info', 'Información del servidor'),
('de', 'servers', 'server_info', 'Serverinformationen'),
('fr', 'servers', 'server_info', 'Informations sur le serveur'),
('zh', 'servers', 'server_info', '服务器信息'),

-- Status
('en', 'common', 'status', 'Status'),
('ru', 'common', 'status', 'Статус'),
('es', 'common', 'status', 'Estado'),
('de', 'common', 'status', 'Status'),
('fr', 'common', 'status', 'Statut'),
('zh', 'common', 'status', '状态'),

-- Client Configuration
('en', 'clients', 'configuration', 'Client Configuration'),
('ru', 'clients', 'configuration', 'Конфигурация клиента'),
('es', 'clients', 'configuration', 'Configuración del cliente'),
('de', 'clients', 'configuration', 'Client-Konfiguration'),
('fr', 'clients', 'configuration', 'Configuration du client'),
('zh', 'clients', 'configuration', '客户端配置'),

-- Traffic Statistics
('en', 'clients', 'traffic_stats', 'Traffic Statistics'),
('ru', 'clients', 'traffic_stats', 'Статистика трафика'),
('es', 'clients', 'traffic_stats', 'Estadísticas de tráfico'),
('de', 'clients', 'traffic_stats', 'Traffic-Statistiken'),
('fr', 'clients', 'traffic_stats', 'Statistiques de trafic'),
('zh', 'clients', 'traffic_stats', '流量统计'),

-- Uploaded
('en', 'common', 'uploaded', 'Uploaded'),
('ru', 'common', 'uploaded', 'Отправлено'),
('es', 'common', 'uploaded', 'Subido'),
('de', 'common', 'uploaded', 'Hochgeladen'),
('fr', 'common', 'uploaded', 'Envoyé'),
('zh', 'common', 'uploaded', '上传'),

-- Downloaded
('en', 'common', 'downloaded', 'Downloaded'),
('ru', 'common', 'downloaded', 'Получено'),
('es', 'common', 'downloaded', 'Descargado'),
('de', 'common', 'downloaded', 'Heruntergeladen'),
('fr', 'common', 'downloaded', 'Reçu'),
('zh', 'common', 'downloaded', '下载'),

-- Total
('en', 'common', 'total', 'Total'),
('ru', 'common', 'total', 'Всего'),
('es', 'common', 'total', 'Total'),
('de', 'common', 'total', 'Gesamt'),
('fr', 'common', 'total', 'Total'),
('zh', 'common', 'total', '总计'),

-- Created
('en', 'common', 'created', 'Created'),
('ru', 'common', 'created', 'Создан'),
('es', 'common', 'created', 'Creado'),
('de', 'common', 'created', 'Erstellt'),
('fr', 'common', 'created', 'Créé'),
('zh', 'common', 'created', '创建时间'),

-- IP Address
('en', 'common', 'ip_address', 'IP Address'),
('ru', 'common', 'ip_address', 'IP-адрес'),
('es', 'common', 'ip_address', 'Dirección IP'),
('de', 'common', 'ip_address', 'IP-Adresse'),
('fr', 'common', 'ip_address', 'Adresse IP'),
('zh', 'common', 'ip_address', 'IP地址')

ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('011_add_ldap_configs.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Insert default LDAP configuration (disabled by default)
INSERT INTO ldap_configs (id, enabled, host, port, base_dn, bind_dn, bind_password) 
VALUES (1, FALSE, 'ldap.example.com', 389, 'dc=example,dc=com', 'cn=admin,dc=example,dc=com', '');

INSERT INTO schema_migrations (filename, checksum) VALUES ('012_add_user_roles.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Insert default roles
INSERT INTO user_roles (name, display_name, description, permissions) VALUES
('admin', 'Administrator', 'Full access to all features', json_build_array('*')),
('manager', 'Manager', 'Can manage servers and clients', json_build_array('servers.view', 'servers.create', 'servers.edit', 'clients.view', 'clients.create', 'clients.edit', 'clients.delete')),
('viewer', 'Viewer', 'Can only view own clients', json_build_array('clients.view_own', 'clients.download_own'));

-- Insert default LDAP group mappings (examples)
INSERT INTO ldap_group_mappings (ldap_group, role_name, description) VALUES
('vpn-admins', 'admin', 'VPN administrators with full access'),
('vpn-managers', 'manager', 'VPN managers who can create and manage clients'),
('vpn-users', 'viewer', 'Regular VPN users with view-only access');

INSERT INTO schema_migrations (filename, checksum) VALUES ('013_add_ldap_translations.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Migration: Add LDAP translations (English and Russian)
-- Date: 2025-11-10

-- English translations
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'ldap', 'settings', 'LDAP Settings'),
('en', 'ldap', 'enable_ldap_auth', 'Enable LDAP Authentication'),
('en', 'ldap', 'enable_description', 'Allow users to login using LDAP/Active Directory credentials'),
('en', 'ldap', 'host', 'LDAP Host'),
('en', 'ldap', 'port', 'Port'),
('en', 'ldap', 'use_tls', 'Use TLS/SSL'),
('en', 'ldap', 'base_dn', 'Base DN'),
('en', 'ldap', 'base_dn_description', 'The base distinguished name for LDAP searches (e.g., dc=example,dc=com)'),
('en', 'ldap', 'bind_dn', 'Bind DN'),
('en', 'ldap', 'bind_dn_description', 'The distinguished name of the service account to bind with'),
('en', 'ldap', 'bind_password', 'Bind Password'),
('en', 'ldap', 'user_search_filter', 'User Search Filter'),
('en', 'ldap', 'user_search_filter_description', 'LDAP filter to search for users. %s will be replaced with username'),
('en', 'ldap', 'group_search_filter', 'Group Search Filter'),
('en', 'ldap', 'sync_interval', 'Sync Interval (minutes)'),
('en', 'ldap', 'sync_interval_description', 'How often to automatically synchronize users from LDAP'),
('en', 'ldap', 'test_connection', 'Test Connection'),
('en', 'ldap', 'testing', 'Testing'),
('en', 'ldap', 'connection_test_failed', 'Connection test failed'),
('en', 'ldap', 'group_mappings', 'LDAP Group Mappings'),
('en', 'ldap', 'group', 'LDAP Group'),
('en', 'ldap', 'role', 'Panel Role'),
('en', 'ldap', 'description', 'Description');

-- Russian translations
INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'ldap', 'settings', 'Настройки LDAP'),
('ru', 'ldap', 'enable_ldap_auth', 'Включить LDAP аутентификацию'),
('ru', 'ldap', 'enable_description', 'Разрешить пользователям входить используя учетные данные LDAP/Active Directory'),
('ru', 'ldap', 'host', 'LDAP Хост'),
('ru', 'ldap', 'port', 'Порт'),
('ru', 'ldap', 'use_tls', 'Использовать TLS/SSL'),
('ru', 'ldap', 'base_dn', 'Base DN'),
('ru', 'ldap', 'base_dn_description', 'Базовое отличительное имя для поиска в LDAP (например, dc=example,dc=com)'),
('ru', 'ldap', 'bind_dn', 'Bind DN'),
('ru', 'ldap', 'bind_dn_description', 'Отличительное имя служебной учетной записи для подключения'),
('ru', 'ldap', 'bind_password', 'Пароль подключения'),
('ru', 'ldap', 'user_search_filter', 'Фильтр поиска пользователей'),
('ru', 'ldap', 'user_search_filter_description', 'LDAP фильтр для поиска пользователей. %s будет заменен на имя пользователя'),
('ru', 'ldap', 'group_search_filter', 'Фильтр поиска групп'),
('ru', 'ldap', 'sync_interval', 'Интервал синхронизации (минуты)'),
('ru', 'ldap', 'sync_interval_description', 'Как часто автоматически синхронизировать пользователей из LDAP'),
('ru', 'ldap', 'test_connection', 'Тест подключения'),
('ru', 'ldap', 'testing', 'Тестирование'),
('ru', 'ldap', 'connection_test_failed', 'Тест подключения не удался'),
('ru', 'ldap', 'group_mappings', 'Связи групп LDAP'),
('ru', 'ldap', 'group', 'Группа LDAP'),
('ru', 'ldap', 'role', 'Роль в панели'),
('ru', 'ldap', 'description', 'Описание');

-- Common translations for buttons
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'common', 'save', 'Save'),
('en', 'common', 'cancel', 'Cancel'),
('ru', 'common', 'save', 'Сохранить'),
('ru', 'common', 'cancel', 'Отмена');

INSERT INTO schema_migrations (filename, checksum) VALUES ('014_consolidated.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

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
('fr', 'servers', 'config_import_type_amnezia', 'Sauvegarde de l’application Amnezia (.backup)'),
('fr', 'servers', 'config_import_file_label', 'Fichier de configuration'),
('fr', 'servers', 'config_import_file_hint', 'Notre panneau utilise des fichiers .json. L’application Amnezia utilise des fichiers .backup.'),
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
('en','servers','backup_upload_hint','Supported formats: panel JSON export or Amnezia application .backup'),
('en','servers','backup_server_entry','Select server entry'),
('en','servers','backup_summary_host','Host'),
('en','servers','backup_summary_clients','Clients'),
('en','servers','config_import_title','Restore configuration from backup'),
('en','servers','config_import_hint','Import server configuration (and optional clients) from a panel export or Amnezia application backup.'),
('en','servers','config_import_type_label','Backup type'),
('en','servers','config_import_type_panel','Panel export (.json)'),
('en','servers','config_import_type_amnezia','Amnezia app backup (.backup)'),
('en','servers','config_import_file_label','Configuration file'),
('en','servers','config_import_file_hint','The file remains on the server only during import and is deleted afterwards.'),
('en','servers','config_import_submit','Import configuration'),
('ru','servers','creation_mode','Режим создания'),
('ru','servers','creation_mode_manual','Ручная настройка'),
('ru','servers','creation_mode_backup','Импорт из бэкапа'),
('ru','servers','upload_backup_file','Загрузите файл бэкапа'),
('ru','servers','backup_upload_hint','Поддерживаются форматы: экспорт панели JSON или бэкап приложения Amnezia (.backup)'),
('ru','servers','backup_server_entry','Выберите запись сервера'),
('ru','servers','backup_summary_host','Хост'),
('ru','servers','backup_summary_clients','Клиенты'),
('ru','servers','config_import_title','Восстановление конфигурации из бэкапа'),
('ru','servers','config_import_hint','Импортируйте конфигурацию сервера (и при необходимости клиентов) из экспорта панели или бэкапа приложения Amnezia.'),
('ru','servers','config_import_type_label','Тип бэкапа'),
('ru','servers','config_import_type_panel','Экспорт панели (.json)'),
('ru','servers','config_import_type_amnezia','Бэкап приложения Amnezia (.backup)'),
('ru','servers','config_import_file_label','Файл конфигурации'),
('ru','servers','config_import_file_hint','Файл хранится на сервере только во время импорта и удаляется сразу после завершения.'),
('ru','servers','config_import_submit','Импортировать конфигурацию')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active) 
SELECT 'AmneziaWG Advanced', 'amnezia-wg-advanced', 'AmneziaWG protocol with advanced junk packet obfuscation parameters', '#!/bin/bash
echo "AmneziaWG Advanced installed"
', '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

Jc = {{Jc}}
Jmin = {{Jmin}}
Jmax = {{Jmax}}
S1 = {{S1}}
S2 = {{S2}}
H1 = {{H1}}
H2 = {{H2}}
H3 = {{H3}}
H4 = {{H4}}', true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='amnezia-wg-advanced');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active) 
SELECT 'WireGuard Standard', 'wireguard-standard', 'Standard WireGuard VPN protocol', '#!/bin/bash
CONTAINER_NAME="wireguard"
VPN_SUBNET="10.8.2.0/24"
PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo $PRIVATE_KEY | wg pubkey)
PRESHARED_KEY=$(wg genpsk)
docker run -d \
  --name $CONTAINER_NAME \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -v /opt/wireguard:/etc/wireguard \
  linuxserver/wireguard
cat > /opt/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.8.2.1/24
ListenPort = 51820

[Peer]
PublicKey = 
PresharedKey = $PRESHARED_KEY
AllowedIPs = 10.8.2.2/32
EOF
echo "WireGuard Standard installed successfully"
echo "Server Public Key: $PUBLIC_KEY"', '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25', true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='wireguard-standard');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active) 
SELECT 'OpenVPN', 'openvpn', 'OpenVPN protocol with TCP/UDP support', '#!/bin/bash
CONTAINER_NAME="openvpn"
VPN_SUBNET="10.8.3.0/24"
docker run -d \
  --name $CONTAINER_NAME \
  --cap-add=NET_ADMIN \
  -p 1194:1194/udp \
  -p 1194:1194/tcp \
  -v /opt/openvpn:/etc/openvpn \
  kylemanna/openvpn
docker exec -it $CONTAINER_NAME ovpn_genconfig -u udp://{{server_host}}:1194
docker exec -it $CONTAINER_NAME ovpn_initpki
echo "OpenVPN installed successfully"
echo "Available on ports: 1194/udp, 1194/tcp"', 'client
dev tun
proto {{protocol}}
remote {{server_host}} {{server_port}}
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3', true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='openvpn');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active) 
SELECT 'Shadowsocks', 'shadowsocks', 'Shadowsocks proxy protocol', '#!/bin/bash
CONTAINER_NAME="shadowsocks"
PASSWORD=$(openssl rand -base64 12)
docker run -d \
  --name $CONTAINER_NAME \
  -p 8388:8388 \
  -e METHOD=aes-256-gcm \
  -e PASSWORD=$PASSWORD \
  shadowsocks/shadowsocks-libev
echo "Shadowsocks installed successfully"
echo "Port: 8388"
echo "Method: aes-256-gcm"
echo "Password: $PASSWORD"', '{
  "server": "{{server_host}}",
  "server_port": {{server_port}},
  "password": "{{password}}",
  "method": "{{method}}"
}', true, true
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='shadowsocks');

INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default AmneziaWG', '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/32
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
Endpoint = {{server_host}}:{{server_port}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25

Jc = {{Jc}}
Jmin = {{Jmin}}
Jmax = {{Jmax}}
S1 = {{S1}}
S2 = {{S2}}
H1 = {{H1}}
H2 = {{H2}}
H3 = {{H3}}
H4 = {{H4}}', true
FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id=p.id AND template_name='Default AmneziaWG');

INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default WireGuard', '[Interface]
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

INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default OpenVPN', 'client
dev tun
proto {{protocol}}
remote {{server_host}} {{server_port}}
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client.crt
key client.key
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3', true
FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id=p.id AND template_name='Default OpenVPN');

INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default Shadowsocks', '{
  "server": "{{server_host}}",
  "server_port": {{server_port}},
  "password": "{{password}}",
  "method": "{{method}}"
}', true
FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id=p.id AND template_name='Default Shadowsocks');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'private_key', 'string', '', 'Client private key', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='private_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'client_ip', 'string', '10.8.1.2', 'Client IP address', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='client_ip');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_public_key', 'string', '', 'Server public key', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_public_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'preshared_key', 'string', '', 'Pre-shared key for additional security', true FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='preshared_key');

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

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'private_key', 'string', '', 'Client private key', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='private_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'client_ip', 'string', '10.8.2.2', 'Client IP address', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='client_ip');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_public_key', 'string', '', 'Server public key', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_public_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'preshared_key', 'string', '', 'Pre-shared key for additional security', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='preshared_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '51820', 'Server port', true FROM protocols p WHERE p.slug='wireguard-standard' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'protocol', 'string', 'udp', 'Connection protocol (udp/tcp)', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='protocol');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '1194', 'Server port', true FROM protocols p WHERE p.slug='openvpn' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '8388', 'Server port', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='server_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'password', 'string', '', 'Connection password', true FROM protocols p WHERE p.slug='shadowsocks' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='password');

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
('de','protocols','template_editor_help','Verwenden Sie Platzhalter wie {{variable}} und sehen Sie die Client‑Ausgabe in der Vorschau'),
('fr','protocols','template_editor_help','Utilisez des placeholders comme {{variable}} et prévisualisez la sortie client'),
('zh','protocols','template_editor_help','使用如 {{variable}} 的占位符并预览客户端输出'),
('en','protocols','variable_private_key_help','Client private key'),
('ru','protocols','variable_private_key_help','Приватный ключ клиента'),
('es','protocols','variable_private_key_help','Clave privada del cliente'),
('de','protocols','variable_private_key_help','Privater Schlüssel des Clients'),
('fr','protocols','variable_private_key_help','Clé privée du client'),
('zh','protocols','variable_private_key_help','客户端私钥'),
('en','protocols','variable_public_key_help','Server public key'),
('ru','protocols','variable_public_key_help','Публичный ключ сервера'),
('es','protocols','variable_public_key_help','Clave pública del servidor'),
('de','protocols','variable_public_key_help','Öffentlicher Schlüssel des Servers'),
('fr','protocols','variable_public_key_help','Clé publique du serveur'),
('zh','protocols','variable_public_key_help','服务器公钥'),
('en','protocols','variable_client_ip_help','Client IP address'),
('ru','protocols','variable_client_ip_help','IP‑адрес клиента'),
('es','protocols','variable_client_ip_help','Dirección IP del cliente'),
('de','protocols','variable_client_ip_help','IP‑Adresse des Clients'),
('fr','protocols','variable_client_ip_help','Adresse IP du client'),
('zh','protocols','variable_client_ip_help','客户端 IP 地址'),
('en','protocols','variable_server_host_help','VPN server host'),
('ru','protocols','variable_server_host_help','Хост VPN‑сервера'),
('es','protocols','variable_server_host_help','Host del servidor VPN'),
('de','protocols','variable_server_host_help','VPN‑Server‑Host'),
('fr','protocols','variable_server_host_help','Hôte du serveur VPN'),
('zh','protocols','variable_server_host_help','VPN 服务器主机'),
('en','protocols','variable_server_port_help','VPN server port'),
('ru','protocols','variable_server_port_help','Порт VPN‑сервера'),
('es','protocols','variable_server_port_help','Puerto del servidor VPN'),
('de','protocols','variable_server_port_help','VPN‑Server‑Port'),
('fr','protocols','variable_server_port_help','Port du serveur VPN'),
('zh','protocols','variable_server_port_help','VPN 服务器端口'),
('en','protocols','variable_preshared_key_help','WireGuard preshared key'),
('ru','protocols','variable_preshared_key_help','Предварительно общий ключ WireGuard'),
('es','protocols','variable_preshared_key_help','Clave precompartida de WireGuard'),
('de','protocols','variable_preshared_key_help','WireGuard‑vorausgeteilter Schlüssel'),
('fr','protocols','variable_preshared_key_help','Clé prépartagée WireGuard'),
('zh','protocols','variable_preshared_key_help','WireGuard 预共享密钥')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en','ai','enter_protocol_id_to_apply','Enter protocol ID to apply'),
('ru','ai','enter_protocol_id_to_apply','Введите ID протокола для применения'),
('es','ai','enter_protocol_id_to_apply','Introduce el ID de protocolo para aplicar'),
('de','ai','enter_protocol_id_to_apply','Protokoll‑ID zum Anwenden eingeben'),
('fr','ai','enter_protocol_id_to_apply','Saisissez l’ID du protocole à appliquer'),
('zh','ai','enter_protocol_id_to_apply','输入要应用的协议 ID'),
('en','ai','improve_protocol','Improve protocol script for'),
('ru','ai','improve_protocol','Улучшить скрипт протокола для'),
('es','ai','improve_protocol','Mejorar script del protocolo для'),
('de','ai','improve_protocol','Protokollskript verbessern für'),
('fr','ai','improve_protocol','Améliorer le script du protocole pour'),
('zh','ai','improve_protocol','改进协议脚本：'),
('en','protocols','enter_protocol_name','Enter protocol name'),
('ru','protocols','enter_protocol_name','Введите имя протокола'),
('es','protocols','enter_protocol_name','Introduce el nombre del protocolo'),
('de','protocols','enter_protocol_name','Protokollnamen eingeben'),
('fr','protocols','enter_protocol_name','Saisissez le nom du protocole'),
('zh','protocols','enter_protocol_name','输入协议名称'),
('en','protocols','enter_protocol_slug','Enter protocol slug'),
('ru','protocols','enter_protocol_slug','Введите slug протокола'),
('es','protocols','enter_protocol_slug','Introduce el slug del protocolo'),
('de','protocols','enter_protocol_slug','Protokoll‑Slug eingeben'),
('fr','protocols','enter_protocol_slug','Saisissez le slug du protocole'),
('zh','protocols','enter_protocol_slug','输入协议 slug'),
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
('zh','protocols','error_creating_protocol','创建协议时出错')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
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
('zh','settings','protocol_management','协议管理')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en','protocols','test_install','Test install'),
('ru','protocols','test_install','Протестировать установку'),
('es','protocols','test_install','Probar instalación'),
('de','protocols','test_install','Installation testen'),
('fr','protocols','test_install','Tester l’installation'),
('zh','protocols','test_install','测试安装'),
('en','protocols','testing_on_ubuntu22','Testing on Ubuntu 22.04 in isolated Docker'),
('ru','protocols','testing_on_ubuntu22','Тест на Ubuntu 22.04 в изолированном Docker'),
('es','protocols','testing_on_ubuntu22','Prueba en Ubuntu 22.04 en Docker aislado'),
('de','protocols','testing_on_ubuntu22','Test auf Ubuntu 22.04 in isoliertem Docker'),
('fr','protocols','testing_on_ubuntu22','Test sur Ubuntu 22.04 dans Docker isolé'),
('zh','protocols','testing_on_ubuntu22','在隔离的 Docker 中于 Ubuntu 22.04 测试'),
('en','protocols','test_result','Test result'),
('ru','protocols','test_result','Результат теста'),
('es','protocols','test_result','Resultado de la prueba'),
('de','protocols','test_result','Testergebnis'),
('fr','protocols','test_result','Résultat du test'),
('zh','protocols','test_result','测试结果'),
('en','protocols','client_output_preview','Client output preview'),
('ru','protocols','client_output_preview','Предпросмотр ответа клиенту'),
('es','protocols','client_output_preview','Vista previa de salida del cliente'),
('de','protocols','client_output_preview','Client‑Ausgabevorschau'),
('fr','protocols','client_output_preview','Aperçu de la sortie client'),
('zh','protocols','client_output_preview','客户端输出预览'),
('en','protocols','test_failed','Test failed'),
('ru','protocols','test_failed','Ошибка теста'),
('es','protocols','test_failed','La prueba falló'),
('de','protocols','test_failed','Test fehlgeschlagen'),
('fr','protocols','test_failed','Échec du test'),
('zh','protocols','test_failed','测试失败')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active, created_at, updated_at)
SELECT 'SMB Server', 'smb', 'Samba SMB file share inside Docker with random host port', '#!/bin/bash\n\nset -euo pipefail\nset -x\n\nCONTAINER_NAME="${CONTAINER_NAME:-amnezia-smb}"\nPORT_RANGE_START=${PORT_RANGE_START:-30000}\nPORT_RANGE_END=${PORT_RANGE_END:-65000}\nSMB_PORT=$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))\n\n docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true\nmkdir -p /opt/amnezia/smb/share\n docker run -d \\\n  --name "$CONTAINER_NAME" \\\n  -p "${SMB_PORT}:445" \\\n  -v /opt/amnezia/smb/share:/share \\\n  dperson/samba -p -u "amnezia;amnezia" -s "share;/share;yes;no;no;amnezia"\n echo "Port: ${SMB_PORT}"\n echo "Password: amnezia"\n', 'smb://{{server_host}}:{{server_port}}/share\nUsername: amnezia\nPassword: {{password}}', true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='smb');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_host', 'string', '127.0.0.1', 'Server hostname or IP', true FROM protocols WHERE slug = 'smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='smb') AND variable_name='server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_port', 'number', '445', 'Server port', true FROM protocols WHERE slug = 'smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='smb') AND variable_name='server_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'password', 'string', '', 'Connection password', true FROM protocols WHERE slug = 'smb' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='smb') AND variable_name='password');

INSERT INTO protocols (name, slug, description, install_script, output_template, ubuntu_compatible, is_active, created_at, updated_at)
SELECT 'XRay VLESS', 'xray-vless', 'XRay VLESS server inside Docker with generated client UUID', '#!/bin/bash\n\nset -euo pipefail\nset -x\n\nCONTAINER_NAME="${CONTAINER_NAME:-amnezia-xray}"\nPORT_RANGE_START=${PORT_RANGE_START:-30000}\nPORT_RANGE_END=${PORT_RANGE_END:-65000}\nXRAY_PORT=$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))\nCLIENT_ID=$(cat /proc/sys/kernel/random/uuid)\n docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true\nmkdir -p /opt/amnezia/xray\n cat > /opt/amnezia/xray/config.json << EOF\n{\n  "inbounds": [\n    {\n      "listen": "0.0.0.0",\n      "port": 443,\n      "protocol": "vless",\n      "settings": {\n        "clients": [\n          { "id": "${CLIENT_ID}" }\n        ],\n        "decryption": "none"\n      },\n      "streamSettings": {\n        "network": "tcp",\n        "security": "none"\n      }\n    }\n  ],\n  "outbounds": [\n    { "protocol": "freedom" }\n  ]\n}\nEOF\n docker run -d \\\n  --name "$CONTAINER_NAME" \\\n  --restart always \\\n  -p "${XRAY_PORT}:443" \\\n  -v /opt/amnezia/xray:/etc/xray \\\n  teddysun/xray\n echo "Port: ${XRAY_PORT}"\n echo "ClientID: ${CLIENT_ID}"\n', 'vless://{{client_id}}@{{server_host}}:{{server_port}}?security=none&type=tcp', true, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug='xray-vless');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_host', 'string', '127.0.0.1', 'Server hostname or IP', true FROM protocols WHERE slug = 'xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'server_port', 'number', '443', 'Server port', true FROM protocols WHERE slug = 'xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='server_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT id, 'client_id', 'string', '', 'VLESS client ID (UUID)', true FROM protocols WHERE slug = 'xray-vless' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = (SELECT id FROM protocols WHERE slug='xray-vless') AND variable_name='client_id');

INSERT INTO schema_migrations (filename, checksum) VALUES ('015_fix_awg_script.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('016_fix_awg_recovery.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('017_fix_awg_script_exit_code.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('018_fix_awg_final.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('019_fix_awg_heredoc.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('020_fix_awg_params.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('021_fix_awg_h_params.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('022_fix_awg_peer.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('023_ensure_container_running.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('024_fix_xray_ports.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('025_xray_reality.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, description, required)
SELECT (SELECT id FROM protocols WHERE slug = 'xray-vless'), 'reality_public_key', 'string', 'Reality public key (base64url)', true
WHERE NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug = 'xray-vless') AND variable_name='reality_public_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, description, required)
SELECT (SELECT id FROM protocols WHERE slug = 'xray-vless'), 'reality_short_id', 'string', 'Reality shortId', true
WHERE NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug = 'xray-vless') AND variable_name='reality_short_id');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, description, required)
SELECT (SELECT id FROM protocols WHERE slug = 'xray-vless'), 'reality_server_name', 'string', 'SNI server name for Reality', true
WHERE NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=(SELECT id FROM protocols WHERE slug = 'xray-vless') AND variable_name='reality_server_name');

INSERT INTO schema_migrations (filename, checksum) VALUES ('026_xray_uninstall_script.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('027_update_xray_install_script.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('028_fix_xray_install_keys.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('029_xray_respect_server_port.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('030_xray_default_port_443.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('031_add_qr_code_templates.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('032_add_qr_code_translations.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add translations for QR code template UI
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'qr_code_template', 'QR Code Template'),
('en', 'protocols', 'qr_code_format', 'QR Code Format'),
('en', 'protocols', 'qr_code_format_help', 'Select the format for the QR code payload. "Amnezia Compressed" uses the legacy Qt/QDataStream format. "Raw Content" uses the template output directly.'),
('en', 'protocols', 'qr_code_template_help', 'Template for the QR code payload. Use {{last_config_json}} to include the full configuration as a JSON object.'),
('en', 'protocols', 'variable_last_config_json_help', 'Full configuration as a JSON object (required for Amnezia format)'),
('en', 'protocols', 'plus_all_output_variables', 'Plus all variables from the Output Template section'),
('en', 'ai', 'prompt_placeholder_qr_template', 'Describe how the QR code payload should be structured (e.g., "Standard WireGuard config format" or "JSON with specific fields")')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('033_add_protocol_editor_translations.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add Russian translations for Protocol Editor
INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'edit_protocol', 'Редактирование протокола'),
('ru', 'protocols', 'create_protocol', 'Создание протокола'),
('ru', 'protocols', 'edit_protocol_description', 'Изменение настроек и скриптов протокола'),
('ru', 'protocols', 'create_protocol_description', 'Добавление нового протокола в систему'),
('ru', 'protocols', 'back_to_protocols', 'К списку протоколов'),
('ru', 'protocols', 'basic_information', 'Основная информация'),
('ru', 'protocols', 'name_label', 'Название'),
('ru', 'protocols', 'name_help', 'Отображаемое имя протокола'),
('ru', 'protocols', 'slug_label', 'Слаг (ID)'),
('ru', 'protocols', 'slug_help', 'Уникальный идентификатор (латиница, цифры, дефис)'),
('ru', 'protocols', 'description_help', 'Краткое описание протокола'),
('ru', 'protocols', 'installation_script', 'Скрипт установки'),
('ru', 'protocols', 'install_script_help', 'Bash скрипт, который будет выполнен при установке протокола'),
('ru', 'protocols', 'uninstallation_script', 'Скрипт удаления'),
('ru', 'protocols', 'uninstall_script_help', 'Bash скрипт, который будет выполнен при удалении протокола'),
('ru', 'protocols', 'test_install', 'Тест установки'),
('ru', 'protocols', 'test_uninstall', 'Тест удаления'),
('ru', 'protocols', 'testing_on_ubuntu22', 'Тестирование на Ubuntu 22.04 (Docker)'),
('ru', 'protocols', 'test_result', 'Результат выполнения'),
('ru', 'protocols', 'client_output_preview', 'Предпросмотр конфига клиента'),
('ru', 'protocols', 'output_template', 'Шаблон конфигурации'),
('ru', 'protocols', 'output_template_help', 'Шаблон для генерации файла конфигурации клиента. Используйте переменные {{variable}}'),
('ru', 'protocols', 'available_variables', 'Доступные переменные'),
('ru', 'protocols', 'variable_private_key_help', 'Приватный ключ клиента'),
('ru', 'protocols', 'variable_public_key_help', 'Публичный ключ сервера'),
('ru', 'protocols', 'variable_client_ip_help', 'IP-адрес клиента'),
('ru', 'protocols', 'variable_server_host_help', 'Хост сервера (IP или домен)'),
('ru', 'protocols', 'variable_server_port_help', 'Порт сервера'),
('ru', 'protocols', 'variable_preshared_key_help', 'Дополнительный ключ шифрования (PSK)'),
('ru', 'protocols', 'variable_last_config_json_help', 'Полная конфигурация в формате JSON (для Amnezia)'),
('ru', 'protocols', 'plus_all_output_variables', 'Плюс все переменные из шаблона конфигурации'),
('ru', 'protocols', 'qr_code_template', 'Шаблон QR-кода'),
('ru', 'protocols', 'qr_code_template_help', 'Шаблон для формирования содержимого QR-кода'),
('ru', 'protocols', 'qr_code_format', 'Формат QR-кода'),
('ru', 'protocols', 'qr_code_format_help', 'Выберите формат данных в QR-коде'),
('ru', 'protocols', 'password_generation', 'Генерация пароля'),
('ru', 'protocols', 'password_command_help', 'Команда для генерации пароля/ключа (выполняется перед установкой)'),
('ru', 'protocols', 'ubuntu_compatible', 'Совместим с Ubuntu'),
('ru', 'protocols', 'active_label', 'Активен'),
('ru', 'protocols', 'update_protocol', 'Обновить протокол'),
('ru', 'protocols', 'save_protocol', 'Сохранить протокол'),
('ru', 'protocols', 'please_fill_required_fields', 'Пожалуйста, заполните обязательные поля'),
('ru', 'protocols', 'invalid_slug_format', 'Неверный формат слага'),
('ru', 'ai', 'get_ai_help', 'Помощь AI'),
('ru', 'ai', 'assistant', 'AI Ассистент'),
('ru', 'ai', 'select_model', 'Выберите модель'),
('ru', 'ai', 'model_gpt35_turbo', 'GPT-3.5 Turbo'),
('ru', 'ai', 'model_gpt4', 'GPT-4'),
('ru', 'ai', 'model_claude3_haiku', 'Claude 3 Haiku'),
('ru', 'ai', 'model_claude3_sonnet', 'Claude 3 Sonnet'),
('ru', 'ai', 'custom_model_placeholder', 'Или введите имя модели вручную'),
('ru', 'ai', 'check_availability', 'Проверить'),
('ru', 'ai', 'protocol_type', 'Тип протокола'),
('ru', 'ai', 'general_vpn', 'Общий VPN'),
('ru', 'ai', 'describe_requirements', 'Опишите требования'),
('ru', 'ai', 'prompt_placeholder', 'Например: Скрипт для установки Shadowsocks на порт 8388...'),
('ru', 'ai', 'prompt_placeholder_template', 'Например: Конфиг в формате JSON с полями server, port, password...'),
('ru', 'ai', 'prompt_placeholder_qr_template', 'Например: Ссылка вида vless://uuid@host:port...'),
('ru', 'ai', 'prompt_placeholder_uninstall', 'Например: Остановить docker контейнер и удалить файлы...'),
('ru', 'ai', 'generate_script', 'Сгенерировать'),
('ru', 'ai', 'generating_script', 'Генерация...'),
('ru', 'ai', 'generated_script', 'Результат'),
('ru', 'ai', 'suggestions', 'Предложения'),
('ru', 'ai', 'apply_to_current_protocol', 'Применить'),
('ru', 'ai', 'confirm_apply_script', 'Это заменит текущее содержимое поля. Продолжить?'),
('ru', 'ai', 'please_enter_requirements', 'Пожалуйста, введите требования'),
('ru', 'ai', 'error_generating_script', 'Ошибка генерации')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('034_add_show_text_content.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add translations
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'show_text_content', 'Show text content on client page'),
('en', 'protocols', 'qr_code_format_text', 'Simple Text'),
('ru', 'protocols', 'show_text_content', 'Показывать текстовое содержимое на странице клиента'),
('ru', 'protocols', 'qr_code_format_text', 'Простой текст')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('035_restore_awg_script.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('036_fix_awg_script_output.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('037_fix_awg_mtu_1280.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('039_fix_awg_client_template.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Create capital letter variables that map to lowercase ones
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'Jc', 'number', '5', 'Junk packet count', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='Jc');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'Jmin', 'number', '100', 'Minimum junk packet size', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='Jmin');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'Jmax', 'number', '200', 'Maximum junk packet size', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='Jmax');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'S1', 'number', '50', 'Junk packet size 1', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='S1');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'S2', 'number', '100', 'Junk packet size 2', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='S2');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'H1', 'number', '1', 'Obfuscation header 1', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='H1');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'H2', 'number', '2', 'Obfuscation header 2', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='H2');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'H3', 'number', '3', 'Obfuscation header 3', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='H3');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'H4', 'number', '4', 'Obfuscation header 4', false FROM protocols p WHERE p.slug='amnezia-wg-advanced' AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id=p.id AND variable_name='H4');

INSERT INTO schema_migrations (filename, checksum) VALUES ('040_remove_uppercase_variables.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('041_add_ssh_key_column.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('042_fix_xray_variable_expansion.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('043_fix_xray_json_quotes.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('044_add_xray_flow.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('045_xray_port_443.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('046_fix_xray_docker_run.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('047_create_protocols_table.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- 2. Insert Data (amnezia-wg removed - use amnezia-wg-advanced instead)
INSERT INTO protocols (slug, name, description, definition, show_text_content, is_active) VALUES
('wireguard', 'WireGuard', 'Standard WireGuard', '{}', 0, 1),
('openvpn', 'OpenVPN', 'Standard OpenVPN', '{}', 0, 1),
('shadowsocks', 'Shadowsocks', 'Shadowsocks proxy', '{}', 0, 1),
('cloak', 'Cloak', 'Cloak obfuscation', '{}', 0, 1);

INSERT INTO schema_migrations (filename, checksum) VALUES ('048_enable_xray_stats.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('049_add_dns_servers.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('050_fix_awg_random_params.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('051_fix_awg_fresh_install.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('052_add_current_speed_to_clients.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('053_split_speed.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('054_xray_single_ip_enforcement.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('055_dashboard_online_now_translation.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add translation for dashboard.online_now
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'dashboard', 'online_now', 'Online Now'),
('ru', 'dashboard', 'online_now', 'Сейчас онлайн'),
('es', 'dashboard', 'online_now', 'En línea ahora'),
('de', 'dashboard', 'online_now', 'Jetzt online'),
('fr', 'dashboard', 'online_now', 'En ligne maintenant'),
('zh', 'dashboard', 'online_now', '当前在线')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('056_enable_show_text_content_for_xray.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('057_add_protocol_management_translations.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add missing translations for protocol management UI (EN/RU)
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'management', 'Protocol Management'),
('ru', 'protocols', 'management', 'Управление протоколами'),
('en', 'protocols', 'management_description', 'Configure and manage VPN protocols'),
('ru', 'protocols', 'management_description', 'Настройка и управление VPN-протоколами'),
('en', 'common', 'active', 'Active'),
('ru', 'common', 'active', 'Активный'),
('en', 'common', 'inactive', 'Inactive'),
('ru', 'common', 'inactive', 'Неактивный'),
('en', 'protocols', 'add_protocol', 'Add Protocol'),
('ru', 'protocols', 'add_protocol', 'Добавить протокол'),
('en', 'common', 'settings', 'Settings'),
('ru', 'common', 'settings', 'Настройки'),
('en', 'protocols', 'available_protocols', 'Available Protocols'),
('ru', 'protocols', 'available_protocols', 'Доступные протоколы'),
('en', 'protocols', 'search_protocols', 'Search protocols'),
('ru', 'protocols', 'search_protocols', 'Поиск протоколов'),
('en', 'protocols', 'all_protocols', 'All Protocols'),
('ru', 'protocols', 'all_protocols', 'Все протоколы'),
('en', 'protocols', 'active_only', 'Active only'),
('ru', 'protocols', 'active_only', 'Только активные'),
('en', 'protocols', 'with_ai_generations', 'With AI generations'),
('ru', 'protocols', 'with_ai_generations', 'С AI-генерациями')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('058_add_awg2_protocol.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- =====================================================================
-- Migration 058: Add AmneziaWG 2.0 protocol (amneziawg-go userspace)
-- Uses amneziawg-go (Go userspace) instead of kernel module
-- https://github.com/amnezia-vpn/amneziawg-go
-- =====================================================================

-- 1. Insert the protocol entry (clone output_template from amnezia-wg-advanced)
INSERT INTO protocols (name, slug, description, install_script, uninstall_script, output_template, ubuntu_compatible, is_active, definition, created_at, updated_at)
SELECT
  'AmneziaWG 2.0',
  'awg2',
  'AmneziaWG 2.0 — userspace Go implementation (amneziawg-go). No kernel module required.',
  '#!/bin/bash
set -euo pipefail

# Use exported variables from panel (SERVER_PORT, SERVER_CONTAINER) or defaults
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-awg2}"
PORT_RANGE_START=${PORT_RANGE_START:-30000}
PORT_RANGE_END=${PORT_RANGE_END:-65000}
VPN_PORT="${SERVER_PORT:-$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))}"
MTU=${MTU:-1420}

# Install git if not available
if ! command -v git &> /dev/null; then
  apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1
fi

mkdir -p /opt/amnezia/awg2

# Clone amneziawg-go source for Docker build
if [ ! -d /opt/amnezia/awg2/src ]; then
  git clone --depth=1 https://github.com/amnezia-vpn/amneziawg-go.git /opt/amnezia/awg2/src
fi

# Build Docker image using the repo Dockerfile (multi-stage: Go compile + tools)
docker build -t amnezia-awg2 /opt/amnezia/awg2/src

# Run container (userspace: no SYS_MODULE, no /lib/modules)
EXISTING=$(docker ps -aq -f "name=$CONTAINER_NAME" 2>/dev/null | head -1)
if [ -z "$EXISTING" ]; then
  docker run -d --name "$CONTAINER_NAME" --restart always --cap-add=NET_ADMIN --device /dev/net/tun -p "${VPN_PORT}:${VPN_PORT}/udp" -v /opt/amnezia/awg2:/opt/amnezia/awg amnezia-awg2 sh -c "while [ ! -f /opt/amnezia/awg/wg0.conf ]; do sleep 1; done; WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go awg-quick up /opt/amnezia/awg/wg0.conf && sleep infinity"

  sleep 2
else
  STATUS=$(docker inspect --format="{{.State.Status}}" "$CONTAINER_NAME" 2>/dev/null || echo "")
  if [ \"$STATUS\" != \"running\" ]; then
    docker start \"$CONTAINER_NAME\" >/dev/null 2>&1 || true
  fi
fi

# Check for existing config
if [ -f /opt/amnezia/awg2/wg0.conf ]; then
  PORT=$(grep -E "^ListenPort" /opt/amnezia/awg2/wg0.conf | cut -d= -f2 | tr -d "[:space:]")
  PSK=$(cat /opt/amnezia/awg2/wireguard_psk.key 2>/dev/null || true)
  if [ -z "$PSK" ]; then
    PSK=$(grep -E "^PresharedKey" /opt/amnezia/awg2/wg0.conf | cut -d= -f2 | tr -d "[:space:]")
  fi
  PUBKEY=$(cat /opt/amnezia/awg2/wireguard_server_public_key.key 2>/dev/null || true)
  if [ -z "$PUBKEY" ]; then
    PRIVKEY=$(cat /opt/amnezia/awg2/wireguard_server_private_key.key 2>/dev/null || true)
    if [ -n "$PRIVKEY" ]; then
      PUBKEY=$(echo "$PRIVKEY" | docker exec -i "$CONTAINER_NAME" wg pubkey)
    fi
  fi

  echo "Using existing AmneziaWG 2.0 configuration"
  echo "Port: ${PORT:-$VPN_PORT}"
  if [ -n "${PUBKEY:-}" ]; then echo "Server Public Key: $PUBKEY"; fi
  if [ -n "${PSK:-}" ]; then echo "PresharedKey = $PSK"; fi

  EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")
  echo "Server Host: $EXTERNAL_IP"

  # Output AWG params from existing config
  for P in Jc Jmin Jmax S1 S2 S3 S4 H1 H2 H3 H4; do
    VAL=$(grep -E "^$P " /opt/amnezia/awg2/wg0.conf | cut -d= -f2 | tr -d "[:space:]")
    if [ -n "$VAL" ]; then echo "Variable: $P=$VAL"; fi
  done
  echo "Variable: dns_servers=1.1.1.1, 1.0.0.1"
  exit 0
fi

# Generate keys
PRIVATE_KEY=$(docker exec "$CONTAINER_NAME" wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | docker exec -i "$CONTAINER_NAME" wg pubkey)
PRESHARED_KEY=$(docker exec "$CONTAINER_NAME" wg genpsk)

# AWG obfuscation parameters
JC=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(3+rand()*(10-3+1))}')
JMIN=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(10+rand()*(50-10+1))}')
JMAX=$(awk -v seed=$RANDOM -v jmin=$JMIN 'BEGIN{srand(seed); print int(jmin+rand()*(1000-jmin+1))}')
S1_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(15+rand()*(50-15+1))}')
S2_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(110+rand()*(150-110+1))}')
S3_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(110+rand()*(150-110+1))}')
S4_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(5+rand()*(40-5+1))}')
# H1-H4: keep numeric values for broad awg-tools compatibility.
H1_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}')
H2_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}')
H3_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}')
H4_VAL=$(awk -v seed=$RANDOM 'BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}')

# Write config
cat > /opt/amnezia/awg2/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.8.1.1/24
ListenPort = $VPN_PORT
MTU = $MTU
Jc = $JC
Jmin = $JMIN
Jmax = $JMAX
S1 = $S1_VAL
S2 = $S2_VAL
S3 = $S3_VAL
S4 = $S4_VAL
H1 = $H1_VAL
H2 = $H2_VAL
H3 = $H3_VAL
H4 = $H4_VAL
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

echo "$PRIVATE_KEY" > /opt/amnezia/awg2/wireguard_server_private_key.key
echo "$PUBLIC_KEY" > /opt/amnezia/awg2/wireguard_server_public_key.key
echo "$PRESHARED_KEY" > /opt/amnezia/awg2/wireguard_psk.key
echo "[]" > /opt/amnezia/awg2/clientsTable

# Get external IP
EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

echo "AmneziaWG 2.0 installed successfully"
echo "Port: $VPN_PORT"
echo "Server Public Key: $PUBLIC_KEY"
echo "PresharedKey = $PRESHARED_KEY"
echo "Server Host: $EXTERNAL_IP"
echo "Variable: Jc=$JC"
echo "Variable: Jmin=$JMIN"
echo "Variable: Jmax=$JMAX"
echo "Variable: S1=$S1_VAL"
echo "Variable: S2=$S2_VAL"
echo "Variable: S3=$S3_VAL"
echo "Variable: S4=$S4_VAL"
echo "Variable: H1=$H1_VAL"
echo "Variable: H2=$H2_VAL"
echo "Variable: H3=$H3_VAL"
echo "Variable: H4=$H4_VAL"
echo "Variable: dns_servers=1.1.1.1, 1.0.0.1"',
  '#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-amnezia-awg2}"

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
docker image rm amnezia-awg2 2>/dev/null || true
rm -rf /opt/amnezia/awg2 2>/dev/null || true

echo "{\"success\":true,\"message\":\"AmneziaWG 2.0 uninstalled\"}"',
  p.output_template,
  1,
  1,
  json_build_object(
    'engine', 'shell',
    'metadata', json_build_object(
      'container_name', 'amnezia-awg2',
      'vpn_subnet', '10.8.1.0/24',
      'port_range', json_build_array(30000, 65000),
      'config_dir', '/opt/amnezia/awg2'
    )
  ),
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM protocols p
WHERE p.slug = 'amnezia-wg-advanced'
  AND NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'awg2');

-- 2. Clone protocol variables from amnezia-wg-advanced to awg2
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT 
  (SELECT id FROM protocols WHERE slug = 'awg2' LIMIT 1),
  src.variable_name,
  src.variable_type,
  src.default_value,
  src.description,
  src.required
FROM protocol_variables src
WHERE src.protocol_id = (SELECT id FROM protocols WHERE slug = 'amnezia-wg-advanced' LIMIT 1)
  AND NOT EXISTS (
    SELECT 1 FROM protocol_variables ev
    WHERE ev.protocol_id = (SELECT id FROM protocols WHERE slug = 'awg2' LIMIT 1)
      AND ev.variable_name = src.variable_name
  );

-- 3. Clone protocol templates from amnezia-wg-advanced to awg2
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT
  (SELECT id FROM protocols WHERE slug = 'awg2' LIMIT 1),
  src.template_name,
  src.template_content,
  src.is_default
FROM protocol_templates src
WHERE src.protocol_id = (SELECT id FROM protocols WHERE slug = 'amnezia-wg-advanced' LIMIT 1)
  AND NOT EXISTS (
    SELECT 1 FROM protocol_templates et
    WHERE et.protocol_id = (SELECT id FROM protocols WHERE slug = 'awg2' LIMIT 1)
      AND et.template_name = src.template_name
  );

-- 6. Add S3/S4 protocol variables for awg2
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'S3', 'number', '20', 'Padding of handshake cookie message', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'S3');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'S4', 'number', '10', 'Padding of transport messages', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'S4');

INSERT INTO schema_migrations (filename, checksum) VALUES ('059_add_mtproxy_protocol.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- =====================================================================
-- Migration 059: Add MTProxy (Telegram) protocol
-- https://hub.docker.com/r/telegrammessenger/proxy/
-- Zero-configuration Telegram MTProto proxy server
-- =====================================================================

-- 1. Insert the MTProxy protocol
INSERT INTO protocols (name, slug, description, install_script, uninstall_script, output_template, show_text_content, ubuntu_compatible, is_active, definition, created_at, updated_at)
SELECT
  'MTProxy (Telegram)',
  'mtproxy',
  'Telegram MTProto proxy — zero-configuration proxy server for Telegram messenger.',
  '#!/bin/bash
set -euo pipefail

# Use exported variables from panel (SERVER_PORT, SERVER_CONTAINER) or defaults
CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-mtproxy}"
PORT_RANGE_START=${PORT_RANGE_START:-30000}
PORT_RANGE_END=${PORT_RANGE_END:-65000}
MTPROXY_PORT="${SERVER_PORT:-$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))}"

mkdir -p /opt/amnezia/mtproxy

# Generate secret if not exists
if [ -f /opt/amnezia/mtproxy/secret ]; then
  SECRET=$(cat /opt/amnezia/mtproxy/secret)
  echo "Using existing MTProxy secret"
else
  SECRET=$(cat /dev/urandom | tr -dc a-f0-9 | head -c 32 || true)
  echo "$SECRET" > /opt/amnezia/mtproxy/secret
fi

# Store port
echo "$MTPROXY_PORT" > /opt/amnezia/mtproxy/port

# Remove existing container
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Run MTProxy container (single line for heredoc compatibility)
docker run -d --name "$CONTAINER_NAME" --restart always -p "${MTPROXY_PORT}:443" -v /opt/amnezia/mtproxy:/data -e SECRET="$SECRET" telegrammessenger/proxy:latest

sleep 3

# Get external IP
EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

echo "MTProxy installed successfully"
echo "Port: $MTPROXY_PORT"
echo "Secret: $SECRET"
echo "Server Host: $EXTERNAL_IP"',
  '#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-amnezia-mtproxy}"

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
docker image rm telegrammessenger/proxy:latest 2>/dev/null || true
rm -rf /opt/amnezia/mtproxy 2>/dev/null || true

echo "{\"success\":true,\"message\":\"MTProxy uninstalled\"}"',
  'tg://proxy?server={{server_host}}&port={{server_port}}&secret={{secret}}',
  1,
  1,
  1,
  json_build_object(
    'engine', 'shell',
    'metadata', json_build_object(
      'container_name', 'amnezia-mtproxy',
      'port_range', json_build_array(30000, 65000),
      'config_dir', '/opt/amnezia/mtproxy'
    )
  ),
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'mtproxy');

-- 2. Add protocol variables for MTProxy
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'secret', 'string', '', 'MTProxy secret (32 hex chars)', true
FROM protocols p WHERE p.slug = 'mtproxy'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'secret');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true
FROM protocols p WHERE p.slug = 'mtproxy'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '443', 'MTProxy external port', true
FROM protocols p WHERE p.slug = 'mtproxy'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'server_port');

-- 3. Add default template for MTProxy
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default MTProxy', 'tg://proxy?server={{server_host}}&port={{server_port}}&secret={{secret}}', true
FROM protocols p WHERE p.slug = 'mtproxy'
  AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id = p.id AND template_name = 'Default MTProxy');

-- 5. Add translations for MTProxy
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'protocol_mtproxy', 'MTProxy (Telegram)')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'protocol_mtproxy', 'MTProxy (Telegram)')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('060_add_aivpn_protocol.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- =====================================================================
-- Migration 060: Add AIVPN protocol (AI-powered VPN with traffic disguise)
-- https://github.com/infosave2007/aivpn
-- Neural Resonance AI for DPI bypass, Zero-RTT, PFS
-- =====================================================================

-- 1. Insert the AIVPN protocol
INSERT INTO protocols (name, slug, description, install_script, uninstall_script, output_template, show_text_content, ubuntu_compatible, is_active, definition, created_at, updated_at)
SELECT
  'AIVPN',
  'aivpn',
  'AIVPN — AI-powered VPN с маскировкой трафика под реальные приложения (Zoom, TikTok, DNS). Neural Resonance для обхода DPI.',
  '#!/bin/bash
set -euo pipefail

# Use exported variables from panel (SERVER_PORT, SERVER_CONTAINER) or defaults
CONTAINER_NAME="${SERVER_CONTAINER:-aivpn-server}"
VPN_PORT="${SERVER_PORT:-443}"
CONFIG_DIR="/etc/aivpn"

# Install git and iptables if not available
if ! command -v git &> /dev/null || ! command -v iptables &> /dev/null; then
  apt-get update -qq
  if ! command -v git &> /dev/null; then
    apt-get install -y -qq git >/dev/null 2>&1
  fi
  if ! command -v iptables &> /dev/null; then
    apt-get install -y -qq iptables >/dev/null 2>&1
  fi
fi

# Install Docker if not available
if ! command -v docker &> /dev/null; then
  apt-get update -qq
  apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null 2>&1
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq && apt-get install -y -qq docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
fi

mkdir -p "$CONFIG_DIR"

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true

# Generate server key if not exists
if [ ! -f "$CONFIG_DIR/server.key" ]; then
  openssl rand 32 > "$CONFIG_DIR/server.key"
  chmod 600 "$CONFIG_DIR/server.key"
  echo "Generated new AIVPN server key"
else
  echo "Using existing AIVPN server key"
fi

# Setup NAT
iptables -t nat -C POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE

# Get external IP
EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

# Clone AIVPN source for Docker build
if [ ! -d /opt/amnezia/aivpn ]; then
  git clone --depth=1 https://github.com/infosave2007/aivpn.git /opt/amnezia/aivpn
fi

# Build Docker image
cd /opt/amnezia/aivpn
docker build -t aivpn-server -f Dockerfile .

# Remove existing container
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Run AIVPN container
docker run -d --name "$CONTAINER_NAME" --restart always --cap-add=NET_ADMIN --device /dev/net/tun --network host -v "$CONFIG_DIR:/etc/aivpn" aivpn-server --listen "0.0.0.0:${VPN_PORT}" --key-file /etc/aivpn/server.key

sleep 3

# Check container status
STATUS=$(docker inspect --format="{{.State.Status}}" "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$STATUS" != "running" ]; then
  echo "ERROR: AIVPN container is not running"
  docker logs "$CONTAINER_NAME" 2>&1
  exit 1
fi

echo "AIVPN installed successfully"
# Output variables for the web panel parser
KEY_B64=$(base64 -w 0 "$CONFIG_DIR/server.key" 2>/dev/null || base64 "$CONFIG_DIR/server.key")
echo "Variable: connection_key=$KEY_B64"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Variable: server_port=$VPN_PORT"
echo "Variable: config_dir=$CONFIG_DIR"',
  '#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-aivpn-server}"

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
docker image rm aivpn-server 2>/dev/null || true
rm -rf /opt/amnezia/aivpn 2>/dev/null || true

# Remove NAT rules
iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true

echo "{\"success\":true,\"message\":\"AIVPN uninstalled\"}"',
  'aivpn://{{connection_key}}',
  1,
  1,
  1,
  json_build_object(
    'engine', 'shell',
    'metadata', json_build_object(
      'container_name', 'aivpn-server',
      'port_range', json_build_array(443, 443),
      'config_dir', '/etc/aivpn',
      'vpn_subnet', '10.0.0.0/24',
      'requires_docker_build', true,
      'git_repo', 'https://github.com/infosave2007/aivpn.git'
    )
  ),
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'aivpn');

-- 2. Add protocol variables for AIVPN
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'connection_key', 'string', '', 'AIVPN connection key (generated by server)', true
FROM protocols p WHERE p.slug = 'aivpn'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'connection_key');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true
FROM protocols p WHERE p.slug = 'aivpn'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_port', 'number', '443', 'AIVPN server port', true
FROM protocols p WHERE p.slug = 'aivpn'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'server_port');

-- 3. Add default template for AIVPN
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default AIVPN', 'aivpn://{{connection_key}}', true
FROM protocols p WHERE p.slug = 'aivpn'
  AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id = p.id AND template_name = 'Default AIVPN');

-- 4. Add translations for AIVPN
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'protocol_aivpn', 'AIVPN (AI-Powered)')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'protocol_aivpn', 'AIVPN (ИИ-протокол)')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('061_fix_client_connection_instructions_translation.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Ensure clients.connection_instructions exists in all locales used by UI.
-- Without this key, client view heading may be missing or fallback text can appear inconsistent.

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'clients', 'connection_instructions', 'Connection Instructions'),
('ru', 'clients', 'connection_instructions', 'Инструкции по подключению'),
('es', 'clients', 'connection_instructions', 'Instrucciones de conexión'),
('de', 'clients', 'connection_instructions', 'Verbindungsanweisungen'),
('fr', 'clients', 'connection_instructions', 'Instructions de connexion'),
('zh', 'clients', 'connection_instructions', '连接说明')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('062_add_aivpn_counter_offsets.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('063_fix_awg2_empty_peer_in_install_script.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('064_complete_awg2_original_params.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'I1', 'text', '<r 2><b 0x858000010001000000000669636c6f756403636f6d0000010001c00c000100010000105a00044d583737>', 'Original AmneziaWG packet template I1', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'I1');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'I2', 'text', '', 'Original AmneziaWG packet template I2', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'I2');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'I3', 'text', '', 'Original AmneziaWG packet template I3', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'I3');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'I4', 'text', '', 'Original AmneziaWG packet template I4', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'I4');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'I5', 'text', '', 'Original AmneziaWG packet template I5', false
FROM protocols p WHERE p.slug = 'awg2'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'I5');

INSERT INTO schema_migrations (filename, checksum) VALUES ('065_fix_aivpn_prebuilt_binary.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('066_add_cloudflare_warp_protocol.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- =====================================================================
-- Migration 066: Add Cloudflare WARP proxy protocol
-- Installs Cloudflare WARP on VPS and enables SOCKS5/HTTPS proxy mode
-- Creates chain: AmneziaWG → WARP (127.0.0.1:40000) → Internet
-- Adds DPI/censorship bypass layer via Cloudflare tunnel
-- =====================================================================

-- 1. Insert the Cloudflare WARP protocol
INSERT INTO protocols (name, slug, description, install_script, uninstall_script, output_template, show_text_content, ubuntu_compatible, is_active, definition, created_at, updated_at)
SELECT
  'Cloudflare WARP Proxy',
  'cf-warp',
  'Cloudflare WARP — прокси-слой для обхода DPI/цензуры. Устанавливает WARP на сервер в режиме SOCKS5 прокси (127.0.0.1:40000). Трафик идёт по цепочке: VPN-клиент → AmneziaWG → WARP → Cloudflare → Интернет. Скрывает конечные домены от провайдера VPS.',
  '#!/bin/bash
set -eo pipefail

# ======================================================================
# Cloudflare WARP Proxy Installer
# Installs WARP in proxy mode (SOCKS5 on 127.0.0.1:40000)
# For chain: AmneziaWG → WARP → Internet
# ======================================================================

WARP_PROXY_PORT="${WARP_PROXY_PORT:-40000}"
WARP_MODE="${WARP_MODE:-proxy}"

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Cloudflare WARP ==="

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID="$ID"
  OS_VERSION="$VERSION_ID"
else
  OS_ID="unknown"
  OS_VERSION="0"
fi

echo "Detected OS: $OS_ID $OS_VERSION"

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
  echo "ERROR: WARP supports only x86_64 and aarch64, got: $ARCH"
  exit 1
fi

# Install prerequisites
apt-get update -qq
apt-get install -y -qq curl gnupg lsb-release >/dev/null 2>&1

# Add Cloudflare WARP repository
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

# Determine correct repo codename
REPO_CODENAME=""
case "$OS_ID" in
  ubuntu)
    case "$OS_VERSION" in
      24.04) REPO_CODENAME="noble" ;;
      22.04) REPO_CODENAME="jammy" ;;
      20.04) REPO_CODENAME="focal" ;;
      *)     REPO_CODENAME="jammy" ;;
    esac
    ;;
  debian)
    case "$OS_VERSION" in
      12*) REPO_CODENAME="bookworm" ;;
      11*) REPO_CODENAME="bullseye" ;;
      *)   REPO_CODENAME="bookworm" ;;
    esac
    ;;
  *)
    REPO_CODENAME="jammy"
    echo "WARNING: Unsupported OS $OS_ID, trying Ubuntu Jammy repo"
    ;;
esac

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $REPO_CODENAME main" > /etc/apt/sources.list.d/cloudflare-client.list

# Install WARP client
apt-get update -qq
apt-get install -y -qq cloudflare-warp >/dev/null 2>&1

echo "WARP package installed"

# Check if already registered
WARP_STATUS=$(warp-cli --accept-tos status 2>/dev/null || echo "unregistered")

if echo "$WARP_STATUS" | grep -qiE "Registration Missing|unregistered"; then
  echo "Registering WARP..."
  warp-cli --accept-tos registration new
  echo "WARP registered"
else
  echo "WARP already registered"
fi

# Set proxy mode
echo "Setting WARP to proxy mode on port $WARP_PROXY_PORT..."
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port "$WARP_PROXY_PORT"

# Connect WARP
echo "Connecting WARP..."
warp-cli --accept-tos connect

# Wait for connection
for i in $(seq 1 15); do
  CONN_STATUS=$(warp-cli --accept-tos status 2>/dev/null || echo "")
  if echo "$CONN_STATUS" | grep -qi "Connected"; then
    echo "WARP connected successfully"
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "WARNING: WARP connection timeout, may still be connecting..."
  fi
  sleep 2
done

# Verify proxy is listening
sleep 2
if command -v ss >/dev/null 2>&1; then
  LISTENING=$(ss -tlnp 2>/dev/null | grep ":${WARP_PROXY_PORT}" || true)
elif command -v netstat >/dev/null 2>&1; then
  LISTENING=$(netstat -tlnp 2>/dev/null | grep ":${WARP_PROXY_PORT}" || true)
else
  LISTENING=""
fi

if [ -n "$LISTENING" ]; then
  echo "WARP SOCKS5 proxy listening on 127.0.0.1:${WARP_PROXY_PORT}"
else
  echo "WARNING: Proxy port ${WARP_PROXY_PORT} not yet listening, WARP may need more time"
fi

# Test proxy connectivity
PROXY_TEST=$(curl -x socks5h://127.0.0.1:${WARP_PROXY_PORT} -s -o /dev/null -w "%{http_code}" --max-time 10 https://cloudflare.com/cdn-cgi/trace 2>/dev/null || echo "000")
if [ "$PROXY_TEST" = "200" ]; then
  echo "WARP proxy test: OK (HTTP 200)"
else
  echo "WARNING: WARP proxy test returned HTTP $PROXY_TEST (may need a moment to initialize)"
fi

# Get WARP IP info
WARP_IP=$(curl -x socks5h://127.0.0.1:${WARP_PROXY_PORT} -s --max-time 10 https://cloudflare.com/cdn-cgi/trace 2>/dev/null | grep "ip=" | cut -d= -f2 || echo "unknown")
WARP_ACCOUNT=$(warp-cli --accept-tos registration show 2>/dev/null | grep -i "Account ID" | awk "{print \$NF}" || echo "unknown")

# Enable WARP service to start on boot
systemctl enable warp-svc 2>/dev/null || true

# Get server external IP
EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo "=== Cloudflare WARP Proxy Installed ==="
echo "Variable: warp_proxy_port=$WARP_PROXY_PORT"
echo "Variable: warp_mode=$WARP_MODE"
echo "Variable: warp_ip=$WARP_IP"
echo "Variable: warp_account=$WARP_ACCOUNT"
echo "Variable: server_host=$EXTERNAL_IP"
echo "Variable: proxy_address=127.0.0.1:${WARP_PROXY_PORT}"',
  '#!/bin/bash
set -eo pipefail

echo "=== Uninstalling Cloudflare WARP ==="

# Disconnect and deregister
warp-cli --accept-tos disconnect 2>/dev/null || true
warp-cli --accept-tos registration delete 2>/dev/null || true

# Stop service
systemctl stop warp-svc 2>/dev/null || true
systemctl disable warp-svc 2>/dev/null || true

# Remove package
apt-get remove -y cloudflare-warp 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# Clean up config
rm -rf /var/lib/cloudflare-warp 2>/dev/null || true
rm -f /etc/apt/sources.list.d/cloudflare-client.list 2>/dev/null || true
rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg 2>/dev/null || true

echo "{\"success\":true,\"message\":\"Cloudflare WARP uninstalled\"}"',
  'WARP SOCKS5 Proxy: socks5h://127.0.0.1:{{warp_proxy_port}}
WARP IP: {{warp_ip}}
Mode: {{warp_mode}}
Server: {{server_host}}',
  1,
  1,
  1,
  json_build_object(
    'engine', 'shell',
    'metadata', json_build_object(
      'container_name', '',
      'port_range', json_build_array(40000, 40000),
      'config_dir', '/var/lib/cloudflare-warp',
      'is_proxy_layer', true,
      'proxy_port', 40000,
      'proxy_protocol', 'socks5'
    )
  ),
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'cf-warp');

-- 2. Add protocol variables for WARP
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'warp_proxy_port', 'number', '40000', 'WARP SOCKS5 proxy port (default 40000)', true
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'warp_proxy_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'warp_mode', 'string', 'proxy', 'WARP mode (proxy / warp)', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'warp_mode');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'warp_ip', 'string', '', 'WARP exit IP address (via Cloudflare)', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'warp_ip');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'warp_account', 'string', '', 'WARP account ID', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'warp_account');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'server_host', 'string', '', 'Server hostname or IP', true
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'server_host');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'proxy_address', 'string', '127.0.0.1:40000', 'Full proxy address', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'proxy_address');

-- 3. Add default template for WARP
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT p.id, 'Default WARP', 'WARP SOCKS5 Proxy: socks5h://127.0.0.1:{{warp_proxy_port}}
WARP IP: {{warp_ip}}
Mode: {{warp_mode}}
Server: {{server_host}}', true
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_templates WHERE protocol_id = p.id AND template_name = 'Default WARP');

-- 4. Add translations for Cloudflare WARP
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'protocol_cf_warp', 'Cloudflare WARP Proxy')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'protocol_cf_warp', 'Cloudflare WARP Прокси')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

-- WARP-specific UI translations
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'warp_status', 'WARP Status')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'warp_status', 'Статус WARP')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'warp_connected', 'Connected via Cloudflare')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'warp_connected', 'Подключён через Cloudflare')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'warp_disconnected', 'Disconnected')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'warp_disconnected', 'Отключён')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'warp_proxy_info', 'WARP proxy adds a Cloudflare encryption layer to hide destination domains from VPS provider. Traffic chain: Client → AmneziaWG → WARP → Cloudflare → Internet')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'warp_proxy_info', 'WARP прокси добавляет слой шифрования Cloudflare для скрытия конечных доменов от провайдера VPS. Цепочка: Клиент → AmneziaWG → WARP → Cloudflare → Интернет')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'protocols', 'warp_warning_ram', '⚠️ Cloudflare WARP uses ~50-100MB additional RAM')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO translations (locale, category, key_name, translation) VALUES
('ru', 'protocols', 'warp_warning_ram', '⚠️ Cloudflare WARP использует ~50-100 МБ дополнительной RAM')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;

INSERT INTO schema_migrations (filename, checksum) VALUES ('067_warp_auto_redsocks_integration.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

-- Add new protocol variables for redsocks integration
INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'redsocks_port', 'number', '12345', 'Redsocks transparent proxy port', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'redsocks_port');

INSERT INTO protocol_variables (protocol_id, variable_name, variable_type, default_value, description, required)
SELECT p.id, 'routed_subnets', 'string', '10.8.1.0/24', 'VPN subnets routed through WARP', false
FROM protocols p WHERE p.slug = 'cf-warp'
  AND NOT EXISTS (SELECT 1 FROM protocol_variables WHERE protocol_id = p.id AND variable_name = 'routed_subnets');

INSERT INTO schema_migrations (filename, checksum) VALUES ('068_fix_warp_heredoc_compat.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('069_warp_aivpn_subnet_detect.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

INSERT INTO schema_migrations (filename, checksum) VALUES ('070_aivpn_v0_9_1.sql', 'baseline') ON CONFLICT (filename) DO NOTHING;

