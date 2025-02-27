// lib/features/main/presentation/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/chat_data.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/side_panel.dart';
import '../widgets/chat_list_item.dart';
import '../../../startup/domain/enums/work_mode.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/background/background_service.dart';
import '../providers/connection_status_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _sessionService = SessionService();
  final _communicationService = CommunicationService();
  final _backgroundService = BackgroundService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late WorkMode _workMode;
  
  // Временные данные для демонстрации
  final List<ChatData> _chats = [
    ChatData(
      id: '1',
      name: 'Команда разработки',
      lastMessage: 'Обновил документацию по API эндпоинтам',
      time: '12:30',
      unreadCount: 3,
    ),
    ChatData(
      id: '2',
      name: 'Анна Петрова',
      lastMessage: 'Файл с презентацией отправлен',
      time: '11:45',
      unreadCount: 0,
    ),
    ChatData(
      id: '3',
      name: 'Служба поддержки',
      lastMessage: 'Спасибо за обратную связь!',
      time: '10:15',
      unreadCount: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkMode();
    _initializeServices();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Получаем провайдер статуса соединения
    final connectionProvider = Provider.of<ConnectionStatusProvider>(context, listen: false);
    
    // Подписываемся на изменения статуса соединения
    connectionProvider.initialize(_communicationService);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // AppLifecycleState обрабатывается в CommunicationService
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _loadWorkMode() async {
    final mode = await _sessionService.getWorkMode();
    if (mounted) {
      setState(() {
        _workMode = mode!;
      });
    }
  }
  
  Future<void> _initializeServices() async {
    try {
      // Инициализируем коммуникационный сервис
      await _communicationService.initialize();
      
      // Инициализируем и запускаем фоновый сервис, если в серверном режиме
      final workMode = await _sessionService.getWorkMode();
      if (workMode == WorkMode.server) {
        await _backgroundService.initialize();
        await _backgroundService.start();
      }
    } catch (e) {
      // Ошибки инициализации не должны останавливать отображение UI
      debugPrint('Error initializing services: $e');
    }
  }

  void _handleWorkModeChange(WorkMode mode) async {
    setState(() {
      _workMode = mode;
    });
    await _sessionService.saveWorkMode(mode);
    
    // Обновляем состояние сервисов при смене режима
    if (mode == WorkMode.server) {
      await _communicationService.initialize();
      await _backgroundService.start();
    } else {
      // В локальном режиме отключаем WebSocket
      _backgroundService.stop();
    }
  }

  void _handleMenuPressed() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: NavigationPanel(
          onMenuPressed: _handleMenuPressed,
        ),
      ),
      drawer: SidePanel(
        workMode: _workMode,
        onWorkModeChanged: _handleWorkModeChange,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: Column(
        children: [
          // Индикатор статуса соединения
          Consumer<ConnectionStatusProvider>(
            builder: (context, provider, child) {
              // Только для серверного режима показываем статус соединения
              if (_workMode != WorkMode.server) {
                return const SizedBox.shrink();
              }
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: provider.isConnected ? 0 : 36,
                color: Colors.orange.shade100,
                child: provider.isConnected 
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.wifi_off,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ожидание подключения к серверу...',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _communicationService.initialize();
                          },
                          child: const Text('Переподключиться'),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
              );
            },
          ),
          // Список чатов
          Expanded(
            child: _chats.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      return ChatListItem(chat: _chats[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет активных чатов',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Начните новый чат или дождитесь сообщения',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}