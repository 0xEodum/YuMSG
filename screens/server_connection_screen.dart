// screens/server_connection_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yumsg/widgets/scrollable_card.dart';
import '../services/app_state_service.dart';
import '../constants/enums.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  
  bool _isConnecting = false;
  ConnectionStatus? _connectionStatus;

  // Список недавних подключений
  final List<ServerConfig> _recentConnections = [
    ServerConfig(ip: '192.168.1.100', port: '8080'),
    ServerConfig(ip: '10.0.1.5', port: '9000'),
  ];

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ScrollableCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Шапка с кнопкой назад
              _buildHeader(isDark),
              const SizedBox(height: 24),

              // Информационное сообщение
              _buildInfoMessage(isDark),
              const SizedBox(height: 24),

              // Настройки подключения
              _buildConnectionSettings(isDark),
              const SizedBox(height: 24),

              // Недавние подключения
              _buildRecentConnections(isDark),
              const SizedBox(height: 24),

              // Статус подключения (если есть)
              if (_connectionStatus != null) ...[
                _buildConnectionStatus(isDark),
                const SizedBox(height: 24),
              ],

              // Кнопка подключения
              _buildConnectButton(isDark),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        IconButton(
          onPressed: _isConnecting ? null : _handleBack,
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Подключение к серверу',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info,
            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Введите адрес и порт корпоративного сервера для установки защищенного соединения',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSettings(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Text(
          'Настройки подключения',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 16),
        
        // Поля ввода IP и порта
        Row(
          children: [
            // IP адрес
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IP-адрес',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _ipController,
                    enabled: !_isConnecting,
                    decoration: const InputDecoration(
                      hintText: '192.168.1.1',
                      prefixIcon: Icon(Icons.public),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Порт
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Порт',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _portController,
                    enabled: !_isConnecting,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '8080',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Разделитель "ИЛИ"
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ИЛИ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Кнопка загрузки конфигурации
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isConnecting ? null : _handleFileSelect,
            icon: const Icon(Icons.upload_file, size: 20),
            label: const Text('Загрузить конфигурацию из файла'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
              side: BorderSide(
                color: isDark ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentConnections(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Недавние подключения',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Плейсхолдер для показа всех подключений
                },
                child: Text(
                  'Показать все',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recentConnections.map((config) => 
            _buildRecentConnectionItem(config, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentConnectionItem(ServerConfig config, bool isDark) {
    return InkWell(
      onTap: () {
        _ipController.text = config.ip;
        _portController.text = config.port;
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '${config.ip}:${config.port}',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    final status = _connectionStatus!;
    Color bgColor, textColor;
    IconData icon;

    switch (status.state) {
      case ServerConnectionState.error:
        bgColor = isDark ? const Color(0xFF7F1D1D).withOpacity(0.2) : const Color(0xFFFEF2F2);
        textColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        icon = Icons.error;
        break;
      case ServerConnectionState.success:
        bgColor = isDark ? const Color(0xFF14532D).withOpacity(0.2) : const Color(0xFFF0FEF9);
        textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        icon = Icons.check_circle;
        break;
      case ServerConnectionState.connecting:
        bgColor = isDark ? const Color(0xFF92400E).withOpacity(0.2) : const Color(0xFFFFFBEB);
        textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        icon = Icons.sync;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.message,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(bool isDark) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isConnecting ? null : _handleConnect,
        child: _isConnecting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Проверка соединения...'),
                ],
              )
            : const Text('Подключиться'),
      ),
    );
  }

  void _handleBack() {
    // Получаем логически предыдущий экран
    final previousRoute = AppStateService.getPreviousRoute(AppScreen.serverConnection);
    
    if (previousRoute != null) {
      Navigator.pushReplacementNamed(context, previousRoute);
    } else {
      // Если предыдущего экрана нет, просто закрываем текущий
      Navigator.pop(context);
    }
  }

  void _handleFileSelect() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'conf'],
      );

      if (result != null) {
        // Плейсхолдер для обработки файла конфигурации
        // В реальном приложении здесь бы читался файл и извлекались IP и порт
        _ipController.text = '192.168.1.1';
        _portController.text = '8080';
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Конфигурация загружена')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при загрузке файла')),
      );
    }
  }

  void _handleConnect() async {
    if (_ipController.text.isEmpty || _portController.text.isEmpty) {
      setState(() {
        _connectionStatus = ConnectionStatus(
          state: ServerConnectionState.error,
          message: 'Введите IP-адрес и порт сервера',
        );
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionStatus = ConnectionStatus(
        state: ServerConnectionState.connecting,
        message: 'Проверка соединения...',
      );
    });

    // Имитация проверки соединения
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Имитация успешного подключения (70% успеха)
    final isSuccess = DateTime.now().millisecond % 10 < 7;

    setState(() {
      _isConnecting = false;
      if (isSuccess) {
        _connectionStatus = ConnectionStatus(
          state: ServerConnectionState.success,
          message: 'Подключение установлено успешно',
        );
      } else {
        _connectionStatus = ConnectionStatus(
          state: ServerConnectionState.error,
          message: 'Не удалось подключиться к серверу. Проверьте адрес и порт.',
        );
      }
    });

    // Если подключение успешно, сохраняем конфигурацию и переходим дальше
    if (isSuccess) {
      await AppStateService.saveServerConfig(
        ip: _ipController.text,
        port: _portController.text,
        organizationName: 'Orochi Technologies (大蛇)', // Плейсхолдер
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    }
  }
}

class ServerConfig {
  final String ip;
  final String port;

  ServerConfig({required this.ip, required this.port});
}

class ConnectionStatus {
  final ServerConnectionState state;
  final String message;

  ConnectionStatus({required this.state, required this.message});
}
