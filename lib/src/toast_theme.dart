import 'package:flutter/material.dart';

import 'toast.dart';

/// Colours and icon of one toast kind.
@immutable
class ToastStyle {
  /// Creates a style for one [ToastKind].
  const ToastStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  /// Card colour.
  final Color background;

  /// Text, icon and close-button colour.
  final Color foreground;

  /// Shown before the message.
  final IconData icon;

  /// The built-in look. Success, warning and error use fixed green, amber
  /// and red (seeded Material 3 containers can drift into hues that misread,
  /// a success that looks like an error); info follows the app's theme.
  static ToastStyle fallback(ThemeData theme, ToastKind kind) {
    final dark = theme.brightness == Brightness.dark;
    return switch (kind) {
      ToastKind.success => ToastStyle(
          background: dark ? const Color(0xFF1E3B27) : const Color(0xFFE8F5E9),
          foreground: dark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
          icon: Icons.check_circle_outline,
        ),
      ToastKind.info => ToastStyle(
          background: theme.colorScheme.surfaceContainerHigh,
          foreground: theme.colorScheme.onSurface,
          icon: Icons.notifications_outlined,
        ),
      ToastKind.warning => ToastStyle(
          background: dark ? const Color(0xFF4A3B00) : const Color(0xFFFFF8E1),
          foreground: dark ? const Color(0xFFFFD54F) : const Color(0xFF7A5900),
          icon: Icons.warning_amber_outlined,
        ),
      ToastKind.error => ToastStyle(
          background: dark ? const Color(0xFF4E2222) : const Color(0xFFFFEBEE),
          foreground: dark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C),
          icon: Icons.error_outline,
        ),
    };
  }
}

/// Look of the toast cards. Kinds missing from [styles] use
/// [ToastStyle.fallback].
@immutable
class ToastTheme {
  /// Creates a theme; every argument is optional.
  const ToastTheme({
    this.styles = const {},
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.elevation = 3,
    this.textStyle,
  });

  /// Per-kind overrides of the built-in look.
  final Map<ToastKind, ToastStyle> styles;

  /// Card corner radius.
  final BorderRadius borderRadius;

  /// Card shadow depth.
  final double elevation;

  /// Message style; defaults to the theme's `bodyMedium`. Its colour is
  /// replaced by the kind's foreground.
  final TextStyle? textStyle;

  /// The style used for [kind]: the override from [styles], else the
  /// built-in one for [theme].
  ToastStyle resolve(ThemeData theme, ToastKind kind) =>
      styles[kind] ?? ToastStyle.fallback(theme, kind);
}
