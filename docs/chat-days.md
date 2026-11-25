# Real days in chats and Jump to latest

## Day lines

A chat used to start with one "TODAY" line, even when the messages were older. Now each chat shows a line where a new
day starts: **TODAY**, **YESTERDAY**, then the day and date, like **MONDAY, NOV 23** (with the year for another year).

The days come from the time Squall on the computer puts on each message (`at` in the state). A message without a time
stays with the message before it. A computer that sends no times at all gets no lines, because a guessed day would be wrong.

## Jump to latest

Scroll up to read older messages and the chat stays where you are. New messages from teammates don't pull you down
anymore. A pill shows at the bottom instead:

- **Latest** when nothing new came in.
- **3 new messages** in the teammate's color when something did.

Tap it to jump to the end. Sending a message always takes you to the end. At the end of the chat, new messages scroll in
like before.

Code: `Squall/Models/ChatDays.swift` and `ChatView`. Tests: `SquallTests/ChatDaysTests.swift`.
