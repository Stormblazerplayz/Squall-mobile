# Back up this phone

Settings > Data > **Back up this phone** saves the Squall things that live only on your phone into one file:

- Starred messages
- Saved prompts
- How the app looks and acts: your name, message text size, typing dots, times, Send with Return, haptics, sounds,
  soft glow, which chat opens first, the new teammate role, hide in app switcher, Lock Screen and reply pings
- The accent color
- Notification choices: which pings, sound, quiet hours and muted teammates

It never holds the pairing, keys, App lock, chats, teammates or the Safety and Chief settings. Those stay with your
computer, so the file is safe to keep in Files or iCloud Drive.

**Restore** opens a backup file and shows what's in it first. Stars and prompts are added to the ones already on the
phone (nothing is doubled). Settings, the accent color and notification choices are replaced.

Only the settings listed above are read from a file, each checked for the right kind and size, so a changed file can't
set anything else. The code is in `Squall/Models/SquallBackup.swift` and `Squall/Views/Settings/BackupRow.swift`,
with tests in `SquallTests/SquallBackupTests.swift`.
