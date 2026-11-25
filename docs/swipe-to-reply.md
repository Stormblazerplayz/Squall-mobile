# Swipe to reply

Swipe any message to the right to reply to it. A reply arrow fills in as you drag, and the phone ticks once
when letting go will reply. Let go and a quote of the message lands in the message box, ready for you to add
your answer (the same as **Reply with quote** in the long-press menu).

- Your own messages and teammates' replies can be swiped. Day lines, handoffs and problems can't.
- Mostly-up-and-down drags scroll the chat and never move a message.
- VoiceOver users get **Reply with quote** as an action on each message.
- The tick follows Settings > Haptics.

Code: `Squall/Models/SwipeReply.swift` (the math) and `Squall/Views/Chat/SwipeToReply.swift` (the gesture).
Tests: `SquallTests/SwipeReplyTests.swift`.
