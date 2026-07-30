#!/usr/bin/env python3
"""Normaliza los sprites independientes generados para Godot.

Las fuentes de alta resolución viven en ``art-source/<grupo>`` y las copias
optimizadas se escriben en ``game/assets/<grupo>``. Los atlas de animación y
las texturas repetibles se excluyen deliberadamente porque tienen requisitos
de dimensiones distintos.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = PROJECT_ROOT / "art-source"
OUTPUT_ROOT = PROJECT_ROOT / "game/assets"
DEFAULT_GROUPS = ("houses", "mining", "trees")
DEFAULT_SIZE = 250
DEFAULT_PADDING = 8


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convierte sprites independientes a lienzos PNG cuadrados."
    )
    parser.add_argument(
        "--size",
        type=int,
        default=DEFAULT_SIZE,
        help=f"Tamaño final del lienzo en píxeles (por defecto: {DEFAULT_SIZE}).",
    )
    parser.add_argument(
        "--padding",
        type=int,
        default=DEFAULT_PADDING,
        help=f"Margen transparente mínimo (por defecto: {DEFAULT_PADDING}).",
    )
    parser.add_argument(
        "--groups",
        nargs="+",
        default=list(DEFAULT_GROUPS),
        help="Subdirectorios de art-source que se deben procesar.",
    )
    return parser.parse_args()


def discover_sources(groups: list[str]) -> list[tuple[Path, Path]]:
    jobs: list[tuple[Path, Path]] = []
    for group in groups:
        source_directory = SOURCE_ROOT / group
        if not source_directory.is_dir():
            raise FileNotFoundError(f"No existe el grupo de fuentes: {source_directory}")

        for source_path in sorted(source_directory.glob("*.png")):
            output_path = OUTPUT_ROOT / group / source_path.name
            jobs.append((source_path, output_path))

    if not jobs:
        raise FileNotFoundError("No se encontraron sprites PNG para procesar.")
    return jobs


def trim_and_fit(source: Image.Image, size: int, padding: int) -> Image.Image:
    rgba = source.convert("RGBA")
    content_bounds = rgba.getchannel("A").getbbox()
    if content_bounds is None:
        raise ValueError("El sprite no contiene ningún píxel visible.")

    content = rgba.crop(content_bounds)
    available_size = size - padding * 2
    content.thumbnail(
        (available_size, available_size),
        Image.Resampling.LANCZOS,
    )

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    destination_x = (size - content.width) // 2
    destination_y = size - padding - content.height
    canvas.alpha_composite(content, (destination_x, destination_y))
    return canvas


def resize_sprite(
    source_path: Path,
    output_path: Path,
    size: int,
    padding: int,
) -> None:
    with Image.open(source_path) as source:
        source_size = source.size
        resized = trim_and_fit(source, size, padding)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    resized.save(output_path, format="PNG", optimize=True)
    print(
        f"{source_path.relative_to(PROJECT_ROOT)} "
        f"{source_size[0]}x{source_size[1]} -> "
        f"{output_path.relative_to(PROJECT_ROOT)} {size}x{size}"
    )


def main() -> None:
    args = parse_args()
    if args.size <= 0:
        raise ValueError("El tamaño final debe ser mayor que cero.")
    if args.padding < 0 or args.padding * 2 >= args.size:
        raise ValueError("El margen debe caber dentro del lienzo final.")

    for source_path, output_path in discover_sources(args.groups):
        resize_sprite(
            source_path,
            output_path,
            args.size,
            args.padding,
        )


if __name__ == "__main__":
    main()
