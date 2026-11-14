#!/usr/bin/env python3
"""Pretend Squall desktop, for testing phone pairing before the real desktop app supports it.

Run it on your computer (Python 3.8+, nothing to install):

    python3 tools/pairing_test_server.py

It prints the computer's address and a 6-digit code. In the Squall app, pick
"Type the code" and enter both. If the optional `qrcode` package is installed
(`pip install qrcode`), it also prints a QR code you can scan.

Press Enter to make a new code. Press Ctrl+C to stop.
It speaks the protocol in docs/pairing.md.
"""

import argparse
import hashlib
import hmac
import json
import secrets
import socket
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROTOCOL_VERSION = 1
CODE_LIFETIME_SECONDS = 120
MAX_WRONG_TRIES = 5


class PairingState:
    """Holds the current code and the paired phones. Shared by the request threads."""

    def __init__(self, name):
        self.lock = threading.Lock()
        self.computer_id = secrets.token_hex(8)
        self.computer_name = name
        self.code = None
        self.code_expires = 0.0
        self.wrong_tries = 0
        self.devices = {}  # sha256(token) -> device info

    def new_code(self):
        with self.lock:
            self.code = f"{secrets.randbelow(1_000_000):06d}"
            self.code_expires = time.time() + CODE_LIFETIME_SECONDS
            self.wrong_tries = 0
            return self.code

    @staticmethod
    def token_hash(token):
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    def try_pair(self, code, device):
        """Returns (http_status, body)."""
        with self.lock:
            if self.code is None:
                return 409, {"error": "not_listening"}
            if time.time() > self.code_expires:
                self.code = None
                return 410, {"error": "code_expired"}
            if self.wrong_tries >= MAX_WRONG_TRIES:
                return 429, {"error": "too_many_tries"}
            if not isinstance(code, str) or not hmac.compare_digest(code, self.code):
                self.wrong_tries += 1
                if self.wrong_tries >= MAX_WRONG_TRIES:
                    self.code = None
                return 401, {"error": "wrong_code"}
            token = secrets.token_urlsafe(32)
            self.devices[self.token_hash(token)] = device
            self.code = None  # one code, one phone
            return 200, {
                "token": token,
                "computerId": self.computer_id,
                "computerName": self.computer_name,
                "protocolVersion": PROTOCOL_VERSION,
            }

    def device_for(self, token):
        with self.lock:
            return self.devices.get(self.token_hash(token)) if token else None

    def forget(self, token):
        with self.lock:
            return self.devices.pop(self.token_hash(token), None) if token else None


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        server_version = "SquallTestDesktop/1"

        def log_message(self, fmt, *args):
            print(f"  [{self.client_address[0]}] {fmt % args}")

        def send_json(self, status, body=None):
            data = b"" if body is None else json.dumps(body).encode("utf-8")
            self.send_response(status)
            if body is not None:
                self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            if data:
                self.wfile.write(data)

        def bearer(self):
            value = self.headers.get("Authorization", "")
            return value[7:].strip() if value.startswith("Bearer ") else None

        def path_only(self):
            return urllib.parse.urlparse(self.path).path

        def do_POST(self):
            if self.path_only() != "/api/v1/pair":
                return self.send_json(404, {"error": "not_found"})
            try:
                length = min(int(self.headers.get("Content-Length", "0")), 16_384)
                body = json.loads(self.rfile.read(length) or b"{}")
            except (ValueError, json.JSONDecodeError):
                return self.send_json(400, {"error": "bad_json"})
            if not isinstance(body, dict):
                return self.send_json(400, {"error": "bad_json"})
            device = body.get("device") if isinstance(body.get("device"), dict) else {}
            status, reply = state.try_pair(body.get("code"), device)
            self.send_json(status, reply)
            if status == 200:
                print(f"\n  Paired with {device.get('deviceName', 'a phone')} ({device.get('platform', '?')}).")
                print("  Press Enter for a new code.\n")

        def do_GET(self):
            if self.path_only() != "/api/v1/hello":
                return self.send_json(404, {"error": "not_found"})
            if state.device_for(self.bearer()) is None:
                return self.send_json(401, {"error": "unknown_token"})
            self.send_json(200, {"computerName": state.computer_name, "protocolVersion": PROTOCOL_VERSION})

        def do_DELETE(self):
            if self.path_only() != "/api/v1/pair":
                return self.send_json(404, {"error": "not_found"})
            device = state.forget(self.bearer())
            if device is None:
                return self.send_json(401, {"error": "unknown_token"})
            print(f"\n  {device.get('deviceName', 'A phone')} unpaired.\n")
            self.send_json(204)

    return Handler


def local_ip():
    """Best guess at this computer's address on the Wi-Fi. Sends nothing."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("10.255.255.255", 1))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def show_code(state, host, port):
    code = state.new_code()
    link = "squall://pair?" + urllib.parse.urlencode(
        {"v": PROTOCOL_VERSION, "host": host, "port": port, "code": code, "name": state.computer_name},
        quote_via=urllib.parse.quote,  # spaces become %20, not +, so the app reads the name right
    )
    print("\n  ==== Pair a phone ====")
    print(f"  Address: {host}:{port}" if port != 47615 else f"  Address: {host}")
    print(f"  Code:    {code[:3]} {code[3:]}   (works for {CODE_LIFETIME_SECONDS // 60} minutes)")
    print(f"  QR link: {link}")
    try:
        import qrcode  # optional

        qr = qrcode.QRCode(border=1)
        qr.add_data(link)
        qr.make(fit=True)
        qr.print_ascii(invert=True)
    except ImportError:
        print("  (pip install qrcode to also show a QR code here)")
    print()


def main():
    parser = argparse.ArgumentParser(description="Pretend Squall desktop for testing phone pairing.")
    parser.add_argument("--port", type=int, default=47615)
    parser.add_argument("--name", default=socket.gethostname() or "Squall desktop")
    parser.add_argument("--host", default=None, help="address to show, if the guess is wrong")
    args = parser.parse_args()

    state = PairingState(args.name)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), make_handler(state))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    host = args.host or local_ip()
    print(f"Pretend Squall desktop '{args.name}' is listening on port {args.port}.")
    show_code(state, host, args.port)
    try:
        while True:
            input()
            show_code(state, host, args.port)
    except (KeyboardInterrupt, EOFError):
        print("\nStopping.")
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
