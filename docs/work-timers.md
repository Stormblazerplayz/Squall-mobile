# Work timers and goals

The timer button in a chat's header keeps that teammate working, the same as the timer dial on the computer.

- **Work timer:** pick 15 min, 30 min, 1 h, 2 h, 4 h or Continuous, then Start. The teammate keeps going until the time
  is up and gets a nudge whenever it stops early. Continuous runs until you stop it.
- **Banner:** while a timer runs, a bar under the chat's header shows a ring, the time left and Stop.
- **Goal:** type one thing to finish and tap Set goal. It's sent as `/goal ...`, so the team works on it step by step.

The button only shows when Squall on the computer sends `timers` in its state (squall-computer docs/phone-timers.md).

Code: `WorkTimers` in Squall/Models/WorkTimers.swift and the views in Squall/Views/Chat/WorkTimerViews.swift.
