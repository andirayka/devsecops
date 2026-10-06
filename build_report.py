#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bangun laporan resmi A4 dari chapters/bab1.md sampai bab5.md.

Jalankan dari folder tugas dengan:
    python3 build_report.py

Isi bab tidak dibuat oleh generator. Skrip menghasilkan satu PDF per bab di
output/babN/ dan satu gabungan di output/. Lihat PARSER_CONTRACT.md untuk sintaks.
"""

from __future__ import annotations

import argparse
import re
import textwrap
from pathlib import Path
from urllib.parse import urlsplit
from xml.sax.saxutils import escape, quoteattr

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)

BASE = Path(__file__).resolve().parent
DEFAULT_CHAPTERS = BASE / "chapters"
DEFAULT_OUTPUT_DIR = BASE / "output"
PDF_FILENAME = "3123640021_Andi.pdf"
LOGO = BASE / "assets" / "logo-pens.png"
CHAPTERS = (
    ("bab1", "Bab 1"),
    ("bab2", "Bab 2"),
    ("bab3", "Bab 3"),
    ("bab4", "Bab 4"),
    ("bab5", "Bab 5"),
)

PAGE_W, PAGE_H = A4
MARGIN = 2 * cm
USABLE_W = PAGE_W - 2 * MARGIN
FRAME_BOTTOM = 1.85 * cm
FRAME_H = PAGE_H - (2 * cm) - FRAME_BOTTOM

INK = colors.HexColor("#16181D")
MUTED = colors.HexColor("#5A5E6B")
ACCENT = colors.HexColor("#1F3A93")
RULE = colors.HexColor("#C9CBD6")
CODE_BG = colors.HexColor("#F6F6F8")
TABLE_HEAD = colors.HexColor("#E8EAF2")
TABLE_GRID = colors.HexColor("#A9ACBD")
QUOTE_BG = colors.HexColor("#F2F4FA")

STYLES = {
    "cover_small": ParagraphStyle(
        "cover_small", fontName="Helvetica", fontSize=10.5, leading=14,
        alignment=TA_CENTER, textColor=MUTED,
    ),
    "cover_title": ParagraphStyle(
        "cover_title", fontName="Helvetica-Bold", fontSize=22, leading=27,
        alignment=TA_CENTER, textColor=INK,
    ),
    "cover_subtitle": ParagraphStyle(
        "cover_subtitle", fontName="Helvetica-Bold", fontSize=13, leading=18,
        alignment=TA_CENTER, textColor=ACCENT,
    ),
    "cover_line": ParagraphStyle(
        "cover_line", fontName="Helvetica", fontSize=10.5, leading=15,
        alignment=TA_CENTER, textColor=INK,
    ),
    "cover_name": ParagraphStyle(
        "cover_name", fontName="Helvetica-Bold", fontSize=14, leading=19,
        alignment=TA_CENTER, textColor=INK,
    ),
    "h1": ParagraphStyle(
        "h1", fontName="Helvetica-Bold", fontSize=15, leading=19,
        spaceBefore=8, spaceAfter=9, textColor=ACCENT, keepWithNext=True,
    ),
    "h2": ParagraphStyle(
        "h2", fontName="Helvetica-Bold", fontSize=12, leading=15,
        spaceBefore=10, spaceAfter=5, textColor=INK, keepWithNext=True,
    ),
    "h3": ParagraphStyle(
        "h3", fontName="Helvetica-Bold", fontSize=10.5, leading=13.5,
        spaceBefore=7, spaceAfter=4, textColor=colors.HexColor("#333A56"),
        keepWithNext=True,
    ),
    "body": ParagraphStyle(
        "body", fontName="Helvetica", fontSize=9.5, leading=14,
        alignment=TA_JUSTIFY, textColor=INK, spaceAfter=5,
    ),
    "bullet": ParagraphStyle(
        "bullet", fontName="Helvetica", fontSize=9.5, leading=13.5,
        alignment=TA_LEFT, textColor=INK, leftIndent=14, bulletIndent=3,
        spaceAfter=2.5,
    ),
    "quote": ParagraphStyle(
        "quote", fontName="Helvetica-Oblique", fontSize=9.2, leading=13,
        textColor=MUTED, leftIndent=5, rightIndent=4,
    ),
    "code": ParagraphStyle(
        "code", fontName="Courier", fontSize=7.5, leading=9.5, textColor=INK,
    ),
    "table_cell": ParagraphStyle(
        "table_cell", fontName="Helvetica", fontSize=8.3, leading=11,
        textColor=INK,
    ),
    "table_head": ParagraphStyle(
        "table_head", fontName="Helvetica-Bold", fontSize=8.5, leading=11,
        textColor=INK,
    ),
    "caption": ParagraphStyle(
        "caption", fontName="Helvetica-Oblique", fontSize=8, leading=10.5,
        alignment=TA_CENTER, textColor=MUTED, spaceBefore=3, spaceAfter=6,
    ),
}

FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^ {0,3}(#{1,6})\s+(.+?)\s*#*\s*$")
LIST_RE = re.compile(r"^( *)([-+*]|\d+[.)])\s+(.*)$")
RULE_RE = re.compile(r"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$")
IMAGE_RE = re.compile(r"^\s*!\[([^]]*)\]\((.+)\)\s*$")
IMAGE_REFERENCE_RE = re.compile(r"^\s*!\[([^]]*)\]\[([^]]*)\]\s*$")
REFERENCE_DEFINITION_RE = re.compile(r"^\s*\[([^]]+)\]:\s*(.+?)\s*$")
INLINE_RE = re.compile(
    r"`([^`]+)`|\[([^]]+)\]\(([^)]+)\)|\*\*(.+?)\*\*|"
    r"\*(?!\s)(.+?)(?<!\s)\*"
)


def inline_markup(source: str) -> str:
    """Escape text and render a small, safe Markdown inline subset."""
    pieces: list[str] = []
    cursor = 0
    for match in INLINE_RE.finditer(source):
        pieces.append(escape(source[cursor : match.start()]))
        code, link_text, link_url, bold, italic = match.groups()
        if code is not None:
            pieces.append(f'<font name="Courier">{escape(code)}</font>')
        elif link_text is not None and link_url is not None:
            url = link_url.strip()
            if urlsplit(url).scheme.lower() in {"http", "https", "mailto"}:
                pieces.append(
                    f"<link href={quoteattr(url)} color='#1F3A93'>"
                    f"{inline_markup(link_text)}</link>"
                )
            else:
                pieces.append(escape(link_text))
        elif bold is not None:
            pieces.append(f"<b>{escape(bold)}</b>")
        elif italic is not None:
            pieces.append(f"<i>{escape(italic)}</i>")
        cursor = match.end()
    pieces.append(escape(source[cursor:]))
    return "".join(pieces)


def split_table_row(line: str) -> list[str]:
    row = line.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|"):
        row = row[:-1]
    return [cell.strip().replace(r"\|", "|") for cell in re.split(r"(?<!\\)\|", row)]


def is_table_start(lines: list[str], index: int) -> bool:
    if index + 1 >= len(lines) or "|" not in lines[index]:
        return False
    separators = split_table_row(lines[index + 1])
    return bool(separators) and all(
        re.fullmatch(r":?-{3,}:?", cell.replace(" ", "")) for cell in separators
    )


def is_block_start(lines: list[str], index: int) -> bool:
    line = lines[index]
    return bool(
        FENCE_RE.match(line)
        or HEADING_RE.match(line)
        or RULE_RE.match(line)
        or LIST_RE.match(line)
        or line.lstrip().startswith(">")
        or IMAGE_RE.match(line)
        or IMAGE_REFERENCE_RE.match(line)
        or is_table_start(lines, index)
    )


def cover_rule() -> Table:
    rule = Table([[""]], colWidths=[8 * cm], rowHeights=[1.2])
    rule.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), ACCENT)]))
    rule.hAlign = "CENTER"
    return rule


def cover(args: argparse.Namespace, subtitle: str, report_label: str) -> list:
    if not LOGO.is_file():
        raise FileNotFoundError(f"Logo PENS tidak ditemukan: {LOGO}")

    logo_width = 3.4 * cm
    image_width, image_height = ImageReader(str(LOGO)).getSize()
    logo_height = logo_width * image_height / image_width
    story: list = [
        Spacer(1, 0.45 * cm),
        Image(str(LOGO), width=logo_width, height=logo_height, hAlign="CENTER"),
        Spacer(1, 0.55 * cm),
        Paragraph("Laporan Praktikum DevSecOps", STYLES["cover_title"]),
        Paragraph(escape(subtitle), STYLES["cover_subtitle"]),
        Spacer(1, 0.55 * cm),
        cover_rule(),
        Spacer(1, 0.75 * cm),
        Paragraph("LAPORAN RESMI DEVOPS", STYLES["cover_line"]),
        Paragraph(escape(report_label.upper()), STYLES["cover_line"]),
    ]

    if args.group:
        story.append(Paragraph(f"Kelompok: {escape(args.group)}", STYLES["cover_small"]))
    if args.lecturer:
        story.append(Paragraph(f"Dosen pengampu: {escape(args.lecturer)}", STYLES["cover_small"]))

    story.extend(
        [
            Spacer(1, 1.15 * cm),
            Paragraph("Disusun oleh:", STYLES["cover_small"]),
            Paragraph("Andi Rayka C", STYLES["cover_name"]),
            Paragraph("NRP 3123640021", STYLES["cover_line"]),
            Paragraph("Kelas D4 LJ Informatika", STYLES["cover_line"]),
            Spacer(1, 1.25 * cm),
            Paragraph("PROGRAM STUDI LJ-D4 TEKNIK INFORMATIKA", STYLES["cover_line"]),
            Paragraph("POLITEKNIK ELEKTRONIKA NEGERI SURABAYA", STYLES["cover_name"]),
        ]
    )
    if args.academic_year:
        story.append(Paragraph(escape(args.academic_year), STYLES["cover_line"]))
    story.append(PageBreak())
    return story


def code_block(source: str) -> Table:
    max_chars = max(40, int((USABLE_W - 18) / 4.5))
    rows: list[list[Preformatted]] = []
    for line in source.splitlines() or [""]:
        wrapped = textwrap.wrap(
            line,
            width=max_chars,
            subsequent_indent="    ",
            break_long_words=True,
            break_on_hyphens=False,
            replace_whitespace=False,
        ) or [""]
        rows.extend([[Preformatted(part or "\u00a0", STYLES["code"])] for part in wrapped])

    table = Table(rows, colWidths=[USABLE_W], splitByRow=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
                ("BOX", (0, 0), (-1, -1), 0.6, RULE),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    return table


def normalized_reference(reference: str) -> str:
    return " ".join(reference.casefold().split())


def image_destination(raw_destination: str) -> str:
    destination = raw_destination.strip()
    if destination.startswith("<"):
        closing = destination.find(">")
        if closing == -1:
            raise ValueError(f"Sintaks path gambar dengan '<' tanpa '>' : {raw_destination}")
        return destination[1:closing]

    title = re.match(r"^(.+?)\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\))\s*$", destination)
    if title:
        destination = title.group(1)
    return destination.strip("\"'")


def collect_image_references(lines: list[str]) -> tuple[list[str], dict[str, str]]:
    content: list[str] = []
    references: dict[str, str] = {}
    for line in lines:
        definition = REFERENCE_DEFINITION_RE.match(line)
        if definition:
            label, raw_destination = definition.groups()
            references[normalized_reference(label)] = image_destination(raw_destination)
        else:
            content.append(line)
    return content, references


def markdown_image(line: str, source_file: Path, references: dict[str, str]) -> list:
    inline_match = IMAGE_RE.match(line)
    reference_match = IMAGE_REFERENCE_RE.match(line)
    if inline_match:
        alt_text, raw_destination = inline_match.groups()
        destination = image_destination(raw_destination)
    elif reference_match:
        alt_text, reference = reference_match.groups()
        reference = reference or alt_text
        key = normalized_reference(reference)
        if key not in references:
            raise ValueError(f"Definisi gambar [{reference}] tidak ditemukan di {source_file}")
        destination = references[key]
    else:
        raise ValueError(f"Sintaks gambar Markdown tidak valid di {source_file}: {line}")

    if urlsplit(destination).scheme:
        raise ValueError(
            f"Gambar eksternal belum didukung; simpan gambar secara lokal: {source_file}: {destination}"
        )

    relative_path = Path(destination)
    candidates = [source_file.parent / relative_path, BASE / relative_path]
    image_path = next((candidate for candidate in candidates if candidate.is_file()), None)
    if image_path is None:
        tried = ", ".join(str(candidate) for candidate in candidates)
        raise FileNotFoundError(f"Gambar Markdown tidak ditemukan ({source_file}): {tried}")

    image_width, image_height = ImageReader(str(image_path)).getSize()
    max_width = USABLE_W
    max_height = FRAME_H * 0.72
    scale = min(max_width / image_width, max_height / image_height, 1.0)
    image = Image(
        str(image_path),
        width=image_width * scale,
        height=image_height * scale,
        hAlign="CENTER",
    )
    if alt_text.strip():
        caption = Paragraph(inline_markup(alt_text), STYLES["caption"])
        return [Spacer(1, 3), KeepTogether([image, caption])]
    return [Spacer(1, 3), image, Spacer(1, 5)]


def markdown_table(lines: list[str], start: int) -> tuple[Table, int]:
    header = split_table_row(lines[start])
    column_count = len(header)
    rows = [header]
    index = start + 2
    while index < len(lines) and "|" in lines[index] and lines[index].strip():
        row = split_table_row(lines[index])[:column_count]
        rows.append(row + [""] * (column_count - len(row)))
        index += 1

    data = [
        [Paragraph(inline_markup(cell), STYLES["table_head"]) for cell in rows[0]],
        *[
            [Paragraph(inline_markup(cell), STYLES["table_cell"]) for cell in row]
            for row in rows[1:]
        ],
    ]
    table = Table(
        data,
        colWidths=[USABLE_W / column_count] * column_count,
        repeatRows=1,
        splitByRow=1,
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), TABLE_HEAD),
                ("GRID", (0, 0), (-1, -1), 0.45, TABLE_GRID),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table, index


def markdown_to_flowables(source_file: Path, source: str) -> list:
    lines, image_references = collect_image_references(source.splitlines())
    story: list = []
    index = 0

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if not stripped:
            index += 1
            continue

        fence = FENCE_RE.match(line)
        if fence:
            marker = fence.group(1)
            closing = re.compile(rf"^ {{0,3}}{re.escape(marker[0])}{{{len(marker)},}}\s*$")
            index += 1
            code_lines: list[str] = []
            while index < len(lines) and not closing.match(lines[index]):
                code_lines.append(lines[index])
                index += 1
            if index < len(lines):
                index += 1
            story.extend([Spacer(1, 3), code_block("\n".join(code_lines)), Spacer(1, 6)])
            continue

        heading = HEADING_RE.match(line)
        if heading:
            level = len(heading.group(1))
            style = STYLES["h1"] if level == 1 else STYLES["h2"] if level == 2 else STYLES["h3"]
            story.append(Paragraph(inline_markup(heading.group(2)), style))
            index += 1
            continue

        image_match = IMAGE_RE.match(line) or IMAGE_REFERENCE_RE.match(line)
        if image_match:
            story.extend(markdown_image(line, source_file, image_references))
            index += 1
            continue

        if is_table_start(lines, index):
            table, index = markdown_table(lines, index)
            story.extend([table, Spacer(1, 6)])
            continue

        list_item = LIST_RE.match(line)
        if list_item:
            base_indent = len(list_item.group(1))
            items: list[tuple[int, str, list[str]]] = []
            while index < len(lines):
                current = LIST_RE.match(lines[index])
                if current:
                    depth = max(0, len(current.group(1)) - base_indent) // 2
                    items.append((depth, current.group(2), [current.group(3)]))
                    index += 1
                    continue
                if IMAGE_RE.match(lines[index]) or IMAGE_REFERENCE_RE.match(lines[index]):
                    break
                if (
                    lines[index].strip()
                    and len(lines[index]) - len(lines[index].lstrip()) > base_indent
                    and items
                ):
                    items[-1][2].append(lines[index].strip())
                    index += 1
                    continue
                break
            for item_number, (depth, marker, item_lines) in enumerate(items):
                style = ParagraphStyle(
                    f"list_{index}_{item_number}",
                    parent=STYLES["bullet"],
                    leftIndent=14 + depth * 12,
                    bulletIndent=3 + depth * 12,
                )
                story.append(
                    Paragraph(
                        inline_markup(" ".join(item_lines)),
                        style,
                        bulletText=marker,
                    )
                )
            continue

        if stripped.startswith(">"):
            quote_lines: list[str] = []
            while index < len(lines) and lines[index].lstrip().startswith(">"):
                quote_lines.append(re.sub(r"^\s*>\s?", "", lines[index]))
                index += 1
            quote = Table(
                [[Paragraph("<br/>".join(inline_markup(part) for part in quote_lines), STYLES["quote"])]],
                colWidths=[USABLE_W],
            )
            quote.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, -1), QUOTE_BG),
                        ("LINEBEFORE", (0, 0), (0, -1), 2, ACCENT),
                        ("LEFTPADDING", (0, 0), (-1, -1), 9),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                        ("TOPPADDING", (0, 0), (-1, -1), 6),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                    ]
                )
            )
            story.extend([quote, Spacer(1, 5)])
            continue

        if RULE_RE.match(line):
            rule = Table([[""]], colWidths=[USABLE_W], rowHeights=[0.8])
            rule.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), RULE)]))
            story.extend([Spacer(1, 4), rule, Spacer(1, 6)])
            index += 1
            continue

        paragraph_lines = [stripped]
        index += 1
        while index < len(lines) and lines[index].strip() and not is_block_start(lines, index):
            paragraph_lines.append(lines[index].strip())
            index += 1
        story.append(Paragraph(inline_markup(" ".join(paragraph_lines)), STYLES["body"]))

    if not story:
        raise ValueError(f"Bab Markdown kosong: {source_file}")
    return story


def draw_footer(canvas, doc, report_label: str) -> None:
    canvas.saveState()
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.6)
    canvas.line(MARGIN, 1.45 * cm, PAGE_W - MARGIN, 1.45 * cm)
    canvas.setFont("Helvetica", 7.8)
    canvas.setFillColor(MUTED)
    canvas.drawString(MARGIN, 1.05 * cm, f"DevOps — Laporan {report_label}")
    canvas.drawRightString(PAGE_W - MARGIN, 1.05 * cm, f"Halaman {doc.page}")
    canvas.restoreState()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chapters-dir", type=Path, default=DEFAULT_CHAPTERS)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--output", type=Path, help="Path PDF gabungan (default: <output-dir>/3123640021_Andi.pdf)")
    parser.add_argument("--chapter", type=Path, metavar="FILE", help="Build satu laporan bab saja tanpa memerlukan file bab lainnya")
    parser.add_argument("--lecturer", help="Dosen pengampu yang telah diverifikasi")
    parser.add_argument("--group", help="Nama/nomor kelompok yang telah diverifikasi")
    parser.add_argument("--academic-year", help="Tahun akademik yang telah diverifikasi")
    return parser.parse_args()


def build_pdf(
    args: argparse.Namespace,
    chapter_files: list[tuple[str, str, Path, list]],
    output_path: Path,
    subtitle: str,
    report_label: str,
) -> None:
    story = cover(args, subtitle, report_label)
    for chapter_number, (_, _, _, flowables) in enumerate(chapter_files):
        if chapter_number:
            story.append(PageBreak())
        story.extend(flowables)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    document = BaseDocTemplate(
        str(output_path),
        pagesize=A4,
        title=f"Laporan Praktikum DevSecOps — {report_label}",
        author="Andi Rayka C (3123640021)",
        subject=f"Laporan resmi DevOps — {report_label}",
        creator="build_report.py (ReportLab)",
    )
    frame = Frame(
        MARGIN,
        FRAME_BOTTOM,
        USABLE_W,
        FRAME_H,
        id="main",
        leftPadding=0,
        rightPadding=0,
        topPadding=0,
        bottomPadding=0,
    )
    document.addPageTemplates(
        [PageTemplate(id="report", frames=[frame], onPage=lambda canvas, doc: draw_footer(canvas, doc, report_label))]
    )
    document.build(story)


def main() -> int:
    args = parse_args()
    if args.chapter:
        if args.output:
            raise SystemExit("--output hanya untuk PDF gabungan; gunakan --output-dir bersama --chapter.")
        chapter_file = args.chapter.expanduser()
        if not chapter_file.is_absolute() and not chapter_file.is_file():
            chapter_file = args.chapters_dir / chapter_file
        chapter_file = chapter_file.resolve()
        chapter_id = chapter_file.stem.casefold()
        chapter_labels = dict(CHAPTERS)
        if chapter_id not in chapter_labels or chapter_file.suffix.casefold() != ".md":
            raise SystemExit("--chapter harus menunjuk ke bab1.md sampai bab5.md.")
        if not chapter_file.is_file():
            raise SystemExit(f"Berkas bab tidak ditemukan: {chapter_file}")
        content = chapter_file.read_text(encoding="utf-8").strip()
        if not content:
            raise SystemExit(f"Berkas Markdown kosong: {chapter_file}; PDF tidak dibuat.")
        chapter_label = chapter_labels[chapter_id]
        report_label = f"DevSecOps {chapter_label}"
        output_path = args.output_dir / chapter_id / PDF_FILENAME
        flowables = markdown_to_flowables(chapter_file, content)
        build_pdf(args, [(chapter_id, chapter_label, chapter_file, flowables)], output_path, chapter_label, report_label)
        print(f"PDF {chapter_label}: {output_path}")
        return 0

    missing = [
        str(args.chapters_dir / f"{chapter_id}.md")
        for chapter_id, _ in CHAPTERS
        if not (args.chapters_dir / f"{chapter_id}.md").is_file()
    ]
    if missing:
        raise SystemExit("Berkas bab wajib belum tersedia; PDF tidak dibuat:\n- " + "\n- ".join(missing))

    chapter_sources: list[tuple[str, str, Path, str]] = []
    for chapter_id, chapter_label in CHAPTERS:
        chapter_file = args.chapters_dir / f"{chapter_id}.md"
        content = chapter_file.read_text(encoding="utf-8").strip()
        if not content:
            raise SystemExit(f"Berkas Markdown kosong: {chapter_file}; PDF tidak dibuat.")
        # Validate every source before writing outputs. ReportLab mutates flowables
        # during document.build(), so these instances must not be reused below.
        markdown_to_flowables(chapter_file, content)
        chapter_sources.append((chapter_id, chapter_label, chapter_file, content))

    for chapter_id, chapter_label, chapter_file, content in chapter_sources:
        output_path = args.output_dir / chapter_id / PDF_FILENAME
        report_label = f"DevSecOps {chapter_label}"
        flowables = markdown_to_flowables(chapter_file, content)
        build_pdf(args, [(chapter_id, chapter_label, chapter_file, flowables)], output_path, chapter_label, report_label)
        print(f"PDF {chapter_label}: {output_path}")

    combined_path = args.output or args.output_dir / PDF_FILENAME
    combined_label = "DevSecOps Bab 1–5"
    combined_chapters = [
        (chapter_id, chapter_label, chapter_file, markdown_to_flowables(chapter_file, content))
        for chapter_id, chapter_label, chapter_file, content in chapter_sources
    ]
    build_pdf(
        args,
        combined_chapters,
        combined_path,
        "Bab 1 · Bab 2 · Bab 3 · Bab 4 · Bab 5",
        combined_label,
    )
    print(f"PDF gabungan: {combined_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
