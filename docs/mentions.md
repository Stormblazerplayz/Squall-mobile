# @mentions

Write a teammate's name after @, like "@Rex can you take the tests?". In your messages and in teammates' replies, the
mention shows bold, and tapping it opens that teammate's chat.

- Only names on your team count, in any case (@rex works too). @everyone, emails like rex@example.com and longer words
  like @Rexy stay plain text.
- A mention inside `code` stays as code.

Code: `Squall/Models/Mentions.swift` (finding and styling), `Squall/Views/Chat/MentionTaps.swift` (the tap).

## Picking a name

Type @ in the message box and a row of teammates shows above it, names that start with what you typed first. Tap one
to finish the name with a space after it. In a group chat it lists the group's members.
Code: `Squall/Models/MentionPicker.swift`, `Squall/Views/Chat/MentionPickerBar.swift`.
