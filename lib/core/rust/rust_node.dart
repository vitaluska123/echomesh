import 'package:flutter/foundation.dart';

import '../../bridge_generated.dart/api.dart' as rust_api;

/// Lightweight snapshot of Rust node status.
@immutable
class RustNodeStatus {
  final bool running;
  final String? peerId;
  final List<String> listenAddrs;

  const RustNodeStatus({
    required this.running,
    required this.peerId,
    required this.listenAddrs,
  });

  @override
  String toString() =>
      'RustNodeStatus(running=$running, peerId=$peerId, listenAddrs=$listenAddrs)';
}

/// High-level wrapper around FRB-generated Rust node APIs.
///
/// Responsibility:
/// - Provide a stable Dart API for starting/stopping the Rust libp2p node
/// - Keep FFI/FRB details (tuple unpacking, raw strings) away from UI code
///
/// Notes:
/// - Rust side currently supports TCP; `enableQuic` is a forward-compatible flag.
/// - `start()` returns the PeerId string (Rust does "start-or-return-existing").
/// - `stop()` is idempotent.
class RustNodeService {
  const RustNodeService();

  /// Start (or re-use) the node and return the local peer id.
  ///
  /// [listenAddr] example values:
  /// - `/ip4/0.0.0.0/tcp/0` (random port)
  /// - `/ip4/0.0.0.0/tcp/4001`
  ///
  /// Keep `enableQuic=false` for now; Rust will reject QUIC until implemented.
  Future<String> start({
    String listenAddr = '/ip4/0.0.0.0/tcp/0',
    bool enableQuic = false,
  }) {
    return rust_api.nodeStart(listenAddr: listenAddr, enableQuic: enableQuic);
  }

  /// Stop the node (idempotent).
  Future<void> stop() async {
    await rust_api.nodeStop();
  }

  /// If node is running, returns the peer id; otherwise null.
  Future<String?> peerId() {
    return rust_api.nodePeerId();
  }

  /// Return current status snapshot.
  Future<RustNodeStatus> status() async {
    final res = await rust_api.nodeStatus();
    // Rust returns: (running, peer_id, listen_addrs)
    return RustNodeStatus(
      running: res.$1,
      peerId: res.$2,
      listenAddrs: List<String>.unmodifiable(res.$3),
    );
  }
}
