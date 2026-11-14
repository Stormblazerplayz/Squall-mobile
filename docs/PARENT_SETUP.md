# TestFlight setup for a parent or guardian

Storm built Squall, an iPhone app. GitHub already builds it automatically. To get the app onto an iPhone through Apple's **TestFlight** testing app, Apple needs a paid developer account, and only an adult can own one. This page covers the parts only an adult can do. It takes about 30 minutes, plus Apple's approval wait.

**What it costs:** the Apple Developer Program is $99 a year (the price can differ by country). The GitHub builds are free.

**What stays private:** you'll make one secret key file (a `.p8` file). It only goes into GitHub's locked "secrets" box in step 6. Don't email it, text it, paste it into a chat or AI tool, or put it in the code. Nobody needs to see it, Storm included.

---

## 1. Join the Apple Developer Program (account holder: you)

Skip this step if you already have a paid developer account. Use that one and go to step 2.

1. Make sure your Apple Account has two-factor authentication turned on.
2. Enroll at **developer.apple.com/programs/enroll**. The easiest way is the **Apple Developer** app on an iPhone or iPad, because it can check your ID with the camera.
3. Choose **Individual / Sole Proprietor** and pay the yearly fee.
4. Wait for Apple's approval email. It's often quick, but it can take a day or two.

The app will be listed under your name as the developer. That only shows publicly if the app is ever put on the App Store. TestFlight testing is private.

## 2. Register the app's ID

1. Go to **developer.apple.com/account** > **Certificates, IDs & Profiles** > **Identifiers** > **+**.
2. Pick **App IDs** > **App** > Continue.
3. Description: `Squall`. Bundle ID: **Explicit**, `com.stormblazerplayz.squall`.
4. Leave the capabilities unticked. Click Continue, then Register.

If Apple says that bundle ID is taken, use another one, like `com.yourname.squall`, and do the extra step at the bottom of this page.

## 3. Create the app in App Store Connect

1. Go to **appstoreconnect.apple.com** > **Apps** > **+** > **New App**.
2. Platform: **iOS**. Name: `Squall`. If that name is taken, try something like `Squall Team`.
3. Primary language: English. Bundle ID: pick the one from step 2. SKU: `squall-001`. User access: Full Access.
4. Click Create.

## 4. Make the API key (this is the secret file)

1. In App Store Connect, go to **Users and Access** > **Integrations** > **App Store Connect API**.
2. The first time, Apple asks the account holder to **Request Access**. Accept, and it turns on right away.
3. Under **Team Keys**, click **+** (or **Generate API Key**).
4. Name: `GitHub Squall`. Access: **Admin**. GitHub needs Admin so it can make the signing certificate by itself, without anyone sending files around.
5. Click Generate, then **Download** the key. Apple only lets you download it **once**.
6. On the same page, copy down:
   - the **Issuer ID** (shown above the list of keys)
   - the **Key ID** (shown next to the new key)

## 5. Find your Team ID

Go to **developer.apple.com/account** > **Membership details**. Your **Team ID** is 10 letters and numbers.

## 6. Add the 4 secrets to GitHub (you type them, on Storm's GitHub)

GitHub only lets the repository's owner add secrets, and that's Storm's account. So the easiest way is for Storm to sign in to GitHub on the computer and then let you do the typing.

1. Open the repository **Stormblazerplayz/Squall-mobile** on github.com.
2. Go to **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
3. Add these four, one at a time. The name must match exactly.

   | Name | What to paste |
   | --- | --- |
   | `APP_STORE_CONNECT_KEY_ID` | The Key ID from step 4 |
   | `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID from step 4 |
   | `APP_STORE_CONNECT_KEY_P8` | Open the downloaded `.p8` file in a text editor (Notepad or TextEdit) and paste **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
   | `APPLE_TEAM_ID` | The Team ID from step 5 |

4. Once a secret is saved, GitHub never shows it again, even to the owner.
5. Then move the `.p8` file out of your Downloads folder into a safe place, like a password manager, or delete it. If it's lost, make a new key in step 4 and update the secret.

## 7. Run the first TestFlight build

1. Merge the open pull request on GitHub (Storm knows how), so the build setup is on the `main` branch.
2. Every push to `main` now sends a build to TestFlight. To start one by hand: **Actions** > **iOS build** > **Run workflow**.
3. When the run is green, wait about 5 to 15 minutes for Apple to process the build. It then shows up in App Store Connect > your app > **TestFlight**.

## 8. Put the app on the iPhone

1. In App Store Connect > your app > **TestFlight** > **Internal Testing**, make a group and add yourself as a tester. You're already a user as the account holder.
2. On the iPhone, install **TestFlight** from the App Store, signed in with the same Apple Account, and accept the invite. Then tap **Install** on Squall.
3. If Storm has their own Apple Account, you can try adding it as a tester: **Users and Access** > **+**, role **Developer**, then add it to the testing group. Apple can limit this for younger kids' accounts. If it doesn't work, use your own Apple Account in TestFlight on the iPhone Storm uses.

Each TestFlight build works for 90 days. New pushes to `main` make new builds automatically.

---

## If something goes wrong

- **The run says "TestFlight skipped: Apple secrets aren't set yet"**: one of the four secrets is missing or misnamed. The note lists which one.
- **"doesn't look like a .p8 key"**: paste the whole file again, including the BEGIN and END lines.
- **Signing errors**: check that the key's access is **Admin** and the Team ID is right.
- **Upload errors about the bundle ID**: the app in step 3 must use the same bundle ID as step 2.
- **If the key ever leaks** (pasted somewhere public by mistake): App Store Connect > Users and Access > Integrations > Team Keys > **Revoke**. Then make a new one and update the GitHub secret.

### Extra step if you used a different bundle ID

In the GitHub repository: **Settings** > **Secrets and variables** > **Actions** > **Variables** tab > **New repository variable**. Name: `BUNDLE_ID`. Value: your bundle ID. This one isn't secret.
