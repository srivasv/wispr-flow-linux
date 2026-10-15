#!/usr/bin/env bash
# Include Linux in the Status renderer's visual-only surface reporting, and
# emit the initial empty report. Paired with linux-status-idle-unmap.sh.
# Reuses the existing rectangle collector; no pixel sampling or new IPC API.
set -uo pipefail

# shellcheck source=scripts/patches/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
patch_begin "WISPR_LINUX_STATUS_SURFACE_REPORT" "${1:-}"

if ! python3 - "$BUNDLE" "$MARKER" <<'PY'
import re
import sys
from pathlib import Path

path, marker = sys.argv[1:]
source = Path(path).read_text()
Q = r'[`"\']'
ID = r'[\w$]+'

def unique(pattern, text, label):
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1:
        sys.exit(f'ERROR: expected one {label}, found {len(matches)}')
    return matches[0]

unique(Q + 'flow-bar-hot-area' + Q, source, 'semantic flow-bar reporter')
anchor = unique(r'(?:const|let|var) ' + ID + '=' + Q + 'data-alpha-catch' + Q,
                source, 'Status rectangle collector')
openers = list(re.finditer(r'\d+\(' + ID + ',' + ID + ',' + ID + r'\)\{'
                          + Q + 'use strict' + Q + ';', source[:anchor.start()]))
if not openers:
    sys.exit('ERROR: cannot locate collector module opening')
start = openers[-1].start()
following = re.search(r'\},\d+\(' + ID + ',' + ID + ',' + ID + r'\)\{',
                      source[anchor.end():])
if not following:
    sys.exit('ERROR: cannot locate collector module end')
end = anchor.end() + following.start() + 1
collector = source[start:end]
shape = unique('(' + ID + ')=' + Q + 'data-status-window-shape' + Q,
               collector, 'visual surface attribute').group(1)
event = unique('(' + ID + ')=' + Q + 'status-window-shape-remeasure' + Q,
               collector, 'remeasure event').group(1)
gate = unique(r'(' + ID + r'\.' + ID + r')&&' + ID + r'\?\.hasAttribute\('
              + re.escape(shape) + r'\)', collector, 'visual surface platform gate').group(1)
if collector.count(gate) != 3:
    sys.exit('ERROR: expected three matching visual-surface platform reads')
# The resize callback both scans DOM and forces a report when geometry changes.
resize = unique(r'(' + ID + r')=\(\)=>\{(' + ID + r')\(\),(' + ID
                + r')\(\)\};window\.addEventListener\(' + Q + 'resize' + Q
                + r',\1\)', collector, 'resize report callback')
queue = resize.group(3)
initial = unique(r'document\.addEventListener\(' + re.escape(event) + ','
                 + ID + r',!0\),(' + ID + r')\(\),\(\)=>',
                 collector, 'initial surface scan')
# Force a report even if all maps start empty (nothing changed during scan).
collector = (collector[:initial.end()] .removesuffix('()=>') + queue + '(),()=>'
             + collector[initial.end():])
collector = collector.replace(gate, '(' + gate + '||"linux"===window.electron.platform.os)')
patched = source[:start] + '/*' + marker + '*/' + collector + source[end:]
Path(path).write_text(patched)
print('Patched Status visual surfaces and initial report for Linux')
PY
then
	patch_restore
	exit 1
fi
patch_verify_marker
patch_expect_shape -qF '||"linux"===window.electron.platform.os)' \
	-- 'Linux surface-report gate missing'
patch_finish "Status renderer reports Linux visible surfaces in $BUNDLE"
