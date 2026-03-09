import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../core/profile/profile_store.dart';
import '../core/rust/rust_node.dart';
import '../core/theme/appearance_store.dart';
import '../core/theme/theme_builder.dart';
import '../ui/shell/app_shell.dart';

/// Root application widget.
///
/// Responsibilities:
/// - Initialize local persistent stores (e.g. profile via SharedPreferences)
/// - Initialize appearance preferences (theme mode, accent preference)
/// - Initialize Rust node service wrapper (loading the native library happens in `main.dart`)
/// - Provide the main UI shell (bottom navigation: Profile / Chats / Settings)
///
/// Notes:
/// - This keeps initialization logic out of UI pages.
/// - Later you can evolve this into dependency injection (Provider/Riverpod) without
///   rewriting feature modules.
class EchoMeshApp extends StatefulWidget {
  const EchoMeshApp({super.key});

  @override
  State<EchoMeshApp> createState() => _EchoMeshAppState();
}

class _EchoMeshAppState extends State<EchoMeshApp> {
  late final ProfileStore _profileStore;
  late final AppearanceStore _appearanceStore;
  late final RustNodeService _node;

  bool _ready = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _profileStore = ProfileStore();
    _appearanceStore = AppearanceStore();
    _node = const RustNodeService();
    _init();
  }

  Future<void> _init() async {
    try {
      // Load persisted profile/settings.
      await Future.wait([
        _profileStore.load(),
        _appearanceStore.load(),
      ]);

      // Optional: you can auto-start the node here later.
      // For now, keep it manual via UI to simplify debugging and battery considerations.
      //
      // await _node.start(
      //   listenAddr: '/ip4/0.0.0.0/tcp/0',
      //   enableQuic: false,
      // );

      if (!mounted) return;
      setState(() {
        _ready = true;
        _initError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _initError = e;
      });
    }
  }

  @override
  void dispose() {
    _profileStore.dispose();
    _appearanceStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use system dynamic color schemes when available (Android 12+),
    // otherwise fall back to a neutral seeded M3 scheme.
    return DynamicColorBuilder(
      builder: (dynamicLight, dynamicDark) {
        final themes = ThemeBuilder.build(
          light: dynamicLight,
          dark: dynamicDark,
          seed: const ThemeSeed.fallback(),
        );

        return AnimatedBuilder(
          animation: _appearanceStore,
          builder: (context, _) {
            return MaterialApp(
              title: 'EchoMesh',
              theme: themes.light,
              darkTheme: themes.dark,
              themeMode: _appearanceStore.settings.themeMode,
              home: _buildHome(),
            );
          },
        );
      },
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return _InitErrorScreen(
        error: _initError!,
        onRetry: () {
          setState(() {
            _initError = null;
            _ready = false;
          });
          _init();
        },
      );
    }

    if (!_ready) {
      return const _SplashScreen();
    }

    return AppShell(
      profileStore: _profileStore,
      node: _node,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 56,
                  color: cs.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'EchoMesh',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Инициализация…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _InitErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ошибка запуска'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Не удалось инициализировать приложение.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error.toString(),
                  style: TextStyle(
                    color: cs.error,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
