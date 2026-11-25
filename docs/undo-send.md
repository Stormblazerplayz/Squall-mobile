# Undo send

Turn on **Settings > Chat > Undo send** and every message waits 5 seconds in the chat before it goes.

- While it waits, the bubble shows "Sending in 5…" with a ring that fills, and an **Undo** button.
- Undo takes the message back and puts its words in the message box, so you can fix them.
- Leaving Squall sends anything still waiting straight away, so nothing is lost.
- If the computer isn't answering when the wait ends, the message waits in the outbox like any other.
- It's off until you turn it on.

Code: `Squall/Models/UndoSend.swift`, `Squall/Views/Chat/UndoSendBubbles.swift`, and `send`/`sendNow` in `SquallStore`.
Tests: `SquallTests/UndoSendTests.swift`.
