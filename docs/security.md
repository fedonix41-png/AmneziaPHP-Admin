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

