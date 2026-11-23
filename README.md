# Bambu Bay (iPhone and iPad)

A native iPhone and iPad app that runs your Bambu Lab print farm straight from the phone.
No computer, no browser, no server: the app talks to each printer over your Wi-Fi in LAN Mode.

## What it does

- **Printers:** live status for every printer: progress ring, time left, layer, nozzle and bed
  temperatures, AMS spools with colors and how much is left, and printer errors (HMS codes).
- **Controls:** pause, resume, stop (asks first), print speed (Silent, Standard, Sport, Ludicrous)
  and the chamber light.
- **Camera:** live camera picture from A1, A1 mini, P1S and P1P printers.
- **Queue:** add sliced `.3mf` files from Files, AirDrop or iCloud. Pick a plate, a printer (or "any
  free printer"), make copies, reorder by dragging. The queue starts the next job by itself when a
  printer is free and you've tapped **Bed's clear**.
- **Filament matching:** each filament in the file is matched to the AMS slot with the same type and
  the closest color, and you can change any of them. Problems show as warnings and never block a print.
- **Spaghetti detection:** load your own trained model (Core ML). The app checks the camera picture
  every few seconds, and only raises the alarm when most recent checks agree. It asks before pausing,
  unless you switch on auto-pause.
- **History:** every finished, failed or stopped print with time and filament, totals, reprint on
  the same or another printer, and CSV export.
- **Alerts:** iPhone notifications when a print finishes, fails or a queued job starts, plus an
  optional ntfy topic so alerts reach other devices too.

## Set up a printer (Bambu A1)

1. On the printer: **Settings > Network**, switch on **LAN Only Mode**. Write down the **access code**.
2. Newer firmware may also need **Developer Mode** (same screen) before other apps can control it.
3. Put a **microSD card** in the printer. Files are sent to the card before printing.
4. In the app: **Printers > +**. Enter the name, the printer's IP address (Settings > Network on the
   printer, or your router), the serial number (Settings > Device) and the access code.
   Tap **Test connection**.

The access code is kept in the iOS Keychain, only on this device.

## Printing from the phone

Bambu Studio can't run on iPhone or iPad, so files must already be **sliced**:
in Bambu Studio, slice, then **File > Export > Export plate sliced file** (`.gcode.3mf`), and
send it to the phone. Plain `.3mf` projects that aren't sliced, and `.stl` files, are shown with
this explanation instead of being sent to the printer.

## Spaghetti detection model

See [docs/model-setup.md](docs/model-setup.md). Short version:

```
pip install coremltools ultralytics
python3 tools/convert_model.py your_model.pt
```

Then AirDrop the `.zip` it makes to the phone and use **Watch > Import model**.
The app does not include a model of its own, so nothing is detected until you import one.

## Build

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
brew install xcodegen
xcodegen generate
open BambuBay.xcodeproj
```

Needs Xcode 16 or newer and iOS 17 or newer. GitHub Actions (`.github/workflows/ios.yml`) builds
the app and runs the tests on every push and pull request, and saves an unsigned `.ipa`.
TestFlight upload only runs on `main` once these secrets are set:
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8`, `APPLE_TEAM_ID`
(optional repo variable `BAMBUBAY_BUNDLE_ID`, default `com.stormblazerplayz.bambubay`).

## Not yet tested on a real printer

The printer connection follows the community-documented Bambu LAN protocol
(OpenBambuAPI, ha-bambulab), but these parts haven't been tried on a real A1 yet:

- Starting a print: the `project_file` command, its `url` (`ftp:///file` by default,
  `file:///sdcard/file` in the printer's Advanced settings) and the `ams_mapping` format.
- Sending files over FTPS (port 990): Bambu printers need the TLS session reused on the data
  connection, which the app does, but it's untested.
- The camera stream on port 6000.
- Whether `mc_remaining_time` is minutes on the A1 (it is on P1 printers).
- Whether your firmware needs Developer Mode.

If something doesn't work, the error message in the app says which step failed.

## Project layout

```
BambuBay/App         app entry, AppModel (printers, queue, history)
BambuBay/Printer     MQTT over TLS, printer state, commands, FTPS upload, camera
BambuBay/Files       zip and 3MF reading
BambuBay/Queue       jobs, storage, filament matching
BambuBay/Detection   Core ML model loading, failure voting, camera watching
BambuBay/Services    notifications, Keychain, background checks
BambuBay/Views       SwiftUI screens
BambuBayTests        unit tests
tools                model converter, icon drawing, build number helper
```
