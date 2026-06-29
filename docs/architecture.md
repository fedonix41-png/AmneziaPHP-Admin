# Architecture

## Database

Проект использует **PostgreSQL 15** как единственную СУБД.

| База данных     | Назначение                                      |
|-----------------|-------------------------------------------------|
| `amnezia_panel` | Данные веб-панели (пользователи, серверы, клиенты, переводы) |
| `telegram_bot`  | Данные Telegram-бота (пользователи, платежи, FSM-сессии)     |

### Инициализация

- `docker-entrypoint-initdb.d/01-init-multiple-databases.sh` — создаёт обе БД
- `docker-entrypoint-initdb.d/02-baseline-schema.sql` — baseline-схема `amnezia_panel`
- `docker-entrypoint-initdb.d/03-telegram-bot-schema.sql` — схема `telegram_bot`

### Миграции (`migrations/`)

Применяются через `update.sh` при каждом обновлении через `psql`. Все файлы написаны в **PostgreSQL-синтаксисе** (SERIAL/BIGSERIAL, ON CONFLICT, ADD COLUMN IF NOT EXISTS, DO $$ blocks).

Трекинг применённых миграций: таблица `schema_migrations` в БД `amnezia_panel`.

---

## Project Architecture

### MVC Pattern

```
Request → Router → Controller Logic → Model → Database
                      ↓
                   View (Twig) → Response
```

### Core Components

#### 1. Router (`inc/Router.php`)

Simple pattern-matching router:

```php
Router::get('/path/{param}', function($params) {
    // Handler logic
    echo $params['param'];
});

Router::post('/form', function() {
    // Handle POST
    $data = $_POST['field'];
});
```

#### 2. Database (`inc/DB.php`)

Singleton PDO connection:

```php
$pdo = DB::conn();
$stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
$stmt->execute([$id]);
$user = $stmt->fetch();
```

#### 3. Authentication (`inc/Auth.php`)

Session-based auth:

```php
// Login
Auth::login($email, $password);

// Get current user
$user = Auth::user();

// Check roles
if (Auth::isAdmin()) {
    // Admin logic (full access incl. system settings)
}
if (Auth::isManager()) {
    // Manager logic — operational management of ALL servers and clients:
    // create/delete/deploy servers, activate/uninstall protocols, create/revoke/
    // restore/delete clients, set expiration & traffic limits, WARP, backups,
    // import. (Also true for admin.)
}

// User role (default) has read-only access to their own allocated servers/clients.

// Logout
Auth::logout();

// Middleware
requireAuth();   // Any logged-in user
requireManager(); // manager or admin (server/client operations, used by the Telegram bot)
requireAdmin();   // admin only (system settings, protocol definitions, user/role & LDAP administration, secrets)
```

> **Ownership & listing:** resource access checks use `!Auth::isManager()` (web) and
> `in_array($role, ['admin','manager'])` (API); list endpoints show **all**
> servers/clients to admin and manager, only owned ones to regular users.
> See `docs/api.md` for endpoint authorization.

#### 4. Views (`inc/View.php`)

Twig template rendering:

```php
View::render('template.twig', [
    'var1' => 'value1',
    'var2' => 'value2',
]);
```

#### 5. Models

**VpnServer** (`inc/VpnServer.php`):

```php
// Create and deploy server
$serverId = VpnServer::create($userId, $name, $host, $port, $username, $password);

// Get server instance
$server = new VpnServer($serverId);
$data = $server->getData();

// Deploy to remote server
$server->deploy();

// List servers
$servers = VpnServer::listAll();
$userServers = VpnServer::listByUser($userId);
```

**VpnClient** (`inc/VpnClient.php`):

```php
// Create client
$clientId = VpnClient::create($serverId, $userId, $name);

// Get client instance
$client = new VpnClient($clientId);
$config = $client->getConfig();
$qrCode = $client->getQRCode();

// List clients
$clients = VpnClient::listByServer($serverId);
$userClients = VpnClient::listByUser($userId);
```

#### 6. QR Code Utility (`inc/QrUtil.php`)

Amnezia-compatible QR encoding:

```php
require_once 'inc/QrUtil.php';

// From WireGuard config text
$payload = QrUtil::encodeOldPayloadFromConf($configText);

// Generate PNG data URI
$qrImage = QrUtil::pngBase64($payload);

// Use in template
echo '<img src="' . $qrImage . '">';
```
