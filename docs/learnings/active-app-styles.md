# Active application and dictation styles

Linux feeds the existing app-style selector through helper IPC focus events.

- `GetActiveAppInfo` answers a query; it does not replace `AppInfoUpdate` events.
- `RecordingStarted` must re-announce the app, even when focus has not changed.
- `SetFocusChangeDetectorState` controls background app-change notifications.
- Empty identity selects the generic style; titles are not application IDs.

## App-side pipeline

Audited against packaged Wispr Flow **1.6.1324**. The native implementations
are the Windows `Release/Wispr Flow Helper.exe` and macOS
`swift-helper-app-dist/Wispr Flow.app/Contents/MacOS/Wispr Flow`; their common
interface is documented in [the IPC contract](../reference/ipc-contract.md).
Linux implements that interface in the separate helper repository.

The main bundle's `AppInfoUpdate` handler updates persistent app context and,
while a dictation exists, its app identity and app type. It refreshes the
personalization settings and sends the changed context to the transcription
backend. Correction reports use the adjacent `UpdateEditedText` handler;
app detection does not replace the field-focus or correction observers.

The exported `getAppType` classifier selects macOS identifiers on macOS and
process-name prefixes otherwise. `Code`, `Cursor`, `code.desktop`, and
`cursor.desktop` already classify as AI apps on Linux. Empty or unrecognized
identifiers classify as Other. Manual app-type overrides retain precedence.
The personalization/My Voice layer then selects the user's configured style.
This is dictation formatting, not the application's light/dark UI theme.

No separate Linux settings switch is needed for this pipeline. This audit did
not find an option literally named "detect application" in the shipped
settings bundle; do not add a new preference or change the existing UI merely
to repair helper events.

## Linux recognition and style fallback

The helper's `app_context` IPC adapter normalizes exact Linux aliases before
both app-query responses and focus events reach Electron. Examples include
`org.telegram.desktop` → `Telegram`, `org.mozilla.Thunderbird.desktop` →
`thunderbird`, and `com.slack.Slack.desktop` → `Slack`. Unknown identifiers
are preserved; matching does not guess from a title or a substring. Browser
aliases map to IDs the upstream browser recognizer accepts.

| Detected application or website | Default category |
|---|---|
| Slack, Teams, Slack web, LinkedIn | Work |
| WhatsApp, Telegram, WhatsApp web, Telegram web | Personal |
| Thunderbird, Gmail web | Email |
| Unrecognized site/app or unavailable URL | Other |

Both style paths are supported. The original personalization path uses the
existing category mapper. The Linux-only `linux-app-style-fallback.sh` patch
makes My Voice use that same category **after** checking every configured
app assignment. Explicit user assignments still win; existing voices and
settings are not rewritten. Windows and macOS keep the original fallback.

## Browser URL detection

A separate helper worker reads the active browser's top-level AT-SPI Document
attribute: `URI` in Chromium and `DocURL` in Firefox. Chromium's attribute
spelling is documented in its
[ATK implementation](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/ui/accessibility/platform/ax_platform_node_auralinux.cc).
No address-bar keystrokes, clipboard operations, browser extensions, or new
runtime dependencies are used. Keyboard and correction IPC bypass the URL
worker, so a slow accessibility provider cannot block those messages.

The worker requires a recognized browser and one matching active window,
searches at most 300 objects to depth 32, and times out after 200 ms. It does
not descend into embedded documents. It checks the window and URL again
before accepting the result. Old focus generations are discarded. Browser
context is polled every 250 ms while detection is enabled so a same-title tab
change still updates the app's style. A failed read clears the previous URL.
Headless sessions never open an accessibility connection for URL detection.

Only recognized site hostnames are sent to Electron: `mail.google.com`,
`app.slack.com` (including workspace subdomains), `linkedin.com`,
`web.whatsapp.com`, and `web.telegram.org`. Paths, query strings, fragments,
and document contents are not sent. Unknown, malformed, non-HTTP(S), and
lookalike domains produce an empty URL and default to Other, unless the user
explicitly assigned a voice to that browser.

Detection requires a working AT-SPI bridge in the browser. Chromium-family
browsers may need `--force-renderer-accessibility=complete`; a browser that
withholds its accessible document safely falls back to Other. PWA wrappers
and browsers outside the explicit alias list are not promised coverage.
Firefox is implemented but has not been live-tested in this environment.

## Helper reliability

The helper changes accompanying this audit add native X11 focus polling at
100 ms intervals, using `_NET_ACTIVE_WINDOW` with `GetInputFocus` and bounded
parent traversal for WMs without EWMH. Event deduplication includes the native
window ID, so windows with identical titles and classes remain distinct.
Classless windows use the WM instance or process name when available.

On Wayland, KWin, the GNOME extension, or AT-SPI supplies identity independently
of injection. XWayland can retain an old active window after focus moves to a
native Wayland window; its identity must never override the Wayland provider.
A missing provider yields empty identity. Native Wayland does not require
XWayland for this detection path. AT-SPI coverage depends on the target app's
accessibility support; an unsupported compositor/app combination cannot be
promised reliable detection. Existing provider focus caches are retained.

Headless sessions skip both app-provider and field-focus tracker startup.
These helper changes require a helper release before updating
`helper-version.txt` and the Nix pin. Local builds can use `HELPER_BIN`.

## Reproducible validation

Run the classifier check on the extracted main bundle after Linux patches:

```bash
node tests/test-app-style.cjs /path/to/.webpack/main/index.js
```

The check executes the shipped classifier and My Voice selector with isolated
platform and preference dependencies. It covers all four categories, explicit
assignments, unchanged Windows/macOS behavior, and the generic fallback. The
unpatched 1.6.1324 bundle fails the new Linux My Voice assertions.

In the helper repository:

```bash
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --check
CHROMIUM_BIN=/path/to/chrome python3 browser_style_test.py target/debug/wispr-flow-linux-helper
env -u WAYLAND_DISPLAY xvfb-run -a cargo test native_focus -- --ignored
env -u DISPLAY -u WAYLAND_DISPLAY cargo test headless_skips -- --ignored
```

The Xvfb test uses real X11 requests and focus events, without accessibility,
covering duplicate titles/classes, disable/re-enable, repeated recording-style
re-announcement, missing identity, no focus, and EWMH precedence. Native
Wayland provider precedence is unit tested; live KDE/GNOME/wlroots and actual
VS Code/Cursor dictation remain a separate manual validation requirement.

The browser harness uses a private Xvfb/D-Bus session, temporary profile, and
local TLS fixture pages for all five sites plus an unknown site. Every page
has the same title. It verifies both asynchronous events and queried URLs;
it does not contact the real services or require login. The bundled selector
checks verify how those hosts map to styles, rather than asserting on the
output of a remote transcription model. Live native Wayland browser behavior
still needs manual validation.
