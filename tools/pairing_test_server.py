#!/usr/bin/env python3
"""Test Squall desktop, for trying the phone app before the real desktop app supports it.

Run it on your computer (Python 3.8+, nothing to install):

    python3 tools/pairing_test_server.py

It prints the computer's address and a 6-digit code. In the Squall app, pick
"Type the code" and enter both. If the optional `qrcode` package is installed
(`pip install qrcode`), it also prints a QR code you can scan.

Press Enter to make a new code. Press Ctrl+C to stop.
It speaks the protocol in docs/pairing.md: pairing, live data and voice calls.
This is a test tool, not real Squall. Once paired, the app shows a small test
team (bots named "Test ..."), so every screen and button can be tried end to end.
Use --no-voice to act like a desktop that can't do calls yet, and --no-live to
act like one that can't send live data yet.
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


def chief_reply(text, turn, team=None):
    """Test Chief: simple fixed answers so a voice call can be tried end to end."""
    said = text.lower()
    if any(word in said for word in ("bye", "goodbye", "hang up", "that's all", "thats all")):
        return "Okay, talk soon. This was the test desktop, so nothing real happened.", True
    if any(word in said for word in ("status", "doing", "up to", "update", "team")):
        if team is not None:
            return team.summary(), False
        return "This is the test desktop, so there's no real team here.", False
    if any(word in said for word in ("hello", "hi ", "hey")) or said in ("hi", "hey"):
        return "Hey! This is the test Chief. Ask me what the team is doing.", False
    return random.choice([
        f"Test Chief heard: {text}",
        "Got it. On the real desktop, Chief would act on that.",
    ]), False


def now_iso(offset_seconds=0):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + offset_seconds))


class TestTeam:
    """A small, clearly labeled test team, so the app has live data to show.

    Everything here is made up for testing. Real data comes from Squall desktop.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.version = 0
        self.paused = False
        self.typing = None
        self.counter = 0
        self.bots = [
            {"id": "chief", "name": "Chief", "color": "#F5B83D", "role": "Team lead", "status": "working",
             "task": "Running the test team", "unread": 0, "log": [], "progress": 0, "steps": ["Watching the test job"]},
            {"id": "test-builder", "name": "Test Builder", "color": "#3B87D6", "role": "Coder", "status": "waiting",
             "task": "Test job: fix a test build", "unread": 0, "log": ["$ make test", "1 test failed"], "progress": 0.5},
            {"id": "test-writer", "name": "Test Writer", "color": "#20B296", "role": "Writer", "status": "idle",
             "task": "Waiting for a test task", "unread": 0, "log": []},
        ]
        self.chats = {
            "chief": [self.message("system", "This is the test desktop. Everything here is test data.", author="system")],
            "test-builder": [],
            "test-writer": [],
        }
        self.groups = []
        self.inbox = [
            {"id": "test-ask", "kind": "ask", "botId": "test-builder", "title": "Test: OK to push?",
             "body": "Test Builder wants to push a test fix to a new branch.", "command": "git push -u origin test/fix",
             "workId": "test-job", "unread": True, "at": now_iso(-120)},
            {"id": "test-choice", "kind": "choice", "botId": "test-writer", "title": "Test: pick a style",
             "body": "Which style should the test notes use?", "options": ["Short", "Detailed"],
             "unread": True, "at": now_iso(-300)},
        ]
        self.routines = [
            {"id": "test-routine", "botId": "test-writer", "task": "Write a test recap", "repeat": "weekdays",
             "days": [True, True, True, True, True, False, False], "minutes": 9 * 60, "isOn": True,
             "pingWhenDone": True, "askBeforePush": True, "skipIfBusy": False},
        ]
        self.work = [{
            "id": "test-job", "botId": "test-builder", "title": "Test job: fix a test build", "from": "Chief",
            "state": "waiting", "startedAt": now_iso(-200), "now": "Waiting for your OK to push",
            "askId": "test-ask",
            "steps": [
                {"title": "Read the test build", "state": "done", "took": "12s",
                 "lines": [{"text": "Read Makefile", "kind": "dim"}]},
                {"title": "Fixed the test", "state": "done", "took": "30s",
                 "lines": [{"text": "-  assert 1 == 2", "kind": "del"}, {"text": "+  assert 1 == 1", "kind": "add"}]},
                {"title": "Push to a new branch", "state": "now", "took": "", "lines": []},
                {"title": "Open a pull request", "state": "todo", "took": "", "lines": []},
            ],
            "terminal": [
                {"text": "$ make test", "kind": "cmd"},
                {"text": "1 test failed", "kind": "err"},
                {"text": "$ make test", "kind": "cmd"},
                {"text": "all tests passed", "kind": "ok"},
            ],
            "files": [{"path": "tests/test_example.py", "change": "+1 -1", "edited": True}],
        }]
        self.handoffs = [{"id": "test-handoff", "from": "chief", "to": "test-builder",
                          "what": "Test job: fix a test build", "at": now_iso(-200)}]
        self.claude_code = {"version": "test", "latest": "test", "needsUpdate": False, "updating": None}

    # Helpers (call with the lock held)

    def message(self, kind, text, author=None, chips=None):
        self.counter += 1
        item = {"id": f"m{self.counter}", "kind": kind, "text": text, "at": now_iso()}
        if author:
            item["author"] = author
        if chips:
            item["chips"] = chips
        return item

    def changed(self):
        self.version += 1

    def bot(self, bot_id):
        return next((b for b in self.bots if b["id"] == bot_id), None)

    def job(self, job_id):
        return next((w for w in self.work if w["id"] == job_id), None)

    def later(self, seconds, fn):
        def run():
            with self.lock:
                fn()
                self.changed()
        timer = threading.Timer(seconds, run)
        timer.daemon = True
        timer.start()

    # What the phone sees

    def summary(self):
        with self.lock:
            busy = [b["name"] for b in self.bots if b["id"] != "chief" and b["status"] in ("working", "waiting")]
        if not busy:
            return "Nobody on the test team is busy right now."
        return f"On the test team, {' and '.join(busy)} {'is' if len(busy) == 1 else 'are'} busy."

    def snapshot(self):
        with self.lock:
            return {
                "version": f"test-{self.version}",
                "paused": self.paused,
                "typing": self.typing,
                "bots": self.bots,
                "chats": self.chats,
                "groups": self.groups,
                "inbox": self.inbox,
                "routines": self.routines,
                "work": self.work,
                "handoffs": self.handoffs,
                "claudeCode": self.claude_code,
            }

    # What the phone does

    def act(self, body):
        """Returns (http_status, reply)."""
        kind = body.get("type")
        with self.lock:
            handler = getattr(self, "do_" + str(kind).replace(".", "_"), None)
            if handler is None:
                return 200, {"ok": False, "error": f"The test desktop can't do {kind} yet."}
            reply = handler(body) or {}
            self.changed()
        reply.setdefault("ok", True)
        return 200, reply

    def do_chat_send(self, body):
        chat_id = str(body.get("chatId", "chief"))
        text = str(body.get("text", "")).strip()
        self.chats.setdefault(chat_id, []).append(self.message("me", text))
        group = next((g for g in self.groups if g["id"] == chat_id), None)
        replier = "chief" if group is None or group.get("chiefLeads", True) else (group["members"] or ["chief"])[0]
        if group is None:
            replier = chat_id if self.bot(chat_id) else "chief"
        self.typing = replier

        def answer():
            self.typing = None
            name = (self.bot(replier) or {}).get("name", "Test bot")
            self.chats.setdefault(chat_id, []).append(
                self.message("bot", f"{name} (test) got: {text}", author=replier))
        self.later(1.5, answer)

    def do_chat_read(self, body):
        bot = self.bot(str(body.get("chatId")))
        if bot:
            bot["unread"] = 0

    def do_chat_clear(self, body):
        self.chats[str(body.get("chatId"))] = []

    def do_chat_clearAll(self, body):
        for key in self.chats:
            self.chats[key] = []

    def do_chief_retry(self, body):
        pass

    def do_chief_wake(self, body):
        self.bot("chief")["status"] = "working"

    def do_chief_nap(self, body):
        self.bot("chief")["status"] = "napping"

    def do_bot_create(self, body):
        self.counter += 1
        bot_id = f"test-bot-{self.counter}"
        name = str(body.get("name", "Test bot")).strip() or "Test bot"
        self.bots.append({"id": bot_id, "name": name, "color": body.get("color", "#7C5CF6"),
                          "role": body.get("role", "Teammate"), "status": "idle",
                          "task": str(body.get("job", "")), "unread": 0, "log": []})
        self.chats[bot_id] = []
        return {"id": bot_id}

    def do_group_create(self, body):
        self.counter += 1
        group_id = f"test-group-{self.counter}"
        members = [m for m in body.get("members", []) if isinstance(m, str)]
        self.groups.append({"id": group_id, "name": str(body.get("name", "Group")), "members": members,
                            "chiefLeads": bool(body.get("chiefLeads", True))})
        self.chats[group_id] = [self.message("system", "Test group made.", author="system")]
        return {"id": group_id}

    def do_handoff(self, body):
        bot_id = str(body.get("botId"))
        bot = self.bot(bot_id)
        if bot is None:
            return {"ok": False, "error": "No such test bot."}
        bot["status"] = "handed"
        self.counter += 1
        self.handoffs.insert(0, {"id": f"h{self.counter}", "from": bot_id, "to": "chief",
                                 "what": bot.get("task", ""), "at": now_iso()})

    def do_inbox_answer(self, body):
        item_id = str(body.get("itemId"))
        answer = str(body.get("answer", ""))
        item = next((i for i in self.inbox if i["id"] == item_id), None)
        if item is None:
            return {"ok": False, "error": "That test item is gone."}
        self.inbox.remove(item)
        job = self.job(item.get("workId", "")) if item.get("workId") else None
        if job is None:
            return
        job["askId"] = None
        builder = self.bot(job["botId"])
        if answer == "deny":
            job["state"] = "stopped"
            job["now"] = "You said no, so the test fix stays put."
            job["terminal"].append({"text": "Push cancelled (test)", "kind": "warn"})
            if builder:
                builder["status"] = "idle"
            return
        job["state"] = "working"
        job["now"] = "Pushing the test branch"
        job["steps"][2]["state"] = "now"
        job["terminal"].append({"text": "$ git push -u origin test/fix", "kind": "cmd"})
        if builder:
            builder["status"] = "working"

        def finish():
            if job["state"] != "working":
                return
            for step in job["steps"]:
                step["state"] = "done"
            job["state"] = "done"
            job["now"] = "Test pull request is ready"
            job["terminal"].append({"text": "test pull request opened", "kind": "ok"})
            if builder:
                builder["status"] = "idle"
                builder["task"] = "Waiting for a test task"
            self.inbox.insert(0, {"id": "test-done", "kind": "done", "botId": job["botId"],
                                  "title": "Test: job finished", "body": "The test fix is in a test pull request.",
                                  "openLabel": "Watch", "opens": "live", "workId": job["id"],
                                  "unread": True, "at": now_iso()})
        self.later(6, finish)

    def do_inbox_read(self, body):
        for item in self.inbox:
            if item["id"] == body.get("itemId"):
                item["unread"] = False

    def do_inbox_readAll(self, body):
        for item in self.inbox:
            item["unread"] = False

    def do_inbox_clear(self, body):
        self.inbox = [i for i in self.inbox if i["id"] != body.get("itemId")]

    def do_work_pause(self, body):
        job = self.job(str(body.get("workId")))
        if job and job["state"] in ("working", "paused"):
            job["state"] = "paused" if body.get("paused") else "working"

    def do_work_stop(self, body):
        job = self.job(str(body.get("workId")))
        if job:
            job["state"] = "stopped"
            job["now"] = "Stopped from the phone"
            job["askId"] = None

    def do_work_note(self, body):
        job = self.job(str(body.get("workId")))
        if job:
            job["terminal"].append({"text": f"# note: {body.get('text', '')}", "kind": "warn"})

    def do_team_pause(self, body):
        self.paused = bool(body.get("paused"))

    def do_routine_save(self, body):
        routine = body.get("routine")
        if not isinstance(routine, dict) or not routine.get("id"):
            return {"ok": False, "error": "That routine is missing its id."}
        self.routines = [r for r in self.routines if r["id"] != routine["id"]] + [routine]

    def do_routine_toggle(self, body):
        for routine in self.routines:
            if routine["id"] == body.get("routineId"):
                routine["isOn"] = bool(body.get("isOn"))

    def do_routine_delete(self, body):
        self.routines = [r for r in self.routines if r["id"] != body.get("routineId")]

    def do_routine_skip(self, body):
        for routine in self.routines:
            if routine["id"] == body.get("routineId"):
                routine.pop("run", None)

    def do_claudeCode_update(self, body):
        pass

    def do_settings_save(self, body):
        pass


