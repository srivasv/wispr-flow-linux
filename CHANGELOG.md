# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Semantic versioning applies to the wrapper (`REPO_VERSION`); the bundled Wispr
Flow app version is tracked separately by the `+wispr{X.Y.Z}` suffix.

## [Unreleased]

## [v1.0.19] - 2026-10-30

### Fixed

- Use Ctrl+Shift+V in focused embedded terminals such as VS Code without
  changing ordinary editor paste shortcuts, via helper `v0.1.4-srivas.10`.
- Read selected text from deeply nested editors such as Codex and call the
  AT-SPI selection method with its correct wire spelling.

## [v1.0.18] - 2026-10-30

### Fixed

- Use the detected category for unassigned Linux My Voice apps while preserving
  explicit assignments. Normalize Linux app identifiers and detect Gmail,
  Slack, LinkedIn, WhatsApp, and Telegram browser URLs via helper
  `v0.1.4-srivas.9`, with Other as the fallback.

## [v1.0.17] - 2026-10-30

### Fixed

- Find deeply nested Copilot Chat inputs without relying on a cached focus event,
  and prioritize active windows over stale focus in inactive apps, via helper
  `v0.1.4-srivas.8`. Keep bounded discovery and GTK/Qt fallback support.

## [v1.0.16] - 2026-10-30

### Fixed

- Observe corrections when a rich-text editor omits the dictated text's trailing
  spaces, via helper `v0.1.4-srivas.7`. Require a unique field-ending match and
  preserve the existing caret, privacy and ambiguity checks.

## [v1.0.15] - 2026-10-30

### Fixed

- Observe corrections in supported Chromium rich-text editors through bounded
  AT-SPI Hypertext expansion, via helper `v0.1.4-srivas.6`. Skip ambiguous or
  unsafe fields while retaining plain GTK and Qt field support.

## [v1.0.14] - 2026-10-30

### Fixed

- Track GTK and Qt field-focus events independently of the compositor app
  provider and prevent large desktop trees from starving correction discovery,
  via helper `v0.1.4-srivas.5`.

## [v1.0.13] - 2026-10-30

### Fixed

- Skip focused, non-editable desktop widgets when finding the dictation field
  for correction observation, via helper `v0.1.4-srivas.4`.

## [v1.0.12] - 2026-10-29

### Fixed

- Observe corrected dictation in GTK4 dialogs that expose a focused text field
  without an active parent, via helper `v0.1.4-srivas.3`.

## [v1.0.11] - 2026-10-29

### Added

- Terminal-aware paste shortcuts and post-paste correction reporting through
  the helper's AT-SPI observer.

### Fixed

- Command-mode copy probes no longer return stale clipboard contents when
  nothing is selected, via helper `v0.1.4-srivas.2`.
- Avoid a shell-wide extension-validation override on GNOME 42–44, where the
  bundled ESM extension cannot load.

### Changed

- Consume independently published helper binaries and Nix sources from
  `srivasv/helper`.

## [v1.0.10] - 2026-10-29

### Added

- Upstream XDG autostart and data-directory support, helper v0.1.3, native
  module pins, and installer checksum pinning.
- Scripted push-to-talk coverage from upstream #142's test-only commit.

### Fixed

- Reconcile upstream #148's X11 shape lifecycle with Wispr 1.6.1297,
  retaining the older handler and validated viewport fallback.
- Import #132 idle visibility, #73 visibility watchdog, #145 dictation audio,
  and #129 protocol registration fixes.
- Abort launch on profile migration conflicts; preserve the original MIME
  configuration if its atomic replacement fails.
- Failed patches restore their immediate input, preserving earlier patches.
- AppImage update metadata follows the repository that builds the release.

### Changed

- Reconcile upstream packaging and CI while retaining fork APT hosting,
  required launch checks, and disabled DNF/AUR publishing.


## [v1.0.9] - 2026-10-26

### Fixed

- Wispr Flow 1.6.1264 package builds accept the async Applications-folder
  guard, added Hub web preferences, and comma-sequence deep-link guard.
  Adapted from upstream PR #136 (fixing upstream issue #135), with regression
  coverage for old and new bundle shapes.

