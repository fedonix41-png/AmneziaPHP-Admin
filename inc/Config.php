<?php
class Config {
  protected static array $env = [];
  protected static ?string $envPath = null;

  public static function load(string $path): void {
    self::$envPath = realpath($path) ?: $path;
    if (!file_exists($path)) {
      // allow running with only environment variables exported
      return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
      if (str_starts_with(trim($line), '#')) continue;
      $parts = explode('=', $line, 2);
      if (count($parts) !== 2) continue;
      $key = trim($parts[0]);
      $value = trim($parts[1]);
      $value = trim($value, "\"' ");
      self::$env[$key] = $value;
      @putenv($key . '=' . $value);
    }
  }

  public static function get(string $key, $default = null) {
    $env = getenv($key);
    if ($env !== false && $env !== null) return $env;
    return self::$env[$key] ?? $default;
  }

  /**
   * Persist a secret in the .env file so it survives restarts.
   * Only writes when the key is currently empty/unset (never overwrites).
   * Used to auto-provision APP_KEY / JWT_SECRET on first run without DB storage.
   */
  public static function ensureKey(string $key, string $value): bool {
    if (self::get($key) !== null && self::get($key) !== '') {
      return false;
    }
    self::$env[$key] = $value;
    @putenv($key . '=' . $value);
    if (self::$envPath !== null && is_writable(self::$envPath)) {
      $line = PHP_EOL . $key . '=' . $value . PHP_EOL;
      @file_put_contents(self::$envPath, $line, FILE_APPEND | LOCK_EX);
    }
    return true;
  }
}