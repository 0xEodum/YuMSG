// lib/features/main/presentation/screens/main_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yumsg/features/chat/domain/adapters/chat_adapters.dart';
import 'package:yumsg/features/chat/domain/services/chat_service.dart';
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
  final _chatService = ChatService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _navigationPanelKey = GlobalKey<NavigationPanelState>();
  late WorkMode _workMode;
  bool _isLoadingWorkMode = true;
  
  // Временные данные для демонстрации
  List<ChatData> _chats = [];
  bool _isLoadingChats = true;

  StreamSubscription? _chatListSubscription;

  @override
  void initState() {
    super.initState();
    _loadWorkMode();
    _initializeServices();
    _loadChats();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    _chatListSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoadingChats = true;
    });
    
    try {
      // Подписываемся на обновления списка чатов
      _chatListSubscription?.cancel();
      _chatListSubscription = _chatService.chats.listen((chats) {
        if (mounted) {
          setState(() {
            _chats = ChatAdapters.chatsToCharDataList(chats);
            _isLoadingChats = false;
          });
        }
      });
      
      // Загружаем начальный список чатов
      final initialChats = await _chatService.getChats();
      if (mounted) {
        setState(() {
          _chats = ChatAdapters.chatsToCharDataList(initialChats);
          _isLoadingChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChats = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки чатов: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    setState(() {
      _isLoadingWorkMode = true;
    });
    
    try {
      final mode = await _sessionService.getWorkMode();
      if (mounted) {
        setState(() {
          // Если режим null, используем WorkMode.server по умолчанию
          _workMode = mode ?? WorkMode.server;
          _isLoadingWorkMode = false;
        });
      }
    } catch (e) {
      // В случае ошибки используем WorkMode.server по умолчанию
      if (mounted) {
        setState(() {
          _workMode = WorkMode.server;
          _isLoadingWorkMode = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки режима работы: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    // Показываем индикатор загрузки, пока _workMode не инициализирован
    if (_isLoadingWorkMode) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: NavigationPanel(
          key: _navigationPanelKey,
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
          // Индикатор статуса соединения (только для серверного режима)
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
            child: _isLoadingChats 
                ? const Center(child: CircularProgressIndicator())
                : _chats.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        child: ListView.builder(
                          itemCount: _chats.length,
                          itemBuilder: (context, index) {
                            return ChatListItem(chat: _chats[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Открываем поиск пользователей при нажатии на кнопку
          _navigationPanelKey.currentState?.toggleSearch();
        },
        child: const Icon(Icons.message),
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