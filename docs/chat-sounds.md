# Chat sounds

Settings → Chat → **Chat sounds** plays iPhone's own message sounds in Squall: one when you send, and one when a
teammate's reply (or a handoff) comes into the chat you have open. A problem message gets its own short sound.

- Off until you turn it on.
- Sounds only play while Squall is on screen, and follow the ring switch, so a silenced iPhone stays quiet.
- Opening another chat, the first load and clearing a chat make no sound.

Code: `Squall/Models/ChatSounds.swift`, hooked up at the end of `ChatView`.
