[< Back to learnings](index.md)

# Clipboard contents are not selected text

A copy probe must clear the clipboard before Ctrl+C to distinguish an absent
selection from stale clipboard text.

- Both helper backends fall back from AT-SPI to a clipboard-copy probe.
- With nothing selected, Ctrl+C often leaves the clipboard unchanged.
- Returning that text as `selectedText` and `contents` supplies unrelated
  clipboard data to command mode, including its search context.

Save the clipboard text, clear it, send Ctrl+C, read the result, then restore
what was saved. Attempt restoration even when copying or reading fails. Abort
before modifying a clipboard that cannot be read. Keep the existing copy delays
so the target application has time to answer.

Comparing the result with the saved clipboard is insufficient: a valid selection
can contain exactly the same text. Test both that case and an ignored Ctrl+C.
The shared workflow and regression tests live in the helper repository's
`src/backend/copy_probe.rs`; X11 and Wayland supply their clipboard operations
and copy chords. AT-SPI selection reads bypass this fallback.

The fallback still saves and restores plain text only. Rich clipboard formats
and applications that copy a whole line with no selection remain limitations of
this approach.

## Slack selection is an embedded-object marker

Slack's Chromium rich-text editor can return U+FFFC from AT-SPI `GetText`
for a selected paragraph instead of its words. On 2026-11-01, the failed
transform record contained exactly that one character and had status
`no_text`; the helper had successfully found the focused field and returned
its selection in five milliseconds. Neither focus depth nor paste completion
explained this failure.

Rejecting U+FFFC and relying on the copy fallback was insufficient: the live
Slack copy attempt returned empty text. The child paragraph exposed the actual
41-character selection, while its textbox parent exposed only `(0, 1)` around
the embedded-object marker.

Use the existing bounded Text/Hypertext reader in selection mode. Each visited
object supplies its own selection offsets; follow only links inside those
ranges, retaining the original offsets for link lookup. Never apply the root
range to flattened text or return the entire editor. Recheck selection ranges
and text after reading, and require two consistent snapshots. Unsupported or
ambiguous ranges still fall back to the copy probe.

The live reader returned the 41 selected characters without placeholders in
150 ms. Regressions cover partial Unicode selections, nonzero root offsets,
multiple paragraphs, invalid ranges, mid-read selection changes and avoiding
unselected paragraphs. Existing ownership, role, size, depth and timeout
checks are shared with full-editor observation.

## Google Docs word context uses paragraph selection offsets

A capitalized insertion after reloading Docs logged `selection offsets
unavailable for expanded editor` on 2026-11-13. Caret-only reload checks passed.
A highlighted word reproduced the rejection: the editor reported `(8, 9)`
around its paragraph marker, while that paragraph reported `(45, 52)` for
the actual seven-character word.

For Docs context, follow the single selected object on the caret path. Map
the paragraph's selection endpoints while expanding any preceding inline
objects; do not apply raw paragraph offsets to expanded text. Require each
ancestor to select exactly its current object marker and recheck every
selection and text snapshot. Reject selections spanning embedded objects
and retain the existing privacy and resource bounds.

The first fixture failed on the ancestor-marker guard; the live word check
then exposed a preceding inline marker missing from the fixture. Both shapes
now have regression coverage. The corrected live read returned context lengths
50 before, 7 selected and 121 after. Subsequent dictation with debug logging
off preserved the selected-word context and post-reload caret context; both
insertions were lowercase. This establishes the unsupported-selection cause,
not that every reload creates such a selection.

## Vivaldi highlights are document selections

A read-only HTML selection need not focus an AT-SPI Text object or mark it
editable. Vivaldi 8.3 exposed a selected file document 19 levels below its
window on 2026-11-09; the focused-widget fallback stopped at depth 12.

The document's Text interface returned an embedded-object marker with range
`(0, 1)`, while its paragraph reported an empty `(0, 0)` Text selection.
`Document.GetTextSelections` instead supplied the paragraph object and the
actual character range, `(7, 20)` for the 13-character test selection.
Requiring focused, editable Text fields or expanding their placeholder ranges
therefore missed this highlight and forced a synthetic Ctrl+C.

The helper now reuses the active-page finder from browser URL detection, then
reads the document's selection endpoints. This works for `file://` pages as
well as web URLs; site recognition still returns only its existing allowlist.
The selected object must belong to that page and application, the range must
be valid, and both the range and text must remain stable. Recheck active-window
state after reading. Full-page text is not returned.

Selections spanning different text objects, ambiguous ranges, and providers
without `GetTextSelections` retain the clipboard-copy fallback. The focused
Text path still runs first. A private D-Bus regression exercises a deep,
unfocused page, partial Unicode selection, inactive windows, invalid ranges
and endpoints outside the page. The live Wayland/Vivaldi check verifies two
exact helper IPC responses without reaching the copy fallback.

## Transform queries need the native window and the full highlight

Electron applications can retain AT-SPI `Focused` and `Active` flags after
losing desktop focus. Searching all applications can therefore return an old
textbox before reaching the actual target. On 2026-11-12, a read-only probe
chose an inactive Slack entry while the Claude extension input in VS Code
exposed a 4,461-character selection.

Bind explicit textbox and selection queries to the window title supplied by
the native active-app provider. Search only that window and reject ambiguous
matches. When native window identity is unavailable, retain the existing
accessibility fallback. Do not trust a cached focused object from a different
window.

The caret-context reader added on 2026-11-03 limits before/after context and
selected text to 500 characters to keep duplicate context fields beneath the
IPC size budget. This rejects a longer highlight rather than truncating it.
Explicit textbox queries must fall back to the existing bounded, stable
selection reader when caret context is unavailable. Dictation keeps its
500-character context window; transforms receive the full supported selection.
The helper's 30,000-byte serialized-message guard still applies.

A private D-Bus regression covers stale focus, an inactive accessibility
window selected by native identity, a long Unicode highlight and a missing
window. Both explicit read paths returned all 4,461 characters in the live
Claude input without a copy chord or a cloud transform request.
