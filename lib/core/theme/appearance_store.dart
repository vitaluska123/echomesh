import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled appearance settings.
///
/// Goals:
/// - Persist theme preference (system/light/dark)
/// - Keep room for future settings: accent color override, AMOLED mode, etc.
/// - Provide a simple ChangeNotifier API for UI
///
/// Note: Dynamic color (Android 12+) is handled by theme building code.
/// This store only describes user preferences; it doesn't compute ColorSchemes.
class AppearanceStore extends ChangeNotifier {
  static const _prefsKey = 'echomesh.appearance.v1';

  AppearanceStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<void>? _loadFuture;
  bool _loaded = false;

  /// Current settings snapshot.
  AppearanceSettings get settings => _settings;
  AppearanceSettings _settings = const AppearanceSettings();

  bool get isLoaded => _loaded;

  /// Load settings from SharedPreferences (idempotent).
  ///
  /// Safe to call multiple times; concurrent callers share the same Future.
  Future<void> load() {
    _loadFuture ??= _loadImpl();
    return _loadFuture!;
  }

  Future<void> _loadImpl() async {
    _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

    final raw = _prefs!.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _settings = const AppearanceSettings();
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _settings = AppearanceSettings.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        } else {
          _settings = const AppearanceSettings();
        }
      } catch (_) {
        _settings = const AppearanceSettings();
      }
    }

    _loaded = true;
    notifyListeners();
  }

  /// Persist current settings.
  Future<void> save() async {
    await load();
    await _prefs!.setString(_prefsKey, jsonEncode(_settings.toJson()));
  }

  /// Reset to defaults.
  Future<void> reset() async {
    await load();
    _settings = const AppearanceSettings();
    notifyListeners();
    await _prefs!.remove(_prefsKey);
  }

  /// Set theme mode (system/light/dark).
  Future<void> setThemeMode(ThemeMode mode) async {
    await load();
    final next = _settings.copyWith(themeMode: mode);
    if (next == _settings) return;

    _settings = next;
    notifyListeners();
    await save();
  }

  /// Future: when system dynamic colors are not available, allow overriding accent.
  ///
  /// For now this is just stored; theme builder can choose to ignore it until you
  /// implement the UI and behavior.
  Future<void> setAccent(AccentPreference pref) async {
    await load();
    final next = _settings.copyWith(accent: pref);
    if (next == _settings) return;

    _settings = next;
    notifyListeners();
    await save();
  }
}

/// Serializable settings snapshot.
@immutable
class AppearanceSettings {
  /// Theme mode selection.
  ///
  /// Defaults to [ThemeMode.system].
  final ThemeMode themeMode;

  /// Accent selection preference.
  ///
  /// Defaults to [AccentPreference.system]. This means:
  /// - If dynamic colors are available: use system (Monet)
  /// - Otherwise: fall back to app default seed
  final AccentPreference accent;

  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.accent = AccentPreference.system,
  });

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    AccentPreference? accent,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'themeMode': _encodeThemeMode(themeMode),
        'accent': accent.name,
      };

  static AppearanceSettings fromJson(Map<String, Object?> json) {
    final themeModeRaw = json['themeMode'];
    final accentRaw = json['accent'];

    return AppearanceSettings(
      themeMode: _decodeThemeMode(themeModeRaw),
      accent: AccentPreference.tryParse(accentRaw?.toString()) ??
          AccentPreference.system,
    );
  }

  @override
  String toString() => 'AppearanceSettings(themeMode=$themeMode, accent=$accent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceSettings &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          accent == other.accent;

  @override
  int get hashCode => Object.hash(themeMode, accent);

  static String _encodeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  static ThemeMode _decodeThemeMode(Object? raw) {
    return switch (raw?.toString()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

/// User preference for accent colors.
///
/// Note: "System" only makes sense on platforms that provide dynamic colors.
/// When dynamic colors are unavailable, theme builder can fall back to seed.
enum AccentPreference {
  system,

  /// Future: let the user pick an app-defined seed/accent.
  ///
  /// This does not store the actual color yet; you'll probably want:
  /// - AccentPreference.custom + customSeedColor (int ARGB)
  /// or:
  /// - a small preset palette.
  custom;

  static AccentPreference? tryParse(String? raw) {
    if (raw == null) return null;
    for (final v in AccentPreference.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}
