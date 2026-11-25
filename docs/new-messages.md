# New messages line

See where you left off when you open a chat.

## How it works

When you open a chat, a red **3 NEW MESSAGES** line shows above the first message a teammate sent since you last had
that chat open. Replies, problems and hand offs count. Your own messages and team notes ("Rex joined") don't.

The line stays while you read and goes when you send something or open another chat. Messages that come in while
you're at the bottom of the open chat count as seen.

A chat you've never opened on this phone, or one that was cleared, shows no line. Where you left off is kept on this
phone for each chat, and forgotten when a teammate leaves the team or you use Forget everything.

## Where it lives

- `Squall/Models/NewMessages.swift`: where the line goes, the count, and `LastSeen` (where you left off).
- `Squall/Views/Chat/NewMessagesLine.swift`: the line.
- Tests: `SquallTests/NewMessagesTests.swift`.
