# Security

## Security Best Practices

### 1. SQL Injection Prevention

❌ **Never do this:**
```php
$sql = "SELECT * FROM users WHERE email = '$email'";
```

✅ **Always use prepared statements:**
```php
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
```

### 2. XSS Prevention

❌ **Never output unescaped:**
```php
echo $_GET['name'];  // Dangerous!
```

✅ **Escape output:**
```php
echo htmlspecialchars($_GET['name'], ENT_QUOTES, 'UTF-8');
```

In Twig (auto-escapes by default):
```twig
{{ user_input }}  {# Safe #}
{{ user_input|raw }}  {# Unsafe - use carefully #}
```

### 3. CSRF Protection

TODO: Implement token-based CSRF protection:

```php
// Generate token
$_SESSION['csrf_token'] = bin2hex(random_bytes(32));

// In form
<input type="hidden" name="csrf_token" value="{{ csrf_token }}">

// Verify
if ($_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    die('CSRF token mismatch');
}
```

### 4. Password Hashing

✅ **Always use bcrypt:**
```php
// Hash
$hash = password_hash($password, PASSWORD_BCRYPT);

// Verify
if (password_verify($password, $hash)) {
    // Correct
}
```

### 5. Input Validation

```php
// Email
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    throw new Exception('Invalid email');
}

// Integer
$id = (int)$_GET['id'];

// String length
if (strlen($name) < 3 || strlen($name) > 50) {
    throw new Exception('Invalid name length');
}
```

---

## Resolved vulnerabilities

The following were previously tracked as TODOs and are now implemented.

### Rate limiting on auth endpoint
`POST /api/auth/token` is protected by IP-based throttling (`inc/RateLimiter.php`).
Failed attempts are tracked in the `auth_attempts` table (amnezia_panel DB, migration `072_create_auth_attempts.sql`).
After `AUTH_RATE_LIMIT` failures (default 5) within `AUTH_RATE_WINDOW` seconds (default 60), the IP is locked out with **exponential backoff** (`AUTH_LOCKOUT_BASE`, default 60s, doubling per repeat, capped at 1h). A successful login clears the counter. Locked requests return `429` with a `Retry-After` header.

### SSH passwords stored in plaintext
SSH passwords are now **encrypted at rest** via libsodium secretbox (`inc/Crypto.php`), keyed by `APP_KEY` from `.env`.
- Ciphertexts carry an `enc:v1:` prefix; legacy plaintext rows are **transparently re-encrypted on first load** (`VpnServer::load()`), so no separate SQL migration is needed.
- Decryption happens in `VpnServer::load()`, so all SSH code still sees plaintext via `$this->data['password']`.
- `/api/servers` no longer returns `password` or `ssh_key` fields (previously leaked via `SELECT *`).
- WARNING: losing/changing `APP_KEY` renders all SSH passwords undecryptable.

### JWT secret in database
JWT signing secret is sourced **only** from the `JWT_SECRET` environment variable (`inc/JWT.php`).
- No database fallback; the legacy `settings.jwt_secret` row is removed by migration `071_remove_jwt_secret_from_settings.sql`.
- `JWT::ensureSecret()` auto-provisions a strong random secret into `.env` on first run if it is missing, shorter than 32 bytes, or equal to the shipped placeholder.

### Secrets provisioning
`APP_KEY` and `JWT_SECRET` are auto-generated and persisted to `.env` on first run (`Config::ensureKey()`). They are **never** stored in the database or logged.

