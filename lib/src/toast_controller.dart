import 'package:flutter/foundation.dart';

import 'toast.dart';

/// The queue of toasts a `ToastOverlay` shows.
///
/// Keep one for the app (or one per screen) and call [show] or one of the
/// shorthands from anywhere; `ToastHost.of(context)` finds the nearest one.
/// Only the newest [maxVisible] toasts are kept.
class ToastController extends ChangeNotifier {
  /// Creates an empty queue.
  ToastController({
    this.maxVisible = 4,
    this.defaultDuration = const Duration(seconds: 4),
  }) : assert(maxVisible > 0, 'maxVisible must be at least 1');

  /// Most toasts on screen at once; older ones are dropped.
  final int maxVisible;

  /// Used when [show] gets no duration.
  final Duration defaultDuration;

  var _toasts = const <ToastData>[];
  var _nextId = 0;

  /// The toasts on screen, oldest first.
  List<ToastData> get toasts => _toasts;

  /// Shows [message] and returns the toast, whose `id` can dismiss it.
  ///
  /// A [duration] of [Duration.zero] keeps the toast until it is closed.
  ToastData show(
    String message, {
    ToastKind kind = ToastKind.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final toast = ToastData(
      id: _nextId++,
      kind: kind,
      message: message,
      duration: duration ?? defaultDuration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    final next = [..._toasts, toast];
    _toasts = List.unmodifiable(
      next.length > maxVisible ? next.sublist(next.length - maxVisible) : next,
    );
    notifyListeners();
    return toast;
  }

  /// Shows a [ToastKind.success] toast; see [show].
  ToastData success(
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ToastKind.success,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Shows a [ToastKind.info] toast; see [show].
  ToastData info(
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Shows a [ToastKind.warning] toast; see [show].
  ToastData warning(
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ToastKind.warning,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Shows a [ToastKind.error] toast; see [show].
  ToastData error(
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      show(
        message,
        kind: ToastKind.error,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Removes the toast with [id]; does nothing if it is already gone.
  void dismiss(int id) {
    final next = [
      for (final toast in _toasts)
        if (toast.id != id) toast,
    ];
    if (next.length == _toasts.length) return;
    _toasts = List.unmodifiable(next);
    notifyListeners();
  }

  /// Removes every toast.
  void clear() {
    if (_toasts.isEmpty) return;
    _toasts = const [];
    notifyListeners();
  }
}
