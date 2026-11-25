# Messages wait when the computer is away

Before, sending a message while your computer wasn't answering showed an error and the message was lost.
Now it waits.

- The message shows at the bottom of the chat as a faded bubble with a dashed edge and
  "Sends when your computer is back".
- As soon as the computer answers again, waiting messages go out in the order you wrote them, and a toast says how
  many were sent. This works after the app was closed too: they go out the next time Squall connects.
- If one fails, it and the ones after it stay waiting, so nothing is sent out of order.
- Long-press a waiting message to **Send now** (when connected), **Edit** it (it moves back into the message box),
  **Copy** it or **Delete** it.
- Up to 50 messages can wait. They're dropped if the teammate leaves the team or the computer is unpaired.
- With no computer paired at all, sending still says to pair first.

Code: `Squall/Models/Outbox.swift`, `Squall/Views/Chat/OutboxBubbles.swift`, and `send` and `flushOutbox` in
`SquallStore`. Tests: `SquallTests/OutboxTests.swift`.
