# Architecture

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

// Check admin
if (Auth::isAdmin()) {
    // Admin logic
}

// Logout
Auth::logout();

// Middleware
requireAuth(); // In route handler
```

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

