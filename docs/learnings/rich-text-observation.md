# Rich-text correction observation

Chromium rich-text composers expose embedded objects that must be expanded
before matching dictated text for correction observation.

- ChatGPT and Slack reproduced the same structure on 2026-10-30.
- Helper `0.1.4-srivas.6` adds bounded Hypertext reading for these editors.
- ChatGPT correction forwarding was confirmed after installation; Slack needed
  the trailing-space baseline fix described below.

## The focused entry contains a placeholder

The ChatGPT composer returned one U+FFFC embedded-object character through
AT-SPI Text, so the old observer reported `pasted text not found in field`.
Slack exposed the same shape: the entry contained a placeholder, a child
paragraph contained 55 characters, and its static-text child duplicated those
characters. Concatenating descendants would duplicate the paragraph.

Hypertext.GetLinkIndex maps the placeholder offset to a Hyperlink whose
GetObject returns the paragraph. Reading that paragraph's Text preserves its
inline formatting text without reading duplicate static descendants. Adjacent
embedded paragraphs receive a newline boundary. Link URLs and accessible names
are never used as substitute text.

## Observation remains inside one editor

The shared snapshot reader supports correction observation, selection reads,
and dictation textbox context. Each embedded object must
have the same bus owner and be a direct child of the referring object; this
keeps every recursive text read inside the original focused editable root.
Only text-bearing roles are accepted. Passwords, independent nested editors,
attachments, defunct objects, cycles and malformed links are rejected before
reading their text.

Two consistent snapshots are required. Each pass is limited to 100,000 total
source characters, 256 objects and depth 16; both passes together have a
two-second deadline. Parent, role, text and link mappings are rechecked during
reads. The observer retries inconsistent snapshots briefly, discarding them;
three consecutive polling failures end observation. Replaced or defunct roots
are discarded. Existing cancellation, watch duration and 8,000-character report
limits remain in place.

Plain Text keeps caret-based matching. Expanded text uses a different offset
space, so it requires a unique exact occurrence of the dictated phrase.
Repeated phrases are deliberately skipped until reliable caret mapping exists.
Both baseline and edited snapshots use the same representation; before/after
anchors restrict the report to the dictated span. Formatting-only changes do
not create word corrections.

## Chromium accessibility can activate lazily

Standard GetAttributes queries on application/window objects activate
Chromium's renderer tree. Fallback discovery queries only this top-level
metadata before walking; it does not read surrounding conversations or change
screen-reader settings. The isolated browser fixture exercises this path
without a force-renderer-accessibility launch flag. Event-targeting cases
start with renderer accessibility enabled to test the other path independently.

The atspi-proxies 0.6 Hyperlink binding requests `Nanchors` as an i16, whereas
Chromium exposes `NAnchors` as an i32. Query that exact property directly while
retaining the existing proxy for other Hyperlink operations.

## Regression coverage

The helper's isolated Chromium matrix covers plain textarea, paragraphs,
bold/italic changes, formatting-only edits, Unicode/emoji, links, mentions,
surrounding anchors, editor replacement, duplicate phrases, images, nested
editors and passwords. Each runs with focus events and with fallback discovery.
No real user conversation is edited by these tests.

A private D-Bus fixture asserts rejected objects' Text methods are never read,
and tests foreign references, malformed links, cycles, changed text/focus/
parents, timeouts, character/depth/node limits and recreated paragraph objects.
GTK4, Qt Widgets, Qt Quick and the real-IPC paste/correction suite remain
regressions. Disabling embedded expansion makes the Chromium paragraph case
fail with `pasted text not found in field`.

## Slack omits a trailing space from the baseline

The 2026-10-30 Slack diagnostic test returned 36 accessible characters for a
37-character paste on all four baseline attempts. The pasted string had one
trailing whitespace character; trimming produced a unique exact match. No
snapshot read failed, and no correction request reached word extraction.

