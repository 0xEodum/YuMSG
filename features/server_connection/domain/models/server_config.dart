class ServerConfig {
  final String host;
  final int port;

  const ServerConfig({
    required this.host,
    required this.port,
  });

  factory ServerConfig.fromAddress(String address) {
    final parts = address.split(':');
    if (parts.length != 2) {
      throw const FormatException('Неверный формат адреса. Используйте формат IP:Port');
    }

    final port = int.tryParse(parts[1]);
    if (port == null || port <= 0 || port > 65535) {
      throw const FormatException('Неверный порт. Используйте значение от 1 до 65535');
    }

    return ServerConfig(
      host: parts[0],
      port: port,
    );
  }

  String get address => '$host:$port';
}