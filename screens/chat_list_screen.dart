// screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import '../services/app_state_service.dart';
import '../services/theme_service.dart';
import 'settings_screen.dart';
import 'files_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../models/chat_models.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _drawerController;
  
  String _searchQuery = '';
  bool _isSearchMode = false;
  
  // Мокап данных чатов
  final List<ChatInfo> _chats = [
    ChatInfo(
      id: 1,
      name: 'Анна Петрова',
      lastMessage: 'Привет! Как дела с проектом?',
      time: '14:32',
      unread: 2,
      avatar: '👩‍💼',
      isOnline: true,
    ),
    ChatInfo(
      id: 2,
      name: 'Команда разработки',
      lastMessage: 'Михаил: Релиз готов к тестированию',
      time: '13:45',
      unread: 0,
      avatar: '👥',
      isOnline: false,
      isGroup: true,
    ),
    ChatInfo(
      id: 3,
      name: 'Сергей Иванов',
      lastMessage: 'Отправил документы на согласование',
      time: '12:18',
      unread: 1,
      avatar: '👨‍💻',
      isOnline: true,
    ),
    ChatInfo(
      id: 4,
      name: 'HR Отдел',
      lastMessage: 'Напоминание о собрании в 15:00',
      time: '11:30',
      unread: 0,
      avatar: '🏢',
      isOnline: false,
      isGroup: true,
    ),
    ChatInfo(
      id: 5,
      name: 'Мария Козлова',
      lastMessage: 'Спасибо за помощь!',
      time: 'Вчера',
      unread: 0,
      avatar: '👩‍🎨',
      isOnline: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<ChatInfo> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((chat) =>
      chat.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appMode = AppStateService.getAppMode();
    final userSession = AppStateService.getUserSession();
    final localUser = AppStateService.getLocalUser();
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(isDark, appMode, userSession, localUser),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _filteredChats.isEmpty 
                ? _buildEmptyState(isDark)
                : _buildChatList(isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSearchToggle,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          _isSearchMode ? Icons.close : Icons.add, 
          color: Colors.white
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDark, String? appMode, Map<String, String?> userSession, String? localUser) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    
    return Drawer(
      child: Column(
        children: [
          // Отступ для системной шторки
          SizedBox(height: statusBarHeight),
          
          // Заголовок
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YuMSG',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => ThemeService().toggleTheme(),
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),

          // Профиль пользователя
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'ИП',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appMode == 'local' ? localUser ?? 'Пользователь' : userSession['username'] ?? 'Пользователь',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Онлайн',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Режим работы
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Режим работы',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                _buildModeIndicator(appMode, isDark),
              ],
            ),
          ),

          // Навигация
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildNavItem(
                    icon: Icons.settings,
                    title: 'Настройки',
                    onTap: () => _handleNavigation('settings'),
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    icon: Icons.person,
                    title: 'Профиль',
                    onTap: () => _handleNavigation('profile'),
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    icon: Icons.folder,
                    title: 'Файлы',
                    onTap: () => _handleNavigation('files'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // Кнопка выхода
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Выйти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2),
                  foregroundColor: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeIndicator(String? appMode, bool isDark) {
    if (appMode == null) return const SizedBox.shrink();
    
    final isServer = appMode == 'server';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF581C87).withOpacity(0.2) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isServer ? Icons.dns : Icons.computer,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isServer ? 'Серверный' : 'Локальный',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              Text(
                isServer ? 'Корпоративный сервер' : 'Локальная сеть',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildHeader(bool isDark) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: _isSearchMode ? _buildSearchHeader(isDark) : _buildNormalHeader(isDark),
    );
  }

  Widget _buildNormalHeader(bool isDark) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Чаты',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
        IconButton(
          onPressed: _handleSearchToggle,
          icon: const Icon(Icons.search),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Поиск чатов или новых собеседников...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF9FAFB),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
            onSubmitted: _handleSearchSubmit,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _handleSearchToggle,
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }

  Widget _buildChatList(bool isDark) {
    if (_isSearchMode && _searchQuery.isNotEmpty) {
      // В режиме поиска показываем результаты + потенциальных новых пользователей
      return ListView(
        children: [
          // Существующие чаты
          if (_filteredChats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Существующие чаты',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            ..._filteredChats.map((chat) => _buildChatItem(chat, isDark)),
          ],
          
          // Потенциальные новые пользователи (мокап)
          if (_searchQuery.length > 2) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Найти новых пользователей',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
            _buildNewUserItem('${_searchQuery.toUpperCase()} (${_searchQuery}@company.com)', isDark),
            _buildNewUserItem('${_searchQuery.toLowerCase()}_user', isDark),
          ],
        ],
      );
    }

    // Обычный список чатов
    return ListView.builder(
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        return _buildChatItem(chat, isDark);
      },
    );
  }

  Widget _buildNewUserItem(String username, bool isDark) {
    return InkWell(
      onTap: () => _handleNewUserTap(username),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            // Аватар для нового пользователя
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_add,
                color: Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Информация о новом пользователе
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите чтобы начать чат',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatInfo chat, bool isDark) {
    return InkWell(
      onTap: () => _handleChatTap(chat),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            // Аватар
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      chat.avatar,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                if (chat.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Содержимое чата
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.isGroup)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Группа',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    if (_isSearchMode && _searchQuery.isNotEmpty) {
      // Состояние когда поиск активен но ничего не найдено
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить поисковый запрос',
              style: TextStyle(
                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Плейсхолдер для поиска новых пользователей
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Поиск новых пользователей: "$_searchQuery"')),
                );
              },
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Найти новых пользователей'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Обычное пустое состояние
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message,
            size: 64,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет чатов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Начните новый разговор',
            style: TextStyle(
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  void _handleChatTap(ChatInfo chat) {
    // ОБНОВЛЕНО: Теперь переходим к экрану чата
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contact: ChatContact(
            name: chat.name,
            avatar: chat.avatar,
            isOnline: chat.isOnline,
          ),
        ),
      ),
    );
  }

  void _handleSearchToggle() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        // Активируем поиск
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        // Деактивируем поиск
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _handleSearchSubmit(String query) {
    // Плейсхолдер для обработки поиска
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Поиск: $query')),
    );
  }

  void _handleNewUserTap(String username) {
    // Плейсхолдер для начала чата с новым пользователем
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Начать чат с $username')),
    );
    
    // Можно автоматически выйти из режима поиска после выбора
    _handleSearchToggle();
  }

  void _handleNavigation(String route) {
    Navigator.pop(context); // Закрываем drawer
    
    switch (route) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
        break;
      case 'files':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FilesScreen(),
          ),
        );
        break;
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переход к $route')),
        );
    }
  }

  void _handleLogout() async {
    Navigator.pop(context); // Закрываем drawer
    
    // Показываем диалог подтверждения
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AppStateService.clearAuthData();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppStateService.getStartRoute());
      }
    }
  }
}
