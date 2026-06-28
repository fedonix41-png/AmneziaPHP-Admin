<?php
/**
 * RateLimiter — IP-based brute-force protection for auth endpoints.
 *
 * Strategy: sliding-window counter per IP with exponential backoff lockout.
 * Storage: PostgreSQL table `auth_attempts` (amnezia_panel DB).
 *
 * Defaults (overridable via .env AUTH_RATE_LIMIT / AUTH_LOCKOUT_BASE):
 *   - AUTH_RATE_LIMIT: max failed attempts within the window before lockout (5)
 *   - AUTH_RATE_WINDOW: rolling window in seconds during which failures count (60)
 *   - AUTH_LOCKOUT_BASE: base lockout seconds; grows exponentially per repeat (60)
 *
 * See docs/security.md#rate-limiting
 */
class RateLimiter
{
    public static function maxAttempts(): int
    {
        return (int) (Config::get('AUTH_RATE_LIMIT') ?: 5);
    }

    public static function windowSeconds(): int
    {
        return (int) (Config::get('AUTH_RATE_WINDOW') ?: 60);
    }

    public static function lockoutBase(): int
    {
        return (int) (Config::get('AUTH_LOCKOUT_BASE') ?: 60);
    }

    /**
     * Resolve client IP, honouring the first hop of X-Forwarded-For when present.
     */
    public static function clientIp(): string
    {
        $forwarded = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
        if ($forwarded !== '') {
            $first = trim(explode(',', $forwarded)[0]);
            if (filter_var($first, FILTER_VALIDATE_IP)) {
                return $first;
            }
        }
        return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }

    /**
     * Returns the remaining lockout seconds for the given IP/key, or 0 when not locked.
     *
     * @param string $bucket Identifier being protected (e.g. 'auth_token').
     */
    public static function lockoutRemaining(string $bucket, ?string $ip = null): int
    {
        $ip = $ip ?? self::clientIp();
        $pdo = DB::conn();
        $stmt = $pdo->prepare(
            'SELECT locked_until FROM auth_attempts
             WHERE ip = ? AND bucket = ?'
        );
        $stmt->execute([$ip, $bucket]);
        $row = $stmt->fetch();

        if (!$row || empty($row['locked_until'])) {
            return 0;
        }
        $remaining = strtotime($row['locked_until']) - time();
        return $remaining > 0 ? $remaining : 0;
    }

    /**
     * Record a failed attempt. Triggers/renews an exponential lockout once the
     * threshold is reached within the rolling window.
     */
    public static function registerFailure(string $bucket, ?string $ip = null): void
    {
        $ip = $ip ?? self::clientIp();
        $pdo = DB::conn();
        $now = time();
        $window = self::windowSeconds();

        $stmt = $pdo->prepare(
            'SELECT failed_count, last_failed_at, lockout_step FROM auth_attempts
             WHERE ip = ? AND bucket = ?'
        );
        $stmt->execute([$ip, $bucket]);
        $row = $stmt->fetch();

        $max = self::maxAttempts();

        if (!$row) {
            $pdo->prepare(
                'INSERT INTO auth_attempts (ip, bucket, failed_count, last_failed_at, locked_until, lockout_step)
                 VALUES (?, ?, 1, NOW(), NULL, 0)'
            )->execute([$ip, $bucket]);
            return;
        }

        $failedCount = (int) $row['failed_count'];
        $lastFailedTs = $row['last_failed_at'] ? strtotime($row['last_failed_at']) : 0;
        $step = (int) $row['lockout_step'];

        // Reset the rolling counter if the previous failure is outside the window
        if (($now - $lastFailedTs) > $window) {
            $failedCount = 0;
            $step = 0;
        }

        $failedCount++;

        if ($failedCount >= $max) {
            // Exponential backoff: base * 2^step, capped at 1 hour
            $step++;
            $lockout = min(self::lockoutBase() * (2 ** ($step - 1)), 3600);
            $pdo->prepare(
                'UPDATE auth_attempts
                 SET failed_count = ?, last_failed_at = NOW(),
                     locked_until = NOW() + (? || \' seconds\')::interval,
                     lockout_step = ?
                 WHERE ip = ? AND bucket = ?'
            )->execute([$failedCount, $lockout, $step, $ip, $bucket]);
        } else {
            $pdo->prepare(
                'UPDATE auth_attempts
                 SET failed_count = ?, last_failed_at = NOW(), lockout_step = ?
                 WHERE ip = ? AND bucket = ?'
            )->execute([$failedCount, $step, $ip, $bucket]);
        }
    }

    /**
     * Reset the failure counter after a successful authentication.
     */
    public static function clear(string $bucket, ?string $ip = null): void
    {
        $ip = $ip ?? self::clientIp();
        $pdo = DB::conn();
        $pdo->prepare(
            'UPDATE auth_attempts
             SET failed_count = 0, locked_until = NULL, lockout_step = 0
             WHERE ip = ? AND bucket = ?'
        )->execute([$ip, $bucket]);
    }
}
