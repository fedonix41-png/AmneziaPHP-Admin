# Setup & Deployment

## Development Setup

### Local Development (without Docker)

1. **Install PHP 8.2+**
```bash
# Ubuntu/Debian
sudo apt install php8.2 php8.2-cli php8.2-mysql php8.2-gd php8.2-curl php8.2-mbstring

# macOS (Homebrew)
brew install php@8.2
```

2. **Install MySQL 8.0**
```bash
# Ubuntu/Debian
sudo apt install mysql-server-8.0

# macOS
brew install mysql@8.0
```

3. **Install Composer**
```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

4. **Clone and Setup**
```bash
git clone <repo-url>
cd amnezia-web-panel
composer install
```

5. **Configure Database**
```bash
mysql -u root -p

CREATE DATABASE amnezia_panel CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'amnezia'@'localhost' IDENTIFIED BY 'amnezia123';
GRANT ALL PRIVILEGES ON amnezia_panel.* TO 'amnezia'@'localhost';
FLUSH PRIVILEGES;

USE amnezia_panel;
SOURCE migrations/001_init.sql;
SOURCE migrations/002_translations_ru.sql;
SOURCE migrations/003_translations_es.sql;
SOURCE migrations/004_translations_de.sql;
SOURCE migrations/005_translations_fr.sql;
SOURCE migrations/006_translations_zh.sql;
```

6. **Update Database Config**

Edit `inc/DB.php`:
```php
private static $config = [
    'host' => 'localhost',  // Change from 'db'
    'dbname' => 'amnezia_panel',
    'user' => 'amnezia',
    'password' => 'amnezia123',
    'charset' => 'utf8mb4',
];
```

7. **Run Development Server**
```bash
cd public
php -S localhost:8000
```

Access: `http://localhost:8000`

### Docker Development (Recommended)

```bash
docker compose up -d
```

Access: `http://localhost:8082`

**Live code editing**: Mount project as volume (already configured in docker-compose.yml)

## Deployment

### Production Checklist

- [ ] Change default admin password
- [ ] Update database passwords in docker-compose.yml
- [ ] Set up HTTPS (nginx reverse proxy + Let's Encrypt)
- [ ] Disable error display
- [ ] Enable error logging
- [ ] Set up automated backups
- [ ] Configure firewall
- [ ] Set up monitoring
- [ ] Review security settings
- [ ] Test disaster recovery

### Environment Variables

Create `.env.production`:
```env
DB_HOST=db
DB_NAME=amnezia_panel
DB_USER=amnezia
DB_PASS=strong_random_password_here
JWT_SECRET=another_strong_random_secret_here
ADMIN_EMAIL=admin@yourdomain.com
```

Load in PHP:
```php
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$dbPassword = $_ENV['DB_PASS'];
```

