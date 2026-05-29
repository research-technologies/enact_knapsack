#!/usr/bin/env python3
"""
Convert the McLean Enact Pathfinders Word template + the OneDrive zip of
source files into a Bulkrax-importable zip:

  enact_mclean_bulkrax.zip
    manifest.csv         # one row per record (1 Portfolio + N PortfolioItems)
    files/<filename>     # each file referenced by a PortfolioItem row

Run from anywhere; all input/output paths are absolute.
"""

from __future__ import annotations

import csv
import os
import re
import shutil
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

DRIVE = Path('/Users/shana/Library/CloudStorage/GoogleDrive-shana@notch8.com/Shared drives/04 - Engineering/PRI Enact/Sample Data')
DOCX = DRIVE / 'McLean_Enact Pathfinders template FINAL.docx'
SRC_ZIP = DRIVE / 'OneDrive_2026-05-29.zip'

WORK_DIR = Path('/tmp/enact_import')
EXTRACT_DIR = WORK_DIR / 'src_files'
STAGE_DIR = WORK_DIR / 'import_stage'
FILES_DIR = STAGE_DIR / 'files'
CSV_PATH = STAGE_DIR / 'manifest.csv'
OUTPUT_ZIP = WORK_DIR / 'enact_mclean_bulkrax.zip'

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

# Map the depositor-supplied "What is this?" values to (portfolio_item_type, item_subtype)
# using our PR Voices controlled vocabs (config/authorities/*_type.yml).
SUBTYPE_MAP = {
    'model / drawing photograph':   ('Artefact',   'documentation'),
    'design proposal document':     ('Artefact',   'design'),
    'report':                       ('Literature', 'monograph'),
    'magazine article':             ('Literature', 'article'),
    'presentation':                 ('Event',      'lecture'),
    'video':                        ('Artefact',   'documentation'),
    'exhibition review':            ('Literature', 'review'),
    'poster':                       ('Artefact',   'documentation'),
    'steel sculpture':              ('Artefact',   'installation'),
    'photograph':                   ('Artefact',   'documentation'),
    'photo documentation':          ('Artefact',   'documentation'),
    'press cutting':                ('Literature', 'review'),
    'invitation card':              ('Artefact',   'documentation'),
    'sculpture':                    ('Artefact',   'installation'),
    'drawing':                      ('Artefact',   'documentation'),
}


def cell_lines(cell) -> list[str]:
    """Return non-empty paragraph-level lines from a Word table cell."""
    out = []
    for p in cell.findall('w:p', NS):
        text = ''.join(t.text or '' for t in p.findall('.//w:t', NS))
        text = text.strip()
        if text:
            out.append(text)
    return out


def first_or_none(lines: list[str]) -> str | None:
    return lines[0] if lines else None


def joined(lines: list[str], sep: str = ' ') -> str:
    return sep.join(lines)


def parse_date(raw_lines: list[str]) -> str:
    """
    Date cells are messy: '1998', 'Sept 2007', 'October 1998', '12th Nov, 2024',
    '26th January 2000', '11th Jan\\n2001', etc. Best-effort: find a 4-digit year
    and use that. ISO-clean is out of scope.
    """
    joined_text = ' '.join(raw_lines)
    m = re.search(r'\b(19|20)\d{2}\b', joined_text)
    return m.group(0) if m else joined_text.strip()


def classify(subtype_raw: str | None) -> tuple[str, str]:
    if not subtype_raw:
        return ('Artefact', 'documentation')
    key = subtype_raw.strip().lower()
    if key in SUBTYPE_MAP:
        return SUBTYPE_MAP[key]
    # fall through: look for keywords
    for k, v in SUBTYPE_MAP.items():
        if k in key:
            return v
    return ('Artefact', 'documentation')


def is_section_divider(cells_lines: list[list[str]]) -> bool:
    """A divider row has a title-cell value but file-cell is empty AND most others empty."""
    title = first_or_none(cells_lines[0])
    file_name = first_or_none(cells_lines[1])
    if not title:
        return False
    if file_name:
        return False
    # Section labels are short, all-caps-ish, like '01 Primary Space Documents'
    # Tolerate up to a few populated cells (some divider rows have stray cells).
    populated = sum(1 for c in cells_lines[1:] if c)
    return populated <= 1


def safe_slug(s: str, n: int = 40) -> str:
    s = re.sub(r'[^a-zA-Z0-9_-]+', '-', s.strip().lower())
    s = re.sub(r'-+', '-', s).strip('-')
    return s[:n] or 'item'


