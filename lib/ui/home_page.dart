import 'package:flutter/material.dart';

import '../core/rust/rust_node.dart';
import '../bridge_generated.dart/api.dart' as rust_api;

/// Home screen used for MVP bring-up.
///
/// Responsibilities:
/// - Display basic Rust/libp2p node lifecycle controls (start/stop/status)
/// - Provide a simple button to call a Rust function (generate peer id)
///
/// Notes:
/// - Keep business logic minimal in UI: delegate to `RustNodeService`.
/// - Later: replace this with proper navigation (contacts, chats, settings).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _defaultListenAddr = '/ip4/0.0.0.0/tcp/0';

  final _node = const RustNodeService();
  final _listenAddrCtrl = TextEditingController(text: _defaultListenAddr);

  bool _busy = false;
  RustNodeStatus? _status;
  String? _lastGeneratedPeerId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _listenAddrCtrl.dispose();
    super.dispose();
  }

  Future<void> _setBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshStatus() async {
    await _setBusy(() async {
      final st = await _node.status();
      if (!mounted) return;
      setState(() => _status = st);
    });
  }

  Future<void> _startNode() async {
    await _setBusy(() async {
      await _node.start(
        listenAddr: _listenAddrCtrl.text.trim().isEmpty
            ? _defaultListenAddr
            : _listenAddrCtrl.text.trim(),
        enableQuic: false, // forward-compatible flag; Rust currently TCP-only
      );
      final st = await _node.status();
      if (!mounted) return;
      setState(() => _status = st);
    });
  }

  Future<void> _stopNode() async {
    await _setBusy(() async {
      await _node.stop();
      final st = await _node.status();
      if (!mounted) return;
      setState(() => _status = st);
    });
  }

  Future<void> _generatePeerId() async {
    await _setBusy(() async {
      final id = await rust_api.generatePeerId();
      if (!mounted) return;
      setState(() => _lastGeneratedPeerId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final running = status?.running ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoMesh — MVP bring-up'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'libp2p Node (TCP)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _listenAddrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Listen addr',
                    hintText: '/ip4/0.0.0.0/tcp/0',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _startNode,
                      child: const Text('Start'),
                    ),
                    OutlinedButton(
                      onPressed: (_busy || !running) ? null : _stopNode,
                      child: const Text('Stop'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _refreshStatus,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _KeyValue(
                  k: 'Running',
                  v: status == null ? '—' : (running ? 'yes' : 'no'),
                ),
                _KeyValue(
                  k: 'PeerId',
                  v: status?.peerId ?? '—',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Listen addrs:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (status == null)
                  const Text('—')
                else if (status.listenAddrs.isEmpty)
                  const Text('(none yet)')
                else
                  ...status.listenAddrs.map(
                    (a) => SelectableText(
                      a,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Rust bridge test',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.tonal(
                  onPressed: _busy ? null : _generatePeerId,
                  child: const Text('Generate PeerId (random)'),
                ),
                const SizedBox(height: 12),
                _KeyValue(
                  k: 'Last generated',
                  v: _lastGeneratedPeerId ?? '—',
                  monospace: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            _Section(
              title: 'Error',
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  final bool monospace;

  const _KeyValue({
    required this.k,
    required this.v,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = monospace
        ? const TextStyle(fontFamily: 'monospace')
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$k:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(v, style: valueStyle)),
        ],
      ),
    );
  }
}