def make_handler(state, voice, team):
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
            if path == "/api/v1/action" and team is not None:
                return self.action()
            return self.send_json(404, {"error": "not_found"})

        def action(self):
            device = state.device_for(self.bearer())
            if device is None:
                return self.send_json(401, {"error": "unknown_token"})
            body = self.read_json()
            if body is None:
                return
            status, reply = team.act(body)
            print(f"  Phone did {body.get('type')}: {'ok' if reply.get('ok') else reply.get('error')}")
            self.send_json(status, reply)

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
                reply, end = "Hey, this is the test Chief. What's up?", False
            else:
                print(f"  You:   {text}")
                reply, end = chief_reply(text, body.get("turn", 0), team)
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
            path = self.path_only()
            if path not in ("/api/v1/hello", "/api/v1/state") or (path == "/api/v1/state" and team is None):
                return self.send_json(404, {"error": "not_found"})
            if state.device_for(self.bearer()) is None:
                return self.send_json(401, {"error": "unknown_token"})
            if path == "/api/v1/state":
                return self.send_json(200, team.snapshot())
            self.send_json(200, {"computerName": state.computer_name, "protocolVersion": PROTOCOL_VERSION})

        def log_request(self, code="-", size="-"):
            # The phone asks for /api/v1/state every few seconds; don't fill the terminal with it.
            if self.path_only() != "/api/v1/state" or code != 200:
                super().log_request(code, size)

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
    parser = argparse.ArgumentParser(description="Test Squall desktop for trying the phone app.")
    parser.add_argument("--port", type=int, default=47615)
    parser.add_argument("--name", default=socket.gethostname() or "Squall desktop")
    parser.add_argument("--host", default=None, help="address to show, if the guess is wrong")
    parser.add_argument("--no-voice", action="store_true", help="act like a desktop that can't do voice calls yet")
    parser.add_argument("--no-live", action="store_true", help="act like a desktop that can't send live data yet")
    args = parser.parse_args()

    state = PairingState(args.name)
    team = None if args.no_live else TestTeam()
    server = ThreadingHTTPServer(("0.0.0.0", args.port), make_handler(state, voice=not args.no_voice, team=team))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    host = args.host or local_ip()
    print(f"Test Squall desktop '{args.name}' is listening on port {args.port}.")
    if team is not None:
        print("Once paired, the app shows a small test team. It's test data, not real Squall.")
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
