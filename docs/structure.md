# Project Structure

## Directory tree

```
amneziavpnphp/                          # Project root
│
├── 🔧 Configuration
│   ├── .env                           # Environment secrets (not in git)
│   ├── .env.example                   # Environment template
│   ├── .gitignore                     # Git ignore rules
│   ├── apache.conf                    # Apache virtual host
│   ├── my.cnf                         # Legacy MySQL config (no longer used)
│   └── .agents/rules/                 # AI agent rules
│       ├── AGENTS.md                  # Agent architecture & role instruction
│       └── GEMINI.md                  # Technical constraints & environment rules
│
├── 🐳 Docker
│   ├── docker-compose.yml             # 4 services: db (PG15), web, dind, telegram_bot
│   ├── Dockerfile                     # PHP 8.2 Apache image
│   ├── docker-entrypoint-initdb.d/    # PostgreSQL init scripts (run once)
│   │   ├── 01-init-multiple-databases.sh
│   │   ├── 02-baseline-schema.sql     # amnezia_panel full schema + seeds
│   │   └── 03-telegram-bot-schema.sql # telegram_bot schema
│   └── telegram_bot/Dockerfile        # Python 3.12 bot image
│
├── 📦 PHP Dependencies
│   ├── composer.json                  # twig/twig, endroid/qr-code, etc.
│   ├── composer.lock
│   └── vendor/                        # Installed packages (not in git)
│
├── 💾 Database
│   └── migrations/                    # 41 PostgreSQL migration files (000–072)
│       └── migrations/README.md
│
├── 🌐 Web Application
│   ├── public/
│   │   ├── index.php                  # Front controller & router
│   │   └── .htaccess                  # Apache URL rewriting
│   ├── inc/                           # Core PHP library (18 files)
│   │   ├── Auth.php                   # Session auth, LDAP, registration
│   │   ├── BackupLibrary.php          # Server backup import/export
│   │   ├── Config.php                 # .env loader + secret provisioning (ensureKey)
│   │   ├── Crypto.php                 # libsodium at-rest encryption (SSH passwords)
│   │   ├── DB.php                     # PostgreSQL PDO singleton (pgsql)
│   │   ├── InstallProtocolManager.php # Protocol lifecycle (install/activate/delete)
│   │   ├── JWT.php                    # JWT token API auth (env-only secret)
│   │   ├── LdapSync.php              # LDAP/AD integration
│   │   ├── Logger.php                 # Logging utility
│   │   ├── OpenRouterService.php      # AI script generation (OpenRouter API)
│   │   ├── PanelImporter.php          # Import configs from other panels
│   │   ├── ProtocolService.php        # Protocol CRUD service
│   │   ├── QrUtil.php                 # Amnezia-compatible QR encoding
│   │   ├── RateLimiter.php            # IP-based brute-force protection (auth_attempts)
│   │   ├── Router.php                 # URL routing
│   │   ├── ServerMonitoring.php       # Xray API online client tracking
│   │   ├── Translator.php             # Multi-language translations (en/ru/es/de/fr/zh)
│   │   ├── View.php                   # Twig template renderer
│   │   ├── VpnClient.php              # VPN client CRUD + config generation
│   │   └── VpnServer.php              # Server deploy + WireGuard management
│   ├── controllers/                   # Route controllers
│   │   ├── AIController.php           # AI assistant endpoints
│   │   ├── LogsController.php         # Log viewer/search/download
│   │   ├── ProtocolManagementController.php
│   │   ├── ScenarioController.php     # Protocol scenario CRUD
│   │   └── SettingsController.php     # Settings, users, API keys, LDAP, protocols
│   └── templates/                     # Twig views (22 files)
│       ├── layout.twig                # Base layout + navigation
│       ├── login.twig / register.twig  # Auth pages
│       ├── dashboard.twig             # Main dashboard
│       ├── servers/                   # Server management views
│       ├── clients/                   # Client config & QR display
│       ├── settings/                  # Admin settings, LDAP, protocols
│       ├── ai/                        # AI assistant UI
│       └── tools/                     # Logs, monitoring tools
│
├── 🤖 Telegram Bot
│   └── telegram_bot/                  # Python 3.12 + aiogram 3.13
│       ├── bot.py                     # Entry point (polling/webhook)
│       ├── config.py                  # Pydantic settings from .env
│       ├── handlers/                  # Route handlers
│       │   ├── auth.py                # Email/password login (FSM)
│       │   ├── start.py               # /start, /help, menus
│       │   ├── admin/                 # Admin panel handlers
│       │   │   ├── backups.py         # Backup management (list/create/download/delete)
│       │   │   ├── clients.py         # Client CRUD, QR/config, expiring/overlimit views
│       │   │   ├── menu.py            # Admin main menu + server/client routing
│       │   │   └── servers.py         # Monitoring, diagnostics, handshake testing
│       │   └── client/                # Client operations
│       │       ├── ai_assist.py       # AI troubleshooting
│       │       ├── common.py          # Shared helpers (auth context, user resolution)
│       │       ├── config.py          # QR, .conf, key reset
│       │       ├── menu.py            # Main + admin menus
│       │       └── stats.py           # Traffic statistics
│       ├── services/
│       │   ├── alerts.py              # Admin alerting framework
│       │   ├── panel_api.py           # REST API client (httpx)
│       │   └── users.py               # User repo (asyncpg)
│       ├── db/
│       │   ├── pool.py                # Connection pool + auto-migration
│       │   └── storage.py             # FSM state persistence
│       ├── states/                    # aiogram FSM states
│       │   ├── admin.py                # Admin FSM states (AddClientStates)
│       │   └── auth.py                 # Auth FSM states
│       ├── keyboards/                 # Inline keyboards
│       │   ├── admin.py               # Admin keyboards (client actions, servers, backups)
│       │   └── client.py              # Client keyboards (main menu, reset confirm)
│       ├── middlewares/               # Access logging
│       │   └── access.py              # Access log middleware
│       └── utils/                     # Formatting utilities
│           └── format.py              # humanize_bytes, humanize_date, status_label
│
├── 🔧 CLI & Automation
│   ├── bin/                           # Cron job scripts
│   │   ├── check_expired_clients.php
│   │   ├── check_traffic_limits.php
│   │   ├── collect_metrics.php
│   │   ├── monitor_metrics.sh          # Server metrics collection shell script
│   │   ├── sync_ldap_users.php
│   │   ├── translate.php               # Translation utility
│   │   └── translate_all.php           # Batch translation script
│   ├── scripts/                       # Utility scripts
│   ├── update.sh                      # Deployment: git pull + composer + migrations
│
├── 📁 Data Directories
│   ├── backups/                       # Server backup exports
│   ├── examples/                      # Example configurations
│   └── logs/                          # Application log files
│
└── 📖 Documentation
    └── docs/                          # Project documentation (SSOT)
        ├── api.md                     # API endpoints, auth, examples
        ├── architecture.md            # System architecture & data flow
        ├── guidelines.md              # Developer guidelines & coding standards
        ├── ldap.md                    # LDAP/AD integration guide
        ├── security.md                # Security best practices
        ├── setup.md                   # Installation & deployment
        ├── structure.md               # This file
        └── telegram_bot_spec.md       # Bot technical specification
```

