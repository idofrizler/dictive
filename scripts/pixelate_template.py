#!/usr/bin/env python3
"""Convert an input image into a Dictive DrawingTemplate color grid.

Requires Pillow: pip install pillow
"""

from __future__ import annotations

import argparse
import colorsys
import math
from pathlib import Path
from typing import Iterable, List, Tuple

Palette = List[Tuple[str, Tuple[int, int, int]]]

GAME_PALETTE_32: Palette = [
    ("red", (230, 57, 70)),
    ("orange", (244, 162, 97)),
    ("yellow", (233, 196, 106)),
    ("green", (76, 175, 80)),
    ("teal", (42, 157, 143)),
    ("brown", (141, 110, 99)),
    ("charcoal", (47, 47, 47)),
    ("lightgray", (176, 190, 197)),
    ("sky", (33, 150, 243)),
    ("indigo", (63, 81, 181)),
    ("violet", (156, 39, 176)),
    ("magenta", (233, 30, 99)),
    ("coral", (255, 112, 67)),
    ("gold", (255, 235, 59)),
    ("seafoam", (0, 150, 136)),
    ("umber", (121, 85, 72)),
    ("slate", (96, 125, 139)),
    ("gray", (158, 158, 158)),
    ("bluegray", (69, 90, 100)),
    ("deeporange", (255, 87, 34)),
    ("lime", (205, 220, 57)),
    ("leaf", (139, 195, 74)),
    ("cyan", (0, 188, 212)),
    ("azure", (3, 169, 244)),
    ("purple", (103, 58, 183)),
    ("hotpink", (255, 64, 129)),
    ("amber", (255, 152, 0)),
    ("white", (250, 250, 250)),
    ("storm", (84, 110, 122)),
    ("petalpink", (255, 167, 192)),
    ("darkgray", (66, 66, 66)),
    ("black", (0, 0, 0)),
]


def palette_for_size(size: int) -> Palette:
    if size not in (16, 32):
        raise ValueError("palette-size must be 16 or 32")
    return GAME_PALETTE_32[:size]


def tonal_palette_from_pixels(pixels: List[Tuple[int, int, int]], buckets: int) -> Palette:
    hsv_values = [colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0) for r, g, b in pixels]
    colorful = [hsv for hsv in hsv_values if hsv[1] > 0.12]

    if colorful:
        x = sum(math.cos(2 * math.pi * h) for h, _, _ in colorful)
        y = sum(math.sin(2 * math.pi * h) for h, _, _ in colorful)
        hue = (math.atan2(y, x) / (2 * math.pi)) % 1.0
        sat = sorted(s for _, s, _ in colorful)[len(colorful) // 2]
    else:
        hue = 0.0
        sat = 0.0

    sat = max(0.25, min(0.85, sat))
    values = [0.22 + (0.72 * (i / max(1, buckets - 1))) for i in range(buckets)]
    palette: Palette = []
    for i, v in enumerate(values):
        r, g, b = colorsys.hsv_to_rgb(hue, sat, v)
        palette.append((f"tone{i}", (int(r * 255), int(g * 255), int(b * 255))))
    return palette


def nearest_palette_index(rgb: Tuple[int, int, int], palette: Palette) -> int:
    r, g, b = rgb
    best_idx = 0
    best_dist = float("inf")
    for idx, (_, (pr, pg, pb)) in enumerate(palette):
        dr = r - pr
        dg = g - pg
        db = b - pb
        dist = (dr * dr) + (dg * dg) + (db * db)
        if dist < best_dist:
            best_dist = dist
            best_idx = idx
    return best_idx


def chunked(values: Iterable[int], width: int) -> List[List[int]]:
    row: List[int] = []
    rows: List[List[int]] = []
    for value in values:
        row.append(value)
        if len(row) == width:
            rows.append(row)
            row = []
    if row:
        rows.append(row)
    return rows


def to_swift_array(rows: List[List[int]]) -> str:
    formatted_rows = ["                " + ", ".join(str(v) for v in row) for row in rows]
    return "[\n" + ",\n".join(formatted_rows) + "\n            ]"


def template_snippet(template_id: str, name: str, width: int, height: int, rows: List[List[int]]) -> str:
    colors = to_swift_array(rows)
    return f'''private static func make{name}() -> DrawingTemplate {{
            let width = {width}
            let height = {height}
            let colors = {colors}
            return DrawingTemplate(id: "{template_id}", name: "{name}", width: width, height: height, colors: colors)
        }}'''


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert image to Dictive drawing template")
    parser.add_argument("input", type=Path, help="Input image path")
    parser.add_argument("--id", required=True, help="DrawingTemplate id")
    parser.add_argument("--name", required=True, help="DrawingTemplate name / function suffix")
    parser.add_argument("--width", type=int, default=15, help="Target pixel width")
    parser.add_argument("--height", type=int, default=15, help="Target pixel height")
    parser.add_argument("--mode", choices=["tonal", "fixed"], default="tonal", help="tonal keeps original hue and buckets shades")
    parser.add_argument("--palette-size", type=int, default=32, choices=[16, 32], help="Fixed palette size when mode=fixed")
    parser.add_argument("--buckets", type=int, default=6, help="Number of shade buckets when mode=tonal")
    parser.add_argument("--alpha-threshold", type=int, default=40, help="Pixels below this alpha become transparent (-1)")
    parser.add_argument("--output", type=Path, help="Optional output file for generated snippet")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        from PIL import Image
    except ImportError:
        raise SystemExit("Pillow is required. Install with: pip install pillow")

    if not args.input.exists():
        raise SystemExit(f"Input file not found: {args.input}")

    with Image.open(args.input) as img:
        rgba = img.convert("RGBA").resize((args.width, args.height), Image.Resampling.LANCZOS)
        pixels_rgba = list(rgba.getdata())
        solid_pixels = [(r, g, b) for r, g, b, a in pixels_rgba if a >= args.alpha_threshold]

    if args.mode == "fixed":
        palette = palette_for_size(args.palette_size)
        mode_desc = f"{args.palette_size} fixed buckets"
    else:
        palette = tonal_palette_from_pixels(solid_pixels or [(255, 255, 255)], max(2, args.buckets))
        mode_desc = f"{len(palette)} tonal buckets"

    mapped: List[int] = []
    for r, g, b, a in pixels_rgba:
        if a < args.alpha_threshold:
            mapped.append(-1)
            continue
        alpha = a / 255.0
        flattened_rgb = (
            int((r * alpha) + (255 * (1 - alpha))),
            int((g * alpha) + (255 * (1 - alpha))),
            int((b * alpha) + (255 * (1 - alpha))),
        )
        mapped.append(nearest_palette_index(flattened_rgb, palette))
    rows = chunked(mapped, args.width)

    used = sorted({value for value in mapped if value >= 0})
    palette_preview = ", ".join(f"{i}:{palette[i][0]}" for i in used)
    snippet = template_snippet(args.id, args.name, args.width, args.height, rows)

    output = f"// Used palette indexes ({mode_desc}): {palette_preview}\n{snippet}\n"
    if args.output:
        args.output.write_text(output)
        print(f"Wrote template snippet to {args.output}")
    else:
        print(output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
