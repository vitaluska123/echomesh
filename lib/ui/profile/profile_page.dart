import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/profile/profile_store.dart';
import '../../core/qr/pairing_payload.dart';
import '../../core/rust/rust_node.dart';

/// Profile tab:
/// - Display name (persisted via [ProfileStore])
/// - Avatar picker (simple built-in set; persisted via [ProfileStore])
/// - Pairing QR bottom sheet (payload built via [PairingPayloadBuilder] + Rust node status)
class ProfilePage extends StatefulWidget {
  final ProfileStore profileStore;
  final RustNodeService node;

  const ProfilePage({
    super.key,
    required this.profileStore,
    required this.node,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameCtrl;

  bool _loading = true;
  bool _savingName = false;
  bool _showingQr = false;

  String? _error;

  // A small built-in palette for a simple avatar picker (MVP).
  static const _avatarOptions = <_AvatarOption>[
    _AvatarOption(id: 0, color: Color(0xFF6750A4), icon: Icons.person),
    _AvatarOption(id: 1, color: Color(0xFF386A20), icon: Icons.park),
    _AvatarOption(id: 2, color: Color(0xFF006874), icon: Icons.waves),
    _AvatarOption(id: 3, color: Color(0xFF7D5260), icon: Icons.favorite),
    _AvatarOption(
      id: 4,
      color: Color(0xFFB3261E),
      icon: Icons.local_fire_department,
    ),
    _AvatarOption(id: 5, color: Color(0xFF0B57D0), icon: Icons.bolt),
    _AvatarOption(id: 6, color: Color(0xFF4A4458), icon: Icons.psychology),
    _AvatarOption(id: 7, color: Color(0xFF1D192B), icon: Icons.shield),
    _AvatarOption(id: 8, color: Color(0xFF005E2D), icon: Icons.eco),
    _AvatarOption(id: 9, color: Color(0xFF7C4D00), icon: Icons.coffee),
    _AvatarOption(id: 10, color: Color(0xFF004B52), icon: Icons.satellite_alt),
    _AvatarOption(id: 11, color: Color(0xFF3F2E00), icon: Icons.star),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await widget.profileStore.load();
      _nameCtrl.text = widget.profileStore.profile.displayName;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _AvatarOption _currentAvatar(UserProfile profile) {
    return _avatarOptions.firstWhere(
      (o) => o.id == profile.avatarId,
      orElse: () => _avatarOptions.first,
    );
  }

  Future<void> _saveName() async {
    final value = _nameCtrl.text;

    setState(() {
      _savingName = true;
      _error = null;
    });

    try {
      await widget.profileStore.setDisplayName(value);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя сохранено')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _pickAvatar(int avatarId) async {
    setState(() => _error = null);
    try {
      await widget.profileStore.setAvatarId(avatarId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _showPairingQrSheet() async {
    if (_showingQr) return;

    setState(() {
      _showingQr = true;
      _error = null;
    });

    try {
      final builder = PairingPayloadBuilder(widget.profileStore);
      final qrString = await builder.buildQrString(
        node: widget.node,
        pretty: false,
      );

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return _PairingQrSheet(
            qrString: qrString,
            onCopy: () async {
              // Clipboard lives behind services (we avoid adding extra imports here).
              // If you want, we can add a proper copy button using Clipboard from
              // `package:flutter/services.dart`.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Скопировать: добавим в следующем шаге'),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _showingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileStore.profile;
    final avatar = _currentAvatar(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            tooltip: 'QR для сопряжения',
            onPressed: _loading ? null : _showPairingQrSheet,
            icon: const Icon(Icons.qr_code_2),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  title: 'Профиль',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AvatarPreview(option: avatar, size: 56),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _showingQr ? null : _showPairingQrSheet,
                            child: const Text('QR'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        enabled: !_savingName,
                        decoration: const InputDecoration(
                          labelText: 'Имя пользователя',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveName(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            onPressed: _savingName ? null : _saveName,
                            child: _savingName
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Сохранить имя'),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              await widget.profileStore.reset();
                              if (!mounted) return;
                              _nameCtrl.text =
                                  widget.profileStore.profile.displayName;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Профиль сброшен'),
                                ),
                              );
                            },
                            child: const Text('Сбросить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Аватар',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Выбери иконку (MVP). Позже добавим фото из галереи.',
                      ),
                      const SizedBox(height: 12),
                      _AvatarGrid(
                        options: _avatarOptions,
                        selectedId: profile.avatarId,
                        onSelect: _pickAvatar,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Ошибка',
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _PairingQrSheet extends StatelessWidget {
  final String qrString;
  final VoidCallback onCopy;

  const _PairingQrSheet({
    required this.qrString,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR для сопряжения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: QrImageView(
                    data: qrString,
                    version: QrVersions.auto,
                    padding: EdgeInsets.zero,
                    // backgroundColor is important for scanners
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Покажи этот QR другу при встрече (QR/NFC).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Копировать JSON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.done),
                    label: const Text('Готово'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Показать содержимое'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SelectableText(
                    qrString,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  final List<_AvatarOption> options;
  final int selectedId;
  final ValueChanged<int> onSelect;

  const _AvatarGrid({
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final crossAxisCount = width >= 520 ? 6 : 4;

        return GridView.builder(
          itemCount: options.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final o = options[index];
            final selected = o.id == selectedId;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(o.id),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35)
                      : null,
                ),
                child: Center(
                  child: _AvatarPreview(option: o, size: 44),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final _AvatarOption option;
  final double size;

  const _AvatarPreview({
    required this.option,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fg =
        ThemeData.estimateBrightnessForColor(option.color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: option.color,
      foregroundColor: fg,
      child: Icon(option.icon, size: size * 0.55),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
  });

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

class _AvatarOption {
  final int id;
  final Color color;
  final IconData icon;

  const _AvatarOption({
    required this.id,
    required this.color,
    required this.icon,
  });
}