Helper `0.1.4-srivas.7` first attempts the existing exact match. Its fallback
allows only omitted trailing ASCII spaces when no caret is available, no full
exact occurrence exists, and the remaining nonblank phrase occurs uniquely at
the end of the field. It does not trim leading whitespace, normalize interior
text, remove newlines/tabs, or accept a partial trailing-space match. Anchors
use the actual observed character span rather than the longer paste length.
An unchanged observed span reports the original pasted string so presentation
alone does not appear to be a correction. Real corrections report the observed
edited text, retaining the original `pastedText` in the IPC payload.

Regression cases cover corrections, formatting-only changes, ambiguity and
omitted newlines in isolated Chromium with both discovery paths. Unit tests
also cover Unicode offsets, preserved anchors, conflicting carets and unsafe
whitespace variants. A live Slack dictionary retest remains necessary.

## Copilot Chat can exceed the fallback focus depth

On 2026-10-30, Copilot Chat's focused editable input appeared 43 levels below
its AT-SPI application root, or 42 below its window. The observer's cached
focus-event path reached it directly, but the fallback stopped at depth 40.
This made correction capture depend on whether a usable focus event had been
seen since the helper started. The timeout was not evidence that the editor
lacked accessibility support.

A live read-only probe also found an inactive ChatGPT field still marked
Focused. Sorting active windows first did not prioritize them sufficiently:
the round-robin walk could reach that shallow stale field before the deeper
active Copilot input. Search active windows to completion first, retaining
round-robin traversal within each group, then search unflagged windows for
GTK/Qt compatibility. Both groups share the same 6,000-node budget and the
existing eight-second outer deadline. Depth 64 reaches Copilot while retaining
a finite limit. No text-reading or private-field checks are relaxed.

The fixed fallback reached the same live Copilot object in 311 ms without a
cached focus event. A private D-Bus regression reproduces both old failures and
checks shared node/depth limits and unflagged-window fallback. A deeply nested
Chromium editor exercises correction capture with and without focus events.

## Focus discovery can time out below the depth limit

On 2026-11-01, VS Code's focused terminal was at depth 36, within the
64-level limit, but the helper's cold terminal probe exhausted its 800 ms
budget. Slack's selected message field was at depth 22; its cold selection
probe took 1.67 seconds, near the two-second limit. Raising the depth limit
would not address these round-trip costs.

Chromium exposes `org.a11y.atspi.Collection.GetMatches`. A window-scoped query
for both Focused and Editable found those same widgets in 3–5 ms. The helper
now tries this query within each active/inactive window group before walking
its trees. Each query has a 100 ms deadline, and returned state is rechecked.
Unsupported, empty, invalid or stalled queries retain the bounded tree
fallback. Terminal detection and selection share this observer lookup.

Transforms have a separate completion requirement: an ACK to `PasteText`
does not substitute for `PasteOutcome`. In Wispr 1.6.1337, missing outcomes
lead to the misleading "Textbox is not editable" notification after the
paste deadline. The helper must echo the paste ID and report clipboard/key
injection success or failure. This is not proof that the target inserted the
text. See the updated [IPC contract](../reference/ipc-contract.md).

## Resumed dictation needs fresh textbox context

Wispr 1.6.1337 resets `textboxContents` for every dictation. Its `TextBoxInfo`
handler supplies `beforeText`, `selectedText` and `afterText` to the formatter;
an ACK to `DictationStart` cannot fill those fields. The Linux helper previously
ACKed both `DictationStart` and `GetTextBoxInfo` as unimplemented commands,
leaving every segment without caret context. This is consistent with resumed
segments being formatted as new sentences, although live service formatting
still needs validation.

The helper now emits fresh `TextBoxInfo` on `DictationStart` and returns it as a
correlated response to `GetTextBoxInfo`. Reads run off the keyboard/IPC thread,
have a two-second budget and are discarded after a newer start. Reads may
finish after `DictationStop` while a short segment is still being processed.
Context is restricted to a focused editor under an active window;
inactive Chromium fields can retain Focused. Two matching snapshots preserve
Unicode character offsets, selection boundaries and surrounding whitespace.
Each surrounding range is capped at 500 characters to bound the IPC payload.

