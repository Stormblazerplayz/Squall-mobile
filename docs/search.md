# Search every chat

Tap the magnifying glass at the top of a chat (or press ⌘F with a keyboard) to search every chat with a teammate.

- Every word you type has to be in the message. Case and accents don't matter, so "cafe" finds "Café".
- The chips under the box show how many messages each chat has. Tap one to search only that chat.
- Results are grouped by chat, newest first, with the words lit up. At most 200 show.
- Tap a result to open that chat. It scrolls to the message and lights it up for a moment.
- Your last 6 searches stay on the phone under Recent. Clear removes them.

Search only looks at what the computer has synced to the phone (each chat's recent messages). Nothing is sent to the computer.

Code: `Squall/Models/ChatSearch.swift` (the matching, tested in `SquallTests/ChatSearchTests.swift`) and
`Squall/Views/Search/ChatSearchView.swift`. The chat's jump to the message is in `ChatView.swift` (`jumpIfAsked`).
