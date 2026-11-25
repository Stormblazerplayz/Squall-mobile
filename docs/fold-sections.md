# Fold parts of a long reply

When a teammate's reply has two or more headings, each heading gets a small chevron.

- Tap a heading to fold away everything under it, up to the next heading of the same size or bigger. It shows "3 more parts" so you know something's there.
- Tap it again to open it. Folding a big heading folds the smaller ones inside it too.
- Folds are just for reading on screen. A PDF of the chat shows every part.

Code: `Squall/Models/MarkdownSections.swift`, the headings in `MarkdownText`.

## Press and hold a heading

- **Copy this part**: copies the heading and everything under it, as Markdown.
- **Show only this part**: folds every other part, but keeps the parts around it and inside it open.
- **Fold all** and **Open all**: fold or open every part at once.
