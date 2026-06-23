<?php
class DB {
  private static ?PDO $pdo = null;

  public static function conn(): PDO {
    if (self::$pdo) return self::$pdo;
    $host = Config::get('DB_HOST', '127.0.0.1');
    $port = Config::get('DB_PORT', '5432');
    $db   = Config::get('DB_DATABASE', 'amnezia_panel');
    $user = Config::get('DB_USERNAME', 'amnezia');
    $pass = Config::get('DB_PASSWORD', '');
    $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', $host, $port, $db);
    $options = [
      PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
      PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
      PDO::ATTR_EMULATE_PREPARES => false,
    ];
    self::$pdo = new PDO($dsn, $user, $pass, $options);
    
    return self::$pdo;
  }
}