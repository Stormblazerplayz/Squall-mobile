# Share a chat as PDF

Tap ••• at the top of a chat and pick **Share as PDF**. Squall draws the chat onto Letter pages the way it looks in the
app: each message with the teammate's sphere, name, color and time, Markdown, tables and code included, on the dark
Squall background, with a title and the date at the top.

- A message is kept whole on one page when it fits. A message taller than a page gets its own page.
- The PDF is made on the phone only when you pick where it goes. Nothing is uploaded.
- Code wraps and tables show in full on the page, since a page can't scroll sideways.
- Share chat still gives the Markdown file.

Code: `Squall/Models/ChatPDFLayout.swift` (pages), `Squall/Views/Chat/ChatPDF.swift` (drawing).
