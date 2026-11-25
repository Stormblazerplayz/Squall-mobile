# Tick task lists in replies

When a teammate's reply has a task list (`- [ ] Run the tests`), tap a line to tick it, and tap again to untick it.

- Ticked lines turn green and get crossed out, with a light tap you can feel.
- A list with two or more tasks shows "2 of 5 done" with a thin bar under it. It turns green and says "All done" when every line is ticked.
- You can also untick a line the teammate already ticked.
- Ticks are kept on this phone for the last 300 replies you ticked. Going back to what the teammate wrote forgets the change.
- Removing a teammate and Forget everything drop the ticks too. A PDF of the chat shows the list as the teammate wrote it.

Code: `Squall/Models/TickLists.swift`, `Squall/Views/Chat/TickProgress.swift`, the task list lines in `MarkdownText`.
