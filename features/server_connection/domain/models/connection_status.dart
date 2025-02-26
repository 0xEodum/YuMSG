enum ServerConnectionState {
  initial,
  connecting,
  success,
  error
}

class ConnectionStatus {
  final ServerConnectionState state;
  final String? message;
  final bool isValid;

  const ConnectionStatus({
    required this.state,
    this.message,
    this.isValid = false,
  });

  factory ConnectionStatus.initial() {
    return const ConnectionStatus(state: ServerConnectionState.initial);
  }

  factory ConnectionStatus.connecting() {
    return const ConnectionStatus(state: ServerConnectionState.connecting);
  }

  factory ConnectionStatus.success() {
    return const ConnectionStatus(
      state: ServerConnectionState.success,
      message: 'Подключение установлено успешно',
      isValid: true,
    );
  }

  factory ConnectionStatus.error(String message) {
    return ConnectionStatus(
      state: ServerConnectionState.error,
      message: message,
      isValid: false,
    );
  }
}