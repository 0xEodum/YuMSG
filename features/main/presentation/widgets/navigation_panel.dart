import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yumsg/core/data/providers/server_data_provider.dart';
import 'package:yumsg/core/services/session/session_service.dart';
import 'package:yumsg/features/main/domain/models/search_result.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_arguments.dart';
import '../../../chat/domain/services/chat_service.dart';

class NavigationPanel extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final GlobalKey<NavigationPanelState>? navigationPanelKey;

  const NavigationPanel({
    super.key,
    required this.onMenuPressed,
    this.navigationPanelKey,
  });

  @override
  State<NavigationPanel> createState() => NavigationPanelState();
}

class NavigationPanelState extends State<NavigationPanel> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _sessionService = SessionService();
  final _serverProvider = ServerDataProvider.instance;
  final _chatService = ChatService();
  
  Timer? _debounceTimer;
  bool _isSearchMode = false;
  bool _isLoading = false;
  String? _error;
  List<UserSearchItem>? _searchResults;

  bool get isSearchMode => _isSearchMode;

  void toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchResults = null;
        _error = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Инициализируем поисковый канал
    _initSearchChannel();
  }

  Future<void> _initSearchChannel() async {
    try {
      await _serverProvider.initializeSearchChannel();
    } catch (e) {
      // Ошибку инициализации можно игнорировать, 
      // канал будет переинициализирован при поиске
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _serverProvider.disposeSearchChannel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchResults = null;
        _error = null;
      }
    });
  }

  Future<void> _handleSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _error = null;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        // Получаем токен для авторизованного запроса
        final authData = await _sessionService.getAuthData();
        if (authData == null) {
          throw Exception('Не удалось получить данные авторизации');
        }

        final results = await _serverProvider.searchUsers(
          query,
          authData.accessToken,
        );
        
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    });
  }

  // Обработчик нажатия на пользователя из результатов поиска
  Future<void> handleUserSelected(UserSearchItem user) async {
    print('User selected: ${user.username}'); // Отладочный вывод
    
    // Закрываем панель поиска
    _toggleSearch();
    
    // Создаем BuildContext переменную для сохранения контекста
    final currentContext = context;
    
    // Показываем индикатор загрузки
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Инициализация чата...'),
          ],
        ),
      ),
    );
    
    try {
      print('Calling openOrCreateChat'); // Отладочный вывод
      
      // Получаем или создаем чат с выбранным пользователем
      final chatId = await _chatService.openOrCreateChat(
        user.id,
        user.username,
      );
      
      print('Chat ID received: $chatId'); // Отладочный вывод
      
      // Закрываем диалог загрузки 
      if (Navigator.canPop(currentContext)) {
        Navigator.of(currentContext).pop();
      }
      
      if (chatId == null) {
        print('Chat ID is null'); // Отладочный вывод
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
        print('Navigating to chat screen'); // Отладочный вывод
        Navigator.of(currentContext).pushNamed(
          AppRouter.chat,
          arguments: ChatScreenArgs(
            chatId: chatId,
            chatName: user.username,
          ),
        );
      }
    } catch (e) {
      print('Error handling user selection: $e'); // Отладочный вывод
      
      // Закрываем диалог загрузки, если он показан
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
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: widget.onMenuPressed,
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
              onChanged: _handleSearchChanged,
            )
          : const Text('Чаты'),
      actions: [
        if (!_isSearchMode)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
          ),
      ],
    );
  }

  // Создает виджет с результатами поиска
  Widget buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
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
              _error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults == null || _searchResults!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'Нет результатов',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults!.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _searchResults![index];
          return InkWell(
            onTap: () {
              print("Tapped on user ${user.username}");
              handleUserSelected(user);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
          );
        },
      ),
    );
  }
}