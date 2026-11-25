# Read aloud

Hear a teammate's reply instead of reading it.

## How to use it

Press and hold a teammate's reply and pick **Read aloud**. A small **Stop** button with a speaker shows next to the
teammate's name while it reads. Tap it, or press and hold the reply and pick **Stop reading**, to stop.

## What you hear

- The words without Markdown marks (no stars, hashes or backticks).
- Headings, list items and table rows each end with a short pause.
- Task list items start with "Done" or "To do".
- A code block is mentioned ("There's some Swift code here.") instead of read out symbol by symbol.
- A bare web link is read as its site: "a link to github.com".
- Very long replies stop after about 4000 letters and say the rest is in the chat.

It uses the nicest voice installed on your phone for your language. Settings > Accessibility > Spoken Content > Voices
can download a better one.

## Sound

Music or podcasts get quieter while it reads and come back after. It stops when you leave Squall, when you start
reading another reply, or when you start a call with Chief.

## Where it lives

- `Squall/Models/ReadAloud.swift`: the words to say and the speech.
- `Squall/Views/Chat/ReadingMark.swift`: the Stop button next to the name.
- The Read aloud item is in the press-and-hold menu in `StarredViews.swift`.
- Tests: `SquallTests/ReadAloudTests.swift`.
