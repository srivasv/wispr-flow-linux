# Wispr 1.6.1400 patch and platform audit (2026-11-07)

Wispr 1.6.1400 removes the fetch-link picker that blocked the nightly bump.

- Input: pristine Windows installer, SHA-256
  `5c72e904d45a5974dca0c48234a5f290a8201e858b5f8afed2716d17c29466b3`.
- Baseline: pristine pinned 1.6.1337 installer, SHA-256
  `4fc7fd44e58918b43d9d005d5ee121ee6588956a2c8e4b5aee001483f9686bf3`.
- Failing run: `srivasv/wispr-flow-linux/actions/runs/42349209524`.
  The patch-stage pre-check failed before committing or tagging; publication
  never started. Its issue reporter also failed because fork issues are disabled.

## Picker removal

Neither `ShowFetchLinkPicker`, `HideFetchLinkPicker`, nor `highlightUrl`
appears in any main or renderer JavaScript in 1.6.1400. The status renderer
has eight `window.screenX` reads instead of nine; contextMenu has four instead
of five. Both versions have 191 renderer JavaScript files.

The auto-polish, extension-menu and shortcut-join forwards remain, as do both
DidHide cursor replies. The patch therefore inserts five wrappers instead of
six. The fetch-link handler is optional only if neither fetch-link IPC name
remains anywhere in the main bundle. A present but moved, duplicated or
malformed handler still fails before mutation. Older bundles retain all six
wrappers. The unconditional fetch-link tripwire moves into that patch guard.

## Platform checks

Pristine main-bundle `process.platform` occurrences increase from 231 to 234.
Comparing beautified platform lines with minified locals normalized identifies
three added uses:

- A macOS arm64 extension gate. Linux returns false and does not load the
  mac-only extension path.
- A native capture window-ID helper returns an empty object outside macOS.
  Linux keeps that fallback.
- A telemetry object gains `platform: process.platform`, with no platform gate.

The `.tD` and `.H8` flag-reference counts remain 239 and 88. The status, hub
and contextMenu renderers each retain one `platform?.isWindows` bind and one
`platform?.isMacOS` bind. No additional Linux patch follows from these checks.

## Validation scope

`tests/test-patch-stage.sh` passes all 14 checks on both pristine versions:
tripwires, both patch passes, byte-identical second pass, backup exclusion,
repacking, JavaScript parsing, classifier behavior and patch markers. The
1.6.1400 repack parses all 212 JavaScript files under `.webpack/`.

Regression fixtures cover the removed picker, the existing picker and a
missing Show handler whose Hide channel remains. Workflow-script tests cover
issue-disabled forks and normal failure/recovery reporting.

This is a static bundle and patch-stage audit. Native package builds,
publication and interactive desktop behavior are not verified here. Merging
the fix re-arms the automatic nightly release and requires maintainer approval.
