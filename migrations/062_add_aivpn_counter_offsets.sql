-- Add persistent AIVPN raw/offset counters for monotonic traffic totals across server restarts.

ALTER TABLE vpn_clients
  ADD COLUMN IF NOT EXISTS aivpn_raw_bytes_in BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS aivpn_raw_bytes_out BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS aivpn_offset_bytes_in BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS aivpn_offset_bytes_out BIGINT UNSIGNED NOT NULL DEFAULT 0;
