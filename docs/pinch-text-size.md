# Pinch to change text size

Make messages bigger or smaller right in the chat.

## How to use it

Pinch the messages with two fingers: apart for bigger, together for smaller. The size snaps to **Small**, **Normal**,
**Big** and **Huge**, with a tick at each step and a badge at the top saying which one you're on. It's the same
setting as Settings > Message text size, so it changes every chat and Settings shows what you picked.

## Where it lives

- `Squall/Models/ChatTextSizes.swift`: the four sizes and how a pinch picks one.
- `Squall/Views/Chat/PinchTextSize.swift`: the pinch, the tick and the badge.
- Settings uses the same list of sizes.
- Tests: `SquallTests/ChatTextSizesTests.swift`.
