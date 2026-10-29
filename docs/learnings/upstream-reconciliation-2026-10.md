# Upstream reconciliation, October 2026

The fork adopts upstream runtime and build improvements while retaining its distribution identity and stricter release checks.

- Fork baseline: `2ab52be` (Wispr 1.6.1297); upstream: `8866a1785300d1370e2aa6b06af05ee713988dcd`.
- Common ancestor: `b040128`; 57 fork-only and 70 upstream-only commits before reconciliation, including version/lockfile bumps and merge commits.
- Scope: packaging repository, nine open upstream PRs, and helper dependency compatibility. Helper and Worker source audits are excluded.
- Original dirty checkout is preserved; implementation lives on `fix/148-upstream-reconciliation` in a separate worktree.

## Changes adopted from upstream

| Area | Decision and effect |
|---|---|
| Patch pipeline | Adopt shared patch library, fail-fast stage, pristine tripwires, backup stripping, real-bundle test, and repaired minified anchors. Fix rollback to restore each patch's input. |
| Downloads/builds | Adopt installer pins, Squirrel fallback, native-module pin, cached runtime version checks, exact stage mirroring and bump prechecks. Retain strict HTTPS, SHA-256, size and schema checks on usable manifests. |
| Desktop | Adopt XDG data paths, autostart and doctor checks, explicit XWayland selection, compact native-Wayland pill and picker positioning. Migration now aborts launch on conflicts or failed moves. |
| Helper | Consume prebuilt helper v0.1.3 and native-v1 modules; retain the documented IPC contract. Source is not merged into the packaging repository. |
| Distribution | Retain `pkg.grimwulf.dev` APT/releases, disabled DNF/AUR jobs, required deb launch, sandbox/version checks, isolated profiles and stored AppImage permission inspection. |
| Existing fork fixes | Preserve Hub focusability and current minified-bundle compatibility through the corresponding upstream patches. Replace the earlier X11 shape patch with #148's more complete lifecycle handling. |

## Pending PR decisions

| Upstream PR | Decision | Reason |
|---|---|---|
| [148](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/148) | Merge and adapt | Covers X11 shape creation, reload, visibility, toast recovery and empty regions. Add the 1.6.1297 validated-report/fallback shape from the fork's work in progress. |
| [132](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/132) | Merge | Unmaps idle Status surfaces while retaining recording feedback; complements X11 clipping. |
| [73](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/73) | Merge | Restores always-on-top visibility; does not itself solve input regions. |
| [145](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/145) | Merge | Honors dictation mute/pause settings and restores only state changed by the app. |
| [129](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/129) | Merge and harden | Stops protocol registration from stealing HTML defaults. Resolve MIME symlinks and replace the target atomically; support all shipped quote styles. |
| [142](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/142) | Cherry-pick `1b54526` only | Fake-helper push-to-talk test is useful. Exclude unrelated staging normalization and primary-monitor positioning commits. |
| [147](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/147) | Exclude | Overlaps #148; combining both would duplicate ownership of the Status input lifecycle. |
| [78](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/78) | Defer | Depends on compositor/helper support not provided by the pinned helper. |
| [118](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/118) | Exclude | External advisory review service adds integration and credential scope without a required runtime fix. |

## Upstream contributions

| PR | Problem solved |
|---|---|
| [149](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/149) | A failed patch no longer silently removes earlier successful patches. |
| [150](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/150) | Artifact smoke tests use scratch profiles and required deb launches; AppImage permissions cannot pass through a lossy extractor. |
| [151](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/151) | Same-repository PRs in forks no longer incorrectly require maintainer-edit permission. |
| [152](https://github.com/wispr-flow-linux/wispr-flow-linux/pull/152) | Fork AppImages update from the publishing fork rather than upstream releases. |

## Compatibility findings

Wispr 1.6.1297 combines the Windows predicate with `applyReport` and adds an `else if` viewport fallback. Both predicates must include Linux X11, while the validation and normalization remain unchanged. The shared rollback snapshot is refreshed per patch so failures preserve earlier transformations. Regression fixtures cover old and new shapes, malformed fallbacks, idempotency and stale backups.

The extra Linux equality check in 1.6.1297 rejects `safeStorage`'s `basic_text` backend for extension credentials. It is preserved. The tripwire excludes that exact audited guard while retaining the expected count for other Linux equality checks, allowing both 1264 and 1297 without weakening the general count to a minimum.

Migration moves only nonconflicting entries and refuses launch on an active lock, collision or move failure. A partial move leaves files recoverable in their source or target; a later launch can resume remaining entries. Existing target data is never overwritten. An unresolved collision requires the user to reconcile the profiles before launch.

## Validation and release boundary

- Both real Windows installers, 1.6.1264 and 1.6.1297: 13/13 patch-stage checks, including all JavaScript syntax, marker coverage, idempotency and no packaged backups.
- 1.6.1297 installer matches pinned SHA-256 `9190434530a6d37607f27a38fd806934ed8839e005ba3a1139b6b625b78ad829`.
- Full Bats suite: 370/370 passed. After adding three harness cases, all 13 harness tests pass (373 cases total in the final tree). Outgoing PR checks: 11 rollback tests, 12 smoke tests and two AppImage maker tests pass.
- Deb and AppImage are built locally. Deb inspection: 34/34 checks. AppImage inspection, real-helper launch and scripted push-to-talk: 39/39 checks, using `APPIMAGELAUNCHER_DISABLE=1 APPIMAGE_EXTRACT_AND_RUN=1` for this host. An extracted-AppDir launch independently reaches helper-ready with X11/XTEST. The host has no Cargo and disallows sudo; build functions were driven with prebuilt helper/native modules and locally extracted icoutils, without changing system packages.
- ShellCheck uses the project's warning-level gate. Actionlint passes with only the two intentionally disabled distribution jobs' constant-false conditions excluded. Codespell is checked.
- Nix now invokes the shared patch stage, preventing drift between the launcher migration and bundle paths. Its pre-existing Windows native-module staging remains incomplete; do not treat the Nix package as validated or release-ready.
- RPM, Nix and arm64 builds, physical click-through, mixed-DPI/multi-monitor behavior, microphone transcription, real paste, and desktop audio restoration remain release-validation work.
- No merge, tag, release, package installation or Worker deployment is performed by this reconciliation.

The host AppImageLauncher initially intercepted launch and tried to manage its daemon inside the scratch D-Bus session. Its [documented environment opt-out](https://github.com/TheAssassin/AppImageLauncher/discussions/679) lets the test execute the artifact directly; no host service configuration was changed.
