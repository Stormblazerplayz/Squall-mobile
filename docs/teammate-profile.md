# Teammate profile

Tap a bot's picture at the top of its chat to open its profile.

- A ring in its status color turns slowly while it works (it stays still with Reduce Motion on).
- **Now**: what it's working on, with the step and a progress bar when there's a live job.
- **Its day**: jobs and time today (from Plan usage, only when the computer sends usage), messages in its chat and how
  many are from you, and how many of its routines are on.
- A row that opens the Inbox when it has things waiting on you or problems.
- **Message**, **Watch** (when it has a live job), **Hand off** (not for Chief) and **Routine**.
- Its latest steps, its routines with the next run, and up to 3 hand offs it was part of.

Every number comes from what the computer synced. When something isn't sent (like usage from an older Squall), that tile
is left out instead of showing a made up number.

Code: `Squall/Models/BotProfile.swift` (tested in `SquallTests/BotProfileTests.swift`) and
`Squall/Views/Profile/BotProfileSheet.swift`. The chat header uses `ProfileSphere`.
