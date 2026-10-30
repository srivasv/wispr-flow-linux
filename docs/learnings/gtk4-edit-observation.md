[< Back to learnings](index.md)

# GTK4 edit observation without an active parent

A focused GTK4 text field can be observable even when its parent dialog omits
the AT-SPI `Active` state.

- Zenity 4.0.1 on KDE reproduced the missing word-learning report.
- The field reported `Focused` and `Editable`; its parent dialog did not report
  `Active`, even with the X11 active-window property set.
- KWin and GNOME use their own app providers, so the helper's AT-SPI focus cache
  stays empty and edit observation uses the fallback tree walk.

The original fallback skipped every top-level window without `Active`, before
checking its children. It therefore returned "no focused accessible" for this
field. The error was logged only at debug level, so the normal launcher log had
no successful `atspi_edit` report.

The fix prefers active windows, then checks other top-level windows for the
focused field. Each walk shares one node budget across windows. The existing
eight-second timeout also bounds retries while toolkits register with a freshly
started accessibility registry. CI exposed that startup race after the parent
state fix. Role, focus, editability and text-anchor validation still gate reads
and reports.

The helper's `gtk4_edit_test.py` runs real GTK4 Zenity under a private Xvfb and
D-Bus session. It calls the observer without starting an AT-SPI focus tracker,
corrects the field, and checks the observed result. The test fails on the old
code and passes with the fallback fix. A GTK3-only fixture had missed this gap.

The toolkit's [Focused state](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/enum.StateType.html)
identifies keyboard focus; field discovery must not assume the parent also
advertises `Active`.
