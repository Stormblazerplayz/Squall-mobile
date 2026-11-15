#!/usr/bin/env python3
"""Prints the next TestFlight build number: the highest build already sent to TestFlight, plus 1.

Used by .github/workflows/ios.yml right before a build that will be uploaded, so build numbers
go up by exactly 1 per TestFlight upload (test runs and failed runs don't use up a number).

It looks in three places and takes the highest:
  1. App Store Connect: every build of the app (needs the API key, see below).
  2. Git tags named testflight-<number>, which the workflow adds after each upload. These catch an
     upload that Apple hasn't listed yet (or one that failed Apple's processing but still used up its number).
  3. tools/testflight_history.txt: build numbers uploaded before the tags existed.

Needs these environment variables (the workflow sets them from the repo secrets):
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8 file), BUNDLE_ID
No extra Python packages: the key signs with the openssl command that every Mac and Linux box has.

Test without Apple:   python3 tools/next_build_number.py --self-test
"""
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """openssl gives an ECDSA signature as DER; a JWT (ES256) wants r and s as 32 bytes each."""
    def read_len(i):
        n = der[i]
        if n < 0x80:
            return n, i + 1
        count = n & 0x7F
        return int.from_bytes(der[i + 1:i + 1 + count], "big"), i + 1 + count

    if der[0] != 0x30:
        raise ValueError("not a DER signature")
    _, i = read_len(1)
    parts = []
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("not a DER integer")
        n, i = read_len(i + 1)
        value = der[i:i + n].lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("number too big for ES256")
        parts.append(value.rjust(32, b"\x00"))
        i += n
    return parts[0] + parts[1]


def make_token(key_id: str, issuer: str, key_path: str) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = b64url(json.dumps(header, separators=(",", ":")).encode()) + "." + \
        b64url(json.dumps(payload, separators=(",", ":")).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                         input=signing_input.encode(), capture_output=True, check=True).stdout
    return signing_input + "." + b64url(der_to_raw(der))


def get(path: str, token: str) -> dict:
    url = path if path.startswith("http") else API + path
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def _versions(url: str, token: str, field: str, pages: int = 10) -> list:
    """Every build number on all pages of an App Store Connect list (newest first)."""
    out = []
    while url and pages > 0:
        page = get(url, token)
        for item in page.get("data", []):
            v = str(item.get("attributes", {}).get(field, "")).strip()
            if v.isdigit():
                out.append((int(v), item.get("attributes", {}).get("processingState") or item.get("attributes", {}).get("state")))
        url = page.get("links", {}).get("next")
        pages -= 1
    return out


def highest_from_apple() -> int:
    """The highest build number App Store Connect has for this app (0 if it has none).

    Looks at every build (processing, failed or ready) and, where Apple offers it, every upload,
    because Apple won't take a build number that isn't higher than one it has already seen.
    """
    token = make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"])
    bundle = os.environ["BUNDLE_ID"]
    apps = get("/apps?" + urllib.parse.urlencode({"filter[bundleId]": bundle, "fields[apps]": "bundleId"}), token)
    app_id = next((a["id"] for a in apps.get("data", []) if a["attributes"].get("bundleId") == bundle), None)
    if not app_id:
        raise RuntimeError(f"App Store Connect has no app with the bundle ID {bundle}")
    found = _versions("/builds?" + urllib.parse.urlencode(
        {"filter[app]": app_id, "fields[builds]": "version,processingState,uploadedDate", "sort": "-uploadedDate", "limit": "200"}),
        token, "version")
    seen = {"builds": max((v for v, _ in found), default=0)}
    # Extra looks that may not work on every account. Each one can only raise the number, never lower it.
    extra = {
        "builds in any state": ("/builds?" + urllib.parse.urlencode(
            {"filter[app]": app_id, "filter[processingState]": "PROCESSING,FAILED,INVALID,VALID",
             "fields[builds]": "version,processingState", "limit": "200"}), "version"),
        "build uploads": (f"/apps/{app_id}/buildUploads?" + urllib.parse.urlencode({"limit": "200"}), "cfBundleVersion"),
    }
    for name, (url, field) in extra.items():
        try:
            more = _versions(url, token, field)
            found += more
            seen[name] = max((v for v, _ in more), default=0)
        except Exception as e:
            seen[name] = f"not available ({str(e)[:60]})"
    newest = sorted({v: s for v, s in found}.items(), reverse=True)[:5]
    print("App Store Connect: " + ", ".join(f"{k} {v}" for k, v in seen.items())
          + ". Newest: " + ", ".join(f"{v} ({s or 'unknown'})" for v, s in newest), file=sys.stderr)
    return max((v for v, _ in found), default=0)


def highest_from_tags() -> int:
    """The highest testflight-<number> tag on the remote (0 if there are none)."""
    out = subprocess.run(["git", "ls-remote", "--tags", "origin", "testflight-*"],
                         capture_output=True, text=True).stdout
    numbers = [int(m) for m in re.findall(r"refs/tags/testflight-(\d+)$", out, re.M)]
    return max(numbers, default=0)


def highest_from_history() -> int:
    """The highest build number written in tools/testflight_history.txt: uploads from before the tags existed."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testflight_history.txt")
    if not os.path.exists(path):
        return 0
    numbers = [int(n) for n in re.findall(r"^\s*(\d+)\b", open(path).read(), re.M)]
    return max(numbers, default=0)


def self_test() -> None:
    """Checks the token signing with a throwaway key (needs the 'cryptography' package to verify)."""
    import tempfile
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature
    key = ec.generate_private_key(ec.SECP256R1())
    with tempfile.NamedTemporaryFile("wb", suffix=".p8", delete=False) as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                  serialization.NoEncryption()))
        path = f.name
    for _ in range(50):   # different signatures hit the short r/s cases
        token = make_token("KEY123", "issuer-abc", path)
        head, body, sig = token.split(".")
        raw = base64.urlsafe_b64decode(sig + "=" * (-len(sig) % 4))
        assert len(raw) == 64
        r, s = int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big")
        key.public_key().verify(encode_dss_signature(r, s), (head + "." + body).encode(), ec.ECDSA(hashes.SHA256()))
        h = json.loads(base64.urlsafe_b64decode(head + "=="))
        assert h == {"alg": "ES256", "kid": "KEY123", "typ": "JWT"}, h
        p = json.loads(base64.urlsafe_b64decode(body + "=" * (-len(body) % 4)))
        assert p["aud"] == "appstoreconnect-v1" and p["iss"] == "issuer-abc" and p["exp"] - p["iat"] == 900
    os.unlink(path)
    print("self-test OK: 50 tokens signed and verified")


def main() -> None:
    if "--self-test" in sys.argv:
        self_test()
        return
    apple, error = None, None
    for attempt in range(3):
        try:
            apple = highest_from_apple()
            break
        except Exception as e:   # network hiccup or Apple being slow: try again
            error = e
            time.sleep(5 * (attempt + 1))
    tags = max(highest_from_tags(), highest_from_history())
    if apple is None:
        if tags == 0:
            sys.exit(f"::error title=Build number::Couldn't read the latest TestFlight build from App Store Connect: {error}")
        print(f"::warning title=Build number::Couldn't reach App Store Connect ({error}), so using the git tags.", file=sys.stderr)
        apple = 0
    print(f"Latest TestFlight build: {apple} (App Store Connect), {tags} (git tags and upload history)", file=sys.stderr)
    print(max(apple, tags) + 1)


if __name__ == "__main__":
    main()
