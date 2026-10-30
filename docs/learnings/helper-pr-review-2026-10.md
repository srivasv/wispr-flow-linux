[< Back to learnings](index.md)

# October 2026 helper PR review

The fork adopts upstream helper PRs #9, #31 and #36 with integration fixes before
its next package rebuild.

| Upstream PR | Decision | Reason |
|---|---|---|
| [#9](https://github.com/wispr-flow-linux/helper/pull/9) | Import and fix | Terminal paste needs Ctrl+Shift+V. Tighten app matching, recognize GNOME desktop IDs, support X11 without an app provider, and validate overrides before changing the clipboard. |
| [#31](https://github.com/wispr-flow-linux/helper/pull/31) | Import and harden | Report corrected dictation through the existing UpdateEditedText IPC. Skip unknown/private roles and ambiguous spans; bound stalled calls and cancel superseded observations. |
| [#36](https://github.com/wispr-flow-linux/helper/pull/36) | Import | GNOME 42–44 cannot load the ESM bridge; disabling shell-wide extension validation there has no benefit. |
| [#10](https://github.com/wispr-flow-linux/helper/pull/10) | Defer | The PR predates removal of modifier release/restore. Its upstream review requests a rebase, exclusion of the helper's own device, and measured smaller delays. No GNOME timing calibration was available here. |
| [#15](https://github.com/wispr-flow-linux/helper/pull/15) | Defer | Optional key filtering addresses a specific left/right modifier preference; no such configuration is currently needed. |
| [#16](https://github.com/wispr-flow-linux/helper/pull/16), [#17](https://github.com/wispr-flow-linux/helper/pull/17), [#18](https://github.com/wispr-flow-linux/helper/pull/18), [#19](https://github.com/wispr-flow-linux/helper/pull/19), [#34](https://github.com/wispr-flow-linux/helper/pull/34) | Defer as a stack | #34 contains the earlier changes. Pinning/clipping identifies Status or Status\|… titles, while this package uses Flow Status Indicator and a different rectangle-report protocol. The stack needs a coordinated app/extension port and GNOME runtime validation. |

## Integration findings

PR #9 originally chose the shortcut only in `Composed::paste_text`. An X11
session without an available app provider returns the bare injector, bypassing
that path. Choose the target in the common request dispatcher instead. Match ambiguous names as whole app-name/desktop-ID components so Warpinator,
Footnotes and Hyperion remain ordinary applications. Retain substring matching
for distinctive names so variants such as gnome-terminal-server keep working.

PR #31 originally treated a failed role lookup as a non-password field, guessed
the last matching pasted string, and checked its duration cap only between
D-Bus calls. Recheck role/focus/editability before reading, reject ambiguous
spans, and wrap the observation in a cancellable wall-clock budget. A new paste
without an observation ID must still cancel the previous observation. Do not
report a superseded observation after a later paste may have changed its field.

The PasteText and UpdateEditedText payloads were checked against Wispr
1.6.1297 and documented in the IPC contract. Helper code remains clean-room;
no proprietary implementation was imported.

## Verification

- Unit regressions fail on the original terminal matching and observer guards.
- The helper's isolated `parity_test.py` drives real IPC and GTK fields under
  Xvfb and a private D-Bus session. It checks native X11 terminal and ordinary
  paste shortcuts, invalid-override clipboard preservation, and corrected
  Unicode text reported after focus loss.
- Native GNOME/Wayland timing, Qt, Chromium accessibility and actual dictionary
  persistence in the proprietary app remain unverified in this review.
