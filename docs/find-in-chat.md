# Find in chat

Tap ••• at the top of a chat and pick **Find in chat**. A bar slides in under the header.

- Type words. Messages that have every word are found, from you and from the teammate, including problems. Lines like "Rex joined" are skipped.
- Case and accents don't matter, so "cafe" finds "Café".
- The bar shows "2 of 5" and jumps to the newest match first, with a glowing ring around it.
- Use the up arrow (or Search on the keyboard) for older matches and the down arrow for newer ones. They wrap around.
- Tap Done, switch chats or leave the chat to close it.

Code: `Squall/Models/ChatFind.swift`, `Squall/Views/Chat/ChatFindBar.swift`.

## Highlights

While the bar is open, the words you typed light up in gold inside every message, yours and the teammate's, so you can see why a message matched.
