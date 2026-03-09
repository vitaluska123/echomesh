import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable user profile snapshot.
///
/// This is intentionally small and JSON-serializable.
/// Later we can add:
/// - public identity keys
/// - device id(s)
/// - pairing metadata
/// - multiple avatars / remote avatar URLs
@immutable
class UserProfile {
  final String displayName;

  /// A simple avatar identifier (MVP).
  ///
  /// UI can interpret this as:
  /// - an index into a built-in avatar set
  /// - or a color seed / icon choice
  ///
  /// If you later move to gallery images, store a URI/path separately.
  final int avatarId;

  const UserProfile({
    required this.displayName,
    required this.avatarId,
  });

  static const defaults = UserProfile(displayName: 'User', avatarId: 0);

  UserProfile copyWith({
    String? displayName,
    int? avatarId,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'displayName': displayName,
        'avatarId': avatarId,
      };

  static UserProfile fromJson(Map<String, Object?> json) {
    final displayName = (json['displayName'] as String?)?.trim();
    final avatarId = json['avatarId'];

    return UserProfile(
      displayName: (displayName == null || displayName.isEmpty)
          ? defaults.displayName
          : displayName,
      avatarId: switch (avatarId) {
        final int v => v,
        final num v => v.toInt(),
        _ => defaults.avatarId,
      },
    );
  }

  @override
  String toString() => 'UserProfile(displayName=$displayName, avatarId=$avatarId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName &&
          avatarId == other.avatarId;

  @override
  int get hashCode => Object.hash(displayName, avatarId);
}

/// Profile storage backed by `shared_preferences`.
///
/// This is a `ChangeNotifier` so UI can listen to it.
///
/// Usage:
/// - Create once (e.g. in your app shell / provider)
/// - Call `await load()` on startup
/// - Read `profile`
/// - Call `setDisplayName` / `setAvatarId` to update (persists automatically)
class ProfileStore extends ChangeNotifier {
  static const _prefsKey = 'echomesh.profile.v1';

  ProfileStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;

  /// Current profile snapshot.
  UserProfile get profile => _profile;
  UserProfile _profile = UserProfile.defaults;

  bool get isLoaded => _isLoaded;
  bool _isLoaded = false;

  SharedPreferences? _prefs;
  Future<void>? _loadFuture;

  /// Load profile from storage (idempotent).
  ///
  /// Safe to call multiple times; concurrent calls are coalesced.
  Future<void> load() {
    _loadFuture ??= _loadImpl();
    return _loadFuture!;
  }

  Future<void> _loadImpl() async {
    _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

    final raw = _prefs!.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _profile = UserProfile.defaults;
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _profile = UserProfile.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        } else {
          _profile = UserProfile.defaults;
        }
      } catch (_) {
        _profile = UserProfile.defaults;
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Persist current profile snapshot.
  Future<void> save() async {
    await load();
    final prefs = _prefs!;
    await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
  }

  /// Reset profile to defaults.
  Future<void> reset() async {
    await load();
    _profile = UserProfile.defaults;
    notifyListeners();

    final prefs = _prefs!;
    await prefs.remove(_prefsKey);
  }

  /// Update display name and persist.
  Future<void> setDisplayName(String value) async {
    await load();
    final trimmed = value.trim();
    final next = _profile.copyWith(
      displayName: trimmed.isEmpty ? UserProfile.defaults.displayName : trimmed,
    );
    if (next == _profile) return;

    _profile = next;
    notifyListeners();
    await save();
  }

  /// Update avatar id and persist.
  Future<void> setAvatarId(int value) async {
    await load();
    final next = _profile.copyWith(avatarId: value);
    if (next == _profile) return;

    _profile = next;
    notifyListeners();
    await save();
  }
}
