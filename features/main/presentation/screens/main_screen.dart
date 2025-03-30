// lib/features/main/presentation/screens/main_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yumsg/core/data/providers/server_data_provider.dart';
import 'package:yumsg/core/services/session/session_service.dart';
import 'package:yumsg/features/chat/domain/adapters/chat_adapters.dart';
import 'package:yumsg/features/chat/domain/services/chat_service.dart';
import 'package:yumsg/features/main/domain/models/search_result.dart';
import '../../domain/models/chat_data.dart';
import '../widgets/side_panel.dart';
import '../widgets/chat_list_item.dart';
import '../../../startup/domain/enums/work_mode.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_arguments.dart';
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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  // Поиск
  bool _isSearchMode = false;
  List<UserSearchItem>? _searchResults;
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounceTimer;
  
  // Основное состояние
  late WorkMode _workMode;
  bool _isLoadingWorkMode = true;
  List<ChatData> _chats = [];
  bool _isLoadingChats = true;
  StreamSubscription? _chatListSubscription;

  @override
  void initState() {
    super.initState();
    _loadWorkMode();
    _initializeServices();
    _loadChats();
    _initSearchChannel();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    _chatListSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Инициализация поискового канала
  Future<void> _initSearchChannel() async {
    try {
      await ServerDataProvider.instance.initializeSearchChannel();
    } catch (e) {
      debugPrint('Error initializing search channel: $e');
      // Канал будет переинициализирован при поиске
    }
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
      // Инициализируем ChatService для миграции старых чатов
      await _chatService.initialize();
      
      // Инициализируем коммуникационный сервис
      await _communicationService.initialize();
      
      // Инициализируем и запускаем фоновый сервис, если в серверном режиме
      final workMode = await _sessionService.getWorkMode();
      if (workMode == WorkMode.server) {
        try {
          // Разделяем инициализацию и запуск для лучшей обработки ошибок
          await _backgroundService.initialize();
          
          try {
            await _backgroundService.start();
          } catch (e) {
            debugPrint('Error starting background service: $e');
            // Продолжаем работу даже если не удалось запустить фоновый сервис
          }
        } catch (e) {
          debugPrint('Error initializing background service: $e');
          // Продолжаем работу даже если не удалось инициализировать фоновый сервис
        }
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
  
  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        _searchResults = null;
        _searchError = null;
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }
  
  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _searchError = null;
      });
      return;
    }
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      setState(() {
        _isSearching = true;
        _searchError = null;
      });
      
      try {
        debugPrint('Performing search for: $query');
        
        // Получаем токен для авторизованного запроса
        final authData = await _sessionService.getAuthData();
        if (authData == null) {
          throw Exception('Не удалось получить данные авторизации');
        }
        
        final results = await ServerDataProvider.instance.searchUsers(
          query,
          authData.accessToken,
        );
        
        debugPrint('Search results received: ${results.length} items');
        
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Error during search: $e');
        if (mounted) {
          setState(() {
            _searchError = e.toString();
            _isSearching = false;
          });
        }
      }
    });
  }
  
  Future<void> _handleUserSelected(UserSearchItem user) async {
    debugPrint('User selected: ${user.username}');
    
    // Закрываем панель поиска
    setState(() {
      _isSearchMode = false;
      _searchController.clear();
      _searchResults = null;
    });
    
    // Создаем BuildContext переменную для сохранения контекста
    final currentContext = context;
    
    // Показываем индикатор загрузки
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Инициализация чата...'),
          ],
        ),
      ),
    );
    
    try {
      debugPrint('Calling openOrCreateChat');
      
      // Получаем или создаем чат с выбранным пользователем
      final chatId = await _chatService.openOrCreateChat(
        user.id,
        user.username,
      );
      
      debugPrint('Chat ID received: $chatId');
      
      // Закрываем диалог загрузки
      if (Navigator.canPop(currentContext)) {
        Navigator.of(currentContext).pop();
      }
      
      if (chatId == null) {
        debugPrint('Chat ID is null');
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть чат'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Переходим на экран чата
      if (mounted) {
        debugPrint('Navigating to chat screen');
        Navigator.of(currentContext).pushNamed(
          AppRouter.chat,
          arguments: ChatScreenArgs(
            chatId: chatId,
            chatName: user.username,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling user selection: $e');
      
      // Закрываем диалог загрузки
      if (Navigator.canPop(currentContext)) {
        Navigator.of(currentContext).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании чата: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _handleMenuPressed,
        ),
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSearch,
                  ),
                ),
                onChanged: _handleSearch,
              )
            : const Text('Чаты'),
        actions: [
          if (!_isSearchMode)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
        ],
      ),
      drawer: SidePanel(
        workMode: _workMode,
        onWorkModeChanged: _handleWorkModeChange,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: Stack(
        children: [
          Column(
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
          
          // Результаты поиска как наложение
          if (_isSearchMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white.withOpacity(0.96),
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: _buildSearchResults(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleSearch,
        child: Icon(_isSearchMode ? Icons.close : Icons.message),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Ошибка при поиске',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text(
            'Введите запрос для поиска пользователей',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    if (_searchResults!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults!.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _searchResults![index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                debugPrint("Tapped on user ${user.username}");
                _handleUserSelected(user);
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.isOnline ? 'В сети' : 'Не в сети',
                            style: TextStyle(
                              fontSize: 14,
                              color: user.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user.isOnline)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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