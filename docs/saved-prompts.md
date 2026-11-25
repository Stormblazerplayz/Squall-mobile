# Saved prompts

Messages you send a lot, kept on your phone so you can use them in any chat with one tap.

## Using one

- Tap the book at the top of a chat to open **Saved prompts**.
- Tap a prompt to put it in the message box (anything you'd typed stays in front of it), so you can change it before sending.
- Tap **Send to <teammate>** to send it right away.
- `{name}` becomes the teammate's name and `{today}` becomes today's date, like "Wednesday, Nov 25".

## Making one

- Tap **+**, or **Save** on the "Save what you typed" card when the message box has words in it.
- Or press and hold one of your own messages in a chat and tap **Save as prompt**.
- A name is optional. Without one, the prompt's first words are its name.
- Up to 100 prompts of up to 4,000 characters each. The same words can't be saved twice.

## Keeping them tidy

- Sort by **Most used**, **Recent** or **A to Z**, and search by name or words.
- The **…** menu on each prompt has Edit, Copy and Delete.

Prompts are kept on this phone only. The code is in `Squall/Models/SavedPrompts.swift` and
`Squall/Views/Chat/SavedPromptsViews.swift`, with tests in `SquallTests/SavedPromptsTests.swift`.
