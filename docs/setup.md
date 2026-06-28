# Setup & Deployment

## Prerequisites

- Docker & docker-compose (recommended)
- Or: PHP 8.2+, PostgreSQL 15, Composer (local dev)

---

## Docker Development (Recommended)

```bash
git clone <repo-url> amneziavpnphp
cd amneziavpnphp
cp .env.example .env
# Edit .env — set passwords, bot token (optional)
docker compose up -d
```

Access web panel: `http://localhost:8082`
Default admin: `admin@amnez.ia` / `admin123`

### Running services

| Service | URL / Access | Notes |
|---------|-------------|-------|
| Web Panel | `http://localhost:8082` | PHP 8.2 + Apache |
| PostgreSQL | `localhost:5432` | Databases: `amnezia_panel`, `telegram_bot` |
| Docker-in-Docker | `tcp://dind:2375` | For deploying VPN containers |
| Telegram Bot | polling (default) or webhook on `:8080` | Set `BOT_TOKEN` in `.env` |

### Live code editing

The `web` container mounts the project directory:
```yaml
volumes:
  - ./:/var/www/html:z
```

PHP and template changes take effect immediately. No rebuild needed.

The `telegram_bot` container requires rebuild after Python changes:
```bash
docker compose build telegram_bot && docker compose up -d telegram_bot
```

> [!NOTE]
> On SELinux-enabled distributions (Fedora, CentOS, RHEL), the `:z` flag
> auto-labels files for container access. Without it, Apache may return 403 errors.

---

## Local Development (without Docker)

### 1. Install PHP 8.2+

```bash
# Ubuntu/Debian
sudo apt install php8.2 php8.2-cli php8.2-pgsql php8.2-gd \
  php8.2-curl php8.2-mbstring php8.2-ldap php8.2-bcmath

# macOS
brew install php@8.2
```

### 2. Install PostgreSQL 15

```bash
# Ubuntu/Debian
sudo apt install postgresql-15

# macOS
brew install postgresql@15
brew services start postgresql@15
```

### 3. Install Composer

```bash
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### 4. Clone and install dependencies

```bash
git clone <repo-url> amneziavpnphp
cd amneziavpnphp
cp .env.example .env
# Edit .env — set DB_HOST=127.0.0.1 for local
composer install
```

### 5. Create databases

```bash
sudo -u postgres psql

CREATE DATABASE amnezia_panel;
CREATE DATABASE telegram_bot;
CREATE USER amnezia WITH PASSWORD 'amnezia';
GRANT ALL PRIVILEGES ON DATABASE amnezia_panel TO amnezia;
GRANT ALL PRIVILEGES ON DATABASE telegram_bot TO amnezia;
\q
```

### 6. Configure `.env`

Set `DB_HOST=127.0.0.1` (instead of `db` — the Docker service name):

```env
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=amnezia_panel
DB_USERNAME=amnezia
DB_PASSWORD=amnezia
```

### 7. Apply schema

```bash
psql -U amnezia -d amnezia_panel -f docker-entrypoint-initdb.d/02-baseline-schema.sql
psql -U amnezia -d telegram_bot -f docker-entrypoint-initdb.d/03-telegram-bot-schema.sql
```

### 8. Run development server

```bash
cd public
php -S localhost:8000
```

Access: `http://localhost:8000`

---

## Production Deployment

### Checklist

- [ ] Change default admin password (`admin@amnez.ia`)
- [ ] Generate strong `DB_PASSWORD` (`JWT_SECRET` and `APP_KEY` are auto-generated on first run — keep `.env` backed up and never rotate `APP_KEY` without re-encrypting secrets)
- [ ] Set up HTTPS (nginx reverse proxy + Let's Encrypt)
- [ ] Disable PHP error display (`APP_ENV=production`)
- [ ] Configure firewall (block direct DB port 5432)
- [ ] Set up automated backups (pg_dump via cron)
- [ ] Register `BOT_TOKEN` with @BotFather (if using Telegram bot)
- [ ] Set `BOT_ADMIN_TELEGRAM_IDS` in `.env`

### Environment Variables

Copy `.env.example` to `.env` and fill in:

```env
APP_ENV=production
DEFAULT_LOCALE=en

DB_HOST=db
DB_PORT=5432
DB_DATABASE=amnezia_panel
DB_USERNAME=amnezia
DB_PASSWORD=<strong_random_password>
DB_ROOT_PASSWORD=<strong_random_password>

JWT_SECRET=<auto_generated_on_first_run>
APP_KEY=<auto_generated_on_first_run>
ADMIN_EMAIL=admin@yourdomain.com
ADMIN_PASSWORD=<strong_random_password>

# Telegram Bot (optional)
BOT_TOKEN=<from_botfather>
BOT_ADMIN_TELEGRAM_IDS=<comma_separated_ids>
PANEL_API_URL=http://web:80
PANEL_API_TOKEN=<api_token>
```

### Apply updates

```bash
./update.sh
```

This script pulls latest code, runs `composer install`, applies pending migrations via `psql`, and restarts containers.

---

## Environment variable reference

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `local` | `local` or `production` |
| `DB_HOST` | `db` | PostgreSQL host (use `127.0.0.1` for local) |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_DATABASE` | `amnezia_panel` | Web panel database |
| `DB_USERNAME` | `amnezia` | Database user |
| `DB_PASSWORD` | — | Database password |
| `JWT_SECRET` | auto | JWT signing secret (auto-generated & persisted to `.env` on first run; ≥32 bytes) |
| `APP_KEY` | auto | libsodium key for SSH-password encryption (auto-generated & persisted to `.env`) |
| `AUTH_RATE_LIMIT` | `5` | Max failed `/api/auth/token` attempts before lockout |
| `AUTH_RATE_WINDOW` | `60` | Rolling window (seconds) for counting failures |
| `AUTH_LOCKOUT_BASE` | `60` | Base lockout seconds (exponential backoff, capped at 1h) |
| `ADMIN_EMAIL` | `admin@amnez.ia` | Default admin email |
| `ADMIN_PASSWORD` | `admin123` | Default admin password |
| `BOT_TOKEN` | — | Telegram bot token from @BotFather |
| `BOT_ADMIN_TELEGRAM_IDS` | — | Comma-separated admin Telegram IDs |
| `PANEL_API_URL` | `http://web:80` | Web panel URL for bot API calls |
| `PANEL_API_TOKEN` | — | Permanent API token for bot |
