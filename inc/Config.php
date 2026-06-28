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
   * Persist a secret into .env so it survives restarts (auto-provisioning of
   * APP_KEY / JWT_SECRET on first run, never stored in the DB).
   *
   * Behaviour:
   *  - A non-empty value already present (in the process env or the file) is never overwritten.
   *  - An existing empty placeholder line (e.g. `APP_KEY=`) is filled in place.
   *  - A missing key is appended at the end of the file.
   * The in-memory value is set regardless so the current process can use it.
   *
   * @return bool True when a value was provisioned, false if one already existed.
   */
  public static function ensureKey(string $key, string $value): bool {
    if (self::hasValue($key)) {
      return false;
    }
    self::$env[$key] = $value;
    @putenv($key . '=' . $value);
    self::persistEnvKey($key, $value);
    return true;
  }

  /**
   * True when a non-empty value for $key is available (process env or .env file).
   */
  private static function hasValue(string $key): bool {
    $env = getenv($key);
    if ($env !== false && $env !== null && $env !== '') {
      return true;
    }
    return self::fileHasValue($key);
  }

  /**
   * True when the .env file already holds a non-empty value for $key.
   */
  private static function fileHasValue(string $key): bool {
    if (self::$envPath === null || !file_exists(self::$envPath)) {
      return false;
    }
    $pattern = '/^' . preg_quote($key, '/') . '\s*=/';
    $lines = file(self::$envPath, FILE_IGNORE_NEW_LINES);
    foreach ($lines ?: [] as $line) {
      if (preg_match($pattern, $line)) {
        $val = trim((string) substr(strstr($line, '='), 1), " \t\"'");
        if ($val !== '') {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Write the secret to .env: fill the empty placeholder in place, or append if absent.
   * Idempotent and never overwrites an existing real value.
   */
  private static function persistEnvKey(string $key, string $value): void {
    if (self::$envPath === null || !is_writable(self::$envPath)) {
      return; // runtime-only fallback (cannot persist, e.g. read-only mount)
    }
    if (self::fileHasValue($key)) {
      return;
    }

    $raw = (string) @file_get_contents(self::$envPath);
    $eol = str_contains($raw, "\r\n") ? "\r\n" : "\n";
    $lines = preg_split('/\r\n|\r|\n/', $raw);
    // Drop trailing empty elements produced by the final newline.
    while (!empty($lines) && end($lines) === '') {
      array_pop($lines);
    }

    $pattern = '/^' . preg_quote($key, '/') . '\s*=/';
    $replaced = false;
    foreach ($lines as $i => $line) {
      if (!$replaced && preg_match($pattern, $line)) {
        $lines[$i] = $key . '=' . $value;
        $replaced = true;
      }
    }
    if (!$replaced) {
      $lines[] = $key . '=' . $value;
    }

    @file_put_contents(self::$envPath, implode($eol, $lines) . $eol, LOCK_EX);
  }
}