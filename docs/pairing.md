# Pairing the app with Squall desktop

The first time Squall opens on a phone or iPad, it asks to pair with Squall on the computer. This page is the deal both sides follow, so Squall desktop knows exactly what to build.

The app has no made-up data. Everything it shows (bots, chats, Inbox, routines, live work) comes from the paired computer through the endpoints below. When it isn't paired, or the computer doesn't answer, every screen says **Not connected to your computer** with a **Pair** button.

You can try it today with the test desktop in `tools/pairing_test_server.py` (see the end of this page).

## What the person does

1. On the computer: Squall > Settings > **Pair a phone**. Desktop starts listening and shows a QR code, its address and a 6-digit code.
2. On the phone: scan the QR code, or tap **Type the code** and enter the address and code.
3. Both show "Paired". The phone keeps a secret token; the desktop keeps a hash of it.

**Skip for now** on the phone leaves it unpaired, so the screens show **Not connected to your computer** with a **Pair** button. Pairing can also be done in Settings > Computer, which has **Unpair** too. Unpairing wipes everything the phone got from the computer.

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

## Voice calls

**Call Chief** in the app is a real call once paired. The phone does the listening and the talking, so the desktop only deals with text:

1. The phone turns your voice into text with on-device speech recognition (that's also the live captions).
2. When you pause, it sends that sentence to the desktop.
3. The desktop asks Chief and sends back what Chief says.
4. The phone speaks it with its own voice, or plays audio if the desktop sends some.
5. If you talk while Chief is talking, the phone stops Chief and listens (barge-in).

The app needs Microphone and Speech Recognition permission. Call Chief only works while the app is connected to the computer; otherwise it shows **Not connected to your computer** with a **Pair** button.

### `POST /api/v1/voice/turn`

Header `Authorization: Bearer <token>`. The phone waits up to 45 seconds for an answer.

```json
{
  "callId": "8C1D...UUID",
  "event": "start",
  "turn": 1,
  "bot": "chief",
  "text": "",
  "locale": "en_US",
  "wantsAudio": true
}
```

| Field | Meaning |
| --- | --- |
| `callId` | Same for every turn of one call. |
| `event` | `start` when the call opens (text is empty, Chief should say hello), then `turn` for each thing you say. |
| `turn` | Counts up from 1 within the call. |
| `bot` | Who you're calling. Always `chief` for now. |
| `text` | What you said, with punctuation. |
| `locale` | The phone's language, like `en_US`. Answer in that language. |
| `wantsAudio` | `true` means the phone can play audio you send back. Sending none is fine. |

Desktop answers:

| Status | When | Body |
| --- | --- | --- |
| `200` | Chief answered | `{"text": "Two bots are working and one needs your OK.", "audio": null, "endCall": false}` |
| `401` | Unknown token | `{"error": "unknown_token"}` (the call ends, the phone says to pair again) |
| `404` / `501` | Desktop can't do calls yet | The phone says to update Squall on the computer |
| `409` / `503` | Chief can't talk right now | The phone shows it and keeps listening |

- `text` is what Chief says. Keep it short and speakable: no code blocks or long lists.
- `audio` is optional: `{"format": "mp3", "base64": "..."}`. Any format iOS can play (mp3, m4a, wav, caf). If it's there the phone plays it instead of speaking `text`, but still shows `text` as the caption.
- `endCall: true` hangs up after Chief finishes talking, for when you say bye.

### `POST /api/v1/voice/end`

Header `Authorization: Bearer <token>`. Body `{"callId": "...", "seconds": 42}`. Sent when the call ends, best effort. Answer `204`.

The desktop should save the call (what you said and what Chief said) into the chat with Chief. The phone fetches fresh data when the call ends, so it shows up there.

## Live data

Once paired, the phone asks the desktop for everything it shows, and sends back what you tap. Both need `Authorization: Bearer <token>`.

- The phone asks every **3 seconds** while connected, every **6 seconds** while the computer isn't answering, and right away when the app comes back to the front or after you do something.
- **Connected** means the last `GET /api/v1/state` worked. Two misses in a row (or one before the first success) and the app shows **Not connected to your computer**, with the reason.
- `401` / `403` means the token was forgotten: the phone says to pair again.
- `404` / `501` means this desktop can't send live data yet: the phone says to update Squall on the computer.

### `GET /api/v1/state`

Answer `200` with one JSON object. Every field is optional and anything unknown is ignored, so the desktop can grow it. One broken item is skipped instead of breaking the update.

```json
{
  "version": "1731590000-42",
  "paused": false,
  "typing": "chief",
  "bots": [
    {"id": "chief", "name": "Chief", "color": "#F5B83D", "role": "Team lead", "status": "working",
     "task": "Splitting up today's work", "unread": 0, "log": ["$ git status", "clean"], "progress": 0.4, "steps": ["Read the plan"]}
  ],
  "chats": {
    "chief": [
      {"id": "m1", "kind": "me", "text": "What's going on?", "at": "2026-11-14T15:02:00Z"},
      {"id": "m2", "kind": "bot", "author": "chief", "text": "Two bots are working.", "chips": ["Show me"], "at": "2026-11-14T15:02:05Z"}
    ]
  },
  "groups": [{"id": "g1", "name": "Build crew", "members": ["bot-a", "bot-b"], "chiefLeads": true}],
  "inbox": [
    {"id": "i1", "kind": "ask", "botId": "bot-a", "title": "Push the fix?", "body": "To a new branch, not main.",
     "command": "git push -u origin fix/ci", "workId": "w1", "unread": true, "at": "2026-11-14T15:00:00Z"}
  ],
  "routines": [
    {"id": "r1", "botId": "bot-a", "task": "Check the build", "repeat": "weekdays", "days": [true, true, true, true, true, false, false],
     "minutes": 540, "isOn": true, "pingWhenDone": true, "askBeforePush": true, "skipIfBusy": false,
     "run": {"done": 3, "total": 8, "label": "Checking files"}}
  ],
  "work": [
    {"id": "w1", "botId": "bot-a", "title": "Fix the build", "from": "Chief", "state": "waiting",
     "startedAt": "2026-11-14T14:55:00Z", "now": "Waiting for your OK to push", "askId": "i1",
     "steps": [{"title": "Found the problem", "state": "done", "took": "41s", "lines": [{"text": "The runner name is wrong.", "kind": "text"}]}],
     "terminal": [{"text": "$ git diff --stat", "kind": "cmd"}],
     "files": [{"path": ".github/workflows/ci.yml", "change": "+2 -1", "edited": true}]}
  ],
  "handoffs": [{"id": "h1", "from": "chief", "to": "bot-a", "what": "Fix the build", "at": "2026-11-14T14:54:00Z"}],
  "claudeCode": {"version": "2.1.0", "latest": "2.1.0", "needsUpdate": false, "updating": null},
  "desktop": {"version": "1.4.0", "latest": "1.5.0", "updating": false}
}
```

| Field | Meaning |
| --- | --- |
| `version` | Changes whenever anything changes. If it's the same as last time, the phone skips the update. Leave it out to always update. |
| `paused` | **Pause all** is on. |
| `typing` | The bot writing a reply right now (shows the typing dots), or `null`. |
| `bots` | Chief must have `id` `chief`. `color` is `#RRGGBB`. `status` is `working`, `idle`, `napping`, `waiting`, `handed` or `paused`. `unread` is a count. `progress` is 0 to 1. |
| `chats` | Messages per chat id: a bot's id, or a group's id. `kind` is `me`, `bot`, `system`, `error` (with `count`) or `handoff` (with `fromName`, `fromColor`, `note`). `at` is an ISO 8601 time, or send `time` as ready-made text. |
| `inbox` | `kind` is `ask` (Allow / Deny, optional `command`), `choice` (with `options`), `error` (optional `details`) or `done` (with `openLabel`, and `opens` `chat` or `live` plus `workId`). |
| `routines` | `repeat` is `daily`, `weekdays` or `custom`. `days` has 7 entries, Monday first. `minutes` is minutes after midnight. `run` is there only while it's running. `lastRun` (optional, `"2026-11-25"`) is the day it last ran or was skipped, on the computer's clock: it doesn't run again that day. |
| `work` | Jobs bots are doing. `state` is `working`, `waiting`, `paused`, `done` or `stopped`. Step `state` is `done`, `now` or `todo`. Line `kind` is `cmd`, `ok`, `warn`, `err`, `dim`, `text`, `add` or `del`. `askId` points at the Inbox item the job waits on. |
| `handoffs` | Recent work passed between bots, newest first. |
| `claudeCode` | The Claude Code version Chief uses. `updating` is 0 to 1 while an update runs. |
| `desktop` | Optional. Squall desktop's own `version`, the newest on GitHub Releases as `latest` (once it has checked), and `updating` while it installs one. Settings > Computer shows it as "1.4.0 · 1.5.0 is ready" or "1.4.0 · updating". |
| `usage` | Optional. The plan's usage, for **Plan usage** (see below). Older desktops leave it out and the screen says to update Squall. |

#### `usage`

What the desktop reads from Claude (every Claude run reports the plan's 5-hour and weekly windows) and measures itself. Nothing is guessed: a prediction is only there once the desktop has enough readings.

```json
"usage": {
  "windows": [
    {"id": "five_hour", "label": "5-hour limit", "percent": 42, "resetsAt": "2026-11-25T14:14:00Z", "predicting": false, "atReset": 61},
    {"id": "week", "label": "Weekly · all models", "percent": 17, "resetsAt": "2026-11-29T09:00:00Z", "predicting": true}
  ],
  "slowDown": true, "limit": 80, "throttled": false,
  "readAt": "2026-11-25T11:58:00Z",
  "today": {"day": "2026-11-25", "bots": [{"botId": "chief", "jobs": 3, "seconds": 840}]}
}
```

| Field | Meaning |
| --- | --- |
| `windows` | Each window: `id` (`five_hour`, `week`, or `week-<model>`), `label`, `percent` used (0 to 100), `resetsAt`. `atReset` is where the pace lands at the reset, `runsOutAt` is when it runs out (only when that's before the reset), and `predicting` is `true` while there aren't enough readings yet. |
| `slowDown` | **Slow the team down to save usage** is on: while usage is tight, bots keep turns short, skip extra work and aren't woken up. |
| `limit` | Also slow down once the 5-hour window reaches this percent (10 to 100), or `null` for only when the pace would run out. |
| `throttled` / `why` | The team is slowed down right now, and why: `pace` (on track to run out before the reset) or `limit`. |
| `readAt` | When the desktop last read the usage from Claude. |
| `overage` | Optional. The plan is using extra usage past its limits. |
| `today` | The jobs each bot ran today on the desktop's clock, timed by Squall from start to end. Bots with no jobs are left out. |

Lock Screen Live Activities only start from this data: a running `work` job, an `ask` Inbox item, a routine with `run`, or busy bots. They end when the thing they follow is gone, and when the phone loses the computer.

### `POST /api/v1/action`

One thing you did on the phone. The body is flat: `type`, a unique `id` (so the desktop can ignore repeats), and the fields below.

```json
{"type": "inbox.answer", "id": "5B2E...UUID", "itemId": "i1", "answer": "allow"}
```

Actions don't only come from the app's screens. Widget and Control Center buttons, Lock Screen and Dynamic Island buttons, notification buttons (Allow and Deny) and Siri send them too, often while the app is closed and hasn't fetched the state yet. They use the same token and the same types, and every press has its own `id`. Siri's **Ask Chief**, **Ask a bot** and **Start a task** send `chat.send` with the bot's id as `chatId`. To read the answer out, Ask then fetches `/api/v1/state` about once a second for up to 24 seconds and takes the bot's messages after the one it sent, once that bot isn't `typing` or `working` any more. Siri's **Approve** and **Decline** send `inbox.answer`.

Answer `200` with `{"ok": true}`. When something new was made, add its id: `{"ok": true, "id": "bot-c"}`. When it didn't work, answer `{"ok": false, "error": "Short reason to show"}` (any status). The phone fetches `/api/v1/state` right after, so the desktop doesn't need to send the new state back.

| `type` | Fields | What it does |
| --- | --- | --- |
| `chat.send` | `chatId`, `text` | Message a bot or a group. |
| `chat.read` | `chatId` | Mark a chat read. |
| `chat.clear` | `chatId` | Clear one chat. |
| `chat.clearAll` | | Clear every chat (bots keep their memory). |
| `chief.retry` | | Try Chief's last failed job again. |
| `chief.wake` / `chief.nap` | | Wake Chief up, or let it nap. |
| `bot.create` | `name`, `role`, `color` (`#RRGGBB`), `job` | Add a teammate. Reply with its `id`. |
| `group.create` | `name`, `members` (bot ids), `chiefLeads` | Make a group chat. Reply with its `id`. |
| `handoff` | `botId`, `job` (`take_over`, `review` or `split`), `note` | Hand a bot's work to Chief. |
| `inbox.answer` | `itemId`, `answer` (`allow`, `deny`, or one of the `options`) | Answer an ask or a choice. |
| `inbox.read` / `inbox.clear` | `itemId` | Mark read, or remove. |
| `inbox.readAll` | | Mark everything read. |
| `work.pause` | `workId`, `paused` | Pause or resume a job. |
| `work.stop` | `workId` | Stop a job. |
| `work.note` | `workId`, `text` | Tell a working bot something. |
| `team.pause` | `paused` | Pause all, or resume. |
| `routine.save` | `routine` (same shape as in the state, with `id`) | Make or change a routine. |
| `routine.toggle` | `routineId`, `isOn` | Turn a routine on or off. |
| `routine.delete` | `routineId` | Delete a routine. |
| `routine.skip` | `routineId` | Skip today's run (from Routines, or from the Lock Screen while it runs). |
| `claudeCode.update` | | Update Claude Code on the computer. |
| `settings.save` | `settings` (the phone's Chief, safety and notification settings) | Keep the desktop's rules in sync. |
| `usage.settings` | `throttle` (`true`/`false`) and/or `limit` (10 to 100, or `null`) | **Slow the team down to save usage**, and the percent that also slows it down. Send the new state before answering, so the phone's next read shows it. |

If the desktop doesn't know a `type`, answer `{"ok": false, "error": "..."}` or `501`; the phone shows the message.

## Safety

- Codes are short-lived, single-use and limited to 5 tries.
- Only the local network is reachable; the token is useless from outside the house.
- HTTP on the Wi-Fi isn't encrypted, so someone on the same network could read traffic. A later version should switch to HTTPS with a certificate the phone pins during pairing (the QR code can carry its fingerprint as `fp=`).

## Try it now with the test desktop

On a computer on the same Wi-Fi as the phone or iPad:

```
python3 tools/pairing_test_server.py
```

It prints the address, a 6-digit code and the `squall://` link (and a QR code if `pip install qrcode` is done). In the app, scan it or tap **Type the code**. Press Enter in the terminal for a fresh code. Add `--no-voice` to act like a desktop that can't do calls yet, or `--no-live` to act like one that can't send live data yet. If the phone can't reach it, allow Python through the computer's firewall for private networks.

It's a test tool, not real Squall: it serves a small test team, clearly named "Test" bots, so every screen and every button can be tried end to end. Chat messages get a simple echo, Allow and Deny change the test job, and **Call Chief** answers with a few fixed lines. Real data comes from Squall desktop once it builds these endpoints.
