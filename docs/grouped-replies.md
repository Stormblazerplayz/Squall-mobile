# Grouped replies

When a teammate sends several replies in a row, they read as one burst.

## How it works

Back-to-back replies from the same teammate, less than 5 minutes apart on the same day, group together. Only the
first shows the teammate's picture and name. The rest line up under it, a little closer, and still show their time
(when message times are on), star and Stop reading button.

A group ends when someone else writes, you write, a new day starts, more than 5 minutes pass, or a reply has its own
buttons.

## Where it lives

- `Squall/Models/ChatGrouping.swift`: which replies continue a group.
- `MessageView` in `Squall/Views/Chat/ChatView.swift` hides the picture and name for those.
- Tests: `SquallTests/ChatGroupingTests.swift`.
