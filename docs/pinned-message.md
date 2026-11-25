# Pin a message

Keep the one message you keep scrolling back for (a link, a port, a plan) at the top of its chat.

- Long-press a message and tap **Pin**. It shows in a bar under the chat's header with who wrote it.
- Tap the bar to read the whole message, copy it, or **Unpin** it. Long-press the message and tap **Unpin** also works.
- Each chat has one pin. Pinning another message replaces it.
- Only your messages and teammates' replies with words can be pinned.
- The pin keeps a copy of the message on this phone, so it stays after the chat is cleared. It goes away when the
  teammate leaves the team or the computer is unpaired.

Code: `Squall/Models/PinnedMessages.swift`, `Squall/Views/Chat/PinnedBanner.swift`, and Pin in the long-press menu
(`MessageMenu` in `StarredViews.swift`). Tests: `SquallTests/PinnedMessagesTests.swift`.
