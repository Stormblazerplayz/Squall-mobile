# Chat list: favorites, order and search

On iPad, the chat column beside a conversation now has:

- **Favorites**: press and hold a chat and pick **Add to favorites**. Favorites sit at the top in their own section,
  in the order you added them, with a small gold star. They also come first in the row of teammates above a chat
  on iPhone.
- **Order**: the arrows button sorts the rest by **Latest message** (the default), **Name** or **Team order**.
  Chats with no dated message keep team order after the others.
- **Find a chat**: type to filter by a teammate's name, role or what they're working on.

Favorites and the order are kept on this phone. A teammate who leaves the team drops off the favorites.

Code: `Squall/Models/ChatFavorites.swift` (favorites and `ChatListOrder`), `ChatList` and `BotStrip` in `ChatView.swift`.
