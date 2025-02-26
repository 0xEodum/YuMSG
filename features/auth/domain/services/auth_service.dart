import 'package:uuid/uuid.dart';
import '../../../../core/data/interfaces/auth_data_provider.dart';
import '../../../../core/data/models/device_info.dart';
import '../../../../core/data/providers/server_data_provider.dart';
import '../models/auth_result.dart';
import '../models/auth_data.dart';
import '../models/validation_result.dart';
import 'crypto_service.dart';

class AuthService {
  AuthDataProvider? _dataProvider;
  final CryptoService _cryptoService;

  AuthService({
    CryptoService? cryptoService,
  }) : _cryptoService = cryptoService ?? CryptoService();

  AuthDataProvider get dataProvider {
    // Для локального режима можно будет вернуть LocalDataProvider
    return _dataProvider ?? ServerDataProvider.instance;
  }

  void setDataProvider(AuthDataProvider provider) {
    _dataProvider = provider;
  }

  Future<AuthResult> login(String email, String password) async {
    return dataProvider.login(
      email: email,
      password: password,
    );
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    
    return dataProvider.register(
      username: username,
      email: email,
      password: password,
    );
  }

  Future<AuthResult> refreshToken(String refreshToken, String deviceId) async {
    return dataProvider.refreshToken(
      refreshToken: refreshToken,
      deviceId: deviceId,
    );
  }

  Future<void> logout(String token, String deviceId) async {
    await dataProvider.logout(
      token: token,
      deviceId: deviceId,
    );
  }

  Future<List<DeviceInfo>> getDevices(String token) async {
    return dataProvider.getDevices(token: token);
  }

  ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult.invalid('Email не может быть пустым');
    }
    
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return ValidationResult.invalid('Некорректный формат email');
    }
    
    return ValidationResult.valid();
  }

  ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult.invalid('Пароль не может быть пустым');
    }
    
    if (password.length < 6) {
      return ValidationResult.invalid('Пароль должен содержать минимум 6 символов');
    }
    
    return ValidationResult.valid();
  }

  ValidationResult validateUsername(String username) {
    if (username.isEmpty) {
      return ValidationResult.invalid('Имя пользователя не может быть пустым');
    }
    
    if (username.length < 3) {
      return ValidationResult.invalid('Имя пользователя должно содержать минимум 3 символа');
    }
    
    return ValidationResult.valid();
  }

  ValidationResult validatePasswordConfirmation(String password, String confirmation) {
    if (password != confirmation) {
      return ValidationResult.invalid('Пароли не совпадают');
    }
    
    return ValidationResult.valid();
  }
}