#!/usr/bin/env python3
"""Draws Squall's six alternate app icons as 1024 px PNGs.

The shapes and colors come from the "App icon ideas" concepts. Run it from the
repo root to rebuild the icon sets in Squall/Resources/Assets.xcassets:

    python3 tools/render_icons.py

Needs Pillow and numpy. Everything is drawn 4x bigger, then shrunk, for smooth edges.
"""

import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersampling
BIG = SIZE * SS
UNIT = BIG / 120.0  # the drawings use a 120 x 120 box

ASSETS = Path("Squall/Resources/Assets.xcassets")


# ---------- colors and gradients ----------

def hex_rgba(value):
    value = value.strip()
    if value.startswith("rgba("):
        r, g, b, a = [float(x) for x in value[5:-1].split(",")]
        return np.array([r, g, b, a * 255.0])
    h = value.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255.0])


def ramp(t, stops):
    """stops: [(position 0..1, rgba)], t: array. Interpolates in premultiplied color like CSS."""
    t = np.clip(t, 0, None)
    out = np.zeros(t.shape + (4,))
    pre = [(p, np.array([c[0] * c[3] / 255, c[1] * c[3] / 255, c[2] * c[3] / 255, c[3]])) for p, c in stops]
    out[...] = pre[-1][1]
    out[t <= pre[0][0]] = pre[0][1]
    for (p0, c0), (p1, c1) in zip(pre, pre[1:]):
        mask = (t > p0) & (t <= p1)
        f = ((t[mask] - p0) / max(p1 - p0, 1e-9))[:, None]
        out[mask] = c0 + (c1 - c0) * f
    return out  # premultiplied


def grid():
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    return (xs + 0.5) / SIZE, (ys + 0.5) / SIZE


def radial(rx, ry, cx, cy, stops):
    x, y = grid()
    t = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    return ramp(t, stops)


def linear(angle_deg, stops):
    x, y = grid()
    a = math.radians(angle_deg)
    dx, dy = math.sin(a), -math.cos(a)
    length = abs(math.sin(a)) + abs(math.cos(a))
    t = ((x - 0.5) * dx + (y - 0.5) * dy) / length + 0.5
    return ramp(t, stops)


def flatten(layers):
    """layers: front to back, like CSS background. Returns an RGB float image 0..255."""
    out = np.zeros((SIZE, SIZE, 3))
    for layer in reversed(layers):
        alpha = layer[..., 3:4] / 255.0
        out = layer[..., :3] + out * (1 - alpha)
    return out


# ---------- SVG paths ----------

NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
TOKEN = re.compile(r"[MmLlHhVvAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def arc_points(x1, y1, rx, ry, phi, large, sweep, x2, y2, steps=48):
    """SVG arc to a list of points (endpoint to center parameterization)."""
    if rx == 0 or ry == 0:
        return [(x2, y2)]
    phi = math.radians(phi)
    cos_p, sin_p = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cos_p * dx + sin_p * dy
    y1p = -sin_p * dx + cos_p * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    coef = math.sqrt(max(num / den, 0)) if den else 0
    if large == sweep:
        coef = -coef
    cxp = coef * rx * y1p / ry
    cyp = -coef * ry * x1p / rx
    cx = cos_p * cxp - sin_p * cyp + (x1 + x2) / 2
    cy = sin_p * cxp + cos_p * cyp + (y1 + y2) / 2

    def angle(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    pts = []
    for i in range(1, steps + 1):
        t = t1 + dt * i / steps
        x = cx + rx * math.cos(t) * cos_p - ry * math.sin(t) * sin_p
        y = cy + rx * math.cos(t) * sin_p + ry * math.sin(t) * cos_p
        pts.append((x, y))
    return pts


def parse_path(d):
    """Returns a list of subpaths, each (points, closed)."""
    tokens = TOKEN.findall(d)
    subpaths, pts = [], []
    x = y = sx = sy = 0.0
    cmd = None
    i = 0

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if re.fullmatch(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                if pts:
                    subpaths.append((pts, True))
                pts = []
                x, y = sx, sy
                continue
        if cmd in "Mm":
            nx, ny = num(), num()
            if cmd == "m":
                nx, ny = x + nx, y + ny
            if pts:
                subpaths.append((pts, False))
            x, y = sx, sy = nx, ny
            pts = [(x, y)]
            cmd = "L" if cmd == "M" else "l"
        elif cmd in "Ll":
            nx, ny = num(), num()
            if cmd == "l":
                nx, ny = x + nx, y + ny
            x, y = nx, ny
            pts.append((x, y))
        elif cmd in "Hh":
            nx = num()
            x = x + nx if cmd == "h" else nx
            pts.append((x, y))
        elif cmd in "Vv":
            ny = num()
            y = y + ny if cmd == "v" else ny
            pts.append((x, y))
        elif cmd in "Aa":
            rx, ry, phi, large, sweep, nx, ny = [num() for _ in range(7)]
            if cmd == "a":
                nx, ny = x + nx, y + ny
            pts.extend(arc_points(x, y, rx, ry, phi, int(large), int(sweep), nx, ny))
            x, y = nx, ny
        else:
            raise ValueError("unsupported path command " + str(cmd))
    if pts:
        subpaths.append((pts, False))
    return subpaths


# ---------- drawing ----------

class Painter:
    def __init__(self, background):
        self.image = Image.fromarray(np.clip(background, 0, 255).astype(np.uint8), "RGB").resize((BIG, BIG), Image.BICUBIC)
        self.shift = (0.0, 0.0)

    def to_px(self, pts):
        dx, dy = self.shift
        return [((px + dx) * UNIT, (py + dy) * UNIT) for px, py in pts]

    def paint(self, mask, color):
        layer = Image.new("RGB", (BIG, BIG), color)
        self.image.paste(layer, (0, 0), mask)

    def fill_path(self, d, color, evenodd=False):
        mask = Image.new("L", (BIG, BIG), 0)
        for pts, _ in parse_path(d):
            sub = Image.new("L", (BIG, BIG), 0)
            ImageDraw.Draw(sub).polygon(self.to_px(pts), fill=255)
            if evenodd:
                mask = Image.fromarray(np.bitwise_xor(np.array(mask), np.array(sub)))
            else:
                mask = Image.fromarray(np.maximum(np.array(mask), np.array(sub)))
        self.paint(mask, color)

    def fill_circle(self, cx, cy, r, color):
        (x, y), = self.to_px([(cx, cy)])
        rr = r * UNIT
        mask = Image.new("L", (BIG, BIG), 0)
        ImageDraw.Draw(mask).ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
        self.paint(mask, color)

    def fill_rect(self, x, y, w, h, color):
        self.fill_path(f"M{x} {y}h{w}v{h}h{-w}z", color)

    def stroke_points(self, pts, width, color, closed=False, round_caps=True):
        px = self.to_px(pts)
        if closed:
            px = px + px[:1]
        half = width * UNIT / 2
        mask = Image.new("L", (BIG, BIG), 0)
        draw = ImageDraw.Draw(mask)
        # Each piece is a thick rectangle, with a round dot at every point for smooth joins.
        for (x0, y0), (x1, y1) in zip(px, px[1:]):
            length = math.hypot(x1 - x0, y1 - y0)
            if length == 0:
                continue
            nx, ny = -(y1 - y0) / length * half, (x1 - x0) / length * half
            draw.polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill=255)
        dots = px if (closed or round_caps) else px[1:-1]
        for x, y in dots:
            draw.ellipse([x - half, y - half, x + half, y + half], fill=255)
        self.paint(mask, color)

    def stroke_path(self, d, width, color):
        for pts, closed in parse_path(d):
            self.stroke_points(pts, width, color, closed=closed)

    def stroke_ellipse(self, cx, cy, rx, ry, rotate, width, color):
        a = math.radians(rotate)
        pts = []
        for i in range(240):
            t = 2 * math.pi * i / 240
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
        self.stroke_points(pts, width, color, closed=True)

    def stroke_round_rect(self, x, y, w, h, r, width, color):
        d = (f"M{x + r} {y}H{x + w - r}a{r} {r} 0 0 1 {r} {r}V{y + h - r}a{r} {r} 0 0 1 {-r} {r}"
             f"H{x + r}a{r} {r} 0 0 1 {-r} {-r}V{y + r}a{r} {r} 0 0 1 {r} {-r}z")
        self.stroke_path(d, width, color)

    def result(self):
        return self.image.resize((SIZE, SIZE), Image.LANCZOS)


def rgb(value):
    c = hex_rgba(value)
    return (int(c[0]), int(c[1]), int(c[2]))


# ---------- the six icons ----------

def storm_cloud():
    bg = flatten([
        radial(0.8, 0.7, 0.28, 0.18, [(0, hex_rgba("#9a8cff")), (0.62, hex_rgba("rgba(154,140,255,0)"))]),
        radial(0.7, 0.6, 0.92, 1.0, [(0, hex_rgba("#18b9a1")), (0.7, hex_rgba("rgba(24,185,161,0)"))]),
        linear(160, [(0, hex_rgba("#4b3dc9")), (1, hex_rgba("#22196b"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ffffff"), rgb("#f5c84b")
    p.shift = (0, -5)
    p.fill_circle(44, 58, 14, main)
    p.fill_circle(62, 47, 20, main)
    p.fill_circle(80, 58, 14, main)
    p.fill_rect(44, 52, 36, 20, main)
    p.fill_path("M66 64 51 88h11l-5 20 19-28H65l8-16z", acc)
    return p.result()


def chiefs_bolt():
    bg = flatten([
        radial(0.7, 0.55, 0.5, 0.12, [(0, hex_rgba("rgba(245,200,75,0.5)")), (0.7, hex_rgba("rgba(245,200,75,0)"))]),
        radial(0.8, 0.6, 0.5, 1.1, [(0, hex_rgba("rgba(109,92,232,0.65)")), (0.7, hex_rgba("rgba(109,92,232,0)"))]),
        linear(170, [(0, hex_rgba("#2a2050")), (1, hex_rgba("#0e0b1f"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ffffff"), rgb("#f5c84b")
    p.shift = (0, -2)
    p.fill_path("M42 33 46 15 55 24 60 13 65 24 74 15 78 33z", acc)
    p.fill_path("M64 38 39 74h20l-6 32 31-42H63l9-26z", main)
    return p.result()


def squall_swirl():
    bg = flatten([
        radial(0.55, 0.55, 0.5, 0.5, [(0, hex_rgba("rgba(47,212,184,0.85)")), (0.7, hex_rgba("rgba(47,212,184,0)"))]),
        linear(150, [(0, hex_rgba("#6d5ce8")), (1, hex_rgba("#1f1a5c"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ffffff"), rgb("#fde68a")
    p.stroke_path("M60 22a38 38 0 0 1 38 38", 9, main)
    p.stroke_path("M60 98a38 38 0 0 1-38-38", 9, main)
    p.stroke_path("M86 60a26 26 0 0 1-26 26", 7, main)
    p.stroke_path("M34 60a26 26 0 0 1 26-26", 7, main)
    p.fill_path("M62 45 51 63h9l-4 14 14-19h-9l5-13z", acc)
    return p.result()


def bot_crew():
    bg = flatten([
        radial(0.8, 0.6, 0.5, 0.0, [(0, hex_rgba("#8f80ff")), (0.65, hex_rgba("rgba(143,128,255,0)"))]),
        linear(165, [(0, hex_rgba("#5a4ad8")), (1, hex_rgba("#2a1f86"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ece9ff"), rgb("#f5c84b")
    p.shift = (0, 10)
    p.fill_path("M24 52h14a8 8 0 0 1 8 8v10a8 8 0 0 1-8 8H24a8 8 0 0 1-8-8V60a8 8 0 0 1 8-8zM24 61v6h4v-6zM34 61v6h4v-6z", main, evenodd=True)
    p.fill_path("M82 52h14a8 8 0 0 1 8 8v10a8 8 0 0 1-8 8H82a8 8 0 0 1-8-8V60a8 8 0 0 1 8-8zM82 61v6h4v-6zM92 61v6h4v-6z", main, evenodd=True)
    p.fill_path("M49 40h22a11 11 0 0 1 11 11v16a11 11 0 0 1-11 11H49a11 11 0 0 1-11-11V51a11 11 0 0 1 11-11zM50 54v9h6v-9zM64 54v9h6v-9z", acc, evenodd=True)
    p.fill_path("M48 36 51 24 57 30 60 22 63 30 69 24 72 36z", acc)
    return p.result()


def orbit():
    bg = flatten([
        radial(0.65, 0.65, 0.5, 0.45, [(0, hex_rgba("rgba(109,92,232,0.75)")), (0.7, hex_rgba("rgba(109,92,232,0)"))]),
        linear(160, [(0, hex_rgba("#0f4450")), (1, hex_rgba("#07131d"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ffffff"), rgb("#5eead4")
    p.fill_path("M66 24 42 63h17l-6 32 26-41H62l8-30z", main)
    p.stroke_ellipse(60, 60, 46, 17, -20, 5, main)
    p.fill_circle(17.5, 69.3, 6.5, acc)
    p.fill_circle(94.5, 38.4, 6.5, acc)
    p.fill_circle(86.6, 65.9, 5, acc)
    return p.result()


def power_chip():
    bg = flatten([
        radial(0.7, 0.6, 0.3, 0.2, [(0, hex_rgba("rgba(255,255,255,0.25)")), (0.6, hex_rgba("rgba(255,255,255,0)"))]),
        linear(145, [(0, hex_rgba("#7c6cf0")), (1, hex_rgba("#2b8f9c"))]),
    ])
    p = Painter(bg)
    main, acc = rgb("#ffffff"), rgb("#fde68a")
    p.stroke_round_rect(34, 34, 52, 52, 12, 6, main)
    for d in ["M48 22v12", "M60 22v12", "M72 22v12", "M48 86v12", "M60 86v12", "M72 86v12",
              "M22 48h12", "M22 60h12", "M22 72h12", "M86 48h12", "M86 60h12", "M86 72h12"]:
        p.stroke_path(d, 6, main)
    p.fill_path("M64 42 50 62h10l-4 16 14-21H60l4-15z", acc)
    return p.result()


# Asset name, picker name, drawing function. The order here is the order in the picker.
ICONS = [
    ("StormCloud", "Storm Cloud", storm_cloud),
    ("ChiefsBolt", "Chief's Bolt", chiefs_bolt),
    ("SquallSwirl", "Squall Swirl", squall_swirl),
    ("BotCrew", "Bot Crew", bot_crew),
    ("Orbit", "Orbit", orbit),
    ("PowerChip", "Power Chip", power_chip),
]

INFO = {"author": "xcode", "version": 1}


def write_icon_set(name, image):
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(folder / f"{name}.png", optimize=True)
    contents = {"images": [{"filename": f"{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": INFO}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_preview(name, image):
    """Small copy the Settings picker can show (app icon sets can't be loaded as images)."""
    folder = ASSETS / f"IconPreview{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").resize((180, 180), Image.LANCZOS).save(folder / f"IconPreview{name}.png", optimize=True)
    contents = {"images": [{"filename": f"IconPreview{name}.png", "idiom": "universal"}], "info": INFO}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main():
    for name, title, draw in ICONS:
        image = draw()
        write_icon_set(name, image)
        write_preview(name, image)
        print(f"Drew {title} -> {name}.appiconset")
    current = Image.open(ASSETS / "AppIcon.appiconset" / "AppIcon.png")
    write_preview("Default", current)
    print("Made a preview of the current icon")


if __name__ == "__main__":
    main()
