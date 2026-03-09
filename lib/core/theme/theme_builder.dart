import 'package:flutter/material.dart';

/// Builds Material 3 themes using system dynamic colors when available.
///
/// Goals:
/// - Use Material 3 everywhere (`useMaterial3: true`)
/// - Prefer system-provided dynamic color schemes (Android 12+ / Monet)
/// - Provide a graceful cross-platform fallback scheme when dynamic colors
///   are not available (iOS, desktop, older Android)
///
/// Usage:
/// Wrap your `MaterialApp` with `DynamicColorBuilder` (from `dynamic_color`) and call:
/// ```
/// DynamicColorBuilder(
///   builder: (light, dark) {
///     final themes = ThemeBuilder.build(light: light, dark: dark);
///     return MaterialApp(theme: themes.light, darkTheme: themes.dark, ...);
///   },
/// );
/// ```
class ThemeBuilder {
  const ThemeBuilder._();

  /// Returns both light and dark themes.
  ///
  /// If [light]/[dark] are null, will fall back to a seeded `ColorScheme`.
  ///
  /// Note: We intentionally do not call any plugin-level \"harmonize\" APIs here,
  /// since they may not be available across `dynamic_color` versions.
  static AppThemes build({
    ColorScheme? light,
    ColorScheme? dark,
    ThemeSeed seed = const ThemeSeed.fallback(),
  }) {
    final fallbackLight = ColorScheme.fromSeed(
      seedColor: seed.seedColor,
      brightness: Brightness.light,
    );

    final fallbackDark = ColorScheme.fromSeed(
      seedColor: seed.seedColor,
      brightness: Brightness.dark,
    );

    final effectiveLight = light ?? fallbackLight;
    final effectiveDark = dark ?? fallbackDark;

    return AppThemes(
      light: _buildThemeData(
        scheme: effectiveLight,
        brightness: Brightness.light,
      ),
      dark: _buildThemeData(
        scheme: effectiveDark,
        brightness: Brightness.dark,
      ),
    );
  }

  static ThemeData _buildThemeData({
    required ColorScheme scheme,
    required Brightness brightness,
  }) {
    // Keep typography and component defaults as close to M3 as possible.
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
  }
}

/// Pair of themes (light + dark) for `MaterialApp`.
class AppThemes {
  final ThemeData light;
  final ThemeData dark;

  const AppThemes({
    required this.light,
    required this.dark,
  });
}

/// Seed used for fallback when dynamic colors are not available.
///
/// This does NOT affect dynamic color on supported devices.
class ThemeSeed {
  final Color seedColor;

  /// Neutral-ish fallback seed (not loud purple).
  ///
  /// Picked to look okay on desktop where there is no dynamic color.
  const ThemeSeed.fallback() : seedColor = const Color(0xFF4F5B62);

  const ThemeSeed.fromColor(Color c) : seedColor = c;
}
