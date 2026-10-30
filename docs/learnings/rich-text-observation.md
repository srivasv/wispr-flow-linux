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

The shared snapshot reader is used only by post-paste correction observation.
Ordinary paste and selection behavior are unchanged. Each embedded object must
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

## Sources

- [AT-SPI Hypertext](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/iface.Hypertext.html): character-offset-to-link mapping.
- [AT-SPI Hyperlink](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/class.Hyperlink.html): embedded anchor objects.
- [Chromium Linux accessibility](https://github.com/chromium/chromium/blob/main/ui/accessibility/platform/ax_platform_node_auralinux.cc): lazy activation and Hypertext representation.
