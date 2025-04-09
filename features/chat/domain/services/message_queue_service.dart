// lib/features/chat/domain/services/message_queue_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/communication/connection_state.dart';
import '../../../../core/services/websocket/websocket_service.dart';
import '../../../../core/crypto/services/crypto_service.dart';
import '../models/chat_message.dart';
import '../managers/chat_manager.dart';
import '../repositories/chat_repository.dart';

/// Сервис для управления очередью исходящих сообщений при отсутствии соединения.
class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  
  final WebSocketService _webSocketService = WebSocketService();
  final CommunicationService _communicationService = CommunicationService();
  final YuCryptoService _cryptoService = YuCryptoService();
  final ChatRepository _chatRepository = ChatRepository();
  final ChatManager _chatManager = ChatManager();
  
  static const String _pendingMessagesKey = 'pending_messages';
  
  Timer? _processingTimer;
  bool _isProcessing = false;
  
  MessageQueueService._internal() {
    // Подписываемся на изменения состояния соединения
    _communicationService.connectionState.listen(_handleConnectionChange);
  }
  
  /// Обрабатывает изменение состояния соединения.
  void _handleConnectionChange(YuConnectionState state) {
    if (state == YuConnectionState.connected) {
      // При восстановлении соединения пытаемся отправить накопленные сообщения
      processQueue();
    }
  }
  
  /// Добавляет сообщение в очередь отправки.
  Future<void> enqueueMessage(ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем текущую очередь сообщений
      final pendingMessagesJson = prefs.getStringList(_pendingMessagesKey) ?? [];
      
      // Добавляем новое сообщение в очередь
      pendingMessagesJson.add(jsonEncode(message.toJson()));
      
      // Сохраняем обновленную очередь
      await prefs.setStringList(_pendingMessagesKey, pendingMessagesJson);
      
      // Пытаемся обработать очередь, если есть соединение
      if (_communicationService.isConnected) {
        processQueue();
      }
    } catch (e) {
      debugPrint('Error enqueueing message: $e');
    }
  }
  
  /// Обрабатывает очередь сообщений, отправляя их при наличии соединения.
  Future<void> processQueue() async {
    // Предотвращаем параллельную обработку очереди
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      debugPrint('Processing message queue...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем список ожидающих сообщений
      final pendingMessagesJson = prefs.getStringList(_pendingMessagesKey) ?? [];
      if (pendingMessagesJson.isEmpty) {
        _isProcessing = false;
        debugPrint('No pending messages in queue');
        return;
      }
      
      debugPrint('Found ${pendingMessagesJson.length} pending messages');
      
      // Преобразуем JSON в объекты сообщений
      final pendingMessages = pendingMessagesJson
          .map((json) => ChatMessage.fromJson(jsonDecode(json)))
          .toList();
      
      // Список успешно отправленных сообщений
      final sentMessageIds = <String>[];
      
      // Перебираем сообщения и пытаемся их отправить
      for (final message in pendingMessages) {
        if (!_communicationService.isConnected) {
          debugPrint('Connection lost during queue processing');
          break; // Прерываем обработку, если соединение потеряно
        }
        
        try {
          // Получаем ID получателя из ID чата (формат: chat_with_recipientId)
          final chatId = message.chatId;
          
          if (!chatId.startsWith('chat_with_')) {
            debugPrint('Invalid chat ID format: $chatId');
            continue;
          }
          
          final recipientId = chatId.substring('chat_with_'.length);
          
          // Проверяем, не был ли чат удален
          if (await _chatManager.isChatWithUserDeleted(recipientId)) {
            debugPrint('Chat with $recipientId was deleted, skipping message');
            sentMessageIds.add(message.id); // помечаем для удаления
            continue;
          }
          
          // Получаем ключи чата
          final chatKey = await _chatRepository.getChatKeys(chatId);
          if (chatKey == null || !chatKey.isComplete) {
            debugPrint('Chat keys not found or incomplete for chat: $chatId');
            continue; // Пропускаем сообщение, если ключи недоступны
          }
          
          debugPrint('Processing pending message ${message.id} to recipient $recipientId');
          
          // Проверяем, есть ли зашифрованный контент
          String encryptedContent;
          if (message.encryptedContent != null) {
            encryptedContent = message.encryptedContent!;
          } else {
            // Шифруем содержимое сообщения
            encryptedContent = await _cryptoService.encryptSymmetric(
              message.content,
              chatKey.symmetricKey!,
            );
          }
          
          // Отправляем сообщение
          await _webSocketService.sendChatMessage(
            recipientId,
            message.id,
            encryptedContent,
            type: message.type,
          );
          
          // Помечаем сообщение как отправленное
          sentMessageIds.add(message.id);
          
          // Обновляем статус сообщения в хранилище
          final updatedMessage = message.copyWith(
            status: MessageStatus.sent,
            encryptedContent: encryptedContent
          );
          await _chatRepository.saveMessage(updatedMessage);
          
          debugPrint('Successfully sent pending message ${message.id}');
          
        } catch (e) {
          debugPrint('Error sending pending message ${message.id}: $e');
          // Продолжаем с другими сообщениями
        }
      }
      
      // Удаляем успешно отправленные сообщения из очереди
      if (sentMessageIds.isNotEmpty) {
        final remainingMessages = pendingMessages
            .where((msg) => !sentMessageIds.contains(msg.id))
            .map((msg) => jsonEncode(msg.toJson()))
            .toList();
        
        await prefs.setStringList(_pendingMessagesKey, remainingMessages);
        debugPrint('Removed ${sentMessageIds.length} sent messages from queue');
      }
    } catch (e) {
      debugPrint('Error processing message queue: $e');
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Запускает автоматическую обработку очереди через указанный интервал.
  void startQueueProcessing() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_communicationService.isConnected) {
          processQueue();
        }
      },
    );
    debugPrint('Message queue processing started');
  }
  
  /// Останавливает автоматическую обработку очереди.
  void stopQueueProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
    debugPrint('Message queue processing stopped');
  }
  
  /// Получает количество сообщений в очереди.
  Future<int> getPendingMessageCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingMessagesJson = prefs.getStringList(_pendingMessagesKey) ?? [];
      return pendingMessagesJson.length;
    } catch (e) {
      debugPrint('Error getting pending message count: $e');
      return 0;
    }
  }
  
  /// Очищает очередь сообщений.
  Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingMessagesKey);
      debugPrint('Message queue cleared');
    } catch (e) {
      debugPrint('Error clearing message queue: $e');
    }
  }
}