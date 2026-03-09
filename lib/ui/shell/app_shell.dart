import 'package:flutter/material.dart';

import '../../core/profile/profile_store.dart';
import '../../core/rust/rust_node.dart';
import '../chats/chats_page.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';

/// Main application shell with bottom navigation.
///
/// Tabs:
/// 1) Profile
/// 2) Chats
/// 3) Settings
///
/// This widget owns only navigation state (selected tab) and wires shared
/// dependencies (profile store + rust node service) into the pages.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = 1,
    required this.profileStore,
    required this.node,
  });

  /// Default to "Chats" as the center of the app.
  final int initialIndex;

  /// Persisted profile/settings store.
  final ProfileStore profileStore;

  /// Rust libp2p node service wrapper.
  final RustNodeService node;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex.clamp(0, 2);

  void _onTap(int value) {
    if (value == _index) return;
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    // Using IndexedStack preserves state of each tab (scroll position, text fields).
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ProfilePage(
            profileStore: widget.profileStore,
            node: widget.node,
          ),
          const ChatsPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
