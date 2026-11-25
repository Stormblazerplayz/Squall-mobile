# Manage teammates

Settings > **Your team** lists every teammate, with a crown on each chief and how full the team is. Tap one to:

- **Rename** it (2 to 20 letters and digits, starting with a letter, not already used). Its chats, routines and history move to the new name.
- **Chief:** make it a chief or take that away. A team has 1 to 4 chiefs.
- **Remove** it from the team, after a confirm. Its chats and routines go; its folder stays on the computer. The only chief can't be removed.

Squall on the computer does each one with the same checks as its right-click menu (squall-computer docs/phone-teammates.md). The phone checks the same rules first, so a button says why it can't be used.

## Where it comes from

The state's `team` block (`size`, `max`, `chiefs`, `maxChiefs`, `manage`) and `bots[].chief`. An older computer sends no block, and the sheet says to update Squall there. The latest state is read from `HistoryFeed` (Team history, #42), so nothing new is added to the store.

## Actions

`bot.rename { botId, name }`, `bot.chief { botId, on }`, `bot.remove { botId, confirm }` where `confirm` is the name the phone showed.

## Files

- `Squall/Models/TeamManage.swift`
- `Squall/Views/Settings/TeamManageViews.swift`
- `SquallTests/TeamManageTests.swift`
