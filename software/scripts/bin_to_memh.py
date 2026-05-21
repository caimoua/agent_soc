#!/usr/bin/env python3
"""Convert a little-endian flat binary to one 32-bit word per MEMH line."""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_bin", type=Path)
    parser.add_argument("output_memh", type=Path)
    parser.add_argument("--fill", default="00000013",
                        help="32-bit hex word used to pad to min-words")
    parser.add_argument("--min-words", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    data = bytearray(args.input_bin.read_bytes())
    while len(data) % 4:
        data.append(0)

    words = []
    for offset in range(0, len(data), 4):
        word = int.from_bytes(data[offset:offset + 4], byteorder="little")
        words.append(f"{word:08x}")

    fill = args.fill.lower()
    if fill.startswith("0x"):
        fill = fill[2:]

    while len(words) < args.min_words:
        words.append(fill.zfill(8))

    args.output_memh.parent.mkdir(parents=True, exist_ok=True)
    args.output_memh.write_text("\n".join(words) + "\n", encoding="ascii")


if __name__ == "__main__":
    main()
