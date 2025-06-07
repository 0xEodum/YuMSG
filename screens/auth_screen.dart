// screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:yumsg/widgets/scrollable_card.dart';
import '../services/app_state_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _securityInfoOpen = false;
  bool _isLoading = false;
  String? _error;
  
  // Controllers для форм
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _localUsernameController = TextEditingController();

  // Данные организации (получаются с сервера в реальном приложении)
  final OrganizationInfo _organization = OrganizationInfo(
    name: "Orochi Technologies (大蛇)",
    algorithms: AlgorithmInfo(
      keyExchange: "SNTRU Prime",
      encryption: "AES-256",
      signature: "Falcon",
    ),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Слушаем изменения вкладок для перестройки UI
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    _localUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final appMode = AppStateService.getAppMode();

  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ScrollableCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Шапка с кнопкой назад
              _buildHeader(isDark),
              const SizedBox(height: 16),

              // Контент в зависимости от режима
              if (appMode == 'server')
                _buildServerModeContent(isDark)
              else
                _buildLocalModeContent(isDark),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        IconButton(
          onPressed: _isLoading ? null : _handleBack,
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Авторизация',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerModeContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Информация об организации
        _buildOrganizationInfo(isDark),
        const SizedBox(height: 24),
        
        // Параметры безопасности
        _buildSecurityInfo(isDark),
        const SizedBox(height: 24),
        
        // Табы для переключения между входом и регистрацией
        _buildTabBar(isDark),
        const SizedBox(height: 24),
        
        // Содержимое вкладок с анимированным размером
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: double.infinity,
            child: _tabController.index == 0
                ? _buildLoginForm(isDark)
                : _buildRegisterForm(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalModeContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Информационное сообщение для локального режима
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.2) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.computer,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Локальный режим: введите ваше имя для работы в локальной сети',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        _buildLocalAuthForm(isDark),
      ],
    );
  }

  Widget _buildOrganizationInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF581C87).withOpacity(0.2) 
            : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Аватар организации
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF7C3AED) 
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                _organization.name.substring(0, 1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark 
                      ? const Color(0xFFE5E7EB) 
                      : const Color(0xFF7C3AED),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Название организации
          Expanded(
            child: Text(
              _organization.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark 
                    ? const Color(0xFF8B5CF6) 
                    : const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Заголовок с кнопкой раскрытия
          InkWell(
            onTap: () => setState(() => _securityInfoOpen = !_securityInfoOpen),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Параметры безопасности',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Icon(
                    _securityInfoOpen 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          
          // Содержимое (раскрывающееся)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _securityInfoOpen ? null : 0,
            curve: Curves.easeInOut,
            child: _securityInfoOpen ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  _buildSecurityParameter('Обмен ключами:', _organization.algorithms.keyExchange, isDark),
                  const SizedBox(height: 8),
                  _buildSecurityParameter('Шифрование сообщений:', _organization.algorithms.encryption, isDark),
                  const SizedBox(height: 8),
                  _buildSecurityParameter('Цифровая подпись:', _organization.algorithms.signature, isDark),
                ],
              ),
            ) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityParameter(String label, String value, bool isDark) {
    return Row(
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Вкладка "Вход"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabController.index = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _tabController.index == 0
                      ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _tabController.index == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Вход',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _tabController.index == 0
                        ? (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED))
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    fontWeight: _tabController.index == 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          
          // Вкладка "Регистрация"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabController.index = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _tabController.index == 1
                      ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _tabController.index == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Регистрация',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _tabController.index == 1
                        ? (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED))
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    fontWeight: _tabController.index == 1 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Column(
      children: [
        // Email поле
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'example@company.com',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Password поле
        _buildTextField(
          controller: _passwordController,
          label: 'Пароль',
          hint: '••••••••',
          icon: Icons.lock,
          isPassword: true,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Ошибка
        if (_error != null) ...[
          _buildErrorMessage(_error!, isDark),
          const SizedBox(height: 16),
        ],
        
        // Кнопка входа
        _buildAuthButton(
          text: 'Войти',
          onPressed: _handleLogin,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildRegisterForm(bool isDark) {
    return Column(
      children: [
        // Username поле
        _buildTextField(
          controller: _usernameController,
          label: 'Имя пользователя',
          hint: 'username',
          icon: Icons.person,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Email поле
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'example@company.com',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Password поле
        _buildTextField(
          controller: _passwordController,
          label: 'Пароль',
          hint: '••••••••',
          icon: Icons.lock,
          isPassword: true,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Confirm Password поле
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Подтверждение пароля',
          hint: '••••••••',
          icon: Icons.lock,
          isPassword: true,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Ошибка
        if (_error != null) ...[
          _buildErrorMessage(_error!, isDark),
          const SizedBox(height: 16),
        ],
        
        // Кнопка регистрации
        _buildAuthButton(
          text: 'Зарегистрироваться',
          onPressed: _handleRegister,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLocalAuthForm(bool isDark) {
    return Column(
      children: [
        _buildTextField(
          controller: _localUsernameController,
          label: 'Имя пользователя',
          hint: 'Иван Иванов',
          icon: Icons.person,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        
        // Ошибка
        if (_error != null) ...[
          _buildErrorMessage(_error!, isDark),
          const SizedBox(height: 16),
        ],
        
        // Кнопка входа
        _buildAuthButton(
          text: 'Войти',
          onPressed: _handleLocalAuth,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
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
            hintText: hint,
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

  Widget _buildAuthButton({
    required String text,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Подождите...'),
                ],
              )
            : Text(text),
      ),
    );
  }

  void _handleBack() {
    // Получаем логически предыдущий экран
    final previousRoute = AppStateService.getPreviousRoute(AppScreen.auth);
    
    if (previousRoute != null) {
      Navigator.pushReplacementNamed(context, previousRoute);
    } else {
      // Если предыдущего экрана нет, просто закрываем текущий
      Navigator.pop(context);
    }
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Пожалуйста, заполните все поля');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Плейсхолдер для запроса авторизации
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Имитация успешной авторизации
    await AppStateService.saveUserSession(
      username: _emailController.text,
      token: 'mock_jwt_token',
      organizationId: 'mock_org_id',
    );

    setState(() => _isLoading = false);

    // Переход к списку чатов
    Navigator.pushReplacementNamed(context, '/chat-list');
  }

  void _handleRegister() async {
    if (_usernameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      setState(() => _error = 'Пожалуйста, заполните все поля');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Плейсхолдер для запроса регистрации
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Имитация успешной регистрации
    await AppStateService.saveUserSession(
      username: _emailController.text,
      token: 'mock_jwt_token',
      organizationId: 'mock_org_id',
    );

    setState(() => _isLoading = false);

    // Переход к списку чатов
    Navigator.pushReplacementNamed(context, '/chat-list');
  }

  void _handleLocalAuth() async {
    if (_localUsernameController.text.isEmpty) {
      setState(() => _error = 'Пожалуйста, введите имя пользователя');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Плейсхолдер для локальной авторизации
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    await AppStateService.saveLocalUser(_localUsernameController.text);

    setState(() => _isLoading = false);

    // Переход к списку чатов
    Navigator.pushReplacementNamed(context, '/chat-list');
  }
}

class OrganizationInfo {
  final String name;
  final AlgorithmInfo algorithms;

  OrganizationInfo({required this.name, required this.algorithms});
}

class AlgorithmInfo {
  final String keyExchange;
  final String encryption;
  final String signature;

  AlgorithmInfo({
    required this.keyExchange,
    required this.encryption,
    required this.signature,
  });
}