# Inbox widget

Add **Squall Inbox** from the Home Screen widget gallery (medium or large).

- It lists what needs you first, then what broke, with the teammate, the time and (on the large one) the command an OK
  would run.
- **✓ Allow** and **✗ Deny** work right on the widget. Allow asks you to unlock the phone first, like on the Lock Screen.
- A question with choices shows **Answer**; tap the widget to answer it in Squall.
- The header counts everything that needs you and every problem, and the bottom says how many more are in Squall.
- Snoozed things are left out. When nothing needs you it says so.
- The data comes from your paired computer only. If it's more than 15 minutes old, the buttons go away and the widget
  says how old it is. After Unpair it says "Not paired".

Code: `Shared/InboxWidgetData.swift`, `Squall/App/InboxWidgetWriter.swift`, `SquallActivities/InboxWidget.swift`.
Tests: `SquallTests/InboxWidgetTests.swift`.
