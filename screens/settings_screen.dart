// screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/app_state_service.dart';
import '../services/theme_service.dart';
import 'profile_screen.dart';
import 'encryption_settings_screen.dart'; // Добавляем импорт нового экрана

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedTheme = 'system';
  String _selectedColorScheme = 'purple';
  String _selectedFontSize = 'medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Загружаем текущую тему из ThemeService
    final themeService = ThemeService();
    switch (themeService.themeMode) {
      case ThemeMode.light:
        _selectedTheme = 'light';
        break;
      case ThemeMode.dark:
        _selectedTheme = 'dark';
        break;
      case ThemeMode.system:
        _selectedTheme = 'system';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final appMode = AppStateService.getAppMode();
    final userSession = AppStateService.getUserSession();
    final localUser = AppStateService.getLocalUser();

    return Scaffold(
      body: Column(
        children: [
          // Заголовок с отступом для системной шторки
          Container(
            padding: EdgeInsets.only(
              top: statusBarHeight + 8,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => ThemeService().toggleTheme(),
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Основной контент
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Блок профиля
                  _buildProfileCard(isDark, appMode, userSession, localUser),
                  const SizedBox(height: 16),

                  // Безопасность и конфиденциальность
                  _buildSecurityCard(isDark),
                  const SizedBox(height: 16),

                  // Уведомления
                  _buildNotificationsCard(isDark),
                  const SizedBox(height: 16),

                  // Внешний вид
                  _buildAppearanceCard(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isDark, String? appMode, Map<String, String?> userSession, String? localUser) {
    final userName = appMode == 'local' ? localUser ?? 'Пользователь' : userSession['username'] ?? 'Пользователь';
    final userEmail = appMode == 'local' ? null : userSession['username'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Аватар
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'А',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Информация пользователя
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  if (userEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _handleEditProfile,
                    child: Text(
                      'Редактировать профиль',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(bool isDark) {
    return _buildSettingsCard(
      title: 'Безопасность и конфиденциальность',
      isDark: isDark,
      children: [
        _buildSettingsItem(
          icon: Icons.security,
          title: 'Сквозное шифрование',
          subtitle: 'Настройка алгоритмов защиты сообщений и файлов',
          onTap: _handleEncryptionSettings,
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildSettingsItem(
          icon: Icons.contacts,
          title: 'Управление контактами',
          subtitle: 'Блокировка и удаление контактов',
          onTap: _handleContactsSettings,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildNotificationsCard(bool isDark) {
    return _buildSettingsCard(
      title: 'Уведомления',
      isDark: isDark,
      children: [
        _buildSettingsItem(
          icon: Icons.notifications,
          title: 'Звуки и вибрация',
          subtitle: null,
          onTap: _handleSoundSettings,
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildSwitchItem(
          icon: Icons.message,
          title: 'Уведомления о новых сообщениях',
          value: _notificationsEnabled,
          onChanged: _handleNotificationToggle,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildAppearanceCard(bool isDark) {
    return _buildSettingsCard(
      title: 'Внешний вид',
      isDark: isDark,
      children: [
        _buildValueItem(
          icon: Icons.palette,
          title: 'Тема',
          value: _getThemeDisplayName(_selectedTheme),
          onTap: _handleThemeSettings,
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildValueItem(
          icon: Icons.color_lens,
          title: 'Цветовая схема',
          value: _getColorSchemeDisplayName(_selectedColorScheme),
          onTap: _handleColorSchemeSettings,
          isDark: isDark,
          trailing: _buildColorPreview(),
        ),
        _buildDivider(isDark),
        _buildValueItem(
          icon: Icons.text_fields,
          title: 'Размер шрифта',
          value: _getFontSizeDisplayName(_selectedFontSize),
          onTap: _handleFontSizeSettings,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildValueItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
    );
  }

  Widget _buildColorPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColorCircle(Theme.of(context).colorScheme.primary, true),
        const SizedBox(width: 4),
        _buildColorCircle(Colors.teal, false),
        const SizedBox(width: 4),
        _buildColorCircle(Colors.orange, false),
        const SizedBox(width: 4),
        _buildColorCircle(Colors.pink, false),
      ],
    );
  }

  Widget _buildColorCircle(Color color, bool isSelected) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: isSelected 
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'light':
        return 'Светлая';
      case 'dark':
        return 'Тёмная';
      case 'system':
        return 'Системная';
      default:
        return 'Системная';
    }
  }

  String _getColorSchemeDisplayName(String scheme) {
    switch (scheme) {
      case 'purple':
        return 'Фиолетовая';
      case 'teal':
        return 'Бирюзовая';
      case 'orange':
        return 'Оранжевая';
      case 'pink':
        return 'Розовая';
      default:
        return 'Фиолетовая';
    }
  }

  String _getFontSizeDisplayName(String size) {
    switch (size) {
      case 'small':
        return 'Маленький';
      case 'medium':
        return 'Средний';
      case 'large':
        return 'Большой';
      default:
        return 'Средний';
    }
  }

  // Обработчики событий
  void _handleEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _handleEncryptionSettings() {
    // ОБНОВЛЕНО: Теперь переходим к экрану настроек шифрования
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EncryptionSettingsScreen(),
      ),
    );
  }

  void _handleContactsSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Управление контактами')),
    );
  }

  void _handleSoundSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки звуков')),
    );
  }

  void _handleNotificationToggle(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Уведомления включены' : 'Уведомления выключены',
        ),
      ),
    );
  }

  void _handleThemeSettings() {
    _showThemeDialog();
  }

  void _handleColorSchemeSettings() {
    _showColorSchemeDialog();
  }

  void _handleFontSizeSettings() {
    _showFontSizeDialog();
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите тему'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('system', 'Системная'),
            _buildThemeOption('light', 'Светлая'),
            _buildThemeOption('dark', 'Тёмная'),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String value, String title) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: _selectedTheme,
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedTheme = newValue;
          });
          
          // Применяем тему
          final themeService = ThemeService();
          switch (newValue) {
            case 'light':
              themeService.setThemeMode(ThemeMode.light);
              break;
            case 'dark':
              themeService.setThemeMode(ThemeMode.dark);
              break;
            case 'system':
              themeService.setThemeMode(ThemeMode.system);
              break;
          }
          
          Navigator.pop(context);
        }
      },
    );
  }

  void _showColorSchemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите цветовую схему'),
        content: const Text('Пока доступна только фиолетовая схема'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите размер шрифта'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFontSizeOption('small', 'Маленький'),
            _buildFontSizeOption('medium', 'Средний'),
            _buildFontSizeOption('large', 'Большой'),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeOption(String value, String title) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: _selectedFontSize,
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedFontSize = newValue;
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Размер шрифта: $title')),
          );
        }
      },
    );
  }
}