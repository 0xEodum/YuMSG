// lib/features/chat/domain/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../core/crypto/services/crypto_service.dart';
import '../../../../core/crypto/services/server_secure_channel.dart';
import '../../../../core/crypto/models/key_pair.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../../core/services/websocket/websocket_service.dart';
import '../../../../core/services/websocket/websocket_event.dart';
import '../models/chat.dart';
import '../models/chat_key.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';

/// Сервис для управления чатами, обработки сообщений и обмена ключами.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  
  final YuCryptoService _cryptoService = YuCryptoService();
  final WebSocketService _webSocketService = WebSocketService();
  final SessionService _sessionService = SessionService();
  final ChatRepository _chatRepository = ChatRepository();
  
  // Потоки для публикации событий
  final _messageSubject = PublishSubject<ChatMessage>();
  final _chatListSubject = BehaviorSubject<List<Chat>>.seeded([]);
  
  Stream<ChatMessage> get messages => _messageSubject.stream;
  Stream<List<Chat>> get chats => _chatListSubject.stream;
  
  ChatService._internal() {
    // Инициализируем обработчики WebSocket событий
    _webSocketService.onChatInit.listen(_handleChatInitialization);
    _webSocketService.onKeyExchange.listen(_handleKeyExchange);
    _webSocketService.onKeyExchangeComplete.listen(_handleKeyExchangeComplete);
    _webSocketService.onMessage.listen(_handleIncomingMessage);
    _webSocketService.onMessageStatus.listen(_handleMessageStatus);
    
    // Загружаем чаты из хранилища при старте
    _loadChats();
  }
  
  /// Загружает список чатов из локального хранилища.
  Future<void> _loadChats() async {
    try {
      final loadedChats = await _chatRepository.getChats();
      _chatListSubject.add(loadedChats);
    } catch (e) {
      debugPrint('Error loading chats: $e');
    }
  }
  
  /// Инициирует новый чат с указанным пользователем.
  Future<String?> initializeChat(String recipientId) async {
    try {
      // Генерируем пару ключей для чата
      final keyPair = await _cryptoService.generateKeyPair();
      
      // Отправляем публичный ключ через WebSocket
      await _webSocketService.sendChatInitialization(
        recipientId,
        keyPair.publicKey,
      );
      
      // Сохраняем ключи в ожидании ответа
      // В реальном приложении нужно добавить проверку на timeout
      
      // Возвращаем temporary chatId (это можно улучшить)
      return '$recipientId-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      return null;
    }
  }
  
  /// Обрабатывает входящий запрос на инициализацию чата.
  Future<void> _handleChatInitialization(ChatInitEvent event) async {
    try {
      final chatId = event.chatId;
      final initiatorId = event.initiatorId;
      final remotePublicKey = event.publicKey;
      
      // Генерируем свою пару ключей для ответа
      final keyPair = await _cryptoService.generateKeyPair();
      
      // Генерируем часть симметричного ключа
      final partialKey = await _cryptoService.generateRandomBytes(32);
      
      // Шифруем часть ключа публичным ключом инициатора
      final encryptedPartialKey = await _cryptoService.encryptAsymmetric(
        partialKey,
        remotePublicKey,
      );
      
      // Отправляем ответ с ключами
      await _webSocketService.sendKeyExchangeResponse(
        chatId,
        keyPair.publicKey,
        encryptedPartialKey,
      );
      
      // Сохраняем информацию о ключах для дальнейшего завершения обмена
      await _chatRepository.saveChatKeys(
        ChatKey(
          chatId: chatId,
          userId: initiatorId,
          publicKey: keyPair.publicKey,
          privateKey: keyPair.privateKey,
          remotePublicKey: remotePublicKey,
          partialKey: partialKey,
          isComplete: false,
        ),
      );
      
      // Создаем новый чат в локальном хранилище (статус: в процессе инициализации)
      final newChat = Chat(
        id: chatId,
        participantId: initiatorId,
        lastMessage: 'Инициализация чата...',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isInitialized: false,
      );
      
      await _chatRepository.saveChat(newChat);
      
      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error handling chat initialization: $e');
    }
  }
  
  /// Обрабатывает ответ при обмене ключами.
  Future<void> _handleKeyExchange(KeyExchangeEvent event) async {
    try {
      final chatId = event.chatId;
      final senderId = event.senderId;
      final remotePublicKey = event.publicKey;
      final encryptedPartialKey = event.encryptedPartialKey;
      
      // Получаем наши ключи для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null) {
        throw Exception('Chat keys not found for chatId: $chatId');
      }
      
      // Расшифровываем частичный ключ собеседника
      final remotePartialKey = await _cryptoService.decryptAsymmetric(
        encryptedPartialKey,
        chatKeyData.privateKey,
      );
      
      // Генерируем нашу часть симметричного ключа
      final ourPartialKey = await _cryptoService.generateRandomBytes(32);
      
      // Комбинируем ключи для создания полного симметричного ключа
      // (в реальном приложении используется более сложный алгоритм)
      final combinedKey = await _cryptoService.deriveKey(
        remotePartialKey + ourPartialKey
      );
      
      // Шифруем нашу часть ключа для отправки
      final encryptedOurPartialKey = await _cryptoService.encryptAsymmetric(
        ourPartialKey,
        remotePublicKey,
      );
      
      // Отправляем завершение обмена ключами
      await _webSocketService.sendKeyExchangeComplete(
        chatId,
        encryptedOurPartialKey,
      );
      
      // Обновляем данные ключа в хранилище
      await _chatRepository.saveChatKeys(
        chatKeyData.copyWith(
          remotePublicKey: remotePublicKey,
          symmetricKey: combinedKey,
          isComplete: true,
        ),
      );
      
      // Обновляем статус чата на "инициализирован"
      final chat = await _chatRepository.getChat(chatId);
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(isInitialized: true),
        );
        
        // Обновляем список чатов
        _loadChats();
      }
    } catch (e) {
      debugPrint('Error handling key exchange: $e');
    }
  }
  
  /// Обрабатывает завершение обмена ключами.
  Future<void> _handleKeyExchangeComplete(KeyExchangeCompleteEvent event) async {
    try {
      final chatId = event.chatId;
      final senderId = event.senderId;
      final encryptedPartialKey = event.encryptedPartialKey;
      
      // Получаем данные ключей для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null) {
        throw Exception('Chat keys not found for chatId: $chatId');
      }
      
      // Расшифровываем финальную часть ключа
      final remotePartialKey = await _cryptoService.decryptAsymmetric(
        encryptedPartialKey,
        chatKeyData.privateKey,
      );
      
      // Комбинируем ключи
      final combinedKey = await _cryptoService.deriveKey(
        chatKeyData.partialKey + remotePartialKey
      );
      
      // Обновляем данные ключа
      await _chatRepository.saveChatKeys(
        chatKeyData.copyWith(
          symmetricKey: combinedKey,
          isComplete: true,
        ),
      );
      
      // Обновляем статус чата
      final chat = await _chatRepository.getChat(chatId);
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(isInitialized: true),
        );
        
        // Обновляем список чатов
        _loadChats();
      }
    } catch (e) {
      debugPrint('Error handling key exchange completion: $e');
    }
  }
  
  /// Отправляет сообщение в указанный чат.
  Future<bool> sendMessage(String chatId, String content, {String type = 'text'}) async {
    try {
      // Получаем данные ключей для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null || !chatKeyData.isComplete) {
        throw Exception('Chat keys not found or incomplete for chatId: $chatId');
      }
      
      // Шифруем контент сообщения симметричным ключом
      final encryptedContent = await _cryptoService.encryptSymmetric(
        content,
        chatKeyData.symmetricKey!,
      );
      
      // Отправляем сообщение через WebSocket
      await _webSocketService.sendMessage(
        chatId,
        encryptedContent,
        type: type,
      );
      
      // Создаем объект сообщения
      final userId = await _getCurrentUserId();
      final message = ChatMessage(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: userId,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      
      // Сохраняем сообщение локально
      await _chatRepository.saveMessage(message);
      
      // Обновляем информацию о чате
      final chat = await _chatRepository.getChat(chatId);
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(
            lastMessage: content,
            lastMessageTime: DateTime.now(),
          ),
        );
        
        // Обновляем список чатов
        _loadChats();
      }
      
      // Публикуем сообщение в поток
      _messageSubject.add(message);
      
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }
  
  /// Обрабатывает входящее сообщение.
  Future<void> _handleIncomingMessage(ChatMessageEvent event) async {
    try {
      final chatId = event.chatId;
      final senderId = event.senderId;
      final encryptedContent = event.content;
      final type = event.type;
      final timestamp = DateTime.parse(event.timestamp);
      
      // Получаем данные ключей
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null || !chatKeyData.isComplete) {
        throw Exception('Chat keys not found or incomplete for chatId: $chatId');
      }
      
      // Расшифровываем контент
      final content = await _cryptoService.decryptSymmetric(
        encryptedContent,
        chatKeyData.symmetricKey!,
      );
      
      // Создаем объект сообщения
      final message = ChatMessage(
        id: event.messageId,
        chatId: chatId,
        senderId: senderId,
        content: content,
        type: type,
        timestamp: timestamp,
        status: MessageStatus.delivered,
      );
      
      // Сохраняем сообщение локально
      await _chatRepository.saveMessage(message);
      
      // Обновляем статус сообщения на "доставлено"
      await _webSocketService.sendMessageStatus(
        event.messageId,
        chatId,
        'delivered',
      );
      
      // Обновляем информацию о чате
      final chat = await _chatRepository.getChat(chatId);
      final userId = await _getCurrentUserId();
      final isFromMe = senderId == userId;
      
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(
            lastMessage: content,
            lastMessageTime: timestamp,
            unreadCount: isFromMe ? chat.unreadCount : chat.unreadCount + 1,
          ),
        );
        
        // Обновляем список чатов
        _loadChats();
      }
      
      // Публикуем сообщение в поток
      _messageSubject.add(message);
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }
  
  /// Обрабатывает обновление статуса сообщения.
  Future<void> _handleMessageStatus(MessageStatusEvent event) async {
    try {
      final messageId = event.messageId;
      final status = event.status;
      
      // Получаем сообщение из хранилища
      final message = await _chatRepository.getMessage(messageId);
      if (message == null) return;
      
      // Определяем новый статус
      final newStatus = _parseMessageStatus(status);
      
      // Обновляем статус сообщения
      await _chatRepository.saveMessage(
        message.copyWith(status: newStatus),
      );
      
      // Публикуем обновленное сообщение
      _messageSubject.add(message.copyWith(status: newStatus));
    } catch (e) {
      debugPrint('Error handling message status: $e');
    }
  }
  
  /// Преобразует строковый статус в enum.
  MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sent;
    }
  }
  
  /// Получает ID текущего пользователя из сессии.
  Future<String> _getCurrentUserId() async {
    // В реальном приложении получаем ID из JWT токена
    // Для демонстрации возвращаем временный ID
    return 'current-user-id';
  }
  
  /// Получает список чатов.
  Future<List<Chat>> getChats() async {
    return _chatRepository.getChats();
  }
  
  /// Получает сообщения для указанного чата.
  Future<List<ChatMessage>> getMessages(String chatId) async {
    return _chatRepository.getMessages(chatId);
  }
  
  /// Освобождает ресурсы.
  void dispose() {
    _messageSubject.close();
    _chatListSubject.close();
  }
}