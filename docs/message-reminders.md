# Remind me

Pick a time on any message, and Squall pings you then with the message. Tapping the ping opens that chat.

## Using it

1. Press and hold a message in a teammate's chat.
2. Tap **Remind me** and pick a time: in 20 minutes, in 1 hour, in 3 hours, this evening (6 PM) or tomorrow morning (8 AM).
3. A gold bell shows at the top of the chat while a reminder is coming. Tap it to see every reminder, open its chat or take
   it off.

Picking a new time on the same message moves its reminder. Press and hold it again to take the reminder off.

## Notes

- Reminders are local notifications, so they come even when Squall is closed. Squall asks to send notifications the first
  time you set one, if it hasn't asked yet.
- A silent Focus (see [focus-filter.md](focus-filter.md)) makes the ping quiet.
- Reminders stay on this phone, up to 50 at a time. Nothing is sent to the computer.
- A teammate that's removed takes its reminders with it. Forgetting the computer clears them all.
- "This evening" isn't offered once it's less than 30 minutes to 6 PM.

Code: `Squall/Models/MessageReminders.swift`, `Squall/Views/Chat/ReminderViews.swift`. Tests: `SquallTests/MessageRemindersTests.swift`.
