# Starred messages and saved prompts in iPhone Search

Swipe down on the Home Screen and search. Starred messages and saved prompts from Squall show up next to your teammates.

- **A starred message** opens the chat it's in.
- **A saved prompt** opens Chief's chat with the prompt in the message box, filled in for Chief, ready to send or change.

## Settings

Settings > Privacy > **Show in iPhone Search** (on to start).

It's off while **Lock with Face ID** (or Touch ID or passcode) is on, because Search would show your messages without
unlocking Squall. Turning it off, or turning App Lock on, takes everything out of Search.

## Notes

- Only what's already on this phone goes in: the newest 200 starred messages and every saved prompt. Nothing new is
  sent to or read from the computer.
- Unstarring a message or deleting a prompt takes it out of Search within a second or two.

Code: `Squall/App/SpotlightContent.swift`, `Squall/Views/Settings/SpotlightRow.swift`. Tests: `SquallTests/SpotlightContentTests.swift`.
