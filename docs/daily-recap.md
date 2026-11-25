# Evening recap

Turn on **Settings > Notifications > Evening recap** and pick a time (6 PM to start with). Once a day you get a ping
like:

> **Your team today**
> Rex was busiest. 14 messages, 3 jobs done and 1 problem. Most happened around 2 PM.

- It's built from Team history, so it only counts things with a real time from your computer.
- No ping on a day when nothing happened.
- It's kept up to date while Squall gets updates (at most every 10 minutes), so it shows what the phone last saw.
- A silent Focus filter makes it land quietly. Tapping it opens the Inbox, where Team history and Team stats are.

Code: `Squall/App/DailyRecap.swift`, `Squall/Views/Settings/DailyRecapRow.swift`. Tests: `SquallTests/DailyRecapTests.swift`.