def extract_records():
    tree = ET.parse(WORK_DIR / 'template_xml' / 'word' / 'document.xml')
    root = tree.getroot()
    tables = root.findall('.//w:tbl', NS)
    if len(tables) < 3:
        sys.exit('Expected at least 3 tables in template docx')

    # --- Portfolio header (Table 0) ---
    project_table = tables[0]
    project_rows = project_table.findall('w:tr', NS)
    project_cells = [cell_lines(c) for c in project_rows[1].findall('w:tc', NS)]
    portfolio_title = first_or_none(project_cells[0]) or 'Primary Space'
    portfolio_description = joined(project_cells[1], '\n') if project_cells[1] else ''
    portfolio_additional = joined(project_cells[2], '\n') if len(project_cells) > 2 and project_cells[2] else ''

    # Pull additional context (URLs / funding) from Table 1.
    ctx_table = tables[1]
    ctx_rows = ctx_table.findall('w:tr', NS)
    related_urls = []
    related_credits = []
    for r in ctx_rows[1:]:
        cells = [cell_lines(c) for c in r.findall('w:tc', NS)]
        if not any(cells):
            continue
        name = first_or_none(cells[0]) if cells else None
        url = first_or_none(cells[1]) if len(cells) > 1 else None
        note = first_or_none(cells[2]) if len(cells) > 2 else None
        if name or url:
            related_credits.append(name or '')
            if url:
                related_urls.append(url)

    # --- Items (Table 2) ---
    items_table = tables[2]
    item_rows = items_table.findall('w:tr', NS)
    records: list[dict] = []
    current_section = None
    item_counter = 0
    for row in item_rows[1:]:  # skip header row
        cells = [cell_lines(c) for c in row.findall('w:tc', NS)]
        if not cells or not any(cells):
            continue
        if is_section_divider(cells):
            current_section = first_or_none(cells[0])
            continue
        item_counter += 1
        idx = item_counter
        title = first_or_none(cells[0])
        file_name = first_or_none(cells[1])
        if not title and not file_name:
            continue

        item_type_raw = first_or_none(cells[3])
        portfolio_item_type, item_subtype = classify(item_type_raw)
        date_raw = cells[4] if len(cells) > 4 else []
        contributors = cells[5] if len(cells) > 5 else []
        description = ' '.join(cells[6]) if len(cells) > 6 else ''
        location = first_or_none(cells[7] if len(cells) > 7 else [])
        keywords = cells[8] if len(cells) > 8 else []
        rights_lines = cells[9] if len(cells) > 9 else []
        url = first_or_none(cells[10] if len(cells) > 10 else [])
        public = (first_or_none(cells[11] if len(cells) > 11 else []) or '').lower()
        additional = ' '.join(cells[12] if len(cells) > 12 else [])

        # Concatenate the multi-line title cell (some rows split the title across
        # paragraphs - e.g. "Dalry Primary  An Innovative" / "Scottish Case Study").
        full_title = ' '.join(cells[0])

        # Visibility: 'Y' -> open, anything else -> private (per the template prompt).
        visibility = 'open' if public.startswith('y') else 'restricted'

        # Combine contributor names + the rights/credits cell (which in this
        # dataset is almost always the same names again) into a single free-text
        # rights_holder list. Both columns describe the people behind the work;
        # the compound `contributors` mapping is Phase 2.
        # Bulkrax's default `rights_statement` mapping CV-validates the value
        # against rightsstatements.org, so free-text names there break the
        # import. `rights_holder` is the free-text equivalent.
        credits = list(dict.fromkeys([c for c in contributors + rights_lines if c]))

        record = {
            'source_identifier': f'mclean-item-{idx:03d}',
            'model': 'PortfolioItem',
            'parents': 'mclean-portfolio',
            'title': full_title,
            'description': description,
            'portfolio_item_type': portfolio_item_type,
            'item_subtype': item_subtype,
            'date_created': parse_date(date_raw),
            'keyword': '|'.join(k for k in keywords if k),
            'rights_holder': '|'.join(credits),
            'file_access_level': 'open' if visibility == 'open' else 'restricted',
            'visibility': visibility,
            'file': file_name or '',
            'based_near': location or '',
            'related_url': url or '',
            'section_label': current_section or '',
            'additional_information': additional,
            'media_type': item_type_raw or '',
        }
        records.append(record)

    portfolio_record = {
        'source_identifier': 'mclean-portfolio',
        'model': 'Portfolio',
        'parents': '',
        'title': portfolio_title,
        'description': portfolio_description,
        'date_range_of_outputs': '1997 / 2008',
        'publisher': '|'.join(related_credits[:3]) if related_credits else '',
        'keyword': 'practice-research|architecture|education|public art',
        # rights_statement on Portfolio is the PR Voices metadata-rights string
        # (free text in our schema). Hyrax's default `rights_statement` field is
        # CV-validated, so we don't import it here - the depositor can fill the
        # Portfolio's metadata rights via the form after import lands.
        'rights_holder': 'University of Westminster',
        'file_access_level': 'open',
        'visibility': 'open',
        'related_url': '|'.join(related_urls),
    }

    return portfolio_record, records


