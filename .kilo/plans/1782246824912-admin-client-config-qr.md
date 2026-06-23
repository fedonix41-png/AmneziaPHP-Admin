# Admin Client Config/QR View in Telegram Bot

## Goal
Add "Show QR" and "Show Config" buttons to the admin client view in Telegram bot,
so admins can view and share client configurations without switching to the web panel.

## Context
- Admin views a client → sees details + management buttons (block/extend/limit/delete)
- Missing: buttons to view QR code and download .conf file
- The `/api/clients/{id}/details` endpoint now regenerates WG config from server (fixed in prior session)
- Pattern already exists: `step_add_duration()` in `handlers/admin/clients.py` sends QR+config after client creation

## Files to change

### 1. `telegram_bot/keyboards/admin.py` — `client_action_kb()`
Add two new buttons at the top of the keyboard:
```python
rows.append([InlineKeyboardButton(text="📱 Показать QR", callback_data=f"admin:client:qr:{cid}")])
rows.append([InlineKeyboardButton(text="📄 Показать конфиг", callback_data=f"admin:client:config:{cid}")])
```

### 2. `telegram_bot/handlers/admin/clients.py` — two new handlers

**QR handler** (`admin:client:qr:{cid}`):
- Extract client_id from callback data
- Call `panel_api.client_details(settings.panel_api_token, client_id)`
- Decode `qr_code` base64 data URI via existing `_b64_to_bytes()`
- Send as photo via `callback.message.answer_photo(BufferedInputFile(...))`
- Fallback: if no QR in response, try `panel_api.client_qr()`

**Config handler** (`admin:client:config:{cid}`):
- Extract client_id from callback data
- Call `panel_api.client_details(settings.panel_api_token, client_id)`
- Get `config` text, encode as UTF-8
- Send as .conf document via `callback.message.answer_document(BufferedInputFile(...))`
- Fallback: if empty config, show error alert

### 3. `docs/telegram_bot_spec.md` — update checklist
Change line 191 (Управление клиентами) from ⬜ to ✅ or add sub-item for config/QR view.

## Design decisions
- Uses admin API token (not user JWT)
- Reuses existing `_b64_to_bytes()` helper already in the file
- Follows `_safe_edit()` pattern for error messages
- `client_details()` already regenerates WG config from server (ensures fresh AWG params)
- Both buttons always visible regardless of client status (admins need config access even for blocked clients)

## Validation
1. Open Telegram bot as admin
2. Navigate to Clients → Manage → select a client
3. Verify "Show QR" and "Show Config" buttons appear
4. Click "Show QR" → QR image sent as photo
5. Click "Show Config" → .conf file sent as document
6. Verify config contains AWG parameters (Jc, Jmin, Jmax, S1, S2, H1-H4) with valid values
