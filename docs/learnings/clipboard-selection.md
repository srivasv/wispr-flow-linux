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
