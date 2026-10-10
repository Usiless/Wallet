"""Resize the approved Cabal artwork into Android launcher resources.

Run with Python 3 and Pillow; this script does not build the app.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/branding/cabal-icon-concept.png"
RESOURCES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def main():
    with Image.open(SOURCE) as artwork:
        for density, scale in DENSITIES.items():
            directory = RESOURCES / f"mipmap-{density}"
            directory.mkdir(parents=True, exist_ok=True)
            # Legacy icons use a 48dp canvas; adaptive icons use 108dp.
            # Keep the approved artwork centered, including its safe margins.
            for name, dp in [("ic_launcher", 48), ("ic_launcher_foreground", 108)]:
                size = round(dp * scale)
                artwork.resize((size, size), Image.Resampling.LANCZOS).save(
                    directory / f"{name}.png"
                )


if __name__ == "__main__":
    main()
