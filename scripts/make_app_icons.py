#!/usr/bin/env python3
"""Draws Sprichst's own app icon and writes it for every platform.

The Flutter template ships Flutter's logo as the app icon; that logo is Google's
trademark and must not be used to identify another product. This icon is
original: a bold "S" in Roboto Black (bundled, Apache-2.0) above the three
bands of the German flag. Nothing here is third-party artwork.

    python3 scripts/make_app_icons.py        # needs Pillow

Re-run after changing the design below. The icon files are committed.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets" / "fonts" / "roboto" / "Roboto-Black.ttf"

INK = (22, 19, 13)
PAPER = (255, 255, 255)
RED = (221, 0, 0)
GOLD = (255, 206, 0)
SIZE = 1024


def draw(inset: float = 0.0, rounded: bool = False) -> Image.Image:
    """The icon at 1024 px. [inset] shrinks the artwork inside a full-bleed
    background (maskable icons keep it inside the safe zone)."""
    image = Image.new("RGBA", (SIZE, SIZE), PAPER + (255,))
    pen = ImageDraw.Draw(image)

    margin = SIZE * inset
    art = SIZE - 2 * margin
    band_height = art * 0.17
    top = SIZE - margin - 3 * band_height

    for i, colour in enumerate((INK, RED, GOLD)):
        y = top + i * band_height
        pen.rectangle([margin, y, SIZE - margin, y + band_height + 1], fill=colour)

    # The S fills most of the space above the bands. Its size is measured, not
    # guessed, so it never touches the bands or the edge.
    room = top - margin
    probe = ImageFont.truetype(str(FONT), 1000)
    probe_box = pen.textbbox((0, 0), "S", font=probe)
    size = int(1000 * (room * 0.74) / (probe_box[3] - probe_box[1]))
    font = ImageFont.truetype(str(FONT), size)
    box = pen.textbbox((0, 0), "S", font=font)
    width, height = box[2] - box[0], box[3] - box[1]
    x = (SIZE - width) / 2 - box[0]
    y = margin + (room - height) / 2 - box[1]
    pen.text((x, y), "S", font=font, fill=INK)

    if rounded:
        mask = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], SIZE * 0.2237, fill=255)
        image.putalpha(mask)
    return image


def save(image: Image.Image, path: Path, pixels: int, flat: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = image.resize((pixels, pixels), Image.LANCZOS)
    if flat:  # iOS app icons must not contain transparency
        out = out.convert("RGB")
    out.save(path, optimize=True)


def main() -> None:
    square = draw()
    rounded = draw(rounded=True)
    maskable = draw(inset=0.12)

    # iOS: every size the asset catalogue lists.
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios / "Contents.json").read_text())
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        save(square, ios / entry["filename"], round(points * scale), flat=True)

    # macOS
    for pixels in (16, 32, 64, 128, 256, 512, 1024):
        save(rounded, ROOT / f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{pixels}.png", pixels)

    # Android legacy launcher icons
    for density, pixels in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(square, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", pixels, flat=True)

    # Web
    for pixels in (192, 512):
        save(rounded, ROOT / f"web/icons/Icon-{pixels}.png", pixels)
        save(maskable, ROOT / f"web/icons/Icon-maskable-{pixels}.png", pixels, flat=True)
    save(rounded, ROOT / "web/favicon.png", 48)

    # Windows
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    rounded.resize((256, 256), Image.LANCZOS).save(
        ico, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print("App icons written.")


if __name__ == "__main__":
    main()
