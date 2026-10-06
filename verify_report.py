#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cek overlap PDF dan render setiap halaman ke PNG.

Ambang gagal: overlap bounding box kata-kata atau kata-gambar > 8 pt^2.

Jalankan:
    python3 verify_report.py
    python3 verify_report.py path/laporan.pdf path/folder-render
"""

from __future__ import annotations

import sys
from pathlib import Path

import pdfplumber
import pypdfium2 as pdfium

BASE = Path(__file__).resolve().parent
DEFAULT_PDF = BASE / "output" / "3123640021_Andi.pdf"
DEFAULT_RENDER_DIR = BASE / "renders"
OVERLAP_LIMIT = 8.0  # pt^2; overlap tepat 8 pt^2 tidak dianggap gagal
RENDER_DPI = 120


def overlap_area(a: dict, b: dict) -> float:
    width = min(a["x1"], b["x1"]) - max(a["x0"], b["x0"])
    height = min(a["bottom"], b["bottom"]) - max(a["top"], b["top"])
    return max(0.0, width) * max(0.0, height)


def check_overlaps(pdf_path: Path) -> list[str]:
    failures: list[str] = []
    with pdfplumber.open(pdf_path) as pdf:
        print(f"PDF: {pdf_path} — {len(pdf.pages)} halaman")
        for page_number, page in enumerate(pdf.pages, start=1):
            words = sorted(
                page.extract_words(use_text_flow=False, keep_blank_chars=False),
                key=lambda word: (word["top"], word["x0"]),
            )
            page_failures: list[str] = []

            for index, first in enumerate(words):
                for second in words[index + 1 :]:
                    if second["top"] >= first["bottom"]:
                        break
                    area = overlap_area(first, second)
                    if area > OVERLAP_LIMIT:
                        page_failures.append(
                            f"hal {page_number}: kata '{first['text'][:35]}' dan "
                            f"'{second['text'][:35]}' overlap {area:.1f} pt^2"
                        )

            for image in page.images:
                for word in words:
                    area = overlap_area(word, image)
                    if area > OVERLAP_LIMIT:
                        page_failures.append(
                            f"hal {page_number}: kata '{word['text'][:35]}' menimpa gambar "
                            f"({area:.1f} pt^2)"
                        )

            status = f"GAGAL ({len(page_failures)} overlap)" if page_failures else "OK"
            print(f"  halaman {page_number:>2}: {len(words):>4} kata, {len(page.images)} gambar -> {status}")
            failures.extend(page_failures)
    return failures


def render_all_pages(pdf_path: Path, render_dir: Path) -> int:
    render_dir.mkdir(parents=True, exist_ok=True)
    document = pdfium.PdfDocument(str(pdf_path))
    page_count = len(document)
    for index in range(page_count):
        page = document[index]
        bitmap = page.render(scale=RENDER_DPI / 72)
        image = bitmap.to_pil()
        image.save(render_dir / f"page-{index + 1:02d}.png")
        image.close()
        page.close()
    document.close()
    print(f"Render {page_count} halaman ({RENDER_DPI} dpi) ke {render_dir}")
    return page_count


def main() -> int:
    pdf_path = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_PDF
    render_dir = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else DEFAULT_RENDER_DIR
    if not pdf_path.is_file():
        print(f"PDF tidak ditemukan: {pdf_path}", file=sys.stderr)
        return 2

    failures = check_overlaps(pdf_path)
    render_all_pages(pdf_path, render_dir)
    if failures:
        print("\n== VERIFIKASI OVERLAP GAGAL ==")
        for failure in failures[:30]:
            print(f" - {failure}")
        if len(failures) > 30:
            print(f" - ... dan {len(failures) - 30} temuan lainnya")
        return 1

    print("\n== VERIFIKASI OVERLAP LULUS ==")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