---

## Docker services

| Service | Image | Container Name | Port |
|---------|-------|----------------|------|
| `db` | `postgres:15-alpine` | `amnezia-panel-db` | `5432` |
| `web` | Built from `Dockerfile` (PHP 8.2 + Apache) | `amnezia-panel-web` | `8082→80` |
| `dind` | `docker:24-dind` (privileged) | `amnezia-panel-dind` | internal |
| `telegram_bot` | Built from `telegram_bot/Dockerfile` | `amnezia-panel-telegram-bot` | `8080` (webhook) |

### PostgreSQL databases

| Database | Purpose |
|----------|---------|
| `amnezia_panel` | Web panel: users, servers, clients, protocols, settings, translations |
| `telegram_bot` | Bot: user mappings, payment records, FSM sessions, cached configs |

Schema initialization via `docker-entrypoint-initdb.d/` runs **only on first container start** (empty volume).
Migrations in `migrations/` are applied by `update.sh` using `psql`.

---

## Core library files (`inc/`)

| File | Purpose |
|------|---------|
| `Auth.php` | Session-based auth, LDAP authentication, registration, role checks |
| `BackupLibrary.php` | Server backup import/export |
| `Config.php` | `.env` file parser, environment variable accessor, secret provisioning (`ensureKey`) |
| `Crypto.php` | libsodium symmetric encryption-at-rest for SSH passwords, keyed by `APP_KEY` |
| `DB.php` | PDO singleton — **PostgreSQL** driver (`pgsql:host=db;port=5432`) |
| `InstallProtocolManager.php` | Protocol lifecycle (install/uninstall/activate/detect) |
| `JWT.php` | JWT token creation and verification for API auth (env-only `JWT_SECRET`) |
| `LdapSync.php` | LDAP/Active Directory: connection, auth, group mapping, user sync |
| `Logger.php` | File-based logging utility |
| `OpenRouterService.php` | OpenRouter AI API client for script generation |
| `PanelImporter.php` | Import configurations from other panels |
| `ProtocolService.php` | Protocol CRUD service layer |
| `QrUtil.php` | Amnezia-compatible QR encoding (QDataStream + Base64) |
| `RateLimiter.php` | IP-based brute-force protection for auth endpoints (`auth_attempts` table) |
| `Router.php` | Custom HTTP router (GET/POST with parameterized paths) |
| `ServerMonitoring.php` | Xray API integration for online client tracking |
| `Translator.php` | Multi-language i18n (en/ru/es/de/fr/zh) |
| `View.php` | Twig template rendering wrapper |
| `VpnClient.php` | Client model: key generation, config, traffic tracking |
| `VpnServer.php` | Server model: SSH connection, deploy, WireGuard management |