## [v1.0.8] - 2026-10-20

### Fixed

- AppImage validation inspects stored directory permissions with `unsquashfs`
  instead of the runtime extractor, which creates private `0700` directories
  even when the image correctly stores `0755` modes.

## [v1.0.7] - 2026-10-20

### Fixed

- Same-repository pull requests in a fork no longer get closed by the
  maintainer-edits check, which now compares source and destination repositories.
- Package builds support upstream's extracted helper-path and environment
  functions and the meeting window's added frame property. Linux patches
  retain their unique-anchor and shipped-marker checks, with regression
  coverage for both the original inline and newer function forms.

## [v1.0.6] - 2026-08-24

### Fixed

- On X11 the transparent portion of the 480x570 Status window could retain a
  full input region and block clicks to applications beneath it. Linux X11 now
  applies Wispr's renderer-reported Flow Bar rectangles through Electron's
  native window shaping, while hidden bars retain an off-surface sentinel
  instead of reverting to a full rectangle. Visible controls and native
  Wayland behavior are unchanged. (#41)
- Installer discovery now reads Wispr's official Windows release manifest
  instead of parsing the redirected bootstrapper filename, and verifies the
  published SHA-256 before packaging. Release CI now requires the `.deb` to
  install and reach the Linux helper-ready state instead of silently degrading
  to inspection-only coverage.

## [v1.0.5] - 2026-07-22

### Added

- A signed APT repository at `pkg.grimwulf.dev` for Debian and Ubuntu users.

## [v1.0.4] - 2026-07-22

### Fixed

- On X11 the Hub window opened as an unmanaged (override-redirect) window:
  pinned above every other window, missing from Alt+Tab, and impossible to
  move, minimize, or maximize. Upstream creates the window with `focusable:!1`
  on every platform and only macOS restores focus later, so Linux inherited
  Electron's override-redirect treatment of non-focusable windows. The new
  `linux-hub-focusable.sh` patch rewrites the Hub config so `focusable` is
  true on Linux only, leaving the shipped macOS and Windows behavior
  untouched. (#36)

## [v1.0.3] - 2026-06-11

### Fixed

- `wispr-flow --doctor` reported `Helper binary: present and executable` (and
  an overall pass) for a helper that aborted on startup, because the check
  only stat-ed the file. The doctor now execs the binary (`--version` probe
  with stdin at EOF, 5s timeout, fd 3 discarded) and surfaces the captured
  stderr — e.g. the loader's `GLIBC_2.39 not found` — on failure. (#16)
- Local builds failed at packaging with `Linux helper not staged` because the
  prebuilt helper was only fetched in CI; staging now auto-fetches the release
  pinned in `helper-version.txt` when `HELPER_BIN` is unset. An explicit
  `HELPER_BIN` (e.g. a local helper build) is still honored and never fetched
  over. (#15)
- `build.sh` emitted `readonly variable` errors when dispatching staging:
  `APP_VERSION`/`ELECTRON_VERSION` are readonly, so the command-prefix env
  assignments were rejected and `build-linux.sh` silently fell back to its own
  defaults. The version constants are now exported instead. (#15)
- A previously fetched helper in `helper-bin/` was reused forever, so bumping
  `helper-version.txt` silently kept shipping the stale binary in local builds.
  `fetch-helper-bin.sh` now stamps the fetched tag (`helper-bin/.tag`) and
  staging refetches when the stamp disagrees with the pin. A manual pre-drop
  (no stamp) and an explicit `HELPER_BIN` are still used as-is.

### Changed

- Helper pin bumped to `v0.1.2`: the helper now supports a `--version` flag,
  the launch probe `wispr-flow --doctor` uses to catch binaries that abort on
  startup (wispr-flow-linux/helper#3, groundwork for #16).
- Helper pin bumped to `v0.1.1`: the helper binaries are now built on Ubuntu
  22.04 (glibc 2.35 floor), so they no longer abort on startup with
  `GLIBC_2.39 not found` on Ubuntu 22.04-era distros (wispr-flow-linux/helper#1).
- The prebuilt native sqlite addons now build and release from their own repo
  (`wispr-flow-linux/native-modules`) instead of this one, mirroring the helper —
  so these CI-consumed artifacts no longer inflate the main project's Release
  download counts. `fetch-native-bin.sh` pulls from the new repo (pin unchanged
  in `native-modules-version.txt`); the local from-source rebuild is now opt-in
  via `WISPR_NATIVE_REBUILD=1` (was an automatic fallback) and never runs by
  default or in CI.
- `build.sh` now downloads the Wispr Flow installer from Wispr's official
  endpoint by default (resolving it via `resolve-installer-url.sh`, the same path
  CI uses), so `--exe` is no longer required. Pass `--exe <path>` to build
  against a local installer instead. The auto-download verifies the resolved
  version matches the pinned `APP_VERSION` and aborts on a mismatch.

## [v1.0.2] - 2026-06-07

### Fixed

- Package shipped `resources/` and its subdirectories as `0700` root-only, so a
  non-root user couldn't traverse them to reach `app.asar` or the helper and the
  app crashed on launch. All three makers now force directories to `0755` after
  staging; artifact tests assert `resources/` is other-traversable. (Regression
  from the `%defattr(-, root, root, -)` change in v1.0.1.)

## [v1.0.1] - 2026-06-07

### Added

- End-user install documentation: `docs/installation.md` plus a README
  Installation section (APT, DNF, AUR, AppImage, manual).
- AppImage auto-update metadata: CI embeds `gh-releases-zsync` update info and
  emits a companion `.AppImage.zsync`.
- `wispr-flow --doctor` install-integrity checks: chrome-sandbox setuid,
  Electron runtime, desktop entry, and free disk.

### Changed

- README opening rewritten in declarative style; Status and Supported-environments
  sections removed.
- rpm spec hardened: `%defattr` default and explicit `%global debug_package %{nil}`.
- `verify-patches.sh` dropped `set -e` per the bash styleguide.

### Fixed

- rpm could ship a non-setuid / missing chrome-sandbox; the setuid `4755` bit is
  now baked into the FHS tree and the build fails on "File listed twice".
- `build.sh --clean` was a no-op; it now prunes intermediates while keeping the
  package and `downloads/`.
- `build-linux.sh` staged a stale version (`APP_VERSION` default `1.5.619` →
  `1.5.695`).

## [v1.0.0] - 2026-06-07

Initial release — unofficial Linux repackaging of Wispr Flow (1.5.695) as
`.deb` / `.rpm` / AppImage for amd64 and arm64, with the clean-room Rust helper
(text injection, clipboard, global key capture), the Linux platform-gate
patches, Nix flake, docs tree, and the tag-driven release/publish pipeline.

[Unreleased]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.17+wispr1.6.1324...HEAD
[v1.0.17]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.16+wispr1.6.1324...v1.0.17+wispr1.6.1324
[v1.0.14]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.13+wispr1.6.1324...v1.0.14+wispr1.6.1324
[v1.0.13]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.12+wispr1.6.1324...v1.0.13+wispr1.6.1324
[v1.0.12]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.11+wispr1.6.1297...v1.0.12+wispr1.6.1297
[v1.0.11]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.10+wispr1.6.1297...v1.0.11+wispr1.6.1297
[v1.0.6]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.5+wispr1.6.606...v1.0.6+wispr1.6.606
[v1.0.5]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.4+wispr1.6.7...v1.0.5+wispr1.6.606
[v1.0.4]: https://github.com/srivasv/wispr-flow-linux/compare/v1.0.3+wispr1.5.751...v1.0.4+wispr1.6.7
[v1.0.3]: https://github.com/wispr-flow-linux/wispr-flow-linux/compare/v1.0.2+wispr1.5.751...v1.0.3+wispr1.5.751
[v1.0.2]: https://github.com/wispr-flow-linux/wispr-flow-linux/compare/v1.0.1+wispr1.5.695...v1.0.2+wispr1.5.695
[v1.0.1]: https://github.com/wispr-flow-linux/wispr-flow-linux/compare/v1.0.0+wispr1.5.695...v1.0.1+wispr1.5.695
[v1.0.0]: https://github.com/wispr-flow-linux/wispr-flow-linux/releases/tag/v1.0.0+wispr1.5.695
