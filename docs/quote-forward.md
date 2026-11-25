# Reply with quote and Forward to

Press and hold a message in a chat:

- **Reply with quote** puts the message in this chat's message box as a quote ("Rex said:" and the words with `>`), so
  your reply says exactly what it's about.
- **Forward to** picks another teammate. Squall opens their chat with the quote in the message box, after anything you'd
  already typed there. Handy for "Chief, look at what Rex said".

Nothing is sent until you tap Send, so you can add a note first. Your own messages are quoted as "I said:". Very long
messages are cut to 1,500 characters in the quote. In a group chat, Forward to works too.

Code: `Squall/Models/QuoteReply.swift` and the long-press menu in `StarredViews.swift`. Tests: `SquallTests/QuoteReplyTests.swift`.
