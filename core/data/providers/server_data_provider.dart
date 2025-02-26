import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:yumsg/features/main/domain/models/search_result.dart';

import '../../../features/auth/domain/models/auth_data.dart';
import '../../../features/auth/domain/models/auth_result.dart';
import '../../../features/server_connection/domain/models/connection_status.dart';
import '../../crypto/services/crypto_service.dart';
import '../../crypto/services/server_secure_channel.dart';
import '../interfaces/auth_data_provider.dart';
import '../models/api_error.dart';
import '../models/device_info.dart';

class ServerDataProvider implements AuthDataProvider {
  final String baseUrl;
  static final _cryptoService = YuCryptoService();
  final ServerSecureChannel _secureChannel;
  bool _isSearchChannelActive = false;

  ServerDataProvider._({
    required this.baseUrl,
    required YuCryptoService cryptoService,
  }) : _secureChannel = ServerSecureChannel(cryptoService: cryptoService);

  static ServerDataProvider? _instance;

  static ServerDataProvider initialize(String serverUrl) {
    _instance = ServerDataProvider._(
      baseUrl: serverUrl,
      cryptoService: _cryptoService,
    );
    return _instance!;
  }

  static ServerDataProvider get instance {
    if (_instance == null) {
      throw StateError('ServerDataProvider not initialized');
    }
    return _instance!;
  }

  static void reset() {
    _instance = null;
  }

  static bool get isInitialized => _instance != null;

