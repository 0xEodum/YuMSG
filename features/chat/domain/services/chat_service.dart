// lib/features/chat/domain/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/communication/connection_state.dart';
import '../services/message_queue_service.dart';
import '../../../../core/crypto/services/crypto_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../../core/services/websocket/websocket_service.dart';
import '../../../../core/services/websocket/websocket_event.dart';
import '../models/chat.dart';
import '../models/chat_key.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../managers/chat_manager.dart';

/// Сервис для управления чатами, обработки сообщений и обмена ключами.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  final YuCryptoService _cryptoService = YuCryptoService();
  final WebSocketService _webSocketService = WebSocketService();
  final SessionService _sessionService = SessionService();
  final ChatRepository _chatRepository = ChatRepository();
  final CommunicationService _communicationService = CommunicationService();
  final ChatManager _chatManager = ChatManager();

  // Потоки для публикации событий
  final _messageSubject = PublishSubject<ChatMessage>();
  final _chatListSubject = BehaviorSubject<List<Chat>>.seeded([]);

  Stream<ChatMessage> get messages => _messageSubject.stream;
  Stream<List<Chat>> get chats => _chatListSubject.stream;

  ChatService._internal() {
    // Инициализируем обработчики WebSocket событий
    _webSocketService.onChatInit.listen(handleChatInitEvent);
    _webSocketService.onKeyExchange.listen(handleKeyExchangeEvent);
    _webSocketService.onKeyExchangeComplete.listen(handleKeyExchangeCompleteEvent);
    _webSocketService.onMessage.listen(handleMessageEvent);
    _webSocketService.onMessageStatus.listen(handleMessageStatusEvent);
    _webSocketService.onChatDelete.listen(handleChatDeleteEvent);

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
  Future<String?> initializeChat(String recipientId, String recipientName) async {
    try {
      debugPrint('initializeChat: Starting initialization with recipientId: $recipientId');
      
      // Проверяем, есть ли соединение
      if (!_communicationService.isConnected) {
        debugPrint('initializeChat: WebSocket not connected, cannot initialize chat');
        throw Exception('WebSocket не подключен, невозможно инициализировать чат');
      }
      
      // Проверяем, был ли чат удален пользователем
      if (await _chatManager.isChatWithUserDeleted(recipientId)) {
        // Если да, снимаем пометку удаления
        await _chatManager.clearDeletedChatMark(recipientId);
      }
      
      // Получаем свой локальный ID чата
      final chatId = _chatManager.generateChatId(recipientId);
      
      // Проверяем существование чата
      if (await _chatManager.hasChatWithUser(recipientId)) {
        debugPrint('initializeChat: Chat already exists with user $recipientId');
        return chatId;
      }
      
      debugPrint('initializeChat: Generating key pair...');
      
      // Генерируем пару ключей для чата
      final keyPair = await _cryptoService.generateKeyPair();
      debugPrint('initializeChat: Key pair generated successfully');
      
      // Генерируем частичный ключ
      final partialKey = await _cryptoService.generateRandomBytes(32);
      
      // Создаем и сохраняем ключи перед отправкой запроса
      await _chatRepository.saveChatKeys(
        ChatKey(
          chatId: chatId,
          userId: recipientId,
          publicKey: keyPair.publicKey,
          privateKey: keyPair.privateKey,
          partialKey: partialKey,
          isComplete: false,
        ),
      );
      debugPrint('initializeChat: Keys saved to repository');
      
      // Создаем чат в локальном хранилище
      final chat = await _chatManager.getOrCreateChatWithUser(
        recipientId, 
        recipientName,
        isInitialized: false
      );
      debugPrint('initializeChat: Chat created and saved');
      
      // Получаем свое имя пользователя для отправки инициатору
      final myUsername = await _getUsername();
      
      try {
        // Отправляем инициализацию через WebSocket
        await _webSocketService.sendChatInit(
          recipientId,
          keyPair.publicKey,
        );
        debugPrint('initializeChat: Initialization request sent successfully');
      } catch (e) {
        debugPrint('initializeChat: Error sending initialization request: $e');
        throw Exception('Не удалось отправить запрос инициализации: $e');
      }
      
      // Обновляем список чатов
      _loadChats();
      
      debugPrint('initializeChat: Completed successfully, returning chatId: $chatId');
      return chatId;
    } catch (e) {
      debugPrint('initializeChat: Error initializing chat: $e');
      debugPrintStack();
      return null;
    }
  }

  /// Обрабатывает входящий запрос на инициализацию чата.
  Future<void> handleChatInitEvent(ChatInitEvent event) async {
    try {
      final senderId = event.senderId;
      final initiatorName = event.initiatorName;
      final remotePublicKey = event.publicKey;

      debugPrint('Handling chat initialization from $initiatorName ($senderId)');
      
      // Проверяем, был ли чат удален пользователем
      if (await _chatManager.isChatWithUserDeleted(senderId)) {
        // Если да, снимаем пометку удаления
        await _chatManager.clearDeletedChatMark(senderId);
      }
      
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(senderId);
      
      // Создаем чат в локальном хранилище, если его еще нет
      await _chatManager.getOrCreateChatWithUser(senderId, initiatorName);

      // Генерируем свою пару ключей для ответа
      final keyPair = await _cryptoService.generateKeyPair();
      
      // Генерируем частичный ключ
      final partialKey = await _cryptoService.generateRandomBytes(32);

      // Шифруем часть ключа публичным ключом инициатора
      final encryptedPartialKey = await _cryptoService.encryptAsymmetric(
        partialKey,
        remotePublicKey,
      );

      // Получаем свое имя пользователя для отправки инициатору
      final myUsername = await _getUsername();
      
      // Сохраняем информацию о ключах для дальнейшего завершения обмена
      await _chatRepository.saveChatKeys(
        ChatKey(
          chatId: chatId,
          userId: senderId,
          publicKey: keyPair.publicKey,
          privateKey: keyPair.privateKey,
          remotePublicKey: remotePublicKey,
          partialKey: partialKey,
          isComplete: false,
        ),
      );

      // Отправляем ответ с ключами
      await _webSocketService.sendKeyExchange(
        senderId,
        keyPair.publicKey,
        encryptedPartialKey,
      );

      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error handling chat initialization: $e');
      debugPrintStack();
    }
  }

  /// Обрабатывает ответ при обмене ключами.
  Future<void> handleKeyExchangeEvent(KeyExchangeEvent event) async {
    try {
      final senderId = event.senderId;
      final responderName = event.responderName;
      final remotePublicKey = event.publicKey;
      final encryptedPartialKey = event.encryptedPartialKey;

      debugPrint('Handling key exchange from $responderName ($senderId)');
      
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(senderId);

      // Получаем наши ключи для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null) {
        throw Exception('Chat keys not found for chat with user: $senderId');
      }

      // Расшифровываем частичный ключ собеседника
      final remotePartialKey = await _cryptoService.decryptAsymmetric(
        encryptedPartialKey,
        chatKeyData.privateKey,
      );

      // Генерируем нашу часть симметричного ключа
      final ourPartialKey = await _cryptoService.generateRandomBytes(32);

      // Комбинируем ключи для создания полного симметричного ключа
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
        senderId,
        encryptedOurPartialKey,
      );

      // Обновляем имя пользователя, если оно изменилось
      await _chatManager.updateUserName(senderId, responderName);
      
      // Обновляем данные ключа в хранилище
      await _chatRepository.saveChatKeys(
        chatKeyData.copyWith(
          remotePublicKey: remotePublicKey,
          symmetricKey: combinedKey,
          isComplete: true,
        ),
      );

      // Обновляем статус чата на "инициализирован"
      final chat = await _chatManager.getChatWithUser(senderId);
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(isInitialized: true),
        );

        // Обновляем список чатов
        _loadChats();
      }
    } catch (e) {
      debugPrint('Error handling key exchange: $e');
      debugPrintStack();
    }
  }

  /// Обрабатывает завершение обмена ключами.
  Future<void> handleKeyExchangeCompleteEvent(
      KeyExchangeCompleteEvent event) async {
    try {
      final senderId = event.senderId;
      final encryptedPartialKey = event.encryptedPartialKey;

      debugPrint('Handling key exchange completion from user $senderId');
      
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(senderId);

      // Получаем данные ключей для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null) {
        throw Exception('Chat keys not found for chat with user: $senderId');
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
      final chat = await _chatManager.getChatWithUser(senderId);
      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(isInitialized: true),
        );

        // Обновляем список чатов
        _loadChats();
      }
    } catch (e) {
      debugPrint('Error handling key exchange completion: $e');
      debugPrintStack();
    }
  }

  /// Отправляет сообщение пользователю.
  Future<bool> sendMessage(String recipientId, String content, {String type = 'text'}) async {
    try {
      debugPrint('Sending message to user $recipientId');
      
      // Получаем ID текущего пользователя
      final userId = await getCurrentUserId();

      // Создаем локальный ID чата
      final chatId = _chatManager.generateChatId(recipientId);
      
      // Генерируем ID сообщения
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, min(5, userId.length))}';

      // Создаем объект сообщения
      final message = ChatMessage(
        id: messageId,
        chatId: chatId,
        senderId: userId,
        content: content, // Расшифрованное содержимое для отображения
        type: type,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        isPending: !_communicationService.isConnected, // Помечаем как ожидающее, если нет соединения
      );

      // Получаем данные ключей для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null || !chatKeyData.isComplete) {
        throw Exception('Chat keys not found or incomplete for chat with user: $recipientId');
      }

      // Шифруем контент сообщения симметричным ключом
      final encryptedContent = await _cryptoService.encryptSymmetric(
        content,
        chatKeyData.symmetricKey!,
      );

      // Создаём копию сообщения с зашифрованным содержимым для хранения
      ChatMessage messageToStore;

      if (_communicationService.isConnected) {
        // Отправляем сообщение через WebSocket
        await _webSocketService.sendChatMessage(
          recipientId,
          messageId,
          encryptedContent,
          type: type,
        );

        // Обновляем статус сообщения на "отправлено"
        messageToStore = message.copyWith(
          status: MessageStatus.sent,
          encryptedContent: encryptedContent, // Сохраняем зашифрованную версию
        );
      } else {
        // Если нет соединения
        messageToStore = message.copyWith(
          encryptedContent: encryptedContent,
        );

        // Добавляем сообщение в очередь на отправку
        await MessageQueueService().enqueueMessage(messageToStore);
      }

      // Сохраняем сообщение локально
      await _chatRepository.saveMessage(messageToStore);

      // Обновляем информацию о чате
      final chat = await _chatManager.getChatWithUser(recipientId);
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
      _messageSubject.add(messageToStore);

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      debugPrintStack();
      return false;
    }
  }


