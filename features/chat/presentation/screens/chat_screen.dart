// lib/features/chat/presentation/screens/chat_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yumsg/core/services/communication/communication_service.dart';
import 'package:yumsg/core/services/communication/connection_state.dart';
import 'package:yumsg/features/chat/domain/services/message_queue_service.dart';
import 'package:yumsg/features/chat/presentation/screens/chat_info_screen.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/services/chat_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String participantName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.participantName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  final _messageQueueService = MessageQueueService();
  final _communicationService = CommunicationService();
  int _pendingMessageCount = 0;
  StreamSubscription? _connectionSubscription;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _currentUserId;

  // Для пагинации
  static const int _pageSize = 20;
  int _currentPage = 1;

  // Подписки
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();

    // Добавляем слушатель для загрузки предыдущих сообщений при скролле
    _scrollController.addListener(_scrollListener);

    // Получаем количество ожидающих сообщений
    _updatePendingMessageCount();

    // Подписываемся на изменения статуса соединения
    _connectionSubscription = _communicationService.connectionState
        .listen(_handleConnectionStateChange);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Получение ID текущего пользователя
    _currentUserId = await _chatService.getCurrentUserId();

    // Загрузка первой страницы сообщений
    await _loadMessages();

    // Подписка на новые сообщения
    _messagesSubscription = _chatService.messages.listen(_handleNewMessage);
  }

  void _handleConnectionStateChange(YuConnectionState state) {
    if (state == YuConnectionState.connected) {
      // При восстановлении соединения обновляем счетчик ожидающих сообщений
      _updatePendingMessageCount();
    }
  }

// Добавляем метод для обновления счетчика ожидающих сообщений
  Future<void> _updatePendingMessageCount() async {
    try {
      final count = await _messageQueueService.getPendingMessageCount();
      if (mounted && count != _pendingMessageCount) {
        setState(() {
          _pendingMessageCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error updating pending message count: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Загрузка сообщений с пагинацией
      final messages = await _chatService.getMessages(
        widget.chatId,
        page: 1,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _hasMoreMessages = messages.length >= _pageSize;
          _currentPage = 1;
        });
      }

      // Прокручиваем к последнему сообщению после загрузки
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_messages.isNotEmpty && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });

      // Помечаем сообщения как прочитанные
      _markMessagesAsRead(messages);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Не удалось загрузить сообщения');
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      // Загрузка следующей страницы сообщений
      final nextPage = _currentPage + 1;
      final olderMessages = await _chatService.getMessages(
        widget.chatId,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          // Добавляем сообщения в начало списка
          _messages.insertAll(0, olderMessages);
          _isLoadingMore = false;
          _hasMoreMessages = olderMessages.length >= _pageSize;

          if (olderMessages.isNotEmpty) {
            _currentPage = nextPage;
          }
        });
      }

      // Помечаем сообщения как прочитанные
      _markMessagesAsRead(olderMessages);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showErrorSnackBar('Не удалось загрузить предыдущие сообщения');
      }
    }
  }

  void _handleNewMessage(ChatMessage message) {
    // Проверяем, принадлежит ли сообщение этому чату
    if (message.chatId != widget.chatId) return;

    // Проверяем, нет ли уже этого сообщения в списке
    if (_messages.any((m) => m.id == message.id)) return;

    if (mounted) {
      setState(() {
        _messages.add(message);
      });

      // Прокручиваем к новому сообщению, если пользователь уже находится внизу списка
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 150) {
        _scrollToBottom();
      }

      // Если сообщение от собеседника, помечаем его как прочитанное
      if (message.senderId != _currentUserId) {
        _chatService.markMessageAsRead(message.id);
      }
    }
  }

  void _markMessagesAsRead(List<ChatMessage> messages) {
    if (_currentUserId == null) return;

    // Помечаем сообщения от собеседника как прочитанные
    for (final message in messages) {
      if (message.senderId != _currentUserId &&
          message.status != MessageStatus.read) {
        _chatService.markMessageAsRead(message.id);
      }
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Очищаем поле ввода
    _messageController.clear();

    try {
      // Отправляем сообщение
      await _chatService.sendMessage(widget.chatId, text);

      // Обновляем счетчик ожидающих сообщений, если нет соединения
      if (!_communicationService.isConnected) {
        await _updatePendingMessageCount();
      }

      // Прокручиваем к новому сообщению
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('Не удалось отправить сообщение');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showChatInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatInfoScreen(
          chatId: widget.chatId,
          participantName: widget.participantName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.participantName),
        actions: [
          // Индикатор ожидающих сообщений
          if (_pendingMessageCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: 'Ожидает отправки: $_pendingMessageCount',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        '$_pendingMessageCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showChatInfo,
          ),
        ],
        // Индикатор состояния соединения
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _communicationService.isConnected ? 0 : 24,
            color: Colors.orange.shade100,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _communicationService.isConnected
                ? const SizedBox.shrink()
                : const Center(
                    child: Text(
                      'Нет соединения, сообщения будут отправлены позже',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Индикатор загрузки более старых сообщений
          if (_isLoadingMore)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),

          // Основной список сообщений
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
          ),

          // Разделитель
          const Divider(height: 1),

          // Поле ввода сообщения
          MessageInput(
            controller: _messageController,
            focusNode: _inputFocusNode,
            onSend: _handleSendMessage,
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
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Нет сообщений',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Начните общение прямо сейчас',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isFromMe = message.senderId == _currentUserId;
        final showDate = index == 0 ||
            !_isSameDay(_messages[index - 1].timestamp, message.timestamp);

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.timestamp),
            MessageBubble(
              message: message,
              isFromMe: isFromMe,
              showStatus: isFromMe,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: 8),
          Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (_isSameDay(date, now)) {
      return 'Сегодня';
    } else if (_isSameDay(date, yesterday)) {
      return 'Вчера';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }
}
