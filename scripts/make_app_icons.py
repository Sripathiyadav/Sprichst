#!/usr/bin/env python3
"""Writes Sprichst's launcher, store and web icons for every platform from the
orbit mark in `assets/brand/` (the design system's logo).

    python3 scripts/make_app_icons.py        # needs Pillow

Re-run after replacing the PNGs in assets/brand/. The icon files are committed.
The Flutter template's logo is Google's trademark and must not identify another
product; this mark is Sprichst's own.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand"
CANVAS = (242, 234, 225)  # #f2eae1, the design system's canvas
CANVAS_HEX = "#f2eae1"


def load(name: str) -> Image.Image:
    return Image.open(BRAND / name).convert("RGBA")


def save(image: Image.Image, path: Path, pixels: int, flat: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = image.resize((pixels, pixels), Image.LANCZOS)
    if flat:  # iOS app icons must not contain transparency
        out = out.convert("RGB")
    out.save(path, optimize=True)


def rounded(image: Image.Image) -> Image.Image:
    size = image.width
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], size * 0.2237, fill=255)
    out = image.copy()
    out.putalpha(mask)
    return out


def main() -> None:
    light, dark = load("sprichst-orbit-light.png"), load("sprichst-orbit-dark.png")
    foreground, mono = load("sprichst-orbit-foreground.png"), load("sprichst-orbit-monochrome.png")

    # iOS: every size the catalogue lists, plus a dark 1024 for Xcode 16+.
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios / "Contents.json").read_text())
    contents["images"] = [i for i in contents["images"] if "appearances" not in i]
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        save(light, ios / entry["filename"], round(points * scale), flat=True)
    save(dark, ios / "Icon-App-1024x1024-dark.png", 1024, flat=True)
    contents["images"].append(
        {
            "filename": "Icon-App-1024x1024-dark.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
            "appearances": [{"appearance": "luminosity", "value": "dark"}],
        }
    )
    (ios / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

    # macOS
    for pixels in (16, 32, 64, 128, 256, 512, 1024):
        save(rounded(light), ROOT / f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{pixels}.png", pixels)

    # Android: legacy icons, and the adaptive icon (API 26+) with a themed layer.
    res = ROOT / "android/app/src/main/res"
    for density, pixels in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(light, res / f"mipmap-{density}/ic_launcher.png", pixels, flat=True)
    for density, pixels in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        save(foreground, res / f"mipmap-{density}/ic_launcher_foreground.png", pixels)
        save(mono, res / f"mipmap-{density}/ic_launcher_monochrome.png", pixels)
    (res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n"
    )
    (res / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f'<resources>\n    <color name="ic_launcher_background">{CANVAS_HEX}</color>\n</resources>\n'
    )

    # Web: the light icon, and a maskable pair (mark on canvas, inside the safe zone).
    maskable = Image.new("RGBA", foreground.size, CANVAS + (255,))
    maskable.alpha_composite(foreground)
    for pixels in (192, 512):
        save(light, ROOT / f"web/icons/Icon-{pixels}.png", pixels, flat=True)
        save(maskable, ROOT / f"web/icons/Icon-maskable-{pixels}.png", pixels, flat=True)
    save(light, ROOT / "web/favicon.png", 48, flat=True)

    # Windows
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    light.resize((256, 256), Image.LANCZOS).save(
        ico, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print("App icons written.")


if __name__ == "__main__":
    main()
