# Team history

Tap the clock in the Inbox header to see everything your team did, newest first.

- **Today card:** messages, finished work, problems and hand offs today, plus a bar for each hour (the current hour is bright) and the busiest hour.
- **Filters:** All, Chats, Needs you, Problems, Done (finished work and jobs started) and Hand offs, each with a count.
- **People:** tap a teammate to see only what they did, or what was sent or handed to them.
- **Search:** finds words in any entry.
- **Timeline:** grouped by day (Today, Yesterday, then the date). Tap an entry to open that teammate's chat.

## Where it comes from

Everything is built from the state Squall on the computer already sends: messages, inbox items, hand offs and jobs started, each with its real time (`at` or `startedAt`). Entries with no time are left out so the order is always true. When the computer sends a `handoffs` list, hand off messages in chats aren't counted again. Nothing is made up.

`HistoryFeed` keeps the latest state (one line in `SquallStore.keepCopy`) and only decodes it while the history screen is open.

## Files

- `Squall/Models/TeamHistory.swift`
- `Squall/Views/Inbox/TeamHistoryView.swift`
- `SquallTests/TeamHistoryTests.swift`
