# Tell me when a teammate is done

Waiting on a long job? Open the teammate's chat, tap ••• and pick **Tell me when Rex is done**.

- It's only offered while the teammate is working.
- A gold bell shows next to their status while you wait. Tap it (or pick **Stop waiting on Rex**) to cancel.
- When they stop working, the phone pings once and the watch ends. The ping says how they stopped:
  - done and free, or taking a nap: "Rex is done"
  - waiting on you: "Rex needs you"
  - handed the work to Chief: "Rex handed it on"
  - the team was paused: "Rex was paused"
- Tapping the ping opens their chat. Focus rules that keep Squall quiet make the ping silent.
- Watches are kept on the phone. The ping comes the next time Squall gets the team from the computer.
- Removing the teammate, or unpairing the computer, drops the watch with no ping.

Code: `Squall/Models/DoneWatch.swift`, the menu and badge in `Squall/Views/Chat/ChatMoreMenu.swift`,
and the check in `SquallStore` next to the evening recap. Tests: `SquallTests/DoneWatchTests.swift`.
