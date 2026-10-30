# Rich-text correction observation

Chromium rich-text composers expose embedded objects that must be expanded
before matching dictated text for correction observation.

- ChatGPT and Slack reproduced the same structure on 2026-10-30.
- Helper `0.1.4-srivas.6` adds bounded Hypertext reading for these editors.
- Real application dictionary acceptance still needs a post-install retest.

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

## Sources

- [AT-SPI Hypertext](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/iface.Hypertext.html): character-offset-to-link mapping.
- [AT-SPI Hyperlink](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/class.Hyperlink.html): embedded anchor objects.
- [Chromium Linux accessibility](https://github.com/chromium/chromium/blob/main/ui/accessibility/platform/ax_platform_node_auralinux.cc): lazy activation and Hypertext representation.
