# Teammate widget

A widget for one teammate: their color, what they're doing, their job, and the last message in your chat with them.
Tapping it opens that chat.

## Adding it

1. Long-press the Home Screen (or the Lock Screen), tap **Edit** or **+**, and pick **Squall teammate**.
2. Long-press the widget and tap **Edit Widget** to pick the teammate. With none picked it shows Chief.

Sizes: small and medium on the Home Screen; a line and a box on the Lock Screen.

## What it shows

- **Small**: the teammate, their status, and the last message ("You:" in front when it was yours).
- **Medium**: their job, the last message with who said it, and **Open chat**.
- The message time, or "Old data" once it's more than 15 minutes old.
- Before Squall has talked to your computer it says "Open Squall to sync", and after Unpair it says "Not paired".
  If the picked teammate is removed, it shows Chief.

## How it works

After each real update from the computer, the app saves a small summary (`Shared/TeammateWidgetData.swift`) the same
two ways the team widget does: the App Group folder when the build has one, and the shared Keychain group. It only
reloads the widget when something on it changed, or every 5 minutes so it can tell the data is fresh. Messages are
plain words with Markdown taken out, cut at 220 characters.

The code is in `Squall/App/TeammateWidgetWriter.swift` and `SquallActivities/TeammateWidget.swift`, with tests in
`SquallTests/TeammateWidgetTests.swift`.