---

## Migration system

Migrations live in `migrations/` and are numbered sequentially (`000_*.sql` through `072_*.sql`).
They use **PostgreSQL syntax**: `SERIAL`, `BIGSERIAL`, `ON CONFLICT`, `ADD COLUMN IF NOT EXISTS`, `DO $$` blocks.

Applied via `update.sh`:
```bash
docker compose exec -T db sh -c "PGPASSWORD='$DB_PASSWORD' psql -U $DB_USERNAME -d $DB_DATABASE -f /dev/stdin" < $migration
```

Tracking table: `schema_migrations` (in `amnezia_panel` database).

---

## Data flow

### Server deployment

```
User submits form → Router: POST /servers/create
  → VpnServer::create() → INSERT into vpn_servers
  → Redirect to deploy page
  → VpnServer->deploy() → SSH to remote host
    → Install/start Docker → Create VPN container
    → Generate WireGuard keys → Configure firewall
  → Update DB with server details
  → Redirect to /servers/{id}
```

### Client creation

```
User submits name → Router: POST /servers/{id}/clients/create
  → VpnClient::create() → Generate client keys via SSH
  → Assign next IP from subnet → Build WireGuard config
  → Add peer to server (wg syncconf) → Generate QR code
  → INSERT into vpn_clients
  → Display config + QR code
```

---

## Monitoring

### Logs

- Apache access: `docker compose logs web` (stdout)
- Apache error: `docker compose logs web` (stderr, symlinked to `/dev/stderr`)
- PHP errors: `error_log()` → stderr
- PostgreSQL logs: `docker compose logs db`

### Health checks

```bash
# Container status
docker compose ps

# App health
curl http://localhost:8082/

# DB health
docker compose exec db pg_isready -U amnezia -d amnezia_panel
```

---

## Backup & Recovery

```bash
# Database backup (PostgreSQL)
docker compose exec db pg_dump -U amnezia amnezia_panel > backup.sql

# Database restore
docker compose exec -T db psql -U amnezia amnezia_panel < backup.sql

# Full project backup
tar -czf amnezia-backup-$(date +%Y%m%d).tar.gz \
  --exclude=vendor --exclude=pg_data .
```

---

## Technology stack

- **PHP 8.2** + Apache 2.4 (mod_rewrite)
- **PostgreSQL 15** (Alpine) + PDO pgsql
- **Twig 3.x** templating
- **Tailwind CSS** + Font Awesome (CDN)
- **Python 3.12** + aiogram 3.13 (Telegram bot)
- **Docker** + docker-compose (4 services)
- **Composer** (PHP deps), **pip** (Python deps)
- **sshpass** (non-interactive SSH), **Docker CLI** (remote deploy)

---

**Last Updated**: 2026-06-24
