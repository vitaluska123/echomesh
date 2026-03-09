import 'package:flutter/material.dart';

/// Chats tab (MVP).
///
/// UI requirements from spec:
/// - Search field above the list
/// - List of chats (placeholder for now)
///
/// Later integration points:
/// - Replace [_allChats] with persisted chat index (drift/sqlite)
/// - Wire list to Rust/libp2p messaging layer (request-response + store-and-forward)
/// - Add unread counters, delivery state, typing indicators, etc.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Placeholder fake data for UI bring-up.
  // Replace with your real chat summaries.
  late final List<_ChatSummary> _allChats = <_ChatSummary>[
    _ChatSummary(
      id: 'chat_alex',
      title: 'Alex',
      lastMessage: 'Го на пары? Я у входа.',
      lastActivity: DateTime.now().subtract(const Duration(minutes: 2)),
      unreadCount: 2,
    ),
    _ChatSummary(
      id: 'chat_mom',
      title: 'Мама',
      lastMessage: 'Ок, жду.',
      lastActivity: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
    ),
    _ChatSummary(
      id: 'chat_team',
      title: 'Команда',
      lastMessage: 'Я залил новый билд, проверьте.',
      lastActivity: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      unreadCount: 5,
    ),
    _ChatSummary(
      id: 'chat_ivan',
      title: 'Иван',
      lastMessage: 'Супер, завтра созвон?',
      lastActivity: DateTime.now().subtract(const Duration(days: 4)),
      unreadCount: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchCtrl.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  List<_ChatSummary> get _filteredChats {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _allChats;

    return _allChats.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final chats = _filteredChats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Поиск',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        onPressed: () => _searchCtrl.clear(),
                        icon: const Icon(Icons.close),
                      ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: chats.isEmpty
                ? _EmptyState(query: _query)
                : ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return _ChatTile(
                        chat: chat,
                        onTap: () {
                          // TODO: open chat screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Открыть чат: ${chat.title}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final title = query.isEmpty ? 'Пока нет чатов' : 'Ничего не найдено';
    final subtitle = query.isEmpty
        ? 'Добавь контакт через QR — и здесь появятся чаты.'
        : 'Попробуй изменить запрос.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                query.isEmpty ? Icons.chat_bubble_outline : Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Запрос: "$query"',
                  style: const TextStyle(fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final _ChatSummary chat;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: _AvatarCircle(seed: chat.title),
      title: Text(
        chat.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastActivity),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          if (chat.unreadCount > 0)
            _UnreadBadge(count: chat.unreadCount)
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'сейчас';
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (diff.inHours < 24) return '${diff.inHours}ч';
    return '${diff.inDays}д';
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : '$count';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String seed;

  const _AvatarCircle({required this.seed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorFromSeed(seed, cs);
    final letter = seed.trim().isEmpty ? '?' : seed.trim()[0].toUpperCase();

    return CircleAvatar(
      backgroundColor: color,
      foregroundColor: ThemeData.estimateBrightnessForColor(color) ==
              Brightness.dark
          ? Colors.white
          : Colors.black,
      child: Text(
        letter,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _colorFromSeed(String s, ColorScheme cs) {
    // Simple deterministic color selection.
    final code = s.runes.fold<int>(0, (acc, r) => (acc + r) & 0x7fffffff);
    final palette = <Color>[
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.surfaceContainerHighest,
    ];
    return palette[code % palette.length];
  }
}

@immutable
class _ChatSummary {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime lastActivity;
  final int unreadCount;

  const _ChatSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastActivity,
    required this.unreadCount,
  });
}
