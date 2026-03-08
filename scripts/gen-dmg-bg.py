#!/usr/bin/env python3
"""Generate a Retina DMG background image with arrow and instruction text."""

from PIL import Image, ImageDraw, ImageFont
import sys

# Window size 520x280, Retina 2x
SCALE = 2
W, H = 520 * SCALE, 280 * SCALE
BG_COLOR = (30, 30, 46)

img = Image.new("RGB", (W, H), BG_COLOR)
draw = ImageDraw.Draw(img, "RGBA")

# Icon centers (Finder coords, scaled to 2x)
# App at (130, 140), Applications at (390, 140)
app_cx = 130 * SCALE
apps_cx = 390 * SCALE
icons_cy = 140 * SCALE
icon_r = 45 * SCALE  # icon radius (80px icon + some padding)

# Arrow: horizontal, centered between the two icons, at icon center height
arrow_y = icons_cy - 8 * SCALE  # slightly above center to avoid label area
arrow_x1 = app_cx + icon_r + 8 * SCALE
arrow_x2 = apps_cx - icon_r - 8 * SCALE
arrow_color = (140, 140, 180, 180)
arrow_width = 3 * SCALE
head_len = 12 * SCALE
head_w = 8 * SCALE

# Arrow shaft
draw.line([(arrow_x1, arrow_y), (arrow_x2 - head_len, arrow_y)],
          fill=arrow_color, width=arrow_width)

# Arrow head (triangle)
draw.polygon([
    (arrow_x2, arrow_y),
    (arrow_x2 - head_len, arrow_y - head_w),
    (arrow_x2 - head_len, arrow_y + head_w),
], fill=arrow_color)

# Instruction text above the arrow
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13 * SCALE)
except Exception:
    font = ImageFont.load_default()

text = "Drag to Applications"
text_color = (160, 160, 200, 200)
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
text_x = (W - tw) // 2
text_y = arrow_y - 28 * SCALE
draw.text((text_x, text_y), text, fill=text_color, font=font)

out = sys.argv[1] if len(sys.argv) > 1 else "dmg-background.png"
img.save(out, dpi=(144, 144))
print(f"Generated: {out} ({W}x{H} @2x)")
