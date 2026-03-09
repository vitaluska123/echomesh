import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper around [SharedPreferences].
///
/// Goal:
/// - Centralize keys
/// - Avoid stringly-typed reads/writes scattered across the app
/// - Provide small typed helpers that are easy to refactor
///
/// Notes:
/// - This is intentionally minimal (no streams). If you later adopt Riverpod/Bloc,
///   you can keep this as the low-level persistence layer.
class Prefs {
  final SharedPreferences _sp;

  const Prefs._(this._sp);

  /// Load SharedPreferences instance.
  static Future<Prefs> load() async {
    final sp = await SharedPreferences.getInstance();
    return Prefs._(sp);
  }

  /// Read a required string. If missing, returns [fallback].
  String getString(PrefKeyString key, {String fallback = ''}) {
    return _sp.getString(key.key) ?? fallback;
  }

  Future<void> setString(PrefKeyString key, String value) async {
    await _sp.setString(key.key, value);
  }

  int getInt(PrefKeyInt key, {int fallback = 0}) {
    return _sp.getInt(key.key) ?? fallback;
  }

  Future<void> setInt(PrefKeyInt key, int value) async {
    await _sp.setInt(key.key, value);
  }

  bool getBool(PrefKeyBool key, {bool fallback = false}) {
    return _sp.getBool(key.key) ?? fallback;
  }

  Future<void> setBool(PrefKeyBool key, bool value) async {
    await _sp.setBool(key.key, value);
  }

  /// Removes a key from preferences (any type).
  Future<void> remove(PrefKey key) async {
    await _sp.remove(key.key);
  }

  /// Helpful for debugging.
  @visibleForTesting
  Set<String> getKeys() => _sp.getKeys();
}

/// Base type for preference keys.
@immutable
sealed class PrefKey {
  final String key;
  const PrefKey(this.key);
}

/// Typed string key.
@immutable
final class PrefKeyString extends PrefKey {
  const PrefKeyString(super.key);
}

/// Typed int key.
@immutable
final class PrefKeyInt extends PrefKey {
  const PrefKeyInt(super.key);
}

/// Typed bool key.
@immutable
final class PrefKeyBool extends PrefKey {
  const PrefKeyBool(super.key);
}

/// Central registry of all keys used in the app.
///
/// Keep this file stable; renaming keys will reset values for users unless you
/// implement a migration.
abstract final class PrefKeys {
  const PrefKeys._();

  // ---- Profile ----
  static const profileName = PrefKeyString('profile.name');
  static const profileAvatarId = PrefKeyInt('profile.avatar_id');

  // ---- UX / settings (reserved) ----
  static const onboardingDone = PrefKeyBool('ux.onboarding_done');
}
