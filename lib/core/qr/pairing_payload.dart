import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../rust/rust_node.dart';
import '../profile/profile_store.dart';

/// Data encoded into the pairing QR code.
///
/// MVP intent:
/// - allow another device to add you as a contact without servers
/// - include enough info to attempt a direct connection (desktop/LAN)
///
/// Security note:
/// This payload is NOT authenticated yet. In a real pairing flow you should
/// include a signature over the payload (using a long-term identity key),
/// and/or do an in-person verification step (e.g. compare safety numbers).
@immutable
class PairingPayload {
  final int v;

  /// Display name.
  final String name;

  /// Optional avatar id (app-defined).
  ///
  /// In this MVP it's derived from [UserProfile.avatarId] (int) and encoded as string.
  final String? avatarId;

  /// libp2p peer id (string form).
  final String peerId;

  /// Multiaddrs where this node is listening (if known).
  final List<String> listenAddrs;

  /// Unix epoch milliseconds for debugging / freshness heuristics.
  final int tsMs;

  const PairingPayload({
    required this.v,
    required this.name,
    required this.avatarId,
    required this.peerId,
    required this.listenAddrs,
    required this.tsMs,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'v': v,
        'name': name,
        'avatarId': avatarId,
        'peerId': peerId,
        'listenAddrs': listenAddrs,
        'tsMs': tsMs,
      };

  String toJsonString({bool pretty = false}) {
    final obj = toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(obj)
        : jsonEncode(obj);
  }

  static PairingPayload fromJson(Map<String, Object?> json) {
    final listenAddrsRaw = json['listenAddrs'];
    final listenAddrs = (listenAddrsRaw is List)
        ? listenAddrsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return PairingPayload(
      v: (json['v'] as num?)?.toInt() ?? 1,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Unknown',
      avatarId: (json['avatarId'] as String?)?.trim().isEmpty == true
          ? null
          : (json['avatarId'] as String?),
      peerId: (json['peerId'] as String?) ?? '',
      listenAddrs: listenAddrs,
      tsMs: (json['tsMs'] as num?)?.toInt() ?? 0,
    );
  }

  static PairingPayload fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('PairingPayload: expected JSON object');
    }
    return fromJson(decoded.cast<String, Object?>());
  }
}

/// Builds pairing payload string to be embedded into a QR.
///
/// Separating this from UI lets you evolve payload format independently.
class PairingPayloadBuilder {
  final ProfileStore _profileStore;

  const PairingPayloadBuilder(this._profileStore);

  /// Create payload based on current profile and Rust node status.
  ///
  /// Throws if node is not running or doesn't have a peer id yet.
  Future<PairingPayload> build({
    required RustNodeService node,
    bool requireRunningNode = true,
  }) async {
    await _profileStore.load();
    final profile = _profileStore.profile;

    final status = await node.status();
    if (requireRunningNode && !status.running) {
      throw StateError('Node is not running');
    }
    final peerId = status.peerId;
    if (peerId == null || peerId.isEmpty) {
      throw StateError('Node peerId is not available');
    }

    return PairingPayload(
      v: 1,
      name: profile.displayName,
      avatarId: profile.avatarId.toString(),
      peerId: peerId,
      listenAddrs: status.listenAddrs,
      tsMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Build and serialize to a JSON string (suitable for QR).
  Future<String> buildQrString({
    required RustNodeService node,
    bool pretty = false,
  }) async {
    final payload = await build(node: node);
    return payload.toJsonString(pretty: pretty);
  }
}
