# Send later

Type a message, tap the clock beside Send, and pick when it should go: in 30 minutes, in an hour, tonight at 6, tomorrow at 8, or any time in the next 7 days.

Squall on your computer keeps the message and sends it at that time (squall-computer, docs/phone-send-later.md), so it goes out even when the phone is off or the app is closed.

## In the chat

- A strip above the message box says how many messages are waiting in that chat and when the next one goes.
- Tap it to see each one with its time and a countdown, plus **Send now** and **Cancel**.
- The list comes straight from the computer's state, so it's always the computer's real list. Nothing is faked or kept only on the phone.

## How it talks to the computer

| Action | Fields |
| --- | --- |
| `chat.sendLater` | `chatId`, `text`, `at` (ISO time) |
| `chat.cancelLater` | `itemId` |
| `chat.sendLaterNow` | `itemId` |

Each state reply can carry `later: [{ id, chatId, text, at }]`, soonest first. The phone checks the same limits as the computer (1 minute to 7 days ahead) before it lets you schedule.

## Files

- `Squall/Models/SendLater.swift`: reads the list, builds the actions, quick picks and wording.
- `Squall/Views/Chat/SendLaterViews.swift`: the clock button, the sheet and the waiting strip.
- `SquallTests/SendLaterTests.swift`.
