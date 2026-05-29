#!/usr/bin/env python3
"""
Build a tiny recovery zip that re-imports the Portfolio + the 99 child rows
*without* file blobs. Used when the file content is already on the tenant
(or when the children were imported once but the parent failed) - Bulkrax
matches existing records by source_identifier and updates them in place,
re-running the parent-child relationship wiring against an existing Portfolio.

Output: /tmp/enact_import/enact_mclean_portfolio_only.zip (~30 KB)
"""

import csv
import shutil
import zipfile
from pathlib import Path

STAGE = Path('/tmp/enact_import/import_stage')
MINI_DIR = Path('/tmp/enact_import/portfolio_only_stage')
MINI_ZIP = Path('/tmp/enact_import/enact_mclean_portfolio_only.zip')

MINI_DIR.mkdir(parents=True, exist_ok=True)
if (MINI_DIR / 'files').exists():
    shutil.rmtree(MINI_DIR / 'files')
(MINI_DIR / 'files').mkdir()

with open(STAGE / 'manifest.csv', newline='') as f:
    reader = csv.DictReader(f)
    fields = reader.fieldnames
    rows = list(reader)

# Clear the `file` column so the existing FileSets on the tenant aren't
# touched. Keep `parents=mclean-portfolio` on items so Bulkrax re-runs the
# relationship wiring.
for r in rows:
    r['file'] = ''

out_csv = MINI_DIR / 'manifest.csv'
with open(out_csv, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    for r in rows:
        w.writerow(r)

if MINI_ZIP.exists():
    MINI_ZIP.unlink()
with zipfile.ZipFile(MINI_ZIP, 'w', zipfile.ZIP_DEFLATED) as z:
    z.write(out_csv, arcname='manifest.csv')

print(f'rows: {len(rows)} (1 Portfolio + {len(rows) - 1} items, no files)')
print(f'Output: {MINI_ZIP} ({MINI_ZIP.stat().st_size / 1024:.1f} KB)')
