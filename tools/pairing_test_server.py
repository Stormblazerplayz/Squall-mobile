#!/usr/bin/env python3
"""Pretend Squall desktop, for testing phone pairing before the real desktop app supports it.

Run it on your computer (Python 3.8+, nothing to install):

    python3 tools/pairing_test_server.py

It prints the computer's address and a 6-digit code. In the Squall app, pick
"Type the code" and enter both. If the optional `qrcode` package is installed
(`pip install qrcode`), it also prints a QR code you can scan.

Press Enter to make a new code. Press Ctrl+C to stop.
It speaks the protocol in docs/pairing.md, including voice calls: once paired,
Call Chief in the app talks to a pretend Chief here that gives simple answers.
Use --no-voice to act like a desktop that can't do calls yet.
"""

import argparse
import random
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


def chief_reply(text, turn):
    """A pretend Chief: simple answers so a voice call can be tried end to end."""
    said = text.lower()
    if any(word in said for word in ("bye", "goodbye", "hang up", "that's all", "thats all")):
        return "Okay, talk soon. I'll ping you if anything changes.", True
    if "barry" in said:
        return "Barry is fixing the Farside build. He needs your OK to push the fix.", False
    if any(word in said for word in ("status", "doing", "up to", "update", "team")):
        return "Barry is on the Farside build, sss is halfway through the Nimbus ideas, and Fox is drawing the app icon.", False
    if any(word in said for word in ("hello", "hi ", "hey")) or said in ("hi", "hey"):
        return "Hey! What do you need?", False
    if "joke" in said:
        return "Why did the robot go on holiday? It needed to recharge.", False
    if said.endswith("?"):
        return random.choice([
            "Good question. I'll ask the team and put the answer in your Inbox.",
            "I'm not sure yet. Want me to have sss look into it?",
        ]), False
    return random.choice([
        f"Got it. You said: {text}",
        "Okay, I'll pass that on to the team.",
        "Sounds good. Anything else?",
    ]), False


def make_handler(state, voice):
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

        def read_json(self):
            """Returns the JSON body as a dict, or None after answering 400."""
            try:
                length = min(int(self.headers.get("Content-Length", "0")), 16_384)
                body = json.loads(self.rfile.read(length) or b"{}")
            except (ValueError, json.JSONDecodeError):
                body = None
            if not isinstance(body, dict):
                self.send_json(400, {"error": "bad_json"})
                return None
            return body

        def do_POST(self):
            path = self.path_only()
            if path == "/api/v1/pair":
                return self.pair()
            if path in ("/api/v1/voice/turn", "/api/v1/voice/end") and voice:
                return self.voice(path)
            return self.send_json(404, {"error": "not_found"})

        def voice(self, path):
            device = state.device_for(self.bearer())
            if device is None:
                return self.send_json(401, {"error": "unknown_token"})
            body = self.read_json()
            if body is None:
                return
            who = device.get("deviceName", "the phone")
            if path == "/api/v1/voice/end":
                print(f"  Call with {who} ended after {body.get('seconds', '?')} seconds.")
                return self.send_json(204)
            text = str(body.get("text", "")).strip()
            if body.get("event") == "start":
                print(f"\n  {who} is calling Chief.")
                reply, end = "Hey, Chief here. What's up?", False
            else:
                print(f"  You:   {text}")
                reply, end = chief_reply(text, body.get("turn", 0))
            print(f"  Chief: {reply}")
            self.send_json(200, {"text": reply, "audio": None, "endCall": end})

        def pair(self):
            body = self.read_json()
            if body is None:
                return
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
    parser.add_argument("--no-voice", action="store_true", help="act like a desktop that can't do voice calls yet")
    args = parser.parse_args()

    state = PairingState(args.name)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), make_handler(state, voice=not args.no_voice))
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
