# Quick replies

Answer a teammate's quick question with one tap.

## How it works

When the newest message in a chat is a teammate's reply that ends with a question you can answer in a word, tap-to-send
answers show under it:

- **Asking to do something**: "Should I push it?", "Want me to open a PR?" get **Yes, go ahead** and **No, wait**.
- **Yes or no**: "Did the tests pass?" gets **Yes** and **No**.
- **A choice**: "Postgres or SQLite?" gets **Postgres** and **SQLite**. "Red, green or blue?" gets all three.
  "Should I keep going or stop?" gets **Keep going** and **Stop**.

Tapping one sends it right away, like typing it. The answers go away once you reply or the teammate starts typing.

A question that needs a real answer ("What should the button say?") gets no quick replies, and neither does a reply
whose question isn't its last line. When the teammate already sent its own buttons, those show instead.

## Where it lives

- `Squall/Models/QuickReplies.swift`: finding the question and the answers.
- `Squall/Views/Chat/QuickReplyRow.swift`: the row of answers.
- Tests: `SquallTests/QuickRepliesTests.swift`.
