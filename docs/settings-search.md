# Search in Settings

Settings has a search field at the top. Type a word like "glow", "quiet" or "face id" and only the sections with
that setting stay on screen, so you don't have to scroll through every card.

- Every word you type has to match. "github push" finds Safety.
- Sections stay in the same order as the page. Clear the field (or tap ✕) to see everything again.
- It works the same on iPhone and iPad.

Code: `Squall/Models/SettingsSearch.swift` lists each section's words, `Squall/Views/Settings/SettingsSearchField.swift`
is the field, and `searchResults` in `SettingsView` shows the matches. Tests: `SquallTests/SettingsSearchTests.swift`.
When you add a row to Settings, add its words to its section in `SettingsSearch.sections`.