  @override
  Future<ConnectionStatus> checkConnection(String address) async {
    try {
      final uri = Uri.parse('http://$address');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );


      if (response.statusCode == 200) {
        return ConnectionStatus.success();
      }

      return ConnectionStatus.error(
          'Сервер недоступен (код: ${response.statusCode})');
    } catch (e) {
      return ConnectionStatus.error(
          'Не удалось подключиться к серверу: ${e.toString()}');
    }
  }

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {

      // 1. Устанавливаем защищенный канал
      await _secureChannel.establishSecureConnection();

      // 2. Отправляем публичный ключ на сервер
      final initResponse = await http.post(
        Uri.parse('$baseUrl/auth/secure-init'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'publicKey': _secureChannel.publicKey,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (initResponse.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(initResponse.body));
      }

      // 3. Получаем и устанавливаем сессионный ключ
      final initData = jsonDecode(initResponse.body);
      await _secureChannel.setSessionKey(initData['sessionKey']);

      // 4. Шифруем данные регистрации
      final encryptedData = await _secureChannel.encryptData(jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'deviceId': const Uuid().v4(),
      }));

      // 5. Отправляем зашифрованные данные
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'data': encryptedData,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(response.body));
      }

      // 6. Расшифровываем ответ с токенами
      final encryptedResponse = jsonDecode(response.body)['data'];
      final decryptedData = await _secureChannel.decryptData(encryptedResponse);
      final authData = AuthData.fromJson(jsonDecode(decryptedData));

      return AuthResult.success(authData);
    } catch (e) {
      if (e is ApiError) rethrow;
      return AuthResult.error('Ошибка регистрации: ${e.toString()}');
    } finally {
      _secureChannel.dispose();
    }
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Устанавливаем защищенный канал
      await _secureChannel.establishSecureConnection();

      // 2. Отправляем публичный ключ на сервер
      final initResponse = await http.post(
        Uri.parse('$baseUrl/auth/secure-init'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'publicKey': _secureChannel.publicKey,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (initResponse.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(initResponse.body));
      }

      // 3. Получаем и устанавливаем сессионный ключ
      final initData = jsonDecode(initResponse.body);
      await _secureChannel.setSessionKey(initData['sessionKey']);

      // 4. Шифруем данные авторизации
      final encryptedData = await _secureChannel.encryptData(jsonEncode({
        'email': email,
        'password': password,
        'deviceId': const Uuid().v4(),
      }));

      // 5. Отправляем зашифрованные данные
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'data': encryptedData,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(response.body));
      }

      // 6. Расшифровываем ответ с токенами
      final encryptedResponse = jsonDecode(response.body)['data'];
      final decryptedData = await _secureChannel.decryptData(encryptedResponse);
      final authData = AuthData.fromJson(jsonDecode(decryptedData));

      return AuthResult.success(authData);
    } catch (e) {
      if (e is ApiError) rethrow;
      return AuthResult.error('Ошибка входа: ${e.toString()}');
    } finally {
      _secureChannel.dispose();
    }
  }

  @override
  Future<AuthResult> refreshToken({
    required String refreshToken,
    required String deviceId,
  }) async {
    try {
      // Для обновления токена используем обычный запрос,
      // так как refreshToken уже является секретным
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        body: jsonEncode({
          'refreshToken': refreshToken,
          'deviceId': deviceId,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(response.body));
      }

      final data = jsonDecode(response.body);
      return AuthResult.success(AuthData(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        deviceId: deviceId,
      ));
    } catch (e) {
      if (e is ApiError) rethrow;
      return AuthResult.error('Ошибка обновления токена: ${e.toString()}');
    }
  }

  @override
  Future<void> logout({
    required String deviceId,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        body: jsonEncode({
          'deviceId': deviceId,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw ApiError.fromJson(data);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(message: 'Ошибка выхода: ${e.toString()}');
    }
  }

  @override
  Future<List<DeviceInfo>> getDevices({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/devices'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw ApiError.fromJson(data);
      }

      final List data = jsonDecode(response.body);
      return data
          .map((device) => DeviceInfo(
                id: device['id'],
                name: device['name'],
                lastActive: DateTime.parse(device['lastActive']),
                isCurrentDevice: device['isCurrentDevice'],
              ))
          .toList();
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
          message: 'Ошибка получения списка устройств: ${e.toString()}');
    }
  }

  Future<void> initializeSearchChannel() async {
    if (_isSearchChannelActive) return;

    try {
      // Устанавливаем защищенное соединение
      await _secureChannel.establishSecureConnection();

      // Отправляем публичный ключ на сервер
      final initResponse = await http.post(
        Uri.parse('$baseUrl/auth/secure-init'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'publicKey': _secureChannel.publicKey,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (initResponse.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(initResponse.body));
      }

      // Устанавливаем сессионный ключ
      final initData = jsonDecode(initResponse.body);
      await _secureChannel.setSessionKey(initData['sessionKey']);
      
      _isSearchChannelActive = true;
    } catch (e) {
      _isSearchChannelActive = false;
      rethrow;
    }
  }

  // Метод поиска пользователей
  Future<List<UserSearchItem>> searchUsers(String query, String token) async {
    try {
      // Проверяем/инициализируем канал
      if (!_isSearchChannelActive) {
        await initializeSearchChannel();
      }

      // Шифруем запрос
      final encryptedData = await _secureChannel.encryptData(jsonEncode({
        'query': query,
        'limit': 10,
      }));

      // Отправляем запрос
      final response = await http.post(
        Uri.parse('$baseUrl/users/search'),
        body: jsonEncode({
          'channelId': _secureChannel.channelId,
          'data': encryptedData,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw ApiError.fromJson(jsonDecode(response.body));
      }

      // Расшифровываем ответ
      final encryptedResponse = jsonDecode(response.body)['data'];
      final decryptedData = await _secureChannel.decryptData(encryptedResponse);
      final data = jsonDecode(decryptedData) as List;
      
      return data.map((user) => UserSearchItem.fromJson(user)).toList();
    } catch (e) {
      // При ошибке сбрасываем состояние канала
      _isSearchChannelActive = false;
      if (e is ApiError) rethrow;
      throw ApiError(message: 'Ошибка поиска пользователей: ${e.toString()}');
    }
  }

  // Метод очистки поискового канала
  void disposeSearchChannel() {
    _isSearchChannelActive = false;
    _secureChannel.dispose();
  }
}
