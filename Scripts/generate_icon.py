#!/usr/bin/env python3
"""Generate KeyPilot.icns — a command-key badge on a dark rounded-rect background."""

import math
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ICONSET = "KeyPilot.iconset"
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: dark navy/indigo rounded rectangle
    r = size * 0.22  # corner radius
    bg_color = (30, 32, 56, 255)       # dark indigo
    accent = (99, 120, 255, 255)       # periwinkle blue

    def rounded_rect(d, xy, radius, fill):
        x0, y0, x1, y1 = xy
        d.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
        d.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
        d.ellipse([x0, y0, x0 + 2*radius, y0 + 2*radius], fill=fill)
        d.ellipse([x1 - 2*radius, y0, x1, y0 + 2*radius], fill=fill)
        d.ellipse([x0, y1 - 2*radius, x0 + 2*radius, y1], fill=fill)
        d.ellipse([x1 - 2*radius, y1 - 2*radius, x1, y1], fill=fill)

    pad = size * 0.04
    rounded_rect(draw, (pad, pad, size - pad, size - pad), r, bg_color)

    # Draw the ⌘ (command key) symbol programmatically
    # The symbol is made of a rounded square with four rounded-square "lobes"
    cx, cy = size / 2, size / 2

    # Lobe radius and gap
    lobe_r = size * 0.115
    gap = size * 0.07
    arm_w = size * 0.085   # stroke width

    lobe_positions = [
        (cx - gap - lobe_r, cy - gap - lobe_r),  # top-left
        (cx + gap + lobe_r, cy - gap - lobe_r),  # top-right
        (cx - gap - lobe_r, cy + gap + lobe_r),  # bottom-left
        (cx + gap + lobe_r, cy + gap + lobe_r),  # bottom-right
    ]

    inner_r = lobe_r * 0.48  # inner hole radius of each lobe

    def draw_lobe(cx_l, cy_l):
        # Outer ring
        draw.ellipse(
            [cx_l - lobe_r, cy_l - lobe_r, cx_l + lobe_r, cy_l + lobe_r],
            fill=accent,
        )
        # Inner hole
        draw.ellipse(
            [cx_l - inner_r, cy_l - inner_r, cx_l + inner_r, cy_l + inner_r],
            fill=bg_color,
        )

    for lx, ly in lobe_positions:
        draw_lobe(lx, ly)

    # Connecting arms — horizontal and vertical bars through the centre
    half = arm_w / 2
    # Horizontal bar
    draw.rectangle(
        [cx - gap - 2*lobe_r + inner_r, cy - half,
         cx + gap + 2*lobe_r - inner_r, cy + half],
        fill=accent,
    )
    # Vertical bar
    draw.rectangle(
        [cx - half, cy - gap - 2*lobe_r + inner_r,
         cx + half, cy + gap + 2*lobe_r - inner_r],
        fill=accent,
    )

    return img


def main():
    # Resolve paths relative to the repo root (parent of Scripts/)
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    iconset_path = os.path.join(repo_root, ICONSET)
    output_path = os.path.join(repo_root, "Resources", "KeyPilot.icns")

    os.makedirs(iconset_path, exist_ok=True)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    for size in SIZES:
        img = draw_icon(size)
        # @1x
        img.save(os.path.join(iconset_path, f"icon_{size}x{size}.png"))
        # @2x (only if half-size exists in the set)
        half = size // 2
        if half in SIZES:
            img.save(os.path.join(iconset_path, f"icon_{half}x{half}@2x.png"))

    subprocess.run(
        ["iconutil", "-c", "icns", iconset_path, "-o", output_path],
        check=True,
    )
    print(f"Generated {output_path}")
    shutil.rmtree(iconset_path)


if __name__ == "__main__":
    main()
