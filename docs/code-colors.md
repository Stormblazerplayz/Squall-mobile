# Code colors in chats

Code blocks in chats are now in color, like in a code editor:

- **Keywords** (`func`, `let`, `if`, `return`...) in purple, **strings** in green, **numbers** in orange, **type names**
  in blue, and **comments** in gray italics.
- **Diffs** show removed lines in red and added lines in green, with the `@@` lines in blue. A block with no language
  that is clearly a diff gets the same colors.
- **Line numbers** down the side of code with 4 lines or more.
- **Wrap**: the button next to Copy wraps long lines instead of scrolling sideways. Squall remembers your choice.
- The header shows how many lines the code has. You can select part of the code to copy it.

Languages: Swift, JavaScript and TypeScript, Python, Go, Rust, Java, Kotlin, C, C++, C#, Ruby, shell, JSON, YAML,
TOML, SQL and CSS. Anything else stays plain. Very long code (over 20,000 characters) stays plain so chats stay fast.

Code: `Squall/Models/CodeHighlight.swift`, `Squall/Views/Chat/CodeColors.swift` and `CodeBlockView` in
`MarkdownText.swift`. Tests: `SquallTests/CodeHighlightTests.swift`.
