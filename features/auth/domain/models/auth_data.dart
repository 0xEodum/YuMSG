// lib/features/auth/domain/models/auth_data.dart
class AuthData {
  final String accessToken;
  final String refreshToken;
  final String deviceId;

  const AuthData({
    required this.accessToken,
    required this.refreshToken,
    required this.deviceId,
  });

  // Фабричный метод для создания из JSON
  factory AuthData.fromJson(Map<String, dynamic> json) {
    // Проверяем, зашифрованы ли данные
    if (json.containsKey('data')) {
      // Если данные зашифрованы, они будут в поле 'data'
      final data = json['data'] as Map<String, dynamic>;
      return AuthData(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        deviceId: data['deviceId'] as String,
      );
    }
    
    // Если данные не зашифрованы (например, при обновлении токена)
    return AuthData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      deviceId: json['deviceId'] as String,
    );
  }

  // Конвертация в JSON
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'deviceId': deviceId,
  };

  // Создание копии с новыми значениями
  AuthData copyWith({
    String? accessToken,
    String? refreshToken,
    String? deviceId,
  }) {
    return AuthData(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}