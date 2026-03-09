import 'package:flutter/material.dart';

/// Settings page (MVP).
///
/// Requirements from README/UX:
/// - Settings grouped by categories
/// - Each category will later contain deeper screens/options
///
/// For now this screen shows placeholder categories and basic navigation stubs.
/// Later we can wire real settings (network, privacy, storage, battery, etc.).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = <_SettingsCategory>[
      const _SettingsCategory(
        title: 'Внешний вид',
        subtitle: 'Тема (системная/светлая/тёмная), акцент, цвета',
        icon: Icons.palette_outlined,
      ),
      const _SettingsCategory(
        title: 'Сеть',
        subtitle: 'Транспорты, relay, DHT, режим изоляции',
        icon: Icons.wifi_tethering,
      ),
      const _SettingsCategory(
        title: 'Приватность',
        subtitle: 'Шифрование, верификация, видимость',
        icon: Icons.lock_outline,
      ),
      const _SettingsCategory(
        title: 'Хранилище',
        subtitle: 'Очередь, медиа, кэш, ограничения',
        icon: Icons.storage_outlined,
      ),
      const _SettingsCategory(
        title: 'Батарея',
        subtitle: 'Экономия, фоновые лимиты, режимы',
        icon: Icons.battery_saver_outlined,
      ),
      const _SettingsCategory(
        title: 'Уведомления',
        subtitle: 'Звук, баннеры, приоритеты',
        icon: Icons.notifications_none,
      ),
      const _SettingsCategory(
        title: 'О приложении',
        subtitle: 'Версия, лицензии, debug',
        icon: Icons.info_outline,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = categories[index];
          return ListTile(
            leading: Icon(c.icon),
            title: Text(c.title),
            subtitle: Text(c.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openCategoryStub(context, c.title),
          );
        },
      ),
    );
  }

  void _openCategoryStub(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsCategoryStubPage(title: title),
      ),
    );
  }
}

class _SettingsCategoryStubPage extends StatelessWidget {
  final String title;

  const _SettingsCategoryStubPage({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Скоро здесь будут настройки этой категории.\n\n'
              'MVP: пока заглушка.\n'
              'Следующий шаг: добавить конкретные опции, сохранить их локально и '
              'передавать в Rust/P2P-ядро.',
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCategory {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SettingsCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