Passwords, terminals, inaccessible fields, selections over 500 characters and
ambiguous rich-text selections or carets report unavailable context. Do not
reuse the last pasted string or lowercase the next transcript:
the user may move the caret, edit the field, or switch applications between
segments.

## Rich-text caret offsets name embedded paragraphs

The 2026-11-03 comparison resumed correctly in Kate and VS Code but failed in
Slack. Length-only diagnostics showed `caret unavailable for editor`. This
was partly the reader's own policy: expanded snapshots deliberately set caret
to -1 for correction matching, and the new dictation-context path reused that
policy. Chromium does expose a usable caret through its embedded objects.

An isolated Chromium entry with two paragraphs returned root caret 1 while
the second paragraph returned caret 5. Root offset 1 names the paragraph's
U+FFFC placeholder, not the second character of the flattened text. Context
reads now translate that placeholder through the validated Hyperlink, add the
paragraph's caret offset to its expanded start, and include inserted paragraph
newlines. Nested embedded objects use the same mapping recursively. Static
descendants that duplicate paragraph text are still not read.

The mapping is enabled only for dictation context. Correction matching retains
its unique-paste rule. Missing, invalid or changing child carets fail closed;
two complete matching snapshots are still required. Expanded selections remain
unavailable because their endpoint offsets need separate mapping. Plain Text
selections are unchanged. Isolated D-Bus regressions cover caret positions,
Unicode, nested objects, invalid/changing offsets and selection rejection. A
real Chromium fd-3 IPC check verified beginning, middle and end context for a
two-paragraph Unicode editor. The live Slack retest supplied 42 characters
before the caret on resume, and the user confirmed correct continuation
without capitalization. Temporary length-only diagnostics were removed
before release.

## Sources

- [AT-SPI Hypertext](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/iface.Hypertext.html): character-offset-to-link mapping.
- [AT-SPI Hyperlink](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/class.Hyperlink.html): embedded anchor objects.
- [Chromium Linux accessibility](https://github.com/chromium/chromium/blob/main/ui/accessibility/platform/ax_platform_node_auralinux.cc): lazy activation and Hypertext representation.

## Google Docs context needs braille and the recording target

Chrome exposes an empty offscreen textbox when Google Docs braille support is
disabled. Screen reader support alone can expose a focused, non-editable group
with no text. Enable both settings in **Tools > Accessibility settings**.

With braille support enabled, Docs exposes its document as embedded-object
markers. The caret descends through tables, rows, cells and paragraphs. The
helper previously rejected those structural roles; accepting them while
walking the whole document then exceeded the two-second context deadline.
For the editor inside `docs-texteventtarget-iframe`, follow only the caret's
validated embedded-object chain into its current text block. Ordinary editor
context, selection reads and correction observation keep their existing paths.

The direct reader passing did not prove that dictation received context.
KWin's Chrome caption omitted the profile suffix present in the accessibility
window name, so exact title matching missed the editor. Allow that suffix
only for Chrome captions and still reject multiple matching windows. The
Flow `Status` window also briefly took focus at recording start; ignore that
specific KWin activation so it cannot replace the prior target. Scratchpad
activations remain valid. Dictation must use native window identity while
retaining its bounded selection policy separately from transform queries.

On 2026-11-13, a live insertion was lowercase and the saved server context
contained 102 characters before the caret and 16 after. Inspect
`History.additionalContext.textbox_contents`; `History.textboxContents` can
remain null even when the formatter received context. Verify the running
helper through `/proc/<pid>/exe`: replacing its installed file does not
replace a running process. Preserve Flow's existing display-backend arguments
when restarting; dropping `--ozone-platform=x11` can change Status placement.
