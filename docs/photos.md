# Photos

Send photos to a teammate from any chat.

- Tap the photo button left of the message box and pick up to 3 photos.
- They show above the box. Tap the x on one to take it out.
- Add words if you want, then tap send. The photos and words go together as one message.

Each photo is made smaller on the phone first (longest side up to 1600, under 210 KB), because the link to the computer
takes 1 MB at a time. On the computer, Squall saves them like a pasted photo and the teammate gets them to look at.
Picked photos stay with their chat until you send them or unpair.

Needs Squall on the computer with phone photos (squall-computer docs/phone-photos.md). On an older one, sending shows an
error and the photos stay picked.

Code: `PhotoSend` and `PhotoTray` in Squall/Models/PhotoSend.swift, `PhotoPickButton` and `PhotoStrip` in
Squall/Views/Chat/PhotoViews.swift.
