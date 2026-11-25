# Reply pings

When a teammate answers you in a one-on-one chat and Squall isn't open, your phone pings with their words.
Long-press the ping (or pull it down) and tap **Reply** to answer without opening the app.

## How it works

- Every ping is a real message the computer sent. Group chats, system lines and problems don't ping
  (problems already reach you through the Inbox).
- The first time the phone sees a computer it only remembers what's already there, so pairing never pings for old messages.
- At most 4 pings come from one look, newest last, so a long time away doesn't flood your phone.
- Code blocks show as "(code)" and Markdown marks are taken out. Pings are cut at 300 characters.
- Tapping the ping opens that chat. **Reply** sends your words to the chat with `chat.send`, straight to the computer.
  If it can't be sent, you get a ping that says so.
- Pings follow Settings > Notifications: the **When a teammate replies** switch, **Play a sound**, **Quiet hours**
  (pings arrive quietly) and muted teammates.
- Unpair forgets what was seen, so the next computer starts fresh.

The code is in `Squall/App/ReplyAlerts.swift`, with tests in `SquallTests/ReplyAlertsTests.swift`.
