// screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:yumsg/widgets/scrollable_card.dart';
import '../services/app_state_service.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  String? _error;

  // Контроллеры для редактирования
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final appMode = AppStateService.getAppMode();
    
    if (appMode == 'local') {
      final localUser = AppStateService.getLocalUser();
      _usernameController.text = localUser ?? '';
    } else {
      final userSession = AppStateService.getUserSession();
      _usernameController.text = userSession['username'] ?? '';
      _emailController.text = userSession['username'] ?? ''; // В серверном режиме username это email
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final appMode = AppStateService.getAppMode();

    return Scaffold(
      body: Column(
        children: [
          // Заголовок
          _buildHeader(isDark, statusBarHeight),
          
          // Основной контент
          Expanded(
            child: ScrollableCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Аватар и основная информация
                  _buildProfileHeader(isDark, appMode),
                  const SizedBox(height: 24),

                  // Информация профиля
                  if (appMode == 'server')
                    _buildServerProfile(isDark)
                  else
                    _buildLocalProfile(isDark),
                  
                  const SizedBox(height: 24),

                  // Дополнительная информация
                  if (appMode == 'server') ...[
                    _buildServerInfo(isDark),
                    const SizedBox(height: 24),
                  ],

                  // Кнопки действий
                  _buildActionButtons(isDark, appMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, double statusBarHeight) {
    return Container(
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
              'Профиль',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
          if (!_isEditing)
            IconButton(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.edit),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark, String? appMode) {
    final userName = appMode == 'local' 
        ? AppStateService.getLocalUser() ?? 'Пользователь'
        : AppStateService.getUserSession()['username'] ?? 'Пользователь';

    return Column(
      children: [
        // Аватар
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'П',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Имя пользователя
        Text(
          userName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        
        // Статус онлайн
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Онлайн',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerProfile(bool isDark) {
    final userSession = AppStateService.getUserSession();
    final serverConfig = AppStateService.getServerConfig();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Text(
          'Информация профиля',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),

        if (_isEditing) ...[
          // Режим редактирования
          _buildTextField(
            controller: _usernameController,
            label: 'Имя пользователя',
            icon: Icons.person,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Смена пароля
          Text(
            'Смена пароля (необязательно)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _currentPasswordController,
            label: 'Текущий пароль',
            icon: Icons.lock,
            isPassword: true,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _newPasswordController,
            label: 'Новый пароль',
            icon: Icons.lock_reset,
            isPassword: true,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Подтверждение пароля',
            icon: Icons.lock_reset,
            isPassword: true,
            isDark: isDark,
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(_error!, isDark),
          ],
        ] else ...[
          // Режим просмотра
          _buildInfoItem(
            icon: Icons.person,
            label: 'Имя пользователя',
            value: userSession['username'] ?? 'Не указано',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildInfoItem(
            icon: Icons.email,
            label: 'Email',
            value: userSession['username'] ?? 'Не указано',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildInfoItem(
            icon: Icons.business,
            label: 'Организация',
            value: serverConfig['organization_name'] ?? 'Не указана',
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildLocalProfile(bool isDark) {
    final localUser = AppStateService.getLocalUser();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Text(
          'Информация профиля',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),

        if (_isEditing) ...[
          // Режим редактирования
          _buildTextField(
            controller: _usernameController,
            label: 'Имя пользователя',
            icon: Icons.person,
            isDark: isDark,
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(_error!, isDark),
          ],
        ] else ...[
          // Режим просмотра
          _buildInfoItem(
            icon: Icons.person,
            label: 'Имя пользователя',
            value: localUser ?? 'Не указано',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          _buildInfoItem(
            icon: Icons.computer,
            label: 'Режим работы',
            value: 'Локальная сеть',
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildServerInfo(bool isDark) {
    final serverConfig = AppStateService.getServerConfig();
    final userSession = AppStateService.getUserSession();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Информация сервера',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),

        _buildInfoItem(
          icon: Icons.dns,
          label: 'Адрес сервера',
          value: '${serverConfig['ip'] ?? 'Неизвестно'}:${serverConfig['port'] ?? 'Неизвестно'}',
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        _buildInfoItem(
          icon: Icons.security,
          label: 'Статус подключения',
          value: 'Подключено',
          isDark: isDark,
          valueColor: Colors.green,
        ),
        const SizedBox(height: 16),

        _buildInfoItem(
          icon: Icons.access_time,
          label: 'Время входа',
          value: _getLoginTime(userSession),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
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
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1F2937)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: !_isLoading,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF7F1D1D).withOpacity(0.2) 
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, String? appMode) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _cancelEditing,
              child: const Text('Отмена'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Сохранить'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _toggleEditMode,
            icon: const Icon(Icons.edit),
            label: const Text('Редактировать профиль'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showChangeAvatarDialog,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Изменить аватар'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  String _getLoginTime(Map<String, String?> userSession) {
    // Заглушка для времени входа
    return 'Сегодня в 14:32';
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _error = null;
    });
    
    if (_isEditing) {
      _loadUserData();
    } else {
      _clearPasswordFields();
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _error = null;
    });
    _loadUserData();
    _clearPasswordFields();
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  void _saveProfile() async {
    final appMode = AppStateService.getAppMode();
    
    if (appMode == 'local') {
      await _saveLocalProfile();
    } else {
      await _saveServerProfile();
    }
  }

  Future<void> _saveLocalProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _error = 'Имя пользователя не может быть пустым');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Имитация сохранения
      await Future.delayed(const Duration(seconds: 1));
      
      await AppStateService.saveLocalUser(_usernameController.text.trim());
      
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлен')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка при сохранении профиля';
      });
    }
  }

  Future<void> _saveServerProfile() async {
    if (_usernameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      setState(() => _error = 'Заполните все обязательные поля');
      return;
    }

    // Проверка паролей, если они введены
    if (_newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        setState(() => _error = 'Введите текущий пароль');
        return;
      }
      
      if (_newPasswordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Новые пароли не совпадают');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Имитация сохранения на сервере
      await Future.delayed(const Duration(seconds: 2));
      
      // В реальном приложении здесь был бы API вызов
      // Пока просто обновляем локальную сессию
      await AppStateService.saveUserSession(
        username: _emailController.text.trim(),
        token: 'updated_token',
        organizationId: 'org_id',
      );
      
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      _clearPasswordFields();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлен')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка при сохранении профиля';
      });
    }
  }

  void _showChangeAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить аватар'),
        content: const Text('Функция изменения аватара будет доступна в следующих версиях'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }
}