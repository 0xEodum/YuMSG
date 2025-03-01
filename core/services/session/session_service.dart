// lib/core/services/session/session_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/startup/domain/enums/work_mode.dart';
import '../../data/providers/server_data_provider.dart';
import '../../../features/auth/domain/models/auth_data.dart';

class SessionService {
  static const _workModeKey = 'work_mode';
  static const _serverAddressKey = 'server_address';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _deviceIdKey = 'device_id';
  
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final _prefs = SharedPreferences.getInstance();
  WorkMode? _currentWorkMode;

  // Методы для работы с режимом
  Future<void> saveWorkMode(WorkMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(_workModeKey, mode.name);
    _currentWorkMode = mode;
  }

  Future<WorkMode> getWorkMode() async {
    if (_currentWorkMode != null) return _currentWorkMode!;
    
    final prefs = await _prefs;
    final modeName = prefs.getString(_workModeKey);
    if (modeName != null) {
      try {
        _currentWorkMode = WorkMode.values.firstWhere(
          (mode) => mode.name == modeName
        );
        return _currentWorkMode!;
      } catch (e) {
        return WorkMode.server;
      }
    }
    return WorkMode.server; // Возвращаем WorkMode.server по умолчанию
  }

  // Методы для работы с адресом сервера
  Future<void> saveServerAddress(String address) async {
    final prefs = await _prefs;
    await prefs.setString(_serverAddressKey, address);

    // Инициализируем провайдер данных с новым адресом
    if (_currentWorkMode == WorkMode.server) {
      ServerDataProvider.initialize('http://$address');
    }
  }

  Future<void> initializeServerProvider() async {
    final address = await getServerAddress();
    final mode = await getWorkMode();

    if (mode == WorkMode.server && address != null) {
      ServerDataProvider.initialize('http://$address');
    }
  }


  Future<String?> getServerAddress() async {
    final prefs = await _prefs;
    return prefs.getString(_serverAddressKey);
  }

  // Методы для работы с данными сессии
  Future<void> saveAuthData(AuthData data) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(_accessTokenKey, data.accessToken),
      prefs.setString(_refreshTokenKey, data.refreshToken),
      prefs.setString(_deviceIdKey, data.deviceId),
    ]);
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_workModeKey),
      prefs.remove(_serverAddressKey),
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_deviceIdKey),
    ]);
    _currentWorkMode = null;
  }

  Future<bool> hasValidSession() async {
    final mode = await getWorkMode();
    if (mode == null) return false;

    final prefs = await _prefs;
    if (mode == WorkMode.server) {
      return prefs.containsKey(_accessTokenKey) && 
             prefs.containsKey(_refreshTokenKey) &&
             prefs.containsKey(_serverAddressKey);
    } else {
      // Для локального режима достаточно наличия режима работы
      return true;
    }
  }

  Future<AuthData?> getAuthData() async {
    final prefs = await _prefs;
    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final deviceId = prefs.getString(_deviceIdKey);

    if (accessToken != null && refreshToken != null && 
        deviceId != null) {
      return AuthData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        deviceId: deviceId,
      );
    }

    return null;
  }

  Future<bool> hasFullSession() async {
    final mode = await getWorkMode();
    if (mode != WorkMode.server) return false;

    final prefs = await _prefs;
    return prefs.containsKey(_accessTokenKey) && 
           prefs.containsKey(_refreshTokenKey) &&
           prefs.containsKey(_deviceIdKey) &&
           prefs.containsKey(_serverAddressKey);
  }

  // Проверка наличия конфигурации сервера
  Future<bool> hasServerConfig() async {
    final mode = await getWorkMode();
    if (mode != WorkMode.server) return false;

    final prefs = await _prefs;
    return prefs.containsKey(_serverAddressKey);
  }

  // Проверка наличия режима работы
  Future<bool> hasWorkMode() async {
    final prefs = await _prefs;
    return prefs.containsKey(_workModeKey);
  }

  // Очистка данных сервера
  Future<void> clearServerData() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove(_serverAddressKey),
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_deviceIdKey),
    ]);
    ServerDataProvider.reset();
  }

  // Очистка режима работы
  Future<void> clearWorkMode() async {
    final prefs = await _prefs;
    await prefs.remove(_workModeKey);
    _currentWorkMode = null;
  }
  
}