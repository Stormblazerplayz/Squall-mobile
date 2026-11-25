# Starred messages

Press and hold a message in a chat to get **Copy**, **Copy as plain text** (teammate replies with formatting), **Star**
and **Share**.

- **Star** keeps a copy of the message in Starred, with a small gold star next to it in the chat.
- Once something is starred, a gold star shows at the top of every chat. It opens **Starred**, starting on that chat.
- **Starred** has a chip for each chat with stars, search, and for each message: Open chat, Copy, Unstar, and
  Show all for long ones. "Not in the chat anymore" shows when the chat no longer has that message.
- Stars live on this phone (up to 300), so they stay after a chat is cleared. **Clear all** takes every star off and
  leaves the chats as they are.

Only your messages and teammates' replies can be starred. Nothing is sent to the computer.

Code: `StarredMessages` in Squall/Models/StarredMessages.swift, and `StarredButton`, `MessageMenu` and `StarredView` in
Squall/Views/Chat/StarredViews.swift. Tests in SquallTests/StarredMessagesTests.swift.
