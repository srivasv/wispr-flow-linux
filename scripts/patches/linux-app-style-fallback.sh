#!/usr/bin/env bash
# Keep explicit My Voice app assignments; use Linux's app category when unassigned.
# shellcheck source=scripts/patches/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
patch_begin 'WISPR_LINUX_APP_STYLE_FALLBACK' "${1:-}" \
	'extract/app/.webpack/main/index.js'

if ! python3 - "$BUNDLE" <<'PY'; then
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_text()
modules = list(re.finditer(r'(?:^|,)(\d+)\([\w$]+,[\w$]+,[\w$]+\)\{', data))
candidates = []
for i, match in enumerate(modules):
    end = modules[i + 1].start() if i + 1 < len(modules) else len(data)
    body = data[match.start():end]
    if 'matchedVoiceType:' in body and '.personalizationStyleSettings=' in body:
        candidates.append((match.start(), end, body))
if len(candidates) != 1:
    sys.exit('ERROR: expected one My Voice style selector module')
start, end, body = candidates[0]
args = re.findall(r'\(\{voices:([\w$]+),appName:[\w$]+,bundleId:([\w$]+),url:([\w$]+)\}\)=>\{', body)
fallback = list(re.finditer(r'return\(([\w$]+)=>\1\.other\?\?\(0,[\w$]+\.IQ\)\(\)\.other\)\(\1\)', body))
selectors = set(re.findall(r'\(0,([\w$]+)\.A0\)\(\(0,([\w$]+)\.getAppType\)', body))
if len(args) != 1 or len(fallback) != 1 or len(selectors) != 1:
    sys.exit('ERROR: My Voice fallback shape changed')
voices, bundle, url = args[0]
if fallback[0].group(1) != voices:
    sys.exit('ERROR: My Voice fallback scope changed')
mapper, classifier = selectors.pop()
injection = ('if("linux"===process.platform){/*WISPR_LINUX_APP_STYLE_FALLBACK*/'
             f'const $wisprStyle=(0,{mapper}.A0)((0,{classifier}.getAppType)('
             f'{bundle},{url}),{bundle},{url});'
             f'if({voices}[$wisprStyle])return {voices}[$wisprStyle]' + '}')
pos = fallback[0].start()
path.write_text(data[:start] + body[:pos] + injection + body[pos:] + data[end:])
PY
	patch_restore
	exit 1
fi
patch_verify_marker
patch_finish 'Linux unassigned apps use their personalization category'
