-- Migrate existing users to 'manager'
UPDATE users SET role = 'manager' WHERE role = 'user';

-- Add translations for 'role_manager'
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'users', 'role_manager', 'Manager'),
('ru', 'users', 'role_manager', 'Менеджер'),
('es', 'users', 'role_manager', 'Gestor'),
('de', 'users', 'role_manager', 'Manager'),
('fr', 'users', 'role_manager', 'Gestionnaire'),
('zh', 'users', 'role_manager', '经理')
ON CONFLICT (locale, category, key_name) DO UPDATE SET translation = EXCLUDED.translation;
