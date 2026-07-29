#!/usr/bin/env python3
"""Reduce las texturas del terreno conservando el pixel-art."""

from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TEXTURE_PATHS = (
    PROJECT_ROOT / "src/renderer/assets/grass-texture.png",
    PROJECT_ROOT / "src/renderer/assets/stone-grass-texture.png",
)
TARGET_SIZE = (50, 50)


def resize_texture(texture_path: Path) -> None:
    with Image.open(texture_path) as source:
        resized = source.convert("RGB").resize(TARGET_SIZE, Image.Resampling.NEAREST)
        resized.save(texture_path, format="PNG", optimize=True)
    print(f"{texture_path.name}: {TARGET_SIZE[0]}x{TARGET_SIZE[1]} px")


if __name__ == "__main__":
    for texture_path in TEXTURE_PATHS:
        resize_texture(texture_path)
