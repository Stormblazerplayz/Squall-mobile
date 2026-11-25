# Long replies fold

A long reply (a big log, a long plan) no longer fills the whole chat.

## How it works

When a teammate's reply would take more than about 24 lines on a phone, it starts folded: the first part shows and
fades out, with a **Show more · 60 lines** button under it. Tap it to open the whole reply, and **Show less** to fold
it again. A reply you opened stays open while you scroll.

Short replies look the same as before. Your own messages never fold. Links, Summary, Read aloud and Copy always use the
whole reply, folded or not.

## Where it lives

- `Squall/Models/LongReplies.swift`: when a reply is long, and which ones you opened.
- `Squall/Views/Chat/FoldedReply.swift`: the fold, the fade and the button.
- Tests: `SquallTests/LongRepliesTests.swift`.
