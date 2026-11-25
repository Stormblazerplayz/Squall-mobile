# Snooze in the Inbox

Not ready to deal with something? Press and hold its card in the Inbox and pick:

- **For 1 hour** or **For 3 hours**
- **Until this evening** (6 PM, shown until 5:30 PM)
- **Until tomorrow morning** (8 AM)

It leaves the Inbox, Answer at once and the app icon's number, and waits under **Snoozed** at the bottom of the Inbox
with when it comes back. Tap **Wake** to bring it back early. When its time comes it's back in the Inbox with a ping
(an OK comes back with Allow and Deny on the ping).

Snoozing is kept on this phone only. Your computer and your team don't change, and the bot keeps waiting. If it's
answered or cleared somewhere else, the snooze simply goes away.

Code: `Squall/Models/InboxSnooze.swift`, `Squall/Views/Inbox/SnoozeViews.swift`. Tests: `SquallTests/InboxSnoozeTests.swift`.
