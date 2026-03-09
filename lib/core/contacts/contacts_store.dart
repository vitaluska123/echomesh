import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single paired contact.
///
/// MVP fields are intentionally small and JSON-serializable.
/// Later you can extend with:
/// - verified identity keys / safety numbers
/// - relay addresses / last-seen / capabilities
/// - per-contact settings
@immutable
class Contact {
  /// Stable identity key for contact in our storage.
  ///
  /// For libp2p this is the PeerId string.
  final String peerId;

  /// Display name (from pairing payload).
  final String displayName;

  /// Avatar identifier as string (from pairing payload).
  ///
  /// Today we store an app-defined avatar id encoded as string.
  /// Later can become URL/path or richer object.
  final String? avatarId;

  /// Candidate listen addresses for direct connection attempts.
  ///
  /// These are multiaddrs as strings.
  final List<String> listenAddrs;

  /// When this contact was first added.
  final int createdAtMs;

  /// When this contact was last updated (e.g., re-paired / refreshed).
  final int updatedAtMs;

  const Contact({
    required this.peerId,
    required this.displayName,
    required this.avatarId,
    required this.listenAddrs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Contact copyWith({
    String? peerId,
    String? displayName,
    String? avatarId,
    List<String>? listenAddrs,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return Contact(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      listenAddrs: listenAddrs ?? this.listenAddrs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'peerId': peerId,
        'displayName': displayName,
        'avatarId': avatarId,
        'listenAddrs': listenAddrs,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  static Contact fromJson(Map<String, Object?> json) {
    final peerId = (json['peerId'] as String?)?.trim() ?? '';
    final displayName = (json['displayName'] as String?)?.trim() ?? '';

    final avatarIdRaw = json['avatarId']?.toString();
    final avatarId = (avatarIdRaw == null || avatarIdRaw.trim().isEmpty)
        ? null
        : avatarIdRaw.trim();

    final listenRaw = json['listenAddrs'];
    final listenAddrs = (listenRaw is List)
        ? listenRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    final createdAtMs = _asInt(json['createdAtMs']) ?? 0;
    final updatedAtMs = _asInt(json['updatedAtMs']) ?? createdAtMs;

    return Contact(
      peerId: peerId,
      displayName: displayName.isEmpty ? 'Unknown' : displayName,
      avatarId: avatarId,
      listenAddrs: List<String>.unmodifiable(listenAddrs),
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
    );
  }

  /// Basic validation for storage/UI.
  bool get isValid => peerId.isNotEmpty;

  @override
  String toString() =>
      'Contact(peerId=$peerId, displayName=$displayName, listenAddrs=${listenAddrs.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          displayName == other.displayName &&
          avatarId == other.avatarId &&
          listEquals(listenAddrs, other.listenAddrs) &&
          createdAtMs == other.createdAtMs &&
          updatedAtMs == other.updatedAtMs;

  @override
  int get hashCode => Object.hash(
        peerId,
        displayName,
        avatarId,
        Object.hashAll(listenAddrs),
        createdAtMs,
        updatedAtMs,
      );

  static int? _asInt(Object? raw) {
    return switch (raw) {
      final int v => v,
      final num v => v.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
  }
}

/// A persisted contacts store backed by `shared_preferences`.
///
/// Storage format:
/// - key: `echomesh.contacts.v1`
/// - value: JSON array of Contact objects
///
/// Notes:
/// - This store is optimized for MVP simplicity, not large data sets.
/// - Later migrate to `drift` (SQLite) when you add chats/messages.
/// - Provides ChangeNotifier so UI can listen for updates.
class ContactsStore extends ChangeNotifier {
  static const _prefsKey = 'echomesh.contacts.v1';

  ContactsStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  bool _loaded = false;
  Future<void>? _loadFuture;

  /// In-memory index of contacts by peerId.
  final Map<String, Contact> _byPeerId = <String, Contact>{};

  bool get isLoaded => _loaded;

  /// Current contacts in a stable order (by displayName, then peerId).
  List<Contact> get contacts {
    final list = _byPeerId.values.toList(growable: false);
    list.sort((a, b) {
      final n = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      if (n != 0) return n;
      return a.peerId.compareTo(b.peerId);
    });
    return List<Contact>.unmodifiable(list);
  }

  /// Load contacts from storage (idempotent).
  ///
  /// Safe to call multiple times; concurrent calls are coalesced.
  Future<void> load() {
    _loadFuture ??= _loadImpl();
    return _loadFuture!;
  }

  Future<void> _loadImpl() async {
    _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

    _byPeerId.clear();

    final raw = _prefs!.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final contact = Contact.fromJson(item.cast<String, Object?>());
              if (contact.isValid) {
                _byPeerId[contact.peerId] = contact;
              }
            }
          }
        }
      } catch (_) {
        // If corrupted, keep empty; caller can re-pair.
      }
    }

    _loaded = true;
    notifyListeners();
  }

  /// Persist current state.
  Future<void> save() async {
    await load();
    final list = _byPeerId.values.map((c) => c.toJson()).toList(growable: false);
    await _prefs!.setString(_prefsKey, jsonEncode(list));
  }

  /// Returns contact if present.
  Contact? getByPeerId(String peerId) {
    final key = peerId.trim();
    if (key.isEmpty) return null;
    return _byPeerId[key];
  }

  /// Add or update a contact.
  ///
  /// - If contact does not exist: sets createdAt/updatedAt to now (if missing/zero).
  /// - If contact exists: preserves createdAt and updates updatedAt to now.
  Future<void> upsert(Contact contact) async {
    await load();
    if (!contact.isValid) {
      throw ArgumentError.value(contact.peerId, 'peerId', 'peerId must be non-empty');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _byPeerId[contact.peerId];

    final normalized = _normalizeContact(contact);

    final next = (existing == null)
        ? normalized.copyWith(
            createdAtMs: normalized.createdAtMs == 0 ? now : normalized.createdAtMs,
            updatedAtMs: now,
          )
        : normalized.copyWith(
            createdAtMs: existing.createdAtMs == 0 ? now : existing.createdAtMs,
            updatedAtMs: now,
          );

    _byPeerId[next.peerId] = next;
    notifyListeners();
    await save();
  }

  /// Remove a contact by peerId (idempotent).
  Future<void> remove(String peerId) async {
    await load();
    final key = peerId.trim();
    if (key.isEmpty) return;

    final removed = _byPeerId.remove(key);
    if (removed == null) return;

    notifyListeners();
    await save();
  }

  /// Clears contacts (useful for debug / reset).
  Future<void> clear() async {
    await load();
    if (_byPeerId.isEmpty) return;

    _byPeerId.clear();
    notifyListeners();
    await _prefs!.remove(_prefsKey);
  }

  Contact _normalizeContact(Contact c) {
    // Ensure consistent trimming and unique listenAddrs, in stable order.
    final peerId = c.peerId.trim();
    final name = c.displayName.trim().isEmpty ? 'Unknown' : c.displayName.trim();
    final avatarId =
        (c.avatarId == null || c.avatarId!.trim().isEmpty) ? null : c.avatarId!.trim();

    final seen = <String>{};
    final addrs = <String>[];
    for (final a in c.listenAddrs) {
      final t = a.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) addrs.add(t);
    }

    return c.copyWith(
      peerId: peerId,
      displayName: name,
      avatarId: avatarId,
      listenAddrs: List<String>.unmodifiable(addrs),
    );
  }
}
