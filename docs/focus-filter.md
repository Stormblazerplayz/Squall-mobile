# Focus filter

Squall works with iOS Focus. Set it up once and your phone stays calm during school, sleep or anything else.

1. Open iPhone **Settings > Focus** and pick a Focus.
2. Under **Focus Filters**, tap **Add Filter**, then **Squall**.
3. Pick what gets through:
   - **Everything** (no change)
   - **Only when a teammate needs me** (questions and OKs)
   - **Only Chief**
   - **Nothing**
4. Turn on **Without sound** to have pings land quietly in Notification Center.

iOS switches the filter on and off with the Focus. While it's on, Settings > Notifications in Squall shows
"A Focus is on" with what's getting through, and **Let all in** goes back to normal until the next time the Focus starts.
Your team keeps working either way, and the app icon's number still counts what needs you.

Code: `Squall/Models/FocusRules.swift`, `Squall/Intents/SquallFocusFilter.swift`, `Squall/Views/Settings/FocusPingsRow.swift`.
Tests: `SquallTests/FocusRulesTests.swift`.
