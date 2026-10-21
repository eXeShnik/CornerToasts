## 0.1.0

- First release.
- `ToastController` queue with `success`, `info`, `warning` and `error`
  shorthands, a visible-count cap and per-toast durations
  (`Duration.zero` keeps a toast until it is closed).
- `ToastHost` (wraps a widget tree, `ToastHost.of(context)`) and
  `ToastOverlay` (for an existing `Stack`).
- Six anchor positions, newest toast closest to the anchored edge.
- Inline action button, close button with the platform's localized tooltip.
- Auto-dismiss stops while the mouse is over a toast or keyboard focus is
  inside it.
- Keyboard access: `ToastHost.focusShortcut` (Alt+T) moves focus to the
  newest toast and back; Escape closes the focused toast.
- A stack taller than the screen scrolls, keeping the newest toast in view.
- Closed toasts fold away; animations are skipped under reduced motion.
- With a screen reader on, a toast with an action waits to be closed.
- Per-kind colours and icons through `ToastTheme`; screen readers announce
  new toasts (not on Linux, whose Flutter embedder has no live regions).
