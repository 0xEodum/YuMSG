import 'package:flutter/material.dart';
import '../../domain/models/chat_data.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/side_panel.dart';
import '../widgets/chat_list_item.dart';
import '../../../startup/domain/enums/work_mode.dart';
import '../../../../core/services/session/session_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _sessionService = SessionService();
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
  }

  Future<void> _loadWorkMode() async {
    final mode = await _sessionService.getWorkMode();
    if (mounted) {
      setState(() {
        _workMode = mode!;
      });
    }
  }

  void _handleWorkModeChange(WorkMode mode) {
    setState(() {
      _workMode = mode;
    });
    _sessionService.saveWorkMode(mode);
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
      body: _chats.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                return ChatListItem(chat: _chats[index]);
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