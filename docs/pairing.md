# Pairing the app with Squall desktop

The first time Squall opens on a phone or iPad, it asks to pair with Squall on the computer. This page is the deal both sides follow, so Squall desktop knows exactly what to build.

You can try it today with the pretend desktop in `tools/pairing_test_server.py` (see the end of this page).

## What the person does

1. On the computer: Squall > Settings > **Pair a phone**. Desktop starts listening and shows a QR code, its address and a 6-digit code.
2. On the phone: scan the QR code, or tap **Type the code** and enter the address and code.
3. Both show "Paired". The phone keeps a secret token; the desktop keeps a hash of it.

**Skip for now** on the phone keeps the pretend data. Pairing can be done later in Settings > Computer, which also has **Unpair**.

## Connection

- Plain HTTP on the local network, port **47615** by default. The desktop listens on all interfaces only while it is running.
- All bodies are JSON (`Content-Type: application/json`).
- The phone allows HTTP only to local addresses (`NSAllowsLocalNetworking`), and iOS asks once for Local Network permission.
- Version: `protocolVersion` is `1`.

## The QR code

The QR code holds one link:

```
squall://pair?v=1&host=192.168.1.20&port=47615&code=482913&name=Storm-PC
```

| Part | Meaning |
| --- | --- |
| `host` | The computer's address on the Wi-Fi (IPv4 or a name like `storm-pc.local`). |
| `port` | Optional. Defaults to 47615. |
| `code` | The same 6 digits shown on screen. |
| `name` | Optional. The computer's name, shown on the phone. Encode spaces as `%20`, not `+`. |

## The code

- 6 random digits from a secure random source.
- Works for **2 minutes**, and for **one** phone. Making a new code cancels the old one.
- After **5** wrong tries the code is cancelled.
- Only valid while the Pair a phone screen is open.

## Endpoints

### `POST /api/v1/pair`

Phone sends the code and who it is:

```json
{
  "code": "482913",
  "protocolVersion": 1,
  "device": {
    "deviceId": "6F1C...UUID",
    "deviceName": "Storm's iPad",
    "platform": "iPadOS",
    "systemVersion": "18.1",
    "appVersion": "0.1.0"
  }
}
```

Desktop answers:

| Status | When | Body |
| --- | --- | --- |
| `200` | Code right | `{"token": "...", "computerId": "...", "computerName": "Storm-PC", "protocolVersion": 1}` |
| `401` | Wrong code | `{"error": "wrong_code"}` |
| `409` | Not on the Pair a phone screen, or the code was already used | `{"error": "not_listening"}` |
| `410` | Code ran out of time | `{"error": "code_expired"}` |
| `429` | Too many wrong tries | `{"error": "too_many_tries"}` |

The token is at least 32 random bytes, base64url. The desktop stores only its SHA-256 hash, with the device info, so it can list paired phones and unpair one. The phone stores the token in the Keychain (this device only, not in backups) and the computer's name and address in its settings.

### `GET /api/v1/hello`

Header `Authorization: Bearer <token>`. Used by **Test connection** in Settings.

- `200` `{"computerName": "Storm-PC", "protocolVersion": 1}`
- `401` if the token is unknown (the phone then says to pair again).

### `DELETE /api/v1/pair`

Header `Authorization: Bearer <token>`. The desktop forgets that phone and answers `204`. The phone forgets the computer even if this call fails.

## Live messages (next step)

Once paired, the app will open a WebSocket to `ws://<host>:<port>/api/v1/events` with the same `Authorization: Bearer <token>` header. Each message is one JSON object with a `type`:

- Desktop to phone: `team.snapshot` (all bots and their status), `bot.status`, `chat.message`, `inbox.item`, `live.log`.
- Phone to desktop: `chat.send`, `inbox.answer` (OK or decline a push), `routine.save`, `call.start`.

Every message carries an `id` so either side can answer with `{"type": "ack", "id": ...}`. The app still shows pretend data until this part is built.

## Safety

- Codes are short-lived, single-use and limited to 5 tries.
- Only the local network is reachable; the token is useless from outside the house.
- HTTP on the Wi-Fi isn't encrypted, so someone on the same network could read traffic. A later version should switch to HTTPS with a certificate the phone pins during pairing (the QR code can carry its fingerprint as `fp=`).

## Try it now with the pretend desktop

On a computer on the same Wi-Fi as the phone or iPad:

```
python3 tools/pairing_test_server.py
```

It prints the address, a 6-digit code and the `squall://` link (and a QR code if `pip install qrcode` is done). In the app, scan it or tap **Type the code**. Press Enter in the terminal for a fresh code. If the phone can't reach it, allow Python through the computer's firewall for private networks.
