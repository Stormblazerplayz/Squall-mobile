# Squall mobile

The iPhone app for Squall, Storm's AI team. It's a SwiftUI app (iOS 17+) with three tabs:

- **Team**: your crew (Chief, Forge, Prism, Scout, Echo) with what each one is doing.
- **Chat**: a team chat. It runs in demo mode until linking to Squall desktop is added.
- **Settings**: desktop address, haptics, app version.

The Xcode project is made from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), so you don't need a Mac. GitHub builds the app for you.

## How the GitHub build works

The workflow is `.github/workflows/ios.yml`.

- **Every pull request and push to `main`**: a quick simulator build checks that the code compiles. No Apple account needed.
- **Run it by hand** (Actions tab > **iOS build** > **Run workflow**): builds a signed `.ipa`, saves it as a downloadable artifact on the run, and uploads it to TestFlight. Untick "Upload the build to TestFlight" if you only want the `.ipa`.

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

7. **Run it.** Actions tab > **iOS build** > **Run workflow**. When it finishes, Apple takes a few minutes to process the build, then it shows up in App Store Connect > your app > TestFlight. Add yourself as an internal tester and install it with the TestFlight app on your iPhone.

### Using a different bundle ID

Add a repository **variable** (not a secret) named `BUNDLE_ID` in Settings > Secrets and variables > Actions > Variables, set to your bundle ID. The workflow uses it instead of `com.stormblazerplayz.squall`.

### If a run fails

- **"The GitHub secret ... is missing"**: add that secret (step 6).
- **"doesn't look like a .p8 key"**: paste the whole `.p8` file again, with the BEGIN and END lines.
- **Signing errors in "Sign and export the .ipa"**: check the API key has the Admin role and the Team ID is right.
- **Upload errors about the bundle ID**: the app in App Store Connect must use the exact same bundle ID as the build.

## Building on a Mac (optional)

```sh
brew install xcodegen
xcodegen generate
open Squall.xcodeproj
```
