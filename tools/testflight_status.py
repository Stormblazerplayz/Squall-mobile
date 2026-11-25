#!/usr/bin/env python3
"""Shows what App Store Connect really has for this app, so a missing TestFlight build can be explained.

Prints the newest builds (with Apple's processing state), the newest uploads (with any errors
Apple attached), the TestFlight version trains and the App Store versions. Read-only: it changes nothing.

Needs the same environment variables as next_build_number.py:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file), BUNDLE_ID
Run by .github/workflows/testflight-status.yml (Actions > TestFlight status > Run workflow).
"""
import json
import os
import sys
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from next_build_number import get, make_token  # noqa: E402


def safe_get(path, token):
    try:
        return get(path, token)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:300]
        print(f"  (Apple said {e.code} for {path.split('?')[0]}: {body})")
        return {"data": []}
    except Exception as e:  # network or parsing trouble: show it and keep going
        print(f"  (couldn't read {path.split('?')[0]}: {e})")
        return {"data": []}


def main() -> int:
    token = make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"])
    bundle = os.environ["BUNDLE_ID"]
    apps = safe_get("/apps?" + urllib.parse.urlencode({"filter[bundleId]": bundle}), token)
    app = next((a for a in apps.get("data", []) if a["attributes"].get("bundleId") == bundle), None)
    if not app:
        print(f"::error::App Store Connect has no app with the bundle ID {bundle}")
        return 1
    app_id = app["id"]
    print(f"App: {app['attributes'].get('name')} ({bundle})")

    print("\nNewest builds (what TestFlight lists):")
    builds = safe_get("/builds?" + urllib.parse.urlencode({
        "filter[app]": app_id, "sort": "-uploadedDate", "limit": "10",
        "include": "preReleaseVersion",
        "fields[builds]": "version,processingState,uploadedDate,expired,expirationDate,preReleaseVersion",
        "fields[preReleaseVersions]": "version"}), token)
    trains = {i["id"]: i["attributes"].get("version") for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
    for b in builds.get("data", []):
        a = b["attributes"]
        pre = (b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
        print(f"  build {a.get('version')} (version {trains.get(pre, '?')}): {a.get('processingState')}, "
              f"uploaded {a.get('uploadedDate')}, expired={a.get('expired')}")
    if not builds.get("data"):
        print("  none")

    print("\nNewest uploads (every file sent to Apple, with any problems Apple found):")
    uploads = safe_get(f"/apps/{app_id}/buildUploads?" + urllib.parse.urlencode({"limit": "8"}), token)
    rows = sorted(uploads.get("data", []), key=lambda u: int(str(u["attributes"].get("cfBundleVersion", "0")) or 0), reverse=True)
    for u in rows[:8]:
        a = u["attributes"]
        print(f"  upload {a.get('cfBundleVersion')} (version {a.get('cfBundleShortVersionString')}): "
              f"{json.dumps(a.get('state'))} uploaded {a.get('uploadedDate') or a.get('createdDate')}")
        for k, v in a.items():
            if k not in ("cfBundleVersion", "cfBundleShortVersionString", "state", "uploadedDate", "createdDate") and v:
                print(f"      {k}: {json.dumps(v)[:400]}")
    if not rows:
        print("  none")

    print("\nTestFlight version trains:")
    pre = safe_get("/preReleaseVersions?" + urllib.parse.urlencode({
        "filter[app]": app_id, "limit": "10", "sort": "-version"}), token)
    for p in pre.get("data", []):
        print(f"  {p['attributes'].get('version')} ({p['attributes'].get('platform')})")
    if not pre.get("data"):
        print("  none")

    print("\nApp Store versions (an approved version closes that version's TestFlight train):")
    asv = safe_get(f"/apps/{app_id}/appStoreVersions?" + urllib.parse.urlencode({"limit": "10"}), token)
    for v in asv.get("data", []):
        a = v["attributes"]
        print(f"  {a.get('versionString')}: {a.get('appStoreState') or a.get('appVersionState')}")
    if not asv.get("data"):
        print("  none")
    return 0


if __name__ == "__main__":
    sys.exit(main())
