# API

## API Development

### Adding New Endpoint

```php
// In public/index.php

Router::post('/api/clients', function() {
    // TODO: Verify JWT token
    
    header('Content-Type: application/json');
    
    try {
        $serverId = (int)$_POST['server_id'];
        $name = trim($_POST['name'] ?? '');
        
        if (!$serverId || !$name) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing parameters']);
            return;
        }
        
        $user = Auth::user();
        $clientId = VpnClient::create($serverId, $user['id'], $name);
        
        $client = new VpnClient($clientId);
        
        echo json_encode([
            'success' => true,
            'client' => $client->getData(),
        ]);
        
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
});
```

### Authorization

All `/api/*` endpoints (except `POST /api/auth/token`) require a Bearer token in the
`Authorization` header (or `X-Api-Token`), validated by `inc/JWT.php`:

```php
$user = JWT::requireAuth();    // any authenticated user, else 401
$user = JWT::requireManager(); // manager or admin, else 401/403
// Admin-only endpoints are gated by JWT::requireAuth() + an inner role === 'admin' check
// (system settings are web-only — see docs/architecture.md#authentication).
```

Role tiers and which tier each endpoint category requires (role model:
`docs/architecture.md` → *Authentication*):

| Tier | Access | Typical endpoints |
|------|--------|-------------------|
| `requireAuth` | any logged-in user (own resources only) | read endpoints, `/api/auth/token`, client details |
| `requireManager` | **manager** or **admin** — manages **all** servers/clients | `POST /api/servers/create`, `DELETE /api/servers/{id}/delete`, `/api/clients/create`, `/api/clients/{id}/revoke\|restore\|delete`, `/api/clients/{id}/set-expiration\|extend\|set-traffic-limit` |
| admin-only | **admin** only | revealing server secrets (`include_secrets`), debug routes |

> **Per-resource access:** write endpoints check `owner OR (admin/manager)`, i.e.
> `!in_array($user['role'] ?? '', ['admin','manager'], true)`. **List** endpoints
> (`GET /api/servers`, `GET /api/clients`, `/api/clients/expiring`) return **all**
> records for admin/manager and only owned ones for regular users.
> The Telegram bot authenticates with `PANEL_API_TOKEN` (a long-lived admin JWT).


# API Usage Examples

## Authentication

### Get JWT Token

> **Rate limited:** `POST /api/auth/token` is protected by IP-based throttling.
> After 5 failed attempts within 60s the IP is locked out with exponential backoff;
> locked requests return `429 Too Many Requests` with a `Retry-After` header.
> A successful login clears the counter. See `docs/security.md#rate-limiting`.

```bash
curl -X POST http://localhost:8082/api/auth/token \
  -d "email=admin@amnez.ia&password=admin123"
```

Response:
```json
{
  "success": true,
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "type": "Bearer",
  "expires_in": 2592000,
  "role": "admin"
}
```

## Protocols

### List Active Protocols (for JWT API clients)

```bash
curl -X GET http://localhost:8082/api/protocols/active \
  -H "Authorization: Bearer $TOKEN"
```

Example response:
```json
{
  "success": true,
  "protocols": [
    {"id": 11, "slug": "awg2", "name": "AmneziaWG 2.0"},
    {"id": 13, "slug": "aivpn", "name": "AIVPN"},
    {"id": 12, "slug": "mtproxy", "name": "MTProxy (Telegram)"},
    {"id": 14, "slug": "openvpn-cloak", "name": "OpenVPN over Cloak"}
  ]
}
```

### OpenVPN over Cloak Data Format
For the `openvpn-cloak` protocol, the client `config` field returns the raw base OpenVPN config. The `qr_code` data URI contains the specialized Amnezia-compatible JSON payload that sets up dual containers (`amnezia-cloak` and `amnezia-openvpn`) with the necessary proxy variables (`cloak_public_key`, `cloak_bypass_uid`, etc.).

### Install Protocol on Server

```bash
curl -X POST http://localhost:8082/api/servers/1/protocols/install \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"protocol_id":11}'
```

## Clients

### Create Client with QR Code

```bash
TOKEN="your-jwt-token"

curl -X POST http://localhost:8082/api/clients/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "server_id": 1,
    "name": "My Phone"
  }'
```

Response:
```json
{
  "success": true,
  "client": {
    "id": 1,
    "name": "My Phone",
    "server_id": 1,
    "client_ip": "10.8.1.1",
    "status": "active",
    "created_at": "2025-11-07 12:00:00",
    "config": "[Interface]\nPrivateKey = ...\n...",
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  }
}
```

The `qr_code` field contains a data URI that can be used directly in HTML:
```html
<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..." alt="QR Code" />
```

### Get Client QR Code

> **Note:** For WireGuard/AWG clients, the QR code is regenerated from the server's live
> container state before returning, same as `/details`.

```bash
curl -X GET http://localhost:8082/api/clients/1/qr \
  -H "Authorization: Bearer $TOKEN"
```

Response:
```json
{
  "success": true,
  "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
  "client_name": "My Phone"
}
```

### Get Client Details with Stats, Config and QR

