# Working now card

While a teammate is on a job, the bottom of their chat shows a small card with what they're doing right now.

- The top line says how the job is going (Working, Waiting for you or Paused), how long it has run, and which
  step it's on, like "Working · 5 min · Step 2 of 5".
- Under it is the job's own line on what's happening now, or the step's title, or the job's title.
- The ring fills as steps finish, and the icon pulses while it's working.
- Tap the card to watch the job live.
- It goes away when the job is done or stopped. Everything on it comes from the job the computer reports.

Code: `Squall/Models/WorkNow.swift` and `Squall/Views/Chat/WorkNowCard.swift`. Tests: `SquallTests/WorkNowTests.swift`.
