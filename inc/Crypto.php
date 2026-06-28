<?php
/**
 * Crypto — symmetric encryption-at-rest for secrets stored in the database.
 *
 * Uses libsodium authenticated symmetric encryption (secretbox/XSalsa20-Poly1305),
 * keyed by APP_KEY from .env. Ciphertexts carry a versioned prefix so legacy
 * plaintext values can be detected and migrated transparently.
 *
 * Encoded form: "enc:v1:" + base64(nonce || ciphertext)
 *
 * WARNING: changing/losing APP_KEY renders all encrypted secrets undecryptable.
 * See docs/security.md#ssh-password-encryption
 */
class Crypto
{
    private const PREFIX = 'enc:v1:';

    private static ?string $key = null;

    /**
     * Ensure APP_KEY exists (auto-provisioned into .env on first run) and return
     * the derived 32-byte secretbox key.
     */
    public static function ensureKey(): void
    {
        if (Config::get('APP_KEY') !== null && Config::get('APP_KEY') !== '') {
            return;
        }
        $generated = base64_encode(random_bytes(SODIUM_CRYPTO_SECRETBOX_KEYBYTES));
        Config::ensureKey('APP_KEY', $generated);
        error_log('Crypto: сгенерирован новый APP_KEY и записан в .env.');
    }

    private static function key(): string
    {
        if (self::$key !== null) {
            return self::$key;
        }
        self::ensureKey();
        $appKey = (string) (Config::get('APP_KEY') ?? '');

        $raw = base64_decode($appKey, true);
        if ($raw !== false && strlen($raw) === SODIUM_CRYPTO_SECRETBOX_KEYBYTES) {
            self::$key = $raw;
        } else {
            // Deterministic derivation for arbitrary-length keys.
            self::$key = hash('sha256', $appKey, true);
        }
        return self::$key;
    }

    public static function isEncrypted(?string $value): bool
    {
        return $value !== null && $value !== '' && str_starts_with($value, self::PREFIX);
    }

    /**
     * Encrypt a plaintext value. null/empty pass through unchanged.
     */
    public static function encrypt(?string $plaintext): ?string
    {
        if ($plaintext === null || $plaintext === '') {
            return $plaintext;
        }
        // Never double-encrypt
        if (self::isEncrypted($plaintext)) {
            return $plaintext;
        }
        $nonce = random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);
        $cipher = sodium_crypto_secretbox($plaintext, $nonce, self::key());
        return self::PREFIX . base64_encode($nonce . $cipher);
    }

    /**
     * Decrypt a value. Legacy plaintext (no prefix) is returned as-is so the
     * migration path is transparent and non-destructive. Returns '' on tamper/decay.
     */
    public static function decrypt(?string $payload): ?string
    {
        if ($payload === null || $payload === '') {
            return $payload;
        }
        if (!self::isEncrypted($payload)) {
            return $payload;
        }
        $decoded = base64_decode(substr($payload, strlen(self::PREFIX)), true);
        if ($decoded === false) {
            return '';
        }
        $nonceLen = SODIUM_CRYPTO_SECRETBOX_NONCEBYTES;
        if (strlen($decoded) < $nonceLen + SODIUM_CRYPTO_SECRETBOX_MACBYTES) {
            return '';
        }
        $nonce = substr($decoded, 0, $nonceLen);
        $cipher = substr($decoded, $nonceLen);
        $plain = sodium_crypto_secretbox_open($cipher, $nonce, self::key());
        return $plain === false ? '' : $plain;
    }
}
