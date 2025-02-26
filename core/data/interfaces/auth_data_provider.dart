import '../../../features/auth/domain/models/auth_result.dart';
import '../../../features/server_connection/domain/models/connection_status.dart';
import '../models/device_info.dart';

abstract class AuthDataProvider {
  /// Проверяет подключение к серверу
  Future<ConnectionStatus> checkConnection(String address);

  /// Регистрация нового пользователя
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  });

  /// Авторизация пользователя
  Future<AuthResult> login({
    required String email,
    required String password,
  });

  /// Обновление токена
  Future<AuthResult> refreshToken({
    required String refreshToken,
    required String deviceId,
  });

  /// Выход с устройства
  Future<void> logout({
    required String deviceId,
    required String token,
  });

  /// Получение списка активных устройств
  Future<List<DeviceInfo>> getDevices({
    required String token,
  });
}
