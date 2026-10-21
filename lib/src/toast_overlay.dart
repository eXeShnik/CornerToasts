import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'toast.dart';
import 'toast_controller.dart';
import 'toast_theme.dart';

/// Wraps [child] with a toast layer, and lets descendants reach [controller]
/// through [ToastHost.of].
///
/// Put it above your routes, for example in `MaterialApp.builder`, or around
/// a single page's `Scaffold`. It brings its own [Overlay] for the cards'
/// tooltips, so it works above the app's `Navigator` too.
///
/// The cards are never reached by Tab or the arrow keys from the page (above
/// the `Navigator`, Tab could not reach them anyway), so they are reached
/// with [focusShortcut]: it moves focus to the newest card, and pressing it
/// again goes back. Tab moves between the cards and Escape closes the focused
/// one; focus then goes to the card visited before it, or back out of the
/// toasts. Above the `Navigator` the shortcut works on every page; see
/// [focusShortcut] for a host inside a page.
class ToastHost extends StatefulWidget {
  /// Wraps [child] with toasts from [controller].
  const ToastHost({
    super.key,
    required this.controller,
    required this.child,
    this.position = ToastPosition.bottomRight,
    this.theme = const ToastTheme(),
    this.maxWidth = 380,
    this.margin = const EdgeInsets.all(16),
    this.spacing = 8,
    this.focusShortcut = const SingleActivator(
      LogicalKeyboardKey.keyT,
      alt: true,
      includeRepeats: false,
    ),
  });

  /// The queue to show; also what [of] returns below this host.
  final ToastController controller;

  /// The content the toasts float above.
  final Widget child;

  /// Where the stack is anchored.
  final ToastPosition position;

  /// Card colours, icons and shape.
  final ToastTheme theme;

  /// Widest a card gets.
  final double maxWidth;

  /// Gap between the stack and the screen edges.
  final EdgeInsets margin;

  /// Gap between cards.
  final double spacing;

  /// Moves keyboard focus to the newest toast and back; null turns it off.
  ///
  /// Like any shortcut, it reaches the host through focus: it works while
  /// focus is anywhere below the host, and the nearest host to focus
  /// answers. Above the `Navigator` that is every page; inside a page, only
  /// once focus is in that page (after Tab, or in a text field).
  final ShortcutActivator? focusShortcut;

