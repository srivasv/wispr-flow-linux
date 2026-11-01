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
