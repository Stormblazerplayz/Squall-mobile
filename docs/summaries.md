# Summaries and Catch up

- **Summary:** long teammate messages (500 characters or more) get a Summary button. Tap it and Squall on the computer
  writes a one or two sentence version, shown under the message here and on the computer.
- **Catch me up:** once a chat has 8 messages, a Catch me up button shows under the header. Tap it for a short version
  of the latest messages (up to 30). When new messages come in after it, "Catch me up again" refreshes it. The x hides
  the button or the card until something new comes in.

Both only show when Squall on the computer sends `summaries` in its state (squall-computer docs/phone-summaries.md).

Code: `ChatSummaries` and `CatchUpMemory` in Squall/Models/ChatSummaries.swift, and `MessageSummary` and `CatchUpBar`
in Squall/Views/Chat/ChatSummaryViews.swift.