  /// The controller of the nearest [ToastHost] above [context].
  static ToastController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No ToastHost found above this context.');
    return controller!;
  }

  /// Like [of], but null when there is no [ToastHost] above [context].
  static ToastController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToastScope>()?.controller;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  // The toast layer lives in an overlay entry so its tooltips find an
  // Overlay even when the host sits above the app's Navigator. The entry
  // reads `widget` when it builds, and every rebuild of this host rebuilds
  // the Overlay and with it the entry, so new settings apply in the same
  // frame.
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => ToastOverlay(
      controller: widget.controller,
      position: widget.position,
      theme: widget.theme,
      maxWidth: widget.maxWidth,
      margin: widget.margin,
      spacing: widget.spacing,
    ),
  );

  // Out of the page's Tab and arrow-key traversal wherever the host sits:
  // its cards are traversable only while focus is inside it.
  final _layer = FocusScopeNode(debugLabel: 'ToastHost', skipTraversal: true)
    ..descendantsAreTraversable = false;

  @override
  void initState() {
    super.initState();
    _layer.addListener(_onLayerFocus);
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    _layer.dispose();
    super.dispose();
  }

  void _toggleFocus() {
    if (_layer.hasFocus) {
      _leaveLayer();
      return;
    }
    _layer.descendantsAreTraversable = true;
    final newest = FocusTraversalGroup.of(
      context,
    ).findFirstFocus(_layer, ignoreCurrentFocus: true);
    // With no card to focus, the policy hands back the layer itself.
    if (newest == null || newest == _layer) {
      _layer.descendantsAreTraversable = false;
      return;
    }
    newest.requestFocus();
  }

  void _onLayerFocus() {
    // When a focused card closes, focus falls back onto the empty layer.
    if (_layer.hasPrimaryFocus) _leaveLayer();
    // Focus also comes back through focus history (a closed dialog, the
    // window regaining focus), not only through the shortcut.
    _layer.descendantsAreTraversable = _layer.hasFocus;
  }

  // Focus scopes remember their focus history and drop nodes that leave the
  // tree, so this returns to the latest focus outside the toasts that still
  // exists.
  void _leaveLayer() {
    _layer.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  @override
  Widget build(BuildContext context) {
    return _ToastScope(
      controller: widget.controller,
      child: CallbackShortcuts(
        bindings: {
          if (widget.focusShortcut case final shortcut?) shortcut: _toggleFocus,
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: FocusScope(
                node: _layer,
                child: Overlay(initialEntries: [_entry]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.controller, required super.child});

  final ToastController controller;

  @override
  bool updateShouldNotify(_ToastScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The toast stack for [controller], filling its parent and anchored at
/// [position]. Only the cards take input; taps elsewhere pass through.
///
/// [ToastHost] places it for you; use it directly to put toasts inside an
/// existing `Stack` (wrap it in `Positioned.fill`). It needs an [Overlay]
/// above it for the cards' tooltips, which every page under a `Navigator`
/// has; above the `Navigator`, use [ToastHost].
class ToastOverlay extends StatefulWidget {
  /// Shows the toasts of [controller].
  const ToastOverlay({
    super.key,
    required this.controller,
    this.position = ToastPosition.bottomRight,
    this.theme = const ToastTheme(),
    this.maxWidth = 380,
    this.margin = const EdgeInsets.all(16),
    this.spacing = 8,
  });

  /// The queue to show.
  final ToastController controller;

  /// Where the stack is anchored.
  final ToastPosition position;

  /// Card colours, icons and shape.
  final ToastTheme theme;

  /// Widest a card gets.
  final double maxWidth;

  /// Gap between the stack and the screen edges.
  final EdgeInsets margin;

  /// Gap between cards.
  final double spacing;

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  // The controller's toasts plus the closed ones still folding away, oldest
  // first.
  late var _shown = widget.controller.toasts;
  final _leaving = <ToastData>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(ToastOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == oldWidget.controller) return;
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
    _leaving.clear();
    _shown = widget.controller.toasts;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    // Pages may show or clear toasts while the tree is being built or torn
    // down, when setState is not allowed; catch up once the frame is done.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
      return;
    }
    final current = widget.controller.toasts;
    setState(() {
      _leaving.addAll(_shown.where((toast) => !current.contains(toast)));
      // The controller only ever adds toasts as the newest.
      _shown = [
        ..._shown,
        ...current.where((toast) => !_shown.contains(toast))
      ];
    });
  }

  void _remove(ToastData toast) {
    setState(() {
      _leaving.remove(toast);
      _shown = [
        for (final shown in _shown)
          if (shown != toast) shown,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty) return const SizedBox.shrink();
    final isTop = widget.position.isTop;
    // The newest card sits closest to the anchored edge.
    final ordered = isTop ? _shown.reversed.toList() : _shown;
    return SafeArea(
      child: Align(
        alignment: switch (widget.position) {
          ToastPosition.topLeft => Alignment.topLeft,
          ToastPosition.topCenter => Alignment.topCenter,
          ToastPosition.topRight => Alignment.topRight,
          ToastPosition.bottomLeft => Alignment.bottomLeft,
          ToastPosition.bottomCenter => Alignment.bottomCenter,
          ToastPosition.bottomRight => Alignment.bottomRight,
        },
        child: Padding(
          padding: widget.margin,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            // Scrolls when the stack is taller than the screen; reversed for
            // bottom anchors so the newest card stays in view. No scrollbar:
            // on desktop its mouse region would catch taps between cards.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                reverse: !isTop,
                primary: false,
                hitTestBehavior: HitTestBehavior.deferToChild,
                // Tab visits the newest card first.
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, toast) in ordered.indexed)
                        FocusTraversalOrder(
                          // Ids restart at 0 in every controller; the toast
                          // itself is unique even across a controller swap.
                          key: ObjectKey(toast),
                          order: NumericFocusOrder(
                            (isTop ? index : ordered.length - 1 - index)
                                .toDouble(),
                          ),
                          child: _FoldAway(
                            leaving: _leaving.contains(toast),
                            onGone: () => _remove(toast),
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: isTop ? 0 : widget.spacing,
                                bottom: isTop ? widget.spacing : 0,
                              ),
                              child: ToastCard(
                                toast: toast,
                                theme: widget.theme,
                                fromTop: isTop,
                                onDismiss: () =>
                                    widget.controller.dismiss(toast.id),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A closed card fades while the space it took shrinks, so the cards behind
// it slide into place. On the way out it ignores the mouse and can't gain
// focus, but a focused one keeps focus until it is gone: taking focus away
// mid-frame would override wherever its action just sent focus, such as a
// dialog.
class _FoldAway extends StatefulWidget {
  const _FoldAway({
    required this.leaving,
    required this.onGone,
    required this.child,
  });

  final bool leaving;
  final VoidCallback onGone;
  final Widget child;

  @override
  State<_FoldAway> createState() => _FoldAwayState();
}

class _FoldAwayState extends State<_FoldAway> {
  var _hasFocus = false;
  var _removalScheduled = false;

  @override
  Widget build(BuildContext context) {
    final leaving = widget.leaving;
    final instant = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Without the fold (from the start, or since the setting changed
    // mid-fold), the card is hidden now and leaves after this frame, so a
    // card holding focus does not take back focus requested this frame
    // (say by a dialog its action opened).
    if (leaving && instant && !_removalScheduled) {
      _removalScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onGone();
      });
    }
    return _Leaving(
      leaving: leaving,
      child: IgnorePointer(
        ignoring: leaving,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          descendantsAreTraversable: !leaving,
          descendantsAreFocusable: !leaving || _hasFocus,
          onFocusChange: (hasFocus) {
            if (!widget.leaving) {
              _hasFocus = hasFocus;
              return;
            }
            setState(() => _hasFocus = hasFocus);
          },
          child: ExcludeSemantics(
            excluding: leaving,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: leaving ? 0 : 1),
              duration:
                  instant ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeIn,
              onEnd: leaving && !instant ? widget.onGone : null,
              builder: (context, t, child) => ClipRect(
                clipBehavior: leaving ? Clip.hardEdge : Clip.none,
                child: Align(
                  heightFactor: t,
                  child: Opacity(opacity: t, child: child),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// Tells a card it is on its way out, however it was closed, so its buttons,
// Escape and countdown do nothing more.
class _Leaving extends InheritedWidget {
  const _Leaving({required this.leaving, required super.child});

  final bool leaving;

  @override
  bool updateShouldNotify(_Leaving oldWidget) => leaving != oldWidget.leaving;
}

/// One toast: icon, message, optional action, close button. Dismisses itself
/// after the toast's duration; the countdown stops while the mouse is over
/// the card or keyboard focus is inside it, and starts over once neither is.
/// Escape closes a focused card.
///
/// While a screen reader is on, a toast with an action stays until it is
/// closed, as a `SnackBar` does, so there is time to reach the action.
class ToastCard extends StatefulWidget {
  /// Creates the card for [toast].
  const ToastCard({
    super.key,
    required this.toast,
    required this.onDismiss,
    this.theme = const ToastTheme(),
    this.fromTop = false,
  });

  /// What the card shows.
  final ToastData toast;

  /// Called when the card closes: its countdown ran out, the close or
  /// action button was pressed, or Escape was pressed while it had focus.
  final VoidCallback onDismiss;

  /// Card colours, icons and shape.
  final ToastTheme theme;

  /// Slides in from above instead of from below.
  final bool fromTop;

  @override
  State<ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<ToastCard> {
  Timer? _timer;
  var _hovered = false;
  var _focused = false;
  bool? _screenReader;

  // A closing card stays on screen while it folds away; it must not close
  // or run its action a second time.
  var _closed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.dependOnInheritedWidgetOfExactType<_Leaving>()?.leaving ??
        false) {
      _closed = true;
      _timer?.cancel();
    }
    final screenReader =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    if (screenReader == _screenReader) return;
    _screenReader = screenReader;
    _restartTimer();
  }

  @override
  void didUpdateWidget(ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toast == oldWidget.toast) return;
    _closed = false;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Counts down from the full duration unless the card is held by the
  // mouse, keyboard focus or a screen reader.
  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_closed) return;
    final waitsForReader =
        _screenReader == true && widget.toast.actionLabel != null;
    if (!widget.toast.sticky && !_hovered && !_focused && !waitsForReader) {
      _timer = Timer(widget.toast.duration, _close);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toast = widget.toast;
    final style = widget.theme.resolve(theme, toast.kind);
    final textStyle = (widget.theme.textStyle ?? theme.textTheme.bodyMedium!)
        .copyWith(color: style.foreground);

    final card = Material(
      color: style.background,
      borderRadius: widget.theme.borderRadius,
      elevation: widget.theme.elevation,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(style.icon, color: style.foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(toast.message, style: textStyle)),
            if (toast.actionLabel != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: style.foreground),
                onPressed: () {
                  if (_closed) return;
                  _close();
                  toast.onAction?.call();
                },
                child: Text(toast.actionLabel!),
              ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, color: style.foreground),
              onPressed: _close,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        onFocusChange: (focused) {
          _focused = focused;
          _restartTimer();
        },
        child: MouseRegion(
          onEnter: (_) {
            _hovered = true;
            _restartTimer();
          },
          onExit: (_) {
            _hovered = false;
            _restartTimer();
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (widget.fromTop ? -12 : 12) * (1 - t)),
                child: child,
              ),
            ),
            child: card,
          ),
        ),
      ),
    );
  }
}
