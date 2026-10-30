# Test application-aware styles

Package 1.0.18 with helper v0.1.4-srivas.9 recognizes Linux apps and five browser services.

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

Expect package `1.6.1324-1.0.18` and helper `0.1.4-srivas.9`. Relaunch Flow.
If APT metadata has not refreshed, download the matching deb from the
[1.0.18 release](https://github.com/srivasv/wispr-flow-linux/releases/tag/v1.0.18%2Bwispr1.6.1324)
and install it with `sudo apt install ./wispr-flow_1.6.1324-1.0.18_amd64.deb`
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

Wait roughly one second after switching tabs before starting each dictation.
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
  | grep --line-buffered -E '\[App Change\]|\[MyVoice\]'
```

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