def find_source_files(filenames: set[str]) -> dict[str, str]:
    """
    Map each requested basename to a member path inside the OneDrive zip.

    Will's docx has a handful of typos / case mismatches against the actual
    filenames in the zip (e.g. `MG_3657.JPG` vs `IMG_3657.JPG`, `Planets.jpg`
    vs `planets.jpg`, `alry-...` vs `dalry-...`). Match case-insensitive, then
    try a small set of near-matches as a fallback.
    """
    by_lower: dict[str, str] = {}   # lowercase basename -> first matching member
    with zipfile.ZipFile(SRC_ZIP) as z:
        for member in z.namelist():
            if member.endswith('/'):
                continue
            base_lower = os.path.basename(member).lower()
            by_lower.setdefault(base_lower, member)

    mapping: dict[str, str] = {}
    for fn in filenames:
        if not fn:
            continue
        m = by_lower.get(fn.lower())
        if not m:
            # Try common typo: missing first character ('alry-...' -> 'dalry-...',
            # 'MG_3657' -> 'IMG_3657').
            for prefix in ('d', 'i'):
                cand = (prefix + fn).lower()
                if cand in by_lower:
                    m = by_lower[cand]
                    break
        if m:
            mapping[fn] = m
    return mapping


def build():
    print(f'> Reading docx: {DOCX}')
    portfolio, items = extract_records()
    print(f'  Portfolio: {portfolio["title"]}')
    print(f'  Items:     {len(items)}')

    print(f'> Locating files inside source zip: {SRC_ZIP}')
    requested = {r['file'] for r in items if r['file']}
    found = find_source_files(requested)
    missing = sorted(requested - set(found))
    print(f'  Requested: {len(requested)}   Found: {len(found)}   Missing: {len(missing)}')
    if missing:
        print('  Missing filenames (recorded in CSV but with no attached file):')
        for m in missing[:10]:
            print(f'    - {m}')
        if len(missing) > 10:
            print(f'    ... and {len(missing) - 10} more')

    print(f'> Staging into: {STAGE_DIR}')
    if STAGE_DIR.exists():
        shutil.rmtree(STAGE_DIR)
    FILES_DIR.mkdir(parents=True)

    with zipfile.ZipFile(SRC_ZIP) as z:
        for base, member in found.items():
            target = FILES_DIR / base
            with z.open(member) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)

    fields = [
        'source_identifier', 'model', 'parents', 'title', 'description',
        'portfolio_item_type', 'item_subtype',
        'date_created', 'date_range_of_outputs', 'publisher', 'keyword',
        'rights_holder', 'file_access_level', 'visibility', 'file',
        'based_near', 'related_url', 'section_label',
        'additional_information', 'media_type'
    ]

    with open(CSV_PATH, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        w.writeheader()
        w.writerow(portfolio)
        for r in items:
            # Drop file column for items whose file wasn't found in the source zip;
            # the metadata still imports, the depositor can attach a file later.
            if r['file'] and r['file'] not in found:
                r = dict(r, file='')
            w.writerow(r)

    print(f'> CSV written: {CSV_PATH}')

    if OUTPUT_ZIP.exists():
        OUTPUT_ZIP.unlink()
    print(f'> Building output zip: {OUTPUT_ZIP}')
    with zipfile.ZipFile(OUTPUT_ZIP, 'w', zipfile.ZIP_DEFLATED, allowZip64=True) as z:
        z.write(CSV_PATH, arcname='manifest.csv')
        for p in sorted(FILES_DIR.iterdir()):
            z.write(p, arcname=f'files/{p.name}')

    size_mb = OUTPUT_ZIP.stat().st_size / (1024 * 1024)
    print(f'> Done. {OUTPUT_ZIP} ({size_mb:.1f} MB)')


if __name__ == '__main__':
    build()
