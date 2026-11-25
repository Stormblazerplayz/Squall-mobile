# Answer at once

When two or more teammates are waiting for your OK, the Inbox shows **"N OKs are waiting"** with **Answer at once**.

- Every waiting OK is listed by teammate with what it wants to do (and the command, when there is one).
- Everything starts ticked. Untick anything you're not sure about and answer it on its own in the Inbox.
- **Allow** asks for Face ID, Touch ID or your passcode first, like Allow on a notification.
- **Deny** asks you to confirm.
- They go to your computer one at a time, the same way a single Allow or Deny does. Ones answered somewhere else in the
  meantime are skipped, and anything that didn't go through stays in the Inbox.
- Questions with choices aren't here, because each one needs its own answer.

The code is in `Squall/Models/AnswerMany.swift` and `Squall/Views/Inbox/AnswerManyViews.swift`, with tests in
`SquallTests/AnswerManyTests.swift`.
