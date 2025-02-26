import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yumsg/core/data/providers/server_data_provider.dart';
import 'package:yumsg/core/services/session/session_service.dart';
import 'package:yumsg/features/main/domain/models/search_result.dart';

class NavigationPanel extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const NavigationPanel({
    super.key,
    required this.onMenuPressed,
  });

  @override
  State<NavigationPanel> createState() => _NavigationPanelState();
}

class _NavigationPanelState extends State<NavigationPanel> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _sessionService = SessionService();
  final _serverProvider = ServerDataProvider.instance;
  
  Timer? _debounceTimer;
  bool _isSearchMode = false;
  bool _isLoading = false;
  String? _error;
  List<UserSearchItem>? _searchResults;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
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
        ),
        if (_isSearchMode) _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_searchResults == null || _searchResults!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Нет результатов'),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _searchResults!.map((user) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null ? Text(user.username[0]) : null,
            ),
            title: Text(user.username),
            trailing: user.isOnline
                ? Container(
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
                  )
                : null,
            onTap: () {
              // TODO: Инициировать чат с пользователем
              _toggleSearch();
            },
          );
        }).toList(),
      ),
    );
  }
}