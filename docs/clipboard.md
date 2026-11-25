# Shared clipboard

The clipboard button in the Inbox header moves text between the phone and the computer.

- **Send to computer:** type or tap Paste, then Send. It's on the computer's clipboard, ready to paste.
- **From computer:** tap Get computer clipboard to see what's on it, then Copy to put it on the phone.

The computer's clipboard is only read when you ask, and it's forgotten when you close the sheet (or after 2 minutes).
Text only, 20,000 characters at most. The button only shows when Squall on the computer has the shared clipboard
(squall-computer docs/phone-clipboard.md).

Code: `SharedClipboard` in Squall/Models/SharedClipboard.swift and the views in Squall/Views/Clipboard/ClipboardViews.swift.
