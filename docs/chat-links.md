# Links in chats

Links your teammates send are easy to see and open.

## What it does

- **Bare links work.** A link like `https://github.com/…` or `www.…` in any message can be tapped, in a teammate's
  reply and in your own (yours are underlined). Text in `code` stays as it is.
- **Link cards.** Under a teammate's reply, each web link it has (up to three) gets a small card with the site,
  the rest of the link, and an arrow. Tap the card to open it. Press and hold to open, copy or share it.
- **Links on your computer.** A link to `localhost` or `127.0.0.1` (like a dev server) only opens on the computer,
  so its card shows a computer and copies the link instead of trying to open it. A link to another computer on your
  home network (`192.168.…`, `10.…`, `name.local`) says "On your home network" and opens when the phone is on the same Wi-Fi.
- **Copy link.** Press and hold any message with a link and pick Copy link.

## What counts as a link

Only `http` and `https` links. A bare link has to start with `http://`, `https://` or `www.`, so file names like
`README.md` or `app.py` never turn into links. Links inside code blocks get no card.

Nothing is fetched to make a card: it's built from the link itself, so no site learns you got a link.

## Where it lives

- `Squall/Models/ChatLinks.swift`: finding links, making bare ones tappable, and the card words.
- `Squall/Views/Chat/LinkCards.swift`: the cards, and underlined links in your own messages.
- Tests: `SquallTests/ChatLinksTests.swift`.
