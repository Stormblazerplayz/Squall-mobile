# Full editor for long messages

When a message gets long (about 160 characters, or 4 lines), an **Open full editor** button shows over the message box.
It opens a full-screen editor for that chat's draft:

- **Write**: a big text box with buttons that add a heading, list, numbered list (carries on from the last number),
  to do, quote or code block on a new line.
- **Preview**: how the message looks with its Markdown, the same way replies are shown.
- Word and character counts at the bottom.
- **Send** sends it like the normal Send button. **Done** keeps it as the draft.

Code: `Squall/Models/BigEditor.swift`, `Squall/Views/Chat/BigEditorSheet.swift`.
