import 'package:flutter/foundation.dart';

/// What a toast reports; picks its colours and icon.
enum ToastKind {
  /// Something finished as asked: green, check mark.
  success,

  /// Neutral news, styled from the app's theme.
  info,

  /// Worth a look but not a failure: amber.
  warning,

  /// Something failed: red.
  error,
}

/// Where the toast stack is anchored. The newest toast sits closest to the
/// anchored edge.
enum ToastPosition {
  /// Top-left corner.
  topLeft,

  /// Middle of the top edge.
  topCenter,

  /// Top-right corner.
  topRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Middle of the bottom edge.
  bottomCenter,

  /// Bottom-right corner.
  bottomRight;

  /// True for the three positions along the top edge.
  bool get isTop => this == topLeft || this == topCenter || this == topRight;
}

/// One toast in a [ToastController]'s queue.
@immutable
class ToastData {
  /// Creates a toast; [ToastController.show] does this for you.
  const ToastData({
    required this.id,
    required this.kind,
    required this.message,
    required this.duration,
    this.actionLabel,
    this.onAction,
  }) : assert(
          onAction == null || actionLabel != null,
          'onAction needs an actionLabel to show its button',
        );

  /// Unique within its controller; pass it to `dismiss`.
  final int id;

  /// Picks the toast's colours and icon.
  final ToastKind kind;

  /// The text shown on the card.
  final String message;

  /// How long the toast stays before it dismisses itself.
  /// [Duration.zero] keeps it until it is closed.
  final Duration duration;

  /// Label of an optional inline action button.
  final String? actionLabel;

  /// Called when the action is pressed; the toast is dismissed first.
  final VoidCallback? onAction;

  /// True when the toast never dismisses itself.
  bool get sticky => duration == Duration.zero;
}
