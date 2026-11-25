# Work timers and goals

The timer button in a chat's header keeps that teammate working, the same as the timer dial on the computer.

- **Work timer:** pick 15 min, 30 min, 1 h, 2 h, 4 h or Continuous, then Start. The teammate keeps going until the time
  is up and gets a nudge whenever it stops early. Continuous runs until you stop it.
- **Banner:** while a timer runs, a bar under the chat's header shows a ring, the time left and Stop.
- **Lock Screen:** tap Lock Screen on the banner or in the timer sheet to put the timer on the Lock Screen and in the
  Dynamic Island. It counts down by itself (or up, for Continuous), shows Paused with the team, and has Stop and Open
  chat. It ends when the computer no longer lists the timer: "Time's up" when the time ran out, "Stopped" when someone
  stopped it early. Stop on the Lock Screen sends `timer.stop` straight to the computer, even when Squall is closed.
- **Goal:** type one thing to finish and tap Set goal. It's sent as `/goal ...`, so the team works on it step by step.

The button only shows when Squall on the computer sends `timers` in its state (squall-computer docs/phone-timers.md).

Code: `WorkTimers` in Squall/Models/WorkTimers.swift and the views in Squall/Views/Chat/WorkTimerViews.swift. The Lock
Screen part is `WorkTimerActivityAttributes` (Shared/SquallActivityModels.swift), `StopTimerIntent`
(Shared/SquallActivityIntents.swift), SquallActivities/WorkTimerActivityWidget.swift and `startTimer` in
Squall/LiveActivities/LiveActivities.swift.
