import 'package:flutter/foundation.dart';

/// A paired contact (peer) in EchoMesh.
///
/// MVP goals:
/// - store enough info to connect to the peer (peerId + known multiaddrs)
/// - store UI metadata (displayName + avatarId)
/// - keep the model JSON-serializable for simple persistence (SharedPreferences)
///
/// Notes:
/// - `peerId` is the stable identifier from libp2p.
/// - `addrs` is a set of last-known multiaddrs (may go stale).
/// - Later we will add cryptographic identity / verification metadata.
@immutable
class Contact {
  /// libp2p PeerId (string form).
  final String peerId;

  /// Human-readable name (from pairing payload).
  final String displayName;

  /// Optional avatar identifier (MVP: built-in avatar id as string/int).
  ///
  /// Keeping it nullable and stringy makes migrations easier.
  final String? avatarId;

  /// Last-known reachable addresses for this peer (multiaddr strings).
  final List<String> addrs;

  /// When this contact was first paired (unix epoch ms).
  final int createdAtMs;

  /// Last time we updated discovered metadata (unix epoch ms).
  final int updatedAtMs;

  const Contact({
    required this.peerId,
    required this.displayName,
    required this.avatarId,
    required this.addrs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  /// Convenience constructor for a newly paired contact.
  factory Contact.paired({
    required String peerId,
    required String displayName,
    String? avatarId,
    List<String> addrs = const [],
    int? nowMs,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return Contact(
      peerId: peerId,
      displayName: displayName.trim().isEmpty ? 'Unknown' : displayName.trim(),
      avatarId: (avatarId == null || avatarId.trim().isEmpty) ? null : avatarId,
      addrs: _normalizeAddrs(addrs),
      createdAtMs: ts,
      updatedAtMs: ts,
    );
  }

  Contact copyWith({
    String? peerId,
    String? displayName,
    String? avatarId,
    List<String>? addrs,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return Contact(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      addrs: addrs ?? this.addrs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  /// Merge incoming data into an existing contact.
  ///
  /// - keeps `createdAtMs`
  /// - updates `updatedAtMs`
  /// - unions addresses
  Contact merged({
    String? displayName,
    String? avatarId,
    List<String>? addrs,
    int? updatedAtMs,
  }) {
    final nextName = (displayName == null || displayName.trim().isEmpty)
        ? this.displayName
        : displayName.trim();

    final nextAvatar =
        (avatarId == null || avatarId.trim().isEmpty) ? this.avatarId : avatarId;

    final nextAddrs = addrs == null
        ? this.addrs
        : _normalizeAddrs(<String>[...this.addrs, ...addrs]);

    return copyWith(
      displayName: nextName,
      avatarId: nextAvatar,
      addrs: nextAddrs,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'peerId': peerId,
        'displayName': displayName,
        'avatarId': avatarId,
        'addrs': addrs,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  static Contact fromJson(Map<String, Object?> json) {
    final addrsRaw = json['addrs'];
    final addrs = (addrsRaw is List)
        ? addrsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    final peerId = (json['peerId'] as String?) ?? '';
    if (peerId.trim().isEmpty) {
      throw FormatException('Contact.peerId is missing');
    }

    final name = (json['displayName'] as String?)?.trim();
    final createdAt = (json['createdAtMs'] as num?)?.toInt();
    final updatedAt = (json['updatedAtMs'] as num?)?.toInt();

    return Contact(
      peerId: peerId.trim(),
      displayName: (name == null || name.isEmpty) ? 'Unknown' : name,
      avatarId: (json['avatarId'] as String?)?.trim().isEmpty == true
          ? null
          : (json['avatarId'] as String?),
      addrs: _normalizeAddrs(addrs),
      createdAtMs: createdAt ?? 0,
      updatedAtMs: updatedAt ?? createdAt ?? 0,
    );
  }

  @override
  String toString() => 'Contact(peerId=$peerId, displayName=$displayName, '
      'avatarId=$avatarId, addrs=${addrs.length}, createdAtMs=$createdAtMs, updatedAtMs=$updatedAtMs)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          displayName == other.displayName &&
          avatarId == other.avatarId &&
          listEquals(addrs, other.addrs) &&
          createdAtMs == other.createdAtMs &&
          updatedAtMs == other.updatedAtMs;

  @override
  int get hashCode => Object.hash(
        peerId,
        displayName,
        avatarId,
        Object.hashAll(addrs),
        createdAtMs,
        updatedAtMs,
      );
}

List<String> _normalizeAddrs(List<String> input) {
  final set = <String>{};
  for (final a in input) {
    final s = a.trim();
    if (s.isEmpty) continue;
    set.add(s);
  }
  return set.toList(growable: false);
}
