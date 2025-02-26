// lib/features/auth/presentation/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/services/navigation/navigation_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../startup/domain/enums/work_mode.dart';
import '../../domain/models/auth_state.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/models/validation_result.dart';
import '../../domain/services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class AuthScreen extends StatefulWidget {
  final WorkMode workMode;

  const AuthScreen({
    super.key,
    required this.workMode,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final _navigationService = NavigationService();
  final _sessionService = SessionService();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  AuthMode _currentMode = AuthMode.login;
  bool _isLoading = false;
  String? _errorMessage;
  final Map<String, String?> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
  if (widget.workMode == WorkMode.server) {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text(
          'При возврате данные подключения к серверу будут сброшены. Продолжить?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Очищаем данные сервера
    await _sessionService.clearServerData();
    
    if (mounted) {
      // Используем replaceTo вместо обычного возврата
      await _navigationService.replaceTo(AppRouter.serverConnection);
    }
  } else {
    if (mounted) {
      await _navigationService.replaceTo(AppRouter.start);
    }
  }
}

  void _handleTabChange() {
    if (_tabController.index == 0) {
      setState(() {
        _currentMode = AuthMode.login;
      });
    } else {
      setState(() {
        _currentMode = AuthMode.register;
      });
    }
    _clearErrors();
  }

  void _clearErrors() {
    setState(() {
      _errorMessage = null;
      _validationErrors.clear();
    });
  }

  ValidationResult _validateForm() {
    _validationErrors.clear();

    // Валидация email
    final emailValidation = _authService.validateEmail(_emailController.text);
    if (!emailValidation.isValid) {
      _validationErrors['email'] = emailValidation.error;
    }

    // Валидация пароля
    final passwordValidation = _authService.validatePassword(_passwordController.text);
    if (!passwordValidation.isValid) {
      _validationErrors['password'] = passwordValidation.error;
    }

    // Дополнительная валидация для регистрации
    if (_currentMode == AuthMode.register) {
      final usernameValidation = _authService.validateUsername(_usernameController.text);
      if (!usernameValidation.isValid) {
        _validationErrors['username'] = usernameValidation.error;
      }

      final confirmValidation = _authService.validatePasswordConfirmation(
        _passwordController.text,
        _confirmPasswordController.text,
      );
      if (!confirmValidation.isValid) {
        _validationErrors['confirmPassword'] = confirmValidation.error;
      }
    }

    setState(() {});
    return _validationErrors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid('Проверьте правильность заполнения полей');
  }

  Future<void> _handleSubmit() async {
    final validation = _validateForm();
    if (!validation.isValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      late final AuthResult result;
      
      if (widget.workMode == WorkMode.server) {
        // Для серверного режима выполняем реальную авторизацию
        if (_currentMode == AuthMode.login) {
          result = await _authService.login(
            _emailController.text,
            _passwordController.text,
          );
        } else {
          result = await _authService.register(
            username: _usernameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
        }

        if (result.success) {
          // Сохраняем данные авторизации
          await _sessionService.saveAuthData(result.data!);
          if (mounted) {
            await _navigationService.navigateToAndRemoveUntil('/main');
          }
        } else {
          setState(() {
            _errorMessage = result.error;
          });
        }
      } else {
        // Для локального режима просто создаем локальный профиль
        // TODO: Реализовать сохранение локального профиля
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          await _navigationService.navigateToAndRemoveUntil('/main');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла ошибка при выполнении операции';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          if (widget.workMode == WorkMode.server) _buildTabs(),
                          const SizedBox(height: 24),
                          _buildForm(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorMessage(),
                          ],
                          const SizedBox(height: 24),
                          AuthButton(
                            text: _getButtonText(),
                            onPressed: _handleSubmit,
                            loading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (widget.workMode == WorkMode.local) {
      return _currentMode == AuthMode.login 
          ? 'Войти локально'
          : 'Создать локальный профиль';
    }
    return _currentMode == AuthMode.login ? 'Войти' : 'Зарегистрироваться';
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _handleBack,
        ),
        const SizedBox(width: 8),
        Text(
          widget.workMode == WorkMode.server 
              ? 'Вход в систему'
              : 'Локальный профиль',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        tabs: [
          Tab(text: AuthMode.login.title),
          Tab(text: AuthMode.register.title),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return _currentMode == AuthMode.login
        ? _buildLoginForm()
        : _buildRegisterForm();
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        AuthTextField(
          label: 'Email',
          hint: 'Введите email',
          icon: Icons.email_outlined,
          controller: _emailController,
          errorText: _validationErrors['email'],
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _clearErrors(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Пароль',
          hint: 'Введите пароль',
          icon: Icons.lock_outline,
          controller: _passwordController,
          errorText: _validationErrors['password'],
          enabled: !_isLoading,
          obscureText: true,
          onChanged: (_) => _clearErrors(),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        AuthTextField(
          label: 'Имя пользователя',
          hint: 'Введите имя пользователя',
          icon: Icons.person_outline,
          controller: _usernameController,
          errorText: _validationErrors['username'],
          enabled: !_isLoading,
          onChanged: (_) => _clearErrors(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Email',
          hint: 'Введите email',
          icon: Icons.email_outlined,
          controller: _emailController,
          errorText: _validationErrors['email'],
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _clearErrors(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Пароль',
          hint: 'Введите пароль',
          icon: Icons.lock_outline,
          controller: _passwordController,
          errorText: _validationErrors['password'],
          enabled: !_isLoading,
          obscureText: true,
          onChanged: (_) => _clearErrors(),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'Подтверждение пароля',
          hint: 'Повторите пароль',
          icon: Icons.lock_outline,
          controller: _confirmPasswordController,
          errorText: _validationErrors['confirmPassword'],
          enabled: !_isLoading,
          obscureText: true,
          onChanged: (_) => _clearErrors(),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}