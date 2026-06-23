-- 010_add_monitoring_translations.sql — PostgreSQL
-- Migrate translations table structure if needed + add monitoring translations

-- Ensure translations table exists with current (locale/category/key_name) structure
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

-- If old structure (translation_key column) exists, migrate data, then drop old columns.
-- PostgreSQL conditional column migration via DO block:
DO $$
BEGIN
    -- Migrate old column names → new structure
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='translations' AND column_name='translation_key'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='translations' AND column_name='key_name'
    ) THEN
        -- Add new columns
        ALTER TABLE translations ADD COLUMN IF NOT EXISTS locale_new VARCHAR(10);
        ALTER TABLE translations ADD COLUMN IF NOT EXISTS category_new VARCHAR(50);
        ALTER TABLE translations ADD COLUMN IF NOT EXISTS key_name_new VARCHAR(100);
        ALTER TABLE translations ADD COLUMN IF NOT EXISTS translation_new TEXT;
        -- Populate from old structure
        UPDATE translations SET
            locale_new   = language_code,
            category_new = split_part(translation_key, '.', 1),
            key_name_new = split_part(translation_key, '.', 2),
            translation_new = translation_value;
        -- Drop old, rename new
        ALTER TABLE translations DROP COLUMN IF EXISTS language_code;
        ALTER TABLE translations DROP COLUMN IF EXISTS translation_key;
        ALTER TABLE translations DROP COLUMN IF EXISTS translation_value;
        ALTER TABLE translations RENAME COLUMN locale_new TO locale;
        ALTER TABLE translations RENAME COLUMN category_new TO category;
        ALTER TABLE translations RENAME COLUMN key_name_new TO key_name;
        ALTER TABLE translations RENAME COLUMN translation_new TO translation;
    END IF;
END $$;

-- Insert monitoring translations
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
