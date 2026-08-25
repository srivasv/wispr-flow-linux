#!/usr/bin/env bash
# Make the Status window use its renderer-reported shape on Linux X11.
#
# Wispr 1.6.606 already reports bounded interactive and visual rectangles and
# applies them with BrowserWindow.setShape() on Windows. Linux instead relies
# only on whole-window alpha polling. On X11 that can leave the transparent
# 480x570 Status window with a full ShapeInput region, blocking apps below it.
# Reuse the shipped shape manager on X11 without changing any global platform
# flags or the native-Wayland path.

set -u -o pipefail

BUNDLE="${1:-}"
if [[ -z "$BUNDLE" ]]; then
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	BUNDLE="$(cd "$script_dir/../.." && pwd)"
	BUNDLE="$BUNDLE/extract/app/.webpack/main/index.js"
fi

if [[ ! -f "$BUNDLE" ]]; then
	echo "ERROR: bundle not found: $BUNDLE" >&2
	exit 1
fi

readonly LINUX_MARKER='WISPR_LINUX_X11_STATUS_SHAPE'
if grep -q "$LINUX_MARKER" "$BUNDLE"; then
	echo "Already patched ($LINUX_MARKER present in $BUNDLE) - nothing to do."
	exit 0
fi

if [[ ! -f "$BUNDLE.orig" ]]; then
	cp -p "$BUNDLE" "$BUNDLE.orig" || exit 1
	echo "Backup written: $BUNDLE.orig"
fi

if ! python3 - "$BUNDLE" "$LINUX_MARKER" <<'PY'
import io
import re
import sys

path, marker = sys.argv[1], sys.argv[2]
with io.open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
    data = f.read()

x11 = (
    f'/*{marker}*/"linux"===process.platform'
    '&&!!process.env.DISPLAY&&!process.env.WAYLAND_DISPLAY'
)

# Status creation: use the shipped shape manager on Windows or Linux X11.
create = re.compile(
    r'(?P<flag>[\w$]+\.H8)\?'
    r'(?P<manager>[\w$]+)\.replaceWindow\((?P<window>[\w$]+)\):'
    r'(?P=window)\.setIgnoreMouseEvents\(!0,\{forward:!0\}\)'
)
create_matches = list(create.finditer(data))

# Validated ReportAlphaCatchRects handler: feed reports to that same manager.
report = re.compile(
    r'if\((?P<flag>[\w$]+\.H8)\)\{if\(!'
    r'(?P<manager>[\w$]+)\.applyReport\('
    r'(?P<sender>[\w$]+),(?P<report>[\w$]+)\)\)return;'
    r'\(0,(?P<utils>[\w$]+)\.cr\)\('
    r'(?P<window>[\w$]+),(?P=report)\.shapeRects\)\}'
)
report_matches = list(report.finditer(data))

# An empty set means "rectangular" to Electron. Once X11 shaping is enabled,
# use Wispr's existing off-surface sentinel instead so a hidden bar cannot
# become a full-window input blocker between renderer reports.
empty = re.compile(
    r'this\.enabled\?this\.applyShape\(this\.latestRects\)'
    r':this\.applyShape\(this\.everEnabled\?'
    r'(?P<sentinel>[\w$]+):\[\]\)'
)
empty_matches = list(empty.finditer(data))

counts = {
    "status creation": len(create_matches),
    "rectangle report": len(report_matches),
    "empty-shape fallback": len(empty_matches),
}
bad = [f"{name}={count}" for name, count in counts.items() if count != 1]
if bad:
    sys.exit(
        "ERROR: expected exactly one X11 Status shape site for each anchor; "
        + ", ".join(bad)
        + ". Re-audit the StatusInputShape and ReportAlphaCatchRects code."
    )

def patch_create(match):
    flag = match.group("flag")
    manager = match.group("manager")
    window = match.group("window")
    return (
        f'({flag}||({x11}))?'
        f'({manager}.replaceWindow({window}),'
        f'({x11})&&{manager}.setEnabled(!0)):'
        f'{window}.setIgnoreMouseEvents(!0,{{forward:!0}})'
    )

def patch_report(match):
    flag = match.group("flag")
    manager = match.group("manager")
    sender = match.group("sender")
    value = match.group("report")
    utils = match.group("utils")
    window = match.group("window")
    return (
        f'if({flag}||({x11})){{'
        f'if(!{manager}.applyReport({sender},{value}))return;'
        f'(0,{utils}.cr)({window},{value}.shapeRects)}}'
    )

def patch_empty(match):
    sentinel = match.group("sentinel")
    return (
        'this.enabled?this.applyShape('
        f'this.latestRects.length||!({x11})?this.latestRects:{sentinel})'
        f':this.applyShape(this.everEnabled?{sentinel}:[])'
    )

data = create.sub(patch_create, data, count=1)
data = report.sub(patch_report, data, count=1)
data = empty.sub(patch_empty, data, count=1)

with io.open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
    f.write(data)
print("Patched: enabled renderer-reported Status window shapes on Linux X11.")
PY
then
	cp -p "$BUNDLE.orig" "$BUNDLE"
	exit 1
fi

if [[ $(grep -o "$LINUX_MARKER" "$BUNDLE" | wc -l) -ne 4 ]]; then
	echo "ERROR: expected four $LINUX_MARKER markers. Restoring backup." >&2
	cp -p "$BUNDLE.orig" "$BUNDLE"
	exit 1
fi

if command -v node >/dev/null && ! node --check "$BUNDLE"; then
	echo 'ERROR: node --check failed. Restoring backup.' >&2
	cp -p "$BUNDLE.orig" "$BUNDLE"
	exit 1
fi

echo "OK: Linux X11 Status input shaping applied in $BUNDLE"