/// Обрабатывает входящее сообщение.
Future<void> handleMessageEvent(ChatMessageEvent event) async {
  try {
      final senderId = event.senderId;
      final messageId = event.messageId;
      final encryptedContent = event.content;
      final type = event.type;
      final timestamp = DateTime.parse(event.timestamp);

      debugPrint('Handling incoming message from user $senderId');
      
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(senderId);

      // Проверяем, был ли чат удален
      if (await _chatManager.isChatWithUserDeleted(senderId)) {
        debugPrint('Chat with user $senderId was deleted, ignoring message');
        return;
      }

      // Получаем данные ключей
      final chatKey = await _chatRepository.getChatKeys(chatId);
      if (chatKey == null || !chatKey.isComplete) {
        debugPrint('Chat keys not found or incomplete for chat with user: $senderId');
        return;
      }

      // Расшифровываем контент
      String decryptedContent;
      try {
        decryptedContent = await _cryptoService.decryptSymmetric(
          encryptedContent,
          chatKey.symmetricKey!,
        );
      } catch (e) {
        debugPrint('Error decrypting message: $e');
        decryptedContent = '[Ошибка расшифровки сообщения]';
      }

      // Создаем объект сообщения с обоими версиями контента
      final message = ChatMessage(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        content: decryptedContent, // Расшифрованный контент для отображения
        encryptedContent: encryptedContent, // Зашифрованный контент для хранения
        type: type,
        timestamp: timestamp,
        status: MessageStatus.delivered,
      );

      // Сохраняем сообщение локально
      await _chatRepository.saveMessage(message);

      // Обновляем статус сообщения на "доставлено"
      await _webSocketService.sendMessageStatus(
        senderId,
        messageId,
        'delivered',
      );

      // Проверяем существование чата, создаем если его нет
      Chat chat;
      final existingChat = await _chatManager.getChatWithUser(senderId);
      if (existingChat == null) {
        // Если чат не существует, создаем новый
        chat = await _chatManager.getOrCreateChatWithUser(
          senderId, 
          'Пользователь',
          isInitialized: true
        );
      } else {
        chat = existingChat;
      }

      // Обновляем информацию о чате
      final userId = await getCurrentUserId();
      final isFromMe = senderId == userId;

      await _chatRepository.saveChat(
        chat.copyWith(
          lastMessage: decryptedContent,
          lastMessageTime: timestamp,
          unreadCount: isFromMe ? chat.unreadCount : chat.unreadCount + 1,
        ),
      );

      // Обновляем список чатов
      _loadChats();

      // Публикуем сообщение в поток
      _messageSubject.add(message);
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
      debugPrintStack();
    }
}


  /// Обрабатывает обновление статуса сообщения.
  Future<void> handleMessageStatusEvent(MessageStatusEvent event) async {
    try {
      final senderId = event.senderId;
      final messageId = event.messageId;
      final status = event.status;

      debugPrint('Handling message status update from user $senderId: $status');

      // Проверяем, был ли чат удален
      if (await _chatManager.isChatWithUserDeleted(senderId)) {
        debugPrint('Chat with user $senderId was deleted, ignoring status update');
        return;
      }

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
      debugPrintStack();
    }
  }

  /// Обрабатывает удаление чата собеседником.
  Future<void> handleChatDeleteEvent(ChatDeleteEvent event) async {
    try {
      final senderId = event.senderId;

      debugPrint('Handling chat delete request from user $senderId');

      // Проверяем, существует ли чат
      if (await _chatManager.hasChatWithUser(senderId)) {
        // Получаем локальный ID чата
        final chatId = _chatManager.generateChatId(senderId);
        
        // Получаем чат для показа уведомления
        final chat = await _chatManager.getChatWithUser(senderId);
        
        // В этой реализации мы не удаляем чат полностью, а помечаем его
        if (chat != null) {
          await _chatRepository.saveChat(
            chat.copyWith(
              lastMessage: 'Собеседник удалил чат',
              isInitialized: false, // Помечаем как неинициализированный
            ),
          );
          
          // Помечаем чат как удаленный со стороны собеседника
          await _chatManager.markChatWithUserAsDeleted(senderId);
        }
        
        // Обновляем список чатов
        _loadChats();
      }
    } catch (e) {
      debugPrint('Error handling chat delete event: $e');
      debugPrintStack();
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
  Future<String> getCurrentUserId() async {
    try {
      // Получаем данные авторизации
      final authData = await _sessionService.getAuthData();
      if (authData == null) {
        throw Exception('Нет данных авторизации');
      }

      // Извлекаем полезную нагрузку из JWT токена
      final payload = _decodeJwtPayload(authData.accessToken);

      // Извлекаем ID пользователя из стандартного поля sub
      if (payload.containsKey('sub')) {
        return payload['sub'] as String;
      }

      throw Exception(
          'Не удалось извлечь ID пользователя из токена: поле "sub" отсутствует');
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      // В случае ошибки возвращаем временный ID для предотвращения сбоев UI
      return 'unknown-user';
    }
  }

  /// Получает имя текущего пользователя.
  Future<String> _getUsername() async {
    try {
      // Получаем данные авторизации
      final authData = await _sessionService.getAuthData();
      if (authData == null) {
        throw Exception('Нет данных авторизации');
      }

      // Извлекаем полезную нагрузку из JWT токена
      final payload = _decodeJwtPayload(authData.accessToken);

      // Извлекаем имя пользователя из поля username
      if (payload.containsKey('username')) {
        return payload['username'] as String;
      }

      return 'Пользователь';
    } catch (e) {
      debugPrint('Error getting username: $e');
      return 'Пользователь';
    }
  }

  /// Декодирует полезную нагрузку из JWT токена.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      // JWT состоит из трёх частей, разделенных точками: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Некорректная структура JWT токена');
      }

      // Декодируем Base64Url средней части (payload)
      String normalizedPayload = parts[1];
      // Дополняем строку, если её длина не кратна 4
      normalizedPayload = base64Url.normalize(normalizedPayload);

      // Декодируем Base64 в строку и затем парсим JSON
      final payloadString = utf8.decode(base64Url.decode(normalizedPayload));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error decoding JWT: $e');
      return {};
    }
  }

  /// Проверяет статус шифрования чата.
  Future<bool> checkEncryptionStatus(String userId) async {
    try {
      final chatId = _chatManager.generateChatId(userId);
      final chatKey = await _chatRepository.getChatKeys(chatId);
      return chatKey != null && chatKey.isComplete;
    } catch (e) {
      debugPrint('Error checking encryption status: $e');
      return false;
    }
  }

  /// Очищает историю сообщений указанного чата.
  Future<void> clearChatHistory(String userId) async {
    try {
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(userId);
      
      // Получаем текущий чат
      final chat = await _chatManager.getChatWithUser(userId);
      if (chat == null) {
        throw Exception('Чат не найден');
      }

      // Получаем все сообщения чата
      final messages = await _chatRepository.getMessages(chatId);

      // Удаляем сообщения по одному
      for (final message in messages) {
        await _chatRepository.deleteMessage(message.id, chatId);
      }

      // Обновляем информацию о последнем сообщении
      await _chatRepository.saveChat(
        chat.copyWith(
          lastMessage: 'История чата очищена',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        ),
      );

      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
      throw Exception('Не удалось очистить историю чата: ${e.toString()}');
    }
  }

  /// Удаляет чат полностью.
  Future<void> deleteChat(String userId) async {
    try {
      debugPrint('Deleting chat with user $userId');
      
      // Удаляем чат через ChatManager
      await _chatManager.deleteChatWithUser(userId);
      
      // Отправляем уведомление об удалении чата другому пользователю
      if (_communicationService.isConnected) {
        try {
          await _webSocketService.sendChatDelete(userId);
        } catch (e) {
          debugPrint('Error sending chat delete notification: $e');
          // Продолжаем даже при ошибке отправки уведомления
        }
      }

      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      throw Exception('Не удалось удалить чат: ${e.toString()}');
    }
  }

  /// Повторно инициализирует чат (пересоздает ключи шифрования).
  Future<void> reinitializeChat(String userId) async {
    try {
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(userId);
      
      // Информация о чате
      final chat = await _chatManager.getChatWithUser(userId);
      if (chat == null) {
        throw Exception('Чат не найден');
      }

      // Удаляем текущие ключи
      await _chatRepository.deleteChatKeys(chatId);

      // Обновляем статус чата на "не инициализирован"
      await _chatRepository.saveChat(
        chat.copyWith(isInitialized: false),
      );

      // Если есть соединение, инициируем новый обмен ключами
      if (_communicationService.isConnected) {
        // Генерируем новую пару ключей
        final keyPair = await _cryptoService.generateKeyPair();
        final partialKey = await _cryptoService.generateRandomBytes(32);
        
        // Получаем свое имя пользователя для отправки
        final myUsername = await _getUsername();

        // Отправляем запрос на инициализацию чата
        await _webSocketService.sendChatInit(
          userId,
          keyPair.publicKey
        );

        // Сохраняем временные данные ключей
        await _chatRepository.saveChatKeys(
          ChatKey(
            chatId: chatId,
            userId: userId,
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey,
            partialKey: partialKey,
            isComplete: false,
          ),
        );
      }

      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error reinitializing chat: $e');
      throw Exception('Не удалось пересоздать ключи: ${e.toString()}');
    }
  }

  /// Получает список чатов.
  Future<List<Chat>> getChats() async {
    final chats = await _chatRepository.getChats();
    
    // Фильтруем удаленные чаты
    final result = <Chat>[];
    for (final chat in chats) {
      if (!await _chatManager.isChatWithUserDeleted(chat.participantId)) {
        result.add(chat);
      }
    }
    
    return result;
  }

  /// Получает сообщения для указанного чата.
  Future<List<ChatMessage>> getMessages(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      // Получаем локальный ID чата
      final chatId = _chatManager.generateChatId(userId);
      
      // Проверяем, был ли чат удален
      if (await _chatManager.isChatWithUserDeleted(userId)) {
        return [];
      }
      
      // Получаем ключи чата
      final chatKey = await _chatRepository.getChatKeys(chatId);
      
      // Получаем все сообщения для чата
      final allMessages = await _chatRepository.getMessages(chatId);

      // Проверяем, нужно ли расшифровывать какие-либо сообщения
      if (chatKey != null && chatKey.isComplete && chatKey.symmetricKey != null) {
        for (int i = 0; i < allMessages.length; i++) {
          final message = allMessages[i];
  
          // Если у сообщения есть зашифрованное содержимое, но нет расшифрованного
          if (message.encryptedContent != null &&
              (message.content.isEmpty ||
                  message.content == '[Зашифрованное сообщение]')) {
            try {
              // Расшифровываем содержимое
              final decryptedContent = await _cryptoService.decryptSymmetric(
                message.encryptedContent!,
                chatKey.symmetricKey!,
              );
  
              // Обновляем сообщение с расшифрованным содержимым
              final updatedMessage = message.copyWith(content: decryptedContent);
              await _chatRepository.saveMessage(updatedMessage);
  
              // Обновляем сообщение в текущем списке
              allMessages[i] = updatedMessage;
            } catch (e) {
              debugPrint('Error decrypting message ${message.id}: $e');
              // В случае ошибки оставляем оригинальное сообщение
            }
          }
        }
      }

      // Сортируем по времени (от старых к новым)
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Применяем пагинацию
      final startIndex = max(0, allMessages.length - (page * pageSize));
      final endIndex =
          min(allMessages.length, allMessages.length - ((page - 1) * pageSize));

      if (startIndex >= endIndex) {
        return [];
      }

      return allMessages.sublist(startIndex, endIndex);
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Помечает сообщение как прочитанное.
  Future<void> markMessageAsRead(String messageId) async {
    try {
      // Получаем сообщение
      final message = await _chatRepository.getMessage(messageId);
      if (message == null) return;

      // Если сообщение уже прочитано, ничего не делаем
      if (message.status == MessageStatus.read) return;

      // Обновляем статус сообщения локально
      await _chatRepository.saveMessage(
        message.copyWith(status: MessageStatus.read),
      );

      // Извлекаем ID пользователя из ID чата (новый формат: chat_with_userId)
      final chatId = message.chatId;
      final prefixLength = 'chat_with_'.length;
      if (chatId.length > prefixLength && chatId.startsWith('chat_with_')) {
        final recipientId = chatId.substring(prefixLength);
        
        // Отправляем статус на сервер
        await _webSocketService.sendMessageStatus(
          recipientId,
          messageId,
          'read',
        );
      }

      // Публикуем обновленное сообщение
      _messageSubject.add(message.copyWith(status: MessageStatus.read));
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Открывает существующий чат или создает новый с пользователем.
  Future<String?> openOrCreateChat(String userId, String userName) async {
    try {
      debugPrint('openOrCreateChat: Starting for user $userId ($userName)');

      // Проверяем, был ли чат удален пользователем
      if (await _chatManager.isChatWithUserDeleted(userId)) {
        // Если да, снимаем пометку удаления
        await _chatManager.clearDeletedChatMark(userId);
      }
      
      // Проверяем, существует ли чат с пользователем
      if (await _chatManager.hasChatWithUser(userId)) {
        // Чат существует, возвращаем его ID
        final chatId = _chatManager.generateChatId(userId);
        debugPrint('openOrCreateChat: Existing chat found with ID: $chatId');
        return chatId;
      }

      // Если чат не существует и есть соединение, инициируем новый
      if (_communicationService.isConnected) {
        debugPrint('openOrCreateChat: No existing chat found, initializing new chat');
        return await initializeChat(userId, userName);
      } else {
        // Если нет соединения, создаем локальный чат без инициализации
        final chat = await _chatManager.getOrCreateChatWithUser(
          userId, 
          userName,
          isInitialized: false
        );
        debugPrint('openOrCreateChat: Created local chat without initialization');
        return chat.id;
      }
    } catch (e) {
      debugPrint('openOrCreateChat: Error opening or creating chat: $e');
      debugPrintStack();
      return null;
    }
  }

  /// Инициализирует сервис чатов.
  Future<void> initialize() async {
    try {
      // Загружаем чаты
      await _loadChats();

      // Запускаем обработку очереди сообщений
      MessageQueueService().startQueueProcessing();

      // Подписываемся на изменения состояния соединения
      _communicationService.connectionState.listen(_handleConnectionChange);
    } catch (e) {
      debugPrint('Error initializing ChatService: $e');
    }
  }

  /// Обрабатывает изменение состояния соединения.
  void _handleConnectionChange(YuConnectionState state) {
    if (state == YuConnectionState.connected) {
      // При восстановлении соединения пытаемся обработать очередь сообщений
      MessageQueueService().processQueue();
    }
  }

  /// Освобождает ресурсы.
  void dispose() {
    _messageSubject.close();
    _chatListSubject.close();
    MessageQueueService().stopQueueProcessing();
  }
}