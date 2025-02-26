import 'package:flutter/material.dart';
import 'package:yumsg/core/navigation/app_router.dart';
import 'package:yumsg/features/startup/domain/enums/work_mode.dart';

class SidePanel extends StatelessWidget {
  final WorkMode workMode;
  final ValueChanged<WorkMode> onWorkModeChanged;
  final VoidCallback onClose;

  const SidePanel({
    super.key,
    required this.workMode,
    required this.onWorkModeChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Меню',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Режим работы',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Radio<WorkMode>(
                      value: WorkMode.server,
                      groupValue: workMode,
                      onChanged: (value) {
                        if (value != null) onWorkModeChanged(value);
                      },
                    ),
                    const Icon(Icons.cloud_outlined, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Серверный режим'),
                  ],
                ),
                Row(
                  children: [
                    Radio<WorkMode>(
                      value: WorkMode.local,
                      groupValue: workMode,
                      onChanged: (value) {
                        if (value != null) onWorkModeChanged(value);
                      },
                    ),
                    const Icon(Icons.laptop_outlined, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Локальный режим'),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Профиль'),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.profile);
              Navigator.of(context).pop(); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Хранилище'),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.storage);
              Navigator.of(context).pop(); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.sett1ngs);
              Navigator.of(context).pop(); // Close drawer
            },
          ),
        ],
      ),
    );
  }
}