# Developer Guidelines

# Developer Guide

Guide for developers contributing to Amnezia VPN Web Panel.

## Adding New Features

### Example: Add Server Statistics

**1. Add database column**

Create migration `migrations/002_add_stats.sql`:

```sql
ALTER TABLE vpn_servers ADD COLUMN stats_json TEXT;
```

**2. Add method to model**

Edit `inc/VpnServer.php`:

```php
public function getStats(): array {
    if (!$this->data['stats_json']) {
        return [];
    }
    return json_decode($this->data['stats_json'], true);
}

public function updateStats(): void {
    $stats = $this->collectStatsFromServer();
    
    $pdo = DB::conn();
    $stmt = $pdo->prepare('UPDATE vpn_servers SET stats_json = ? WHERE id = ?');
    $stmt->execute([json_encode($stats), $this->serverId]);
}

private function collectStatsFromServer(): array {
    // SSH to server, get stats
    // ...
    return ['cpu' => 45, 'memory' => 60, 'bandwidth' => 1024];
}
```

**3. Add route**

Edit `public/index.php`:

```php
Router::get('/servers/{id}/stats', function($params) {
    requireAuth();
    $serverId = (int)$params['id'];
    
    $server = new VpnServer($serverId);
    $stats = $server->getStats();
    
    header('Content-Type: application/json');
    echo json_encode($stats);
});
```

**4. Add template**

Create `templates/servers/stats.twig`:

```twig
{% extends "layout.twig" %}

{% block content %}
<div class="max-w-4xl mx-auto">
  <h1>Server Statistics</h1>
  
  <div class="grid grid-cols-3 gap-4">
    <div class="bg-white p-4 rounded shadow">
      <h3>CPU Usage</h3>
      <p class="text-3xl">{{ stats.cpu }}%</p>
    </div>
    <!-- More stats -->
  </div>
</div>
{% endblock %}
```

**5. Update navigation**

Edit `templates/layout.twig`:

```twig
<a href="/servers/{{ server.id }}/stats">Statistics</a>
```

## Code Style Guidelines

### PHP

Follow PSR-12 coding standard:

```php
<?php

namespace MyNamespace;

use AnotherNamespace\SomeClass;

class MyClass
{
    private string $property;
    
    public function __construct(string $param)
    {
        $this->property = $param;
    }
    
    public function method(int $arg): bool
    {
        if ($arg > 0) {
            return true;
        }
        
        return false;
    }
}
```

### SQL

```sql
-- Use uppercase keywords
SELECT id, name, created_at
FROM vpn_servers
WHERE status = 'active'
ORDER BY created_at DESC;

-- Prepared statements always
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
```

### JavaScript

```javascript
// Use modern ES6+
const fetchData = async () => {
  try {
    const response = await fetch('/api/servers');
    const data = await response.json();
    console.log(data);
  } catch (error) {
    console.error('Error:', error);
  }
};

// Event listeners
document.getElementById('btn').addEventListener('click', () => {
  fetchData();
});
```

### Twig

```twig
{# Comments #}

{# Variables #}
{{ variable }}
{{ object.property }}
{{ array[0] }}

{# Control structures #}
{% if condition %}
  Content
{% endif %}

{% for item in items %}
  {{ item.name }}
{% endfor %}

{# Filters #}
{{ text|upper }}
{{ html|raw }}  {# Careful with XSS! #}
```

## Testing

### Unit Tests (TODO)

```php
// tests/VpnServerTest.php
use PHPUnit\Framework\TestCase;

class VpnServerTest extends TestCase
{
    public function testCreate()
    {
        $serverId = VpnServer::create(1, 'Test', '192.168.1.1', 22, 'root', 'pass');
        $this->assertIsInt($serverId);
        $this->assertGreaterThan(0, $serverId);
    }
}
```

Run tests:

```bash
composer require --dev phpunit/phpunit
./vendor/bin/phpunit tests/
```

### Manual Testing

See [TESTING.md](TESTING.md) for comprehensive testing guide.

## Debugging

### Enable Error Display

In development, edit `public/index.php`:

```php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
```

### Database Queries

```php
// Enable query logging
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

try {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
} catch (PDOException $e) {
    error_log("SQL Error: " . $e->getMessage());
    error_log("Query: $sql");
    error_log("Params: " . print_r($params, true));
    throw $e;
}
```

### SSH Commands

```php
// Add debug output
$cmd = "your command";
error_log("Executing SSH command: $cmd");
$output = shell_exec($sshCmd);
error_log("SSH output: $output");
```

### Docker Logs

```bash
# Web container logs
docker compose logs -f web

# Database logs
docker compose logs -f db

# Last 100 lines
docker compose logs --tail=100 web
```

## Contributing

1. Fork repository
2. Create feature branch: `git checkout -b feature/my-feature`
3. Make changes
4. Write tests
5. Commit: `git commit -am 'Add my feature'`
6. Push: `git push origin feature/my-feature`
7. Create Pull Request

### Commit Message Format

```
type: subject

body (optional)

footer (optional)
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Tests
- `chore`: Maintenance

Example:

```
feat: add server statistics dashboard

- Added stats collection via SSH
- Created stats API endpoint
- Built statistics template
- Updated navigation

Closes #123
```

## Resources

- [PHP Documentation](https://www.php.net/docs.php)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Twig Documentation](https://twig.symfony.com/doc/)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Docker Documentation](https://docs.docker.com/)
- [WireGuard Protocol](https://www.wireguard.com/)
- [Amnezia VPN GitHub](https://github.com/amnezia-vpn/amnezia-client)

---

Happy coding! 🚀
