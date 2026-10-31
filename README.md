# Squall mobile

The iPhone app for Squall, Storm's AI team, built from the Squall Mobile design concepts. It's a SwiftUI app (iOS 17+) with the dark, glowy look from the concepts. Everything runs on pretend data for now, so you can tap through every screen before it's linked to Squall desktop.

## Screens

Tabs along the bottom:

- **Team**: Chief's card (message Chief, see its steps), quick actions (new teammate, new group, routines) and the team list with unread badges. Long-press a bot, then tap the glowing Chief card to hand its work to Chief.
- **Chat**: one-on-one chat with any bot. Bots reply, Chief shows its grouped "needs an update" error with Try again, there's a strip to jump between bots, reply chips, the Live switch and a call button.
- **Inbox**: things that need you (Barry's push request, Fox's icon question), problems (Chief's update error) and finished work. Allow, Deny, pick, Clear, Undo, and filters.
- **Board**: every bot as a card with Chat, Steps and hand-off, plus Starx, Sessions, Vault and To do tabs. Barry's card has Watch live.
- **Routines**: routines that wake a bot on a schedule, with on/off switches. Long-press one to delete it.

Screens that slide in:

- **New teammate** (sheet): role, name with a dice button, color, what they do, then Bring to life.
- **Hand off to Chief** (sheet): pick what Chief should do and add a note.
- **Routine editor**: who wakes up, what they do, when (days and time), rules, preview and next run.
- **Live work**: watch Barry fix the Farside build step by step, with Steps, Terminal and Files tabs, the push OK, Pause, To Chief and Stop.
- **Group chat**: pick bots, name the group, let Chief lead, then chat with @mentions.
- **Settings**: Chief napping, safety, the Claude Code update, accent color, notifications and Clear all chats.
- **Call Chief**: a pretend voice call with live captions where Chief catches you up.
- **Mission control** (the grid button on Team): everyone at once, Pause all, wake Chief, what needs you, recent handoffs and a jump-to search.

The Xcode project is made from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), so you don't need a Mac. GitHub builds the app for you.

## How the GitHub build works

The workflow is `.github/workflows/ios.yml`. One job runs every time:

1. **Builds the app for iPhone.** This is also the check that the code compiles. No Apple account needed.
2. **Saves an unsigned `.ipa`** on the run (Artifacts > `Squall-unsigned-<number>`). It's unsigned, so an iPhone won't install it as is. It's there so you can see the build worked.
3. **Signs it and uploads it to TestFlight**, but only when the Apple secrets below are set, and only on a push to `main` or when you press **Run workflow**. Pull requests never upload.

If the secrets aren't set, step 3 is skipped with a "TestFlight skipped" note and the run still passes.

Each run's build number is the GitHub run number, so every upload is newer than the last one. To change the version people see (like `0.1.0`), edit `MARKETING_VERSION` in `project.yml`.

## Setting up TestFlight (one time)

You need to do these steps yourself. Never paste keys into code or chat; they only go into GitHub secrets.

1. **Join the Apple Developer Program** at developer.apple.com/programs ($99 a year). You have to be 18 or older to enroll, so a parent or guardian needs to sign up (they can add you to the team afterwards).
2. **Register the app ID.** In developer.apple.com > Certificates, Identifiers & Profiles > Identifiers, add an App ID with the bundle ID `com.stormblazerplayz.squall`. If that ID is taken, pick another one and see "Using a different bundle ID" below.
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
8. **Run it.** Actions tab > **iOS build** > **Run workflow** (or just push to `main`). When it finishes, Apple takes a few minutes to process the build, then it shows up in App Store Connect > your app > TestFlight. Add yourself as an internal tester and install it with the TestFlight app on your iPhone.

### Using a different bundle ID

Add a repository **variable** (not a secret) named `BUNDLE_ID` in Settings > Secrets and variables > Actions > Variables, set to your bundle ID. The workflow uses it instead of `com.stormblazerplayz.squall`.

### If a run fails or skips

- **"TestFlight skipped: Apple secrets aren't set yet"**: add the missing secrets it names (step 6).
- **"TestFlight skipped: Pull requests only check the build"**: that's expected. Merge, then push to `main` or use Run workflow.
- **"doesn't look like a .p8 key"**: paste the whole `.p8` file again, with the BEGIN and END lines.
- **Signing errors in "Sign and export the .ipa"**: check the API key has the Admin role and the Team ID is right.
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
- `Squall/Store`: `SquallStore` (everything the app shows) and `SampleData` (the pretend data).
- `Squall/Views`: one folder per screen.
