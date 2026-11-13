# Test application-aware styles

Package 1.0.30 with helper v0.1.4-srivas.22 recognizes Linux apps and five browser services.

- Gmail → Email.
- Slack and LinkedIn → Work.
- WhatsApp and Telegram → Personal.
- Unknown sites/apps or unavailable URL detection → Other.
- Explicit My Voice app assignments take precedence over these defaults.

## Update and verify

Quit Wispr Flow from its tray menu before updating so the old helper exits.
For an existing APT installation:

```bash
sudo apt update
sudo apt install --only-upgrade wispr-flow
dpkg-query -W -f='${Version}\n' wispr-flow
wispr-flow --doctor
```

Expect package `1.6.1483-1.0.30` and helper `0.1.4-srivas.22`. Relaunch Flow.
If APT metadata has not refreshed, download the matching deb from the
[1.0.30 release](https://github.com/srivasv/wispr-flow-linux/releases/tag/v1.0.30%2Bwispr1.6.1483)
and install it with `sudo apt install ./wispr-flow_1.6.1483-1.0.30_amd64.deb`
(use the arm64 asset on an ARM system).

## Five-minute pass

Choose visibly different existing styles for Work, Personal, Email, and Other
in Flow's settings. Note your original choices so you can restore them. Use
throwaway drafts; do not send messages. Do not add app assignments just for the
test, since they would bypass the default-category fallback being tested.

Open the five services in browser tabs and one unrelated site with an editable
field. Put the caret in a message/composer field and dictate this same sentence
in each:

> hello alex thanks for the update i will check this tomorrow

| Target | Expected default |
|---|---|
| Gmail compose | Email |
| Slack message composer | Work |
| LinkedIn message composer | Work |
| WhatsApp Web message composer | Personal |
| Telegram Web message composer | Personal |
| Unrelated site's editable field | Other |

Start dictation at your normal pace after focusing the composer; no extra
five-second wait should be needed.
Check every site once, then repeat Gmail → Telegram → unrelated site to catch
stale context. Repeat dictation without changing focus once; it must retain
the same category. Test native Slack or Telegram as well if already installed.
Formatting is model-generated and can vary, so use the category logs below as
the authoritative routing check rather than judging punctuation alone.

## Verify routing in logs

The main process logs both detected app changes and the style config sent to
transcription. Watch the launcher log while dictating:

```bash
tail -F "${XDG_CACHE_HOME:-$HOME/.cache}/wispr-flow/launcher.log" \
  | grep --line-buffered -E '\[App Change\]|\[MyVoice\]|myVoiceEnabled:|appName:|bundleId:|matchedVoiceType:|stylePreference:|personalizationAppType:'
```

Style details occupy separate lines after `[MyVoice]`; filtering only for
that prefix hides them. To inspect recent tests, replace `tail -F` with
`tail -n 2000` in the command above.

Look for the hostname in the app-change entry, then
`personalizationAppType` and, when My Voice is enabled, `matchedVoiceType` in
the style-config entry. Expected values are `email`, `work`, `personal`, or
`other`; a custom voice ID is correct when you explicitly assigned that app.
The app-change line's coarse `App type` field is a different classifier;
`Other` there alone does not mean the personalization category failed.

If Electron's console formatting hides the structured attributes, search its
main log under `${XDG_CONFIG_HOME:-$HOME/.config}/Wispr Flow` for the same
`[MyVoice]` entry. The exact file location is shown by the installed app's log
configuration; avoid sharing entire logs, which can contain private content.

## Browser fallback and regressions

If the browser is detected but the URL stays empty, enable browser
accessibility and retry. For Chromium-family browsers, fully quit the browser
and start it with `--force-renderer-accessibility=complete` (append that flag
to your normal browser command). An already-running browser may ignore newly
supplied startup flags. If accessibility is unavailable, Other is expected.
Firefox and native Wayland behavior particularly need live confirmation.

After the routing pass, check push-to-talk, normal text insertion, and one
post-paste correction in an app where correction learning already worked.
Switch between two windows with the same title if convenient. Restore your
style preferences afterward.

For a failure, record package/helper versions, desktop and X11/Wayland session,
browser version, native app versus website, expected/observed category, whether
the URL was empty, and only the relevant redacted log entries.

## Published-build results (2026-11-01)

After updating and restarting Flow, package `1.6.1337-1.0.20` ran helper
`v0.1.4-srivas.11`. The installed and running x86_64 helper matched the
published release asset byte-for-byte (SHA256):

```text
79eb9ddcd635a37f590d69c6d8d21d58bb459ed269b80c6fb554bdb3f570e907
```

Normal-pace dictation into unsent drafts followed Chrome LinkedIn → Vivaldi
WhatsApp → Chrome LinkedIn → Vivaldi WhatsApp. All four attempts passed:

| Browser and site | Attempts | Category sent | Configured style |
|---|---|---|---|
| Chrome LinkedIn | 2/2 | Work | casual |
| Vivaldi WhatsApp Web | 2/2 | Personal | veryCasual |

The first attempt and both directions of browser switching routed correctly.
Each following app-change notification retained the expected hostname
(`linkedin.com` or `web.whatsapp.com`); none of these attempts fell back to
Other. A subsequent ChatGPT dictation selected Other with an empty URL,
confirming no stale browser URL in that transition. No insertion problems
were reported.

The downloaded published x86_64 helper also passed the isolated event/query
harness for Gmail, Slack, LinkedIn, WhatsApp, Telegram, and an unknown site.
These automated fixtures are separate from live service tests. Earlier local
builds passed additional live Chrome and Vivaldi cases; this published-build
manual pass covers only the two browser/site pairs above. Firefox and Vivaldi
Telegram remain unverified live. Logs establish routing, not subjective
transcription wording quality or coverage across every desktop environment.

## Mid-sentence dictation in Google Docs

Enable both screen reader and braille support under **Tools > Accessibility
settings**. Place the caret between words in an existing sentence, including
a sentence inside a table cell, and dictate a lowercase common word. It must
be inserted without starting a new sentence. Repeat after switching windows.

On 2026-11-13, the locally built fix passed a live Chrome/Google Docs check
on KDE with Flow running under XWayland. The inserted word was lowercase.
The saved `History.additionalContext.textbox_contents` contained 102 characters
before the caret, 16 after and no selection, with
`accessibilityIsFunctioning: true` and `couldNotGetTextBoxInfo: false`.
The standalone `History.textboxContents` column was null; use the nested
context field when checking what was sent to the formatter. This was a local
build check; repeat it after installing the published package.

On KDE, also switch from another Chrome tab to Docs without switching windows.
Repeat after Vivaldi → Chrome and leave the Doc focused until each paste
finishes. Check every Chrome test record, rather than the latest dictation
if the test reply itself was dictated into another application. Browser-tab
title changes must update the target before the next context query.

The 2026-11-13 `srivas.22` candidate passed both cases with `RUST_LOG` unset
and no syscall tracer. The saved Chrome context contained 59 characters
before / 129 after the caret for the tab switch and 18 before / 8 after for
the browser switch. Both pasted texts were lowercase. Six preceding traced
Chrome recordings also matched the helper replies to the saved server context.
The candidate used the published app resources in a temporary app copy.
