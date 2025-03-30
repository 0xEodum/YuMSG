// lib/features/chat/presentation/screens/chat_info_screen.dart
import 'package:flutter/material.dart';
import '../../domain/managers/chat_manager.dart';
import '../../domain/models/chat.dart';
import '../../domain/services/chat_service.dart';

class ChatInfoScreen extends StatefulWidget {
  final String recipientId;
  final String participantName;

  const ChatInfoScreen({
    Key? key,
    required this.recipientId,
    required this.participantName,
  }) : super(key: key);

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final _chatService = ChatService();
  final _chatManager = ChatManager();
  
  Chat? _chatData;
  bool _isLoading = true;
  bool _isEncryptionActive = false;
  
  @override
  void initState() {
    super.initState();
    _loadChatData();
  }
  
  Future<void> _loadChatData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Получаем данные о чате
      final chat = await _chatManager.getChatWithUser(widget.recipientId);
      
      // Проверяем статус шифрования
      final encryptionActive = await _chatService.checkEncryptionStatus(widget.recipientId);
      
      if (mounted) {
        setState(() {
          _chatData = chat;
          _isEncryptionActive = encryptionActive;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить информацию о чате: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearChatHistory() async {
    try {
      // Показываем диалог подтверждения
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Очистить историю чата'),
          content: const Text('Вы уверены, что хотите очистить историю этого чата? Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Очистить'),
            ),
          ],
        ),
      );
      
      if (result != true) return;
      
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Очистка истории чата...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Очищаем историю чата
      await _chatService.clearChatHistory(widget.recipientId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('История чата очищена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось очистить историю чата: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteChat() async {
    try {
      // Показываем диалог подтверждения с дополнительным предупреждением
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить чат'),
          content: const Text(
            'Вы уверены, что хотите удалить этот чат? Вся история сообщений и '
            'ключи шифрования будут удалены безвозвратно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      
      if (result != true) return;
      
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Удаление чата...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Удаляем чат
      await _chatService.deleteChat(widget.recipientId);
      
      if (mounted) {
        // Возвращаемся на главный экран
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Чат удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось удалить чат: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _recreateEncryptionKeys() async {
    try {
      // Показываем диалог подтверждения
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пересоздать ключи шифрования'),
          content: const Text(
            'Это действие пересоздаст ключи шифрования для данного чата. '
            'Во время этого процесса обмен сообщениями будет временно недоступен.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Пересоздать'),
            ),
          ],
        ),
      );
      
      if (result != true) return;
      
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пересоздание ключей шифрования...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Инициируем пересоздание ключей
      await _chatService.reinitializeChat(widget.recipientId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ключи шифрования пересозданы'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Обновляем данные на экране
        _loadChatData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось пересоздать ключи шифрования: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о чате'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Информация о собеседнике
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              _chatData?.participantName?[0] ?? widget.participantName[0],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _chatData?.participantName ?? widget.participantName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${widget.recipientId}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Информация о шифровании
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Шифрование',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                _isEncryptionActive 
                                    ? Icons.lock 
                                    : Icons.lock_open,
                                color: _isEncryptionActive
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isEncryptionActive
                                          ? 'Шифрование активно'
                                          : 'Шифрование не настроено',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isEncryptionActive
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isEncryptionActive
                                          ? 'Сообщения защищены сквозным шифрованием'
                                          : 'Сообщения не защищены шифрованием',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _recreateEncryptionKeys,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Пересоздать ключи шифрования'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Пересоздание ключей может потребоваться, если возникли проблемы с отправкой сообщений',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Управление чатом
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Управление чатом',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _clearChatHistory,
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Очистить историю чата'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _deleteChat,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Удалить чат'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}