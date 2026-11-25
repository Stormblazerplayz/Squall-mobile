# Notes

The book button in the Inbox header opens **Notes**: the Obsidian vault on your computer.

- **Search:** type to search every note. With nothing typed you see all notes (up to 40).
- **Read:** tap a note to read it with headings, lists, to-dos, quotes and code. Obsidian links read as their words.
- **Add:** type in the box at the bottom to add to the end of the note (up to 2000 characters).
  Nothing is removed or overwritten.

Long notes show the first part and say so. Notes need the computer to be connected and Squall on the
computer to have phone notes (squall-computer docs/phone-notes.md); an older computer shows a "make sure
Squall on your computer is up to date" message.

How it works: the phone sends `notes.search`, `notes.open`, `notes.append` and `notes.close`, and reads the
answer from the `notes` block in the next state (`VaultNotes` in Squall/Models/VaultNotes.swift).
