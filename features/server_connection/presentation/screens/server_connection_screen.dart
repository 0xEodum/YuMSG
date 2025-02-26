// lib/features/server_connection/presentation/screens/server_connection_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/data/providers/server_data_provider.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_arguments.dart';
import '../../../../core/services/navigation/navigation_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../startup/domain/enums/work_mode.dart';
import '../../domain/models/connection_status.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  final _addressController = TextEditingController();
  final _navigationService = NavigationService();
  final _sessionService = SessionService();
  final _authService = AuthService();
  
  ConnectionStatus _status = ConnectionStatus.initial();
  bool _isLoading = true;
  bool get _isConnecting => _status.state == ServerConnectionState.connecting;

  @override
  void initState() {
    super.initState();
    _checkSavedAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedAddress() async {
    try {
      final savedAddress = await _sessionService.getServerAddress();
      if (savedAddress != null) {
        _addressController.text = savedAddress;
      }
    } catch (e) {
      // Игнорируем ошибки при получении адреса
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBack() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Подтверждение'),
      content: const Text(
        'При возврате текущие настройки подключения будут сброшены. Продолжить?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Продолжить'),
        ),
      ],
    ),
  );

  if (result != true) return;

  // Очищаем режим работы
  await _sessionService.clearWorkMode();
  
  if (mounted) {
    // Используем replaceTo вместо goBack
    await _navigationService.replaceTo(AppRouter.start);
  }
}

  Future<void> _handleConnect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    setState(() {
      _status = ConnectionStatus.connecting();
    });

    try {
      // Инициализируем провайдер с новым адресом
      final provider = ServerDataProvider.initialize('http://$address');
      _authService.setDataProvider(provider);

      // Проверяем соединение через провайдер
      final status = await provider.checkConnection(address);
      
      if (mounted) {
        setState(() {
          _status = status;
        });
      }

      if (status.isValid) {
        await _sessionService.saveServerAddress(address);
        
        if (mounted) {
          await _navigationService.navigateTo(
            '/auth',
            arguments: AuthScreenArgs(workMode: WorkMode.server),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = ConnectionStatus.error(
            'Произошла ошибка при проверке соединения',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          await _handleBack();
          return false;
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildInfoMessage(),
                          const SizedBox(height: 16),
                          _buildAddressInput(),
                          if (_status.message != null) ...[
                            const SizedBox(height: 16),
                            _buildStatusMessage(),
                          ],
                          const SizedBox(height: 24),
                          _buildConnectButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isConnecting ? null : _handleBack,
        ),
        const SizedBox(width: 8),
        const Text(
          'Подключение к серверу',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, 
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Введите адрес корпоративного сервера в формате IP:Port для установки защищенного соединения',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInput() {
    return TextFormField(
      controller: _addressController,
      decoration: InputDecoration(
        hintText: 'Например: 192.168.1.1:8080',
        prefixIcon: const Icon(Icons.dns_outlined),
        enabled: !_isConnecting,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (_) {
        if (_status.state != ServerConnectionState.initial) {
          setState(() {
            _status = ConnectionStatus.initial();
          });
        }
      },
    );
  }

  Widget _buildStatusMessage() {
    final isError = _status.state == ServerConnectionState.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _status.message!,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton() {
    return ElevatedButton(
      onPressed: _isConnecting ? null : _handleConnect,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isConnecting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Проверка соединения...'),
              ],
            )
          : const Text('Подключиться'),
    );
  }
}