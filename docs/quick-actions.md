# Quick actions on the app icon

Press and hold the Squall icon on your Home Screen to jump straight in:

- **Inbox**, with how many things need you.
- **Ask Chief**, which opens Chief's chat.
- The **two teammates you talked to last**, newest first.
- **Call Chief**, when there's room left.

The list is rebuilt from your real team each time you leave Squall, and it's empty while the phone isn't paired.
If you pick a teammate before Squall has loaded the team (a cold start), Chief's chat opens first and switches to that
teammate as soon as they load, unless you've already gone somewhere else.

Picks go in the same way as Siri, so nothing new is opened on the computer. Only Squall's own routes are accepted.

Code: `Squall/App/QuickActions.swift`. Tests: `SquallTests/QuickActionsTests.swift`.
