# Slash for saved prompts

Pick a saved prompt without leaving the keyboard.

## How to use it

In any chat, type **/** in the message box. Your most used saved prompts show above the box. Keep typing to search:
**/fix** shows prompts with "fix" in their name or words, names that start with it first. Tap one and it replaces
what you typed, with `{name}` and `{today}` filled in, ready to edit and send.

Tap the **×** to close the list. It stays closed until you type something else.

## When it doesn't show

So normal messages aren't in the way, the list only shows when the box starts with "/" and:

- there's no second "/" (so a path like `/usr/bin` is just a message),
- there's no new line,
- there's no space right after the "/",
- and it's 30 letters or less.

With no saved prompts yet, it says how to save one: press and hold a message you sent and pick Save as prompt.

## Where it lives

- `Squall/Models/SlashPrompts.swift`: when the box is a search, and which prompts match.
- `Squall/Views/Chat/SlashPromptBar.swift`: the list above the message box.
- Tests: `SquallTests/SlashPromptsTests.swift`.