> **Note:** For WireGuard/AWG clients (`amnezia-wg`, `awg2`, etc.), the endpoint automatically
> regenerates the config from the server's live container state before returning it.
> This ensures AWG obfuscation parameters (Jc, Jmin, Jmax, S1-S4, H1-H4) are always current.

```bash
curl -X GET http://localhost:8082/api/clients/1/details \
  -H "Authorization: Bearer $TOKEN"
```

Response:
```json
{
  "success": true,
  "client": {
    "id": 1,
    "name": "My Phone",
    "server_id": 1,
    "client_ip": "10.8.1.1",
    "status": "active",
    "created_at": "2025-11-07 12:00:00",
    "stats": {
      "sent": "1.23 GB",
      "received": "456.78 MB",
      "total": "1.68 GB",
      "last_seen": "Online",
      "is_online": true
    },
    "bytes_sent": 1320000000,
    "bytes_received": 478800000,
    "last_handshake": "2025-11-07 12:30:00",
    "config": "[Interface]\nPrivateKey = ...\n...",
    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  }
}
```

## Servers

### List Servers

> **Note:** Sensitive fields (`password`, `ssh_key`) are never returned — SSH
> passwords are encrypted at rest (see `docs/security.md#ssh-password-encryption`).

```bash
curl -X GET http://localhost:8082/api/servers \
  -H "Authorization: Bearer $TOKEN"
```

### Create Server

```bash
curl -X POST http://localhost:8082/api/servers/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "US Server",
    "host": "192.168.1.100",
    "port": 22,
    "username": "root",
    "password": "your-password"
  }'
```

### Get Server Clients

```bash
curl -X GET http://localhost:8082/api/servers/1/clients \
  -H "Authorization: Bearer $TOKEN"
```

## Client Management

### Revoke Client

```bash
curl -X POST http://localhost:8082/api/clients/1/revoke \
  -H "Authorization: Bearer $TOKEN"
```

### Restore Client

```bash
curl -X POST http://localhost:8082/api/clients/1/restore \
  -H "Authorization: Bearer $TOKEN"
```

### Delete Client

```bash
curl -X DELETE http://localhost:8082/api/clients/1/delete \
  -H "Authorization: Bearer $TOKEN"
```

## Integration Examples

### Python Example

```python
import requests
import base64
from io import BytesIO
from PIL import Image

# Get token
response = requests.post('http://localhost:8082/api/auth/token', 
    data={'email': 'admin@amnez.ia', 'password': 'admin123'})
token = response.json()['token']

headers = {'Authorization': f'Bearer {token}'}

# Create client
client_data = {
    'server_id': 1,
    'name': 'My Phone'
}
response = requests.post('http://localhost:8082/api/clients/create',
    json=client_data, headers=headers)

result = response.json()
qr_code_data_uri = result['client']['qr_code']

# Save QR code as image
qr_base64 = qr_code_data_uri.split(',')[1]
qr_bytes = base64.b64decode(qr_base64)
image = Image.open(BytesIO(qr_bytes))
image.save('qr_code.png')

print(f"Client created: {result['client']['name']}")
print(f"QR code saved to qr_code.png")
```

### JavaScript/Node.js Example

```javascript
const axios = require('axios');
const fs = require('fs');

// Get token
const authResponse = await axios.post('http://localhost:8082/api/auth/token', 
  'email=admin@amnez.ia&password=admin123');
const token = authResponse.data.token;

const headers = { 'Authorization': `Bearer ${token}` };

// Create client
const clientData = {
  server_id: 1,
  name: 'My Phone'
};

const response = await axios.post('http://localhost:8082/api/clients/create',
  clientData, { headers });

const qrCodeDataUri = response.data.client.qr_code;

// Save QR code as image
const base64Data = qrCodeDataUri.split(',')[1];
fs.writeFileSync('qr_code.png', base64Data, 'base64');

console.log(`Client created: ${response.data.client.name}`);
console.log('QR code saved to qr_code.png');
```

### Display QR Code in Web Page

```html
<!DOCTYPE html>
<html>
<head>
    <title>VPN Client QR Code</title>
</head>
<body>
    <h1>Scan this QR code with Amnezia VPN app</h1>
    <div id="qr-container"></div>

    <script>
        async function loadQRCode() {
            // Get token
            const formData = new URLSearchParams();
            formData.append('email', 'admin@amnez.ia');
            formData.append('password', 'admin123');
            
            const authResponse = await fetch('http://localhost:8082/api/auth/token', {
                method: 'POST',
                body: formData
            });
            const authData = await authResponse.json();
            const token = authData.token;

            // Create client
            const response = await fetch('http://localhost:8082/api/clients/create', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    server_id: 1,
                    name: 'Web Client'
                })
            });

            const data = await response.json();
            
            // Display QR code
            const img = document.createElement('img');
            img.src = data.client.qr_code;
            img.alt = 'VPN Client QR Code';
            img.style.width = '300px';
            img.style.height = '300px';
            
            document.getElementById('qr-container').appendChild(img);
        }

        loadQRCode();
    </script>
</body>
</html>
```
