# corner_toast

Stacked toast notifications for Flutter, anchored to a corner of the screen
(or the middle of the top or bottom edge). Four styles out of the box:
success, info, warning and error, each with its own colour and icon in light
and dark themes.

- **Stacked:** several toasts at once, the newest closest to the corner;
  older ones drop off past a limit you set.
- **Hands off:** each toast closes itself after its duration. The countdown
  stops while the mouse is over the toast or keyboard focus is inside it,
  and starts over once neither is. A toast with `Duration.zero` stays until
  it is closed. Closed toasts fold away and the rest slide into place.
- **Actionable:** an optional inline button (“Undo”, “View”) next to the
  close button.
- **Plain Flutter:** a `ChangeNotifier` controller and a few widgets. No state
  management package required, and it works alongside any of them.
- **Accessible:** screen readers announce new toasts (except on Linux,
  whose Flutter embedder has no live regions), and while one is on, a
  toast with an action waits to be closed (as a `SnackBar` does). A keyboard
  shortcut reaches the toasts (see [Keyboard](#keyboard)), animations are
  skipped when the system asks for reduced motion, and the close button
  uses Flutter's localized tooltip.

## Getting started

```sh
flutter pub add corner_toast
```

The cards are Material widgets: put the host inside a `MaterialApp` (or
anywhere with a Material `Theme` and `MaterialLocalizations` above it).

## Usage

Create one `ToastController` and put a `ToastHost` above your routes:

```dart
import 'package:corner_toast/corner_toast.dart';
import 'package:flutter/material.dart';

final toasts = ToastController();

void main() => runApp(
  MaterialApp(
    builder: (context, child) => ToastHost(
      controller: toasts,
      position: ToastPosition.bottomRight,
      child: child!,
    ),
    home: const HomePage(),
  ),
);
```

Then show toasts from anywhere, through the controller or the nearest host:

```dart
toasts.success('Saved');
ToastHost.of(context).error('Could not connect');

toasts.info(
  'File deleted',
  actionLabel: 'Undo',
  onAction: restoreFile,
);

// Stays until the user closes it.
final toast = toasts.warning('Disk almost full', duration: Duration.zero);
// …or close it yourself.
toasts.dismiss(toast.id);
```

### Options

| Where | Option | Default |
| --- | --- | --- |
| `ToastController` | `maxVisible` | `4` |
| `ToastController` | `defaultDuration` | 4 seconds |
| `ToastHost` / `ToastOverlay` | `position` | `ToastPosition.bottomRight` |
| `ToastHost` / `ToastOverlay` | `maxWidth` | `380` |
| `ToastHost` / `ToastOverlay` | `margin`, `spacing` | `16`, `8` |
| `ToastHost` / `ToastOverlay` | `theme` | built-in colours |
| `ToastHost` | `focusShortcut` | Alt+T |

### Theming

Override any kind's colours and icon, the card shape or the text style:

```dart
ToastHost(
  controller: toasts,
  theme: const ToastTheme(
    styles: {
      ToastKind.success: ToastStyle(
        background: Color(0xFF0B3D2E),
        foreground: Colors.white,
        icon: Icons.done_all,
      ),
    },
    borderRadius: BorderRadius.all(Radius.circular(4)),
    elevation: 6,
  ),
  child: child,
)
```

Kinds you leave out keep the built-in look (`ToastStyle.fallback`).

### Keyboard

Tab and the arrow keys never move focus from the page into the toasts:
wherever the host sits, keyboard users get to them with `focusShortcut`
(Alt+T by default), which moves focus to the newest toast; pressing it
again goes back to where focus was. Tab moves between toasts, newest
first, and Escape closes the focused one; focus then goes to the toast you
were on before it, or back out of the toasts.

Like any shortcut, it reaches the host through focus, and the host nearest
to focus answers. Above the `Navigator` (in `MaterialApp.builder`, as in
[Usage](#usage)) that covers every page, even before anything has focus. A
host inside a page answers only once focus is in that page, for example
after Tab or in a text field. Shortcuts of your own between focus and the
host take precedence, and holding the key down toggles only once.

On macOS the default is Option+T, which some keyboard layouts also use to
type a character. Pass another `ShortcutActivator` to change it, or
`focusShortcut: null` to free the key for your app.

### Inside an existing Stack

`ToastHost` adds a `Stack` for you. If a page already has one, place a
`ToastOverlay` in it instead; it fills its parent and lets taps outside the
cards pass through. The cards are then part of the page's own Tab order,
so there is no focus shortcut. `ToastOverlay` needs an `Overlay` above it
for the cards' tooltips, which every page under a `Navigator` has; above
the `Navigator` (in `MaterialApp.builder`), use `ToastHost`:

```dart
Stack(
  children: [
    page,
    Positioned.fill(child: ToastOverlay(controller: toasts)),
  ],
)
```

## Example

`example/lib/main.dart` shows every kind, an action toast, a sticky toast
and switching the corner at runtime.
