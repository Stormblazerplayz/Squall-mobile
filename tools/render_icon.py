#!/usr/bin/env python3
"""Draws the Bambu Bay app icon (1024x1024 PNG): a print nozzle over layers that turn into waves.

Run:  python3 tools/render_icon.py   (needs Pillow: pip install pillow)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # drawn at 2x, then scaled down for smooth edges
OUT = os.path.join(os.path.dirname(__file__), "..", "BambuBay", "Resources", "Assets.xcassets",
                   "AppIcon.appiconset", "AppIcon.png")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGB", (S, S))
    top, bottom = (14, 22, 40), (6, 40, 44)
    px = img.load()
    for y in range(S):
        c = lerp(top, bottom, y / (S - 1))
        for x in range(S):
            px[x, y] = c

    # Soft glow behind the layers.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((S * 0.18, S * 0.42, S * 0.82, S * 0.98), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.09))
    teal = Image.new("RGB", (S, S), (43, 217, 160))
    img = Image.composite(teal, img, glow.point(lambda v: int(v * 0.35)))

    draw = ImageDraw.Draw(img)

    # Printed layers: straight at the top, turning into waves at the bottom (the "bay").
    layer_colors = [(120, 240, 200), (80, 225, 180), (43, 210, 165), (30, 185, 175), (25, 160, 190)]
    base_y = S * 0.56
    gap = S * 0.075
    width = S * 0.058
    r = width / 2
    for i, color in enumerate(layer_colors):
        y0 = base_y + i * gap
        amp = S * 0.011 * i
        # Stamp circles along the path: smooth thick curves without the gaps of wide lines.
        steps = 900
        for k in range(steps + 1):
            x = S * 0.17 + (S * 0.66) * k / steps
            y = y0 + amp * math.sin(k / steps * math.pi * 3 + i * 0.6)
            draw.ellipse((x - r, y - r, x + r, y + r), fill=color)

    # The nozzle.
    cx = S * 0.5
    body_top, body_bottom = S * 0.17, S * 0.36
    draw.rounded_rectangle((cx - S * 0.17, body_top, cx + S * 0.17, body_bottom), radius=S * 0.05, fill=(236, 242, 248))
    draw.polygon([(cx - S * 0.1, body_bottom - 2), (cx + S * 0.1, body_bottom - 2), (cx + S * 0.035, S * 0.45), (cx - S * 0.035, S * 0.45)],
                 fill=(205, 215, 228))
    # Hot tip and the filament it lays down.
    draw.ellipse((cx - S * 0.03, S * 0.43, cx + S * 0.03, S * 0.49), fill=(255, 150, 60))
    draw.rectangle((cx - S * 0.012, S * 0.48, cx + S * 0.012, base_y), fill=(255, 170, 80))
    # Vent lines on the nozzle body.
    for j in range(3):
        y = body_top + S * 0.055 + j * S * 0.045
        draw.rounded_rectangle((cx - S * 0.11, y, cx + S * 0.11, y + S * 0.016), radius=S * 0.008, fill=(190, 200, 215))

    img = img.resize((1024, 1024), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("Wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
