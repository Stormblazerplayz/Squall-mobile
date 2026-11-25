# Share a chat

Save a whole chat with a teammate as a Markdown file, or copy it.

## How to use it

Tap the **•••** button at the top right of a chat:

- **Share chat** > **Share as a file**: picks where the file goes (Files, Notes, Mail, AirDrop, another app). The file is called
  "Chat with Rex 2026-11-25.md".
- **Share chat** > **Copy chat**: puts the same Markdown on the clipboard.
- **Clear chat**: moved here from the trash button. It still asks first, and starred messages stay in Starred.

## What's in the file

- A title and when it was saved.
- A heading for each day, with the real date.
- Each message with who wrote it and its time. Replies keep their Markdown, so code and lists look right in any
  Markdown app.
- Problems, hand offs (with their note) and team notes like "Rex joined".

Only the messages on the phone go in the file. The file is made when you pick where it goes, in a temporary folder
that iOS cleans up.

## Where it lives

- `Squall/Models/ChatExport.swift`: the Markdown, file name and writing the file.
- `Squall/Views/Chat/ChatMoreMenu.swift`: the ••• menu and the shareable transcript.
- Tests: `SquallTests/ChatExportTests.swift`.

## The ••• menu

The menu keeps the everyday things on top and folds the rest into two submenus:

- **Browse this chat**: Go to a day, Links, Code, To-dos and Chat stats.
- **Share chat**: Share as a file, Share as PDF and Copy chat.
