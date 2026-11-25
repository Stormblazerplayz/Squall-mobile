# Ask with a saved prompt

A Shortcuts action that sends one of your saved prompts to a teammate and reads you the answer.

## Using it

1. Save a prompt in Squall: tap the book at the top of any chat.
2. In the Shortcuts app, add **Ask with a saved prompt** from Squall.
3. Pick the prompt. Pick a bot, or leave it empty to ask Chief.
4. Run it from Shortcuts, the Home Screen, the Action button, or say the shortcut's name to Siri.

`{name}` becomes the bot's name and `{today}` becomes today's date, the same as in a chat. Each run counts as a use, so
the prompt moves up in "Most used".

## Notes

- It needs Squall to be paired with your computer. If it isn't, it says so and nothing is counted.
- If the prompt was deleted, it says so and sends nothing.
- It isn't one of the built-in Siri phrases, because Squall already has the most phrases iOS allows (10). It still
  shows up in the Shortcuts app and works with Siri once it's in a shortcut.
- Prompts stay on this phone. Nothing new is sent to the computer except the question itself.

Code: `Squall/Intents/SavedPromptIntents.swift`. Tests: `SquallTests/SavedPromptIntentsTests.swift`.
