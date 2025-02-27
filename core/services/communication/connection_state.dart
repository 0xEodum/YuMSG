// lib/core/services/communication/connection_state.dart

/// Перечисление возможных состояний соединения.
enum YuConnectionState {
  /// Соединение не установлено.
  disconnected,
  /// Попытка установить соединение.
  connecting,
  /// Соединение установлено.
  connected,
  /// Произошла ошибка при установке соединения.
  error
}