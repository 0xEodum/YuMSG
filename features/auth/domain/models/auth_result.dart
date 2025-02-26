import 'auth_data.dart';

class AuthResult {
  final bool success;
  final String? error;
  final AuthData? data;

  const AuthResult({
    required this.success,
    this.error,
    this.data,
  });

  factory AuthResult.success(AuthData data) {
    return AuthResult(success: true, data: data);
  }

  factory AuthResult.error(String message) {
    return AuthResult(success: false, error: message);
  }
}