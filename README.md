# Squall mobile

The iPhone and iPad app for Squall, Storm's AI team, built from the Squall Mobile design concepts. It's a SwiftUI app (iOS 17+) that runs on iPhone in portrait and on iPad in any direction, including landscape, with the dark, glowy look from the concepts. There's no made-up data: everything it shows comes from Squall on your computer once they're paired.

On first launch the app asks to pair with Squall on your computer (scan a QR code or type a 6-digit code). If you skip, every screen shows **Not connected to your computer** with a **Pair** button.

A line above the tabs shows the connection with a colored dot: green when it's live, yellow while connecting or trying again, red when the computer isn't answering (tap it to try again), gray when not paired. Squall tries again by itself after 2, 4, 6, 8 and then every 10 seconds, right away when Wi-Fi comes back, and whenever you open the app.

The last real update from your computer is kept on the phone, so screens open right away and can still be read when the computer is off, with when it last synced. Buttons that change something wait for the computer. Unpair (Settings > Computer) removes that copy. How pairing and live data work, and a test desktop to try it with, are in [docs/pairing.md](docs/pairing.md).

## Screens

Tabs along the bottom:

- **Team**: Chief's card (message Chief, see its steps), quick actions (new teammate, new group, routines) and the team list with unread badges. Long-press a bot, then tap the glowing Chief card to hand its work to Chief.
- **Chat**: one-on-one chat with any bot, with replies from your computer, Chief's errors with Try again, a strip to jump between bots, reply chips, the Live switch and a call button. Bot replies are formatted the way Claude wrote them: headings, lists, task lists, quotes, tables, links, and code blocks with a Copy button. Long-press a reply to copy it, with or without the formatting.
- **Saved prompts**: messages you send a lot, one tap away from the book at the top of every chat. `{name}` and `{today}` fill in by themselves (see [docs/saved-prompts.md](docs/saved-prompts.md)).
- **Back up this phone**: Settings > Data saves your stars, saved prompts and settings to one file and restores them on any phone (see [docs/backup.md](docs/backup.md)).
- **Answer at once**: when several OKs are waiting, look them over in one list and Allow (with Face ID) or Deny the ones you tick (see [docs/answer-many.md](docs/answer-many.md)).
- **Quick actions**: press and hold the app icon for the Inbox, Chief, a call or your last two teammates (see [docs/quick-actions.md](docs/quick-actions.md)).
- **Focus filter**: pick which pings get through during an iOS Focus, like only Chief or only what needs you (see [docs/focus-filter.md](docs/focus-filter.md)).
- **Snooze**: hide something in the Inbox for an hour, until this evening or until tomorrow, and get pinged when it's back (see [docs/inbox-snooze.md](docs/inbox-snooze.md)).
- **Evening recap**: one ping a day with what your team did today, only when something happened (see [docs/daily-recap.md](docs/daily-recap.md)).
- **Chat drafts**: what you typed but didn't send stays in each chat, with a pencil on the teammate (see [docs/chat-drafts.md](docs/chat-drafts.md)).
- **Inbox widget**: what needs you and what broke on the Home Screen, with Allow and Deny right there (see [docs/inbox-widget.md](docs/inbox-widget.md)).
- **Ask with a saved prompt**: a Shortcuts action that sends a saved prompt to Chief or any bot and reads you the answer (see [docs/saved-prompt-shortcuts.md](docs/saved-prompt-shortcuts.md)).
- **Remind me**: press and hold any message to get pinged about it later, with a bell on the chat while one is coming (see [docs/message-reminders.md](docs/message-reminders.md)).
- **Real days in chats**: a line where each day starts (Today, Yesterday, Monday, Nov 23) and a Jump to latest pill that counts new messages while you read older ones (see [docs/chat-days.md](docs/chat-days.md)).
- **iPhone Search**: starred messages and saved prompts show up in Search; a prompt opens Chief's chat ready to send (see [docs/spotlight-content.md](docs/spotlight-content.md)).
- **Code colors**: code in chats is colored like an editor, with line numbers, red and green diffs, and a Wrap button (see [docs/code-colors.md](docs/code-colors.md)).
- **Reply with quote and Forward to**: press and hold a message to quote it in your reply or pass it to another teammate's chat (see [docs/quote-forward.md](docs/quote-forward.md)).
- **Links in chats**: bare links are tappable, and replies show a card for each link, with localhost links copied instead (see [docs/chat-links.md](docs/chat-links.md)).
- **Read aloud**: press and hold a reply to hear it, with code mentioned instead of read out and a Stop button by the name (see [docs/read-aloud.md](docs/read-aloud.md)).
- **Share a chat**: the ••• button in a chat shares or copies the whole chat as Markdown, with real dates and times (see [docs/chat-export.md](docs/chat-export.md)).
- **Slash for saved prompts**: type / in a chat to pick a saved prompt, and keep typing to search them (see [docs/slash-prompts.md](docs/slash-prompts.md)).
- **Long replies fold**: a reply over about 24 lines starts folded with Show more, so a big log doesn't fill the chat (see [docs/long-replies.md](docs/long-replies.md)).
- **Quick replies**: when a teammate ends with a quick question, tap Yes, No or one of its options to answer (see [docs/quick-replies.md](docs/quick-replies.md)).
- **Pinch to change text size**: pinch a chat to make messages Small, Normal, Big or Huge (see [docs/pinch-text-size.md](docs/pinch-text-size.md)).
- **New messages line**: opening a chat shows a line above what came in since you last looked, with how many (see [docs/new-messages.md](docs/new-messages.md)).
- **Send again**: press and hold your own message to send it again, or edit it first (see [docs/send-again.md](docs/send-again.md)).
- **Grouped replies**: back-to-back replies from one teammate show one picture and name, so a burst reads as one (see [docs/grouped-replies.md](docs/grouped-replies.md)).
- **Tell me when a teammate is done**: one ping when a busy teammate stops working, from the chat's ••• menu (see [docs/done-watch.md](docs/done-watch.md)).
- **Swipe to reply**: swipe a message right to quote it in your reply (see [docs/swipe-to-reply.md](docs/swipe-to-reply.md)).
- **Pin a message**: keep one message at the top of its chat, with Copy and Unpin (see [docs/pinned-message.md](docs/pinned-message.md)).
- **Messages wait when the computer is away**: they show as waiting and send by themselves once it's back (see [docs/outbox.md](docs/outbox.md)).
- **Working now card**: the bottom of a chat shows the teammate's current job step and progress; tap to watch live (see [docs/work-now.md](docs/work-now.md)).
- **Search in Settings**: type a word and only the matching settings show (see [docs/settings-search.md](docs/settings-search.md)).
- **Select messages**: pick many messages to copy, share or star at once (see [docs/select-messages.md](docs/select-messages.md)).
- **Undo send**: an optional 5 second wait with an Undo button before a message goes (see [docs/undo-send.md](docs/undo-send.md)).
- **Share as picture**: press and hold a message to share it as a picture card with the teammate's color and name ([docs](docs/share-picture.md)).
- **Message reactions**: press and hold a message to react with an emoji, which shows on the bubble ([docs](docs/reactions.md)).
- **Translate and Message info**: press and hold a message to translate it or see when it was sent and how long it is ([docs](docs/message-info.md)).
- **Chat wallpaper**: dots, grid, waves, stars or stripes behind a chat, in the teammate's color ([docs](docs/chat-wallpaper.md)).
- **Bubble shape**: Round, Tails or Square message bubbles, in Settings under Chat ([docs](docs/bubble-shape.md)).
- **Big emoji**: a message that's only one to three emoji shows big ([docs](docs/big-emoji.md)).
- **@mentions**: @Rex shows bold in chats and opens Rex's chat on a tap ([docs](docs/mentions.md)).
- **@ name picker**: type @ in the message box to pick a teammate's name ([docs](docs/mentions.md#picking-a-name)).
- **Chat sounds**: an optional soft sound when you send and when a reply comes in ([docs](docs/chat-sounds.md)).
- **Inbox**: things that need you (OKs and questions from your bots), problems and finished work. Allow, Deny, pick, Clear, and filters.
- **Board**: every bot as a card with Chat, Steps and hand-off. A bot with a job running has Watch live.
- **Routines**: routines that wake a bot on a schedule, with on/off switches. Long-press one to delete it.

Screens that slide in:

- **New teammate** (sheet): role, name with a dice button, color, what they do, then Bring to life.
- **Hand off to Chief** (sheet): pick what Chief should do and add a note.
- **Routine editor**: who wakes up, what they do, when (days and time), rules, preview and next run.
- **Live work**: watch a bot's job step by step, with Steps, Terminal and Files tabs, its OK question, a note box, Pause, To Chief and Stop.
- **Group chat**: open one of your groups, or pick bots, name a new group, let Chief lead, then chat with @mentions.
- **Settings**: the computer you're paired with, Chief napping, safety, the Claude Code version and update, accent color, app icon (Chief's Bolt is the normal one; Classic and five more can be picked), notifications and Clear all chats.
- **Call Chief**: a real voice call with Chief on your computer (live captions, Mute, End). It only works while the computer is connected.
- **Mission control** (the grid button on Team): everyone at once, Pause all, wake Chief, what needs you, recent handoffs and a jump-to search.

## Plan usage

Tap the **Plan usage** card on Team (or Settings > Plan usage) to see how much of your Claude plan the team has used, straight from Claude on your computer:

- **5-hour limit**: a ring with how much is used, when it resets, and where your pace lands ("about 61% when it resets", or "runs out in 25m, before it resets").
- **Weekly**: each weekly window with a bar, its reset and its pace.
- **Save usage**: **Slow the team down to save usage** (bots keep turns short and don't wake sleeping teammates while usage is tight) and **Also slow down at** 50% to 90% of the 5-hour window. The gold tick on the ring is your limit. These change Squall on the computer too.
- **Today**: each bot's jobs and how long they worked today. Tap a bot to open its chat.

It needs the newer Squall on the computer; with an older one the screen says to update it.

## Siri and Shortcuts

Say these to Siri, or find them in the Shortcuts app and Spotlight. Everything goes to your real computer; if Squall isn't paired or the computer isn't answering, Siri says so.

- **"Ask Chief in Squall"**: Siri asks what you want to know, sends it to Chief and reads you Chief's real answer, with a card showing it. If Chief takes longer than Siri can wait, Siri reads what's there so far and the rest lands in your chat with Chief.
- **"Ask Builder in Squall"** (any bot's name), or **"Ask a bot in Squall"**: same, for any bot. Siri asks "Which bot?" when you don't say one.
- **"Start a task in Squall"** (or "Tell Chief in Squall"): Siri asks for the job and gives it to Chief. In Shortcuts you can pick another bot.
- **"What's my team doing in Squall"**: who's working on what and what needs you, with a team card. If the computer isn't answering, it says how old the saved copy is.
- **"What needs me in Squall"**: reads out the OKs and questions waiting on you.
- **"Approve the request in Squall"** and **"Decline the request in Squall"**: Siri reads who's asking and what it wants to run, and asks before sending Allow or Deny. Questions with choices stay in the app. In Shortcuts you can pick whose request.
- **"Call Chief in Squall"**: opens a voice call with Chief.
- **"Pause my team in Squall"** and **"Resume my team in Squall"**: pause or start every bot.

Asking, starting a task, approving and declining need your iPhone or iPad unlocked. Your bots also show up in Spotlight: search a bot's name and tap it to open its chat.

## Notifications

Squall pings you when a bot needs your OK or an answer, when something breaks, and (if you turn it on) when work is done. It follows Settings > Notifications: which pings, sound, quiet hours and muted bots. An OK request has **Allow** and **Deny** right on the notification (Allow asks for Face ID first). The app icon's badge counts what needs you. When a teammate replies in a one-on-one chat while Squall is closed, you get a ping with a **Reply** box (see [docs/reply-pings.md](docs/reply-pings.md)).

Squall checks the computer while it's open, for a little while after you leave it, and now and then in the background when iOS allows, so a ping can come a few minutes late. Nothing pings for old news when you first pair.

## Control Center (iOS 18)

Add **Pause my team** (a switch) and **Call Chief** from Control Center's edit screen, or put them on the Lock Screen or the Action button.

## Keyboard (iPad)

⌘1 to ⌘5 switch tabs, ⌘R refreshes, ⌘N adds a teammate, ⇧⌘K calls Chief, ⇧⌘M opens Mission control, ⌘, opens Settings and ⌘[ goes back. Hold ⌘ to see them all.

## Widgets

Add the **Squall team** widget to the Home Screen (small or medium) or the Lock Screen. It shows what needs you, who's working and when it last synced. Tap it to open the Inbox or Team. With no data it says so, and after Unpair it says "Not paired".

The **Squall teammate** widget shows one teammate you pick (long-press the widget, then Edit Widget): what they're doing and the last message in your chat. Tap it to open that chat. It comes in small and medium for the Home Screen and two Lock Screen sizes (see [docs/teammate-widget.md](docs/teammate-widget.md)).

On the Home Screen it has a **Pause / Resume** button, and the medium one shows **Allow** and **Deny** for the first OK request (only while its data is fresh). The buttons send straight to your computer, even when Squall is closed, and the widget changes only after the computer says yes.

The app hands the widget its data through a shared Keychain group (`<team>.<bundle id>.shared`), which needs no setup. If you also turn on **App Groups** for both App IDs at developer.apple.com and add `group.<bundle id>`, the GitHub build signs with that too and uses it first.

## Sounds and buzzes

A small buzz and sound when you allow something, a bot needs you, a job finishes or something breaks. Turn them off in Settings > Look (Vibrate, Small sounds). Sounds follow the silent switch.

## Live Activities

Six Live Activities show on the Lock Screen and in the Dynamic Island. Tap the **Lock Screen** button on a screen to start one, then lock your phone:

- **A bot at work** (Live work): the job's steps fill in, with Pause and Watch live.
- **Chief needs your OK** (Inbox, on an ask): Allow or Deny right from the Lock Screen.
- **A routine running** (Routines, while one runs): counts up, with Skip today.
- **Call with Chief** (Call Chief): starts by itself when a call connects, with a timer, captions, Mute and End. Calls keep going when you leave the app or lock the phone.
- **Whole team** (Mission control): four bots with bars, and Pause all.
- **Work timer** (a chat's timer, while one runs): counts down to the end with a bar that empties, or counts up for Continuous, with Stop and Open chat.

With **Show on Lock Screen by itself** (Settings > Lock Screen, on at first), a new OK request and a team that just started working go on the Lock Screen without a tap while Squall is open. The Lock Screen buttons send straight to your computer, even if Squall was closed.

They only start from real data from your computer, update while the app gets new data, and end when the job is gone or the computer stops answering. If nothing shows up, turn on Live Activities for Squall in the iPhone's Settings app. The extension lives in `SquallActivities`, and the parts it shares with the app are in `Shared`.

The Xcode project is made from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), so you don't need a Mac. GitHub builds the app for you.

## How the GitHub build works

The workflow is `.github/workflows/ios.yml`. One job runs every time:

1. **Builds the app for iPhone and iPad.** This is also the check that the code compiles. No Apple account needed.
2. **Saves an unsigned `.ipa`** on the run (Artifacts > `Squall-unsigned-<number>`). It's unsigned, so an iPhone or iPad won't install it as is. It's there so you can see the build worked.
3. **Signs it and uploads it to TestFlight**, but only when the Apple secrets below are set, and only on a push to `main` or when you press **Run workflow**. Pull requests never upload.

If the secrets aren't set, step 3 is skipped with a "TestFlight skipped" note and the run still passes.

Each TestFlight upload gets the newest TestFlight build number plus 1 (read from App Store Connect, and tagged `testflight-<number>` after the upload), so build numbers go up by exactly 1. Pull request checks don't use up a number. To change the version people see (like `0.1.0`), edit `MARKETING_VERSION` in `project.yml`.

## Setting up TestFlight (one time)

**For a parent or guardian:** [docs/PARENT_SETUP.md](docs/PARENT_SETUP.md) walks through every step an adult needs to do, in plain words. The short version is below.

You need to do these steps yourself. Never paste keys into code or chat; they only go into GitHub secrets.

1. **Join the Apple Developer Program** at developer.apple.com/programs ($99 a year). You have to be 18 or older to enroll, so a parent or guardian needs to sign up (they can add you to the team afterwards).
2. **Register the app IDs.** In developer.apple.com > Certificates, Identifiers & Profiles > Identifiers, add an App ID with the bundle ID `com.stormblazerplayz.squall`. If that ID is taken, pick another one and see "Using a different bundle ID" below. The Live Activities extension needs a second App ID, `com.stormblazerplayz.squall.activities` (your bundle ID plus `.activities`). The build makes it for you when the API key has the Admin role, but you can also add it here by hand. It needs no extra capabilities.
3. **Create the app in App Store Connect.** At appstoreconnect.apple.com > Apps > **+** > New App: platform iOS, name Squall (or any free name), bundle ID from step 2, any SKU like `squall-001`.
4. **Make an API key.** In App Store Connect > Users and Access > Integrations > App Store Connect API > Team Keys, generate a key with the **Admin** role (it needs Admin so GitHub can create the signing certificate for you). Download the `.p8` file. Apple only lets you download it once, so keep it somewhere safe.
5. **Find your Team ID.** It's on developer.apple.com > Account > Membership details (10 letters and numbers).
6. **Add 4 GitHub secrets.** In this repo: Settings > Secrets and variables > Actions > New repository secret.

   | Secret name | What to paste |
   | --- | --- |
   | `APP_STORE_CONNECT_KEY_ID` | The key ID shown next to your API key |
   | `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID shown above the keys list |
   | `APP_STORE_CONNECT_KEY_P8` | The whole `.p8` file, opened in a text editor, including the `BEGIN` and `END` lines |
   | `APPLE_TEAM_ID` | Your Team ID from step 5 |

7. **Merge the pull request into `main`.** GitHub only shows the Run workflow button for workflows that are on `main`, and every push to `main` uploads a new build.
8. **Run it.** Actions tab > **iOS build** > **Run workflow** (or just push to `main`). When it finishes, Apple takes a few minutes to process the build, then it shows up in App Store Connect > your app > TestFlight. Add yourself as an internal tester and install it with the TestFlight app on your iPhone or iPad.

### Using a different bundle ID

Add a repository **variable** (not a secret) named `BUNDLE_ID` in Settings > Secrets and variables > Actions > Variables, set to your bundle ID. The workflow uses it instead of `com.stormblazerplayz.squall`.

### If a run fails or skips

- **"TestFlight skipped: Apple secrets aren't set yet"**: add the missing secrets it names (step 6).
- **"TestFlight skipped: Pull requests only check the build"**: that's expected. Merge, then push to `main` or use Run workflow.
- **"doesn't look like a .p8 key"**: paste the whole `.p8` file again, with the BEGIN and END lines.
- **Signing errors in "Sign and export the .ipa"**: check the API key has the Admin role and the Team ID is right. If it says there's no profile for `com.stormblazerplayz.squall.activities`, add that App ID by hand (step 2).
- **Upload errors about the bundle ID**: the app in App Store Connect must use the exact same bundle ID as the build.

## Building on a Mac (optional)

```sh
brew install xcodegen
xcodegen generate
open Squall.xcodeproj
```

## Where the code lives

- `Squall/Theme`: colors and shared pieces (glowing bot spheres, cards, buttons, status pills).
- `Squall/Models`: bots, chat messages, routines, inbox items and app state.
- `Squall/Store`: `SquallStore`, which holds everything the app shows and sends what you do to the computer, and `SnapshotCache`, the saved copy for offline.
- `Squall/Intents`: Siri and Shortcuts.
- `Squall/Sync`: the live data format from the computer (see docs/pairing.md).
- `Squall/Pairing`: pairing, the connection to the computer and the Keychain token.
- `Squall/Views`: one folder per screen.
- `Squall/LiveActivities`: starts and updates the Live Activities, and the Lock Screen button.
- `Shared`: Live Activity data, their Lock Screen buttons (App Intents) and the widget's data, used by the app and the extension.
- `SquallActivities`: the widget extension that draws the Live Activities and the team widget.
