// lib/features/chat/domain/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:yumsg/core/services/communication/communication_service.dart';
import 'package:yumsg/core/services/communication/connection_state.dart';
import 'package:yumsg/features/chat/domain/services/message_queue_service.dart';
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
  final CommunicationService _communicationService = CommunicationService();

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
      final combinedKey =
          await _cryptoService.deriveKey(remotePartialKey + ourPartialKey);

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
  Future<void> _handleKeyExchangeComplete(
      KeyExchangeCompleteEvent event) async {
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
      final combinedKey = await _cryptoService
          .deriveKey(chatKeyData.partialKey + remotePartialKey);

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
  Future<bool> sendMessage(String chatId, String content,
      {String type = 'text'}) async {
    try {
      // Получаем ID текущего пользователя
      final userId = await getCurrentUserId();

      // Создаем объект сообщения
      final message = ChatMessage(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: userId,
        content: content, // Расшифрованное содержимое
        type: type,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        isPending: !_communicationService
            .isConnected, // Помечаем как ожидающее, если нет соединения
      );

      // Получаем данные ключей для этого чата
      final chatKeyData = await _chatRepository.getChatKeys(chatId);
      if (chatKeyData == null || !chatKeyData.isComplete) {
        throw Exception(
            'Chat keys not found or incomplete for chatId: $chatId');
      }

      // Создаём копию сообщения с зашифрованным содержимым для хранения
      ChatMessage messageToStore;

      if (_communicationService.isConnected) {
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

        // Обновляем статус сообщения на "отправлено"
        messageToStore = message.copyWith(
          status: MessageStatus.sent,
          encryptedContent: encryptedContent, // Сохраняем зашифрованную версию
        );
      } else {
        // Если нет соединения, шифруем для сохранения, но не отправляем
        final encryptedContent = await _cryptoService.encryptSymmetric(
          content,
          chatKeyData.symmetricKey!,
        );

        messageToStore = message.copyWith(
          encryptedContent: encryptedContent,
        );

        // Добавляем сообщение в очередь на отправку
        await MessageQueueService().enqueueMessage(messageToStore);
      }

      // Сохраняем сообщение локально
      await _chatRepository.saveMessage(messageToStore);

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
      _messageSubject.add(messageToStore);

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
      final chatKey = await _chatRepository.getChatKeys(chatId);
      if (chatKey == null || !chatKey.isComplete) {
        throw Exception(
            'Chat keys not found or incomplete for chatId: $chatId');
      }

      // Расшифровываем контент
      final decryptedContent = await _cryptoService.decryptSymmetric(
        encryptedContent,
        chatKey.symmetricKey!,
      );

      // Создаем объект сообщения с обоими версиями контента
      final message = ChatMessage(
        id: event.messageId,
        chatId: chatId,
        senderId: senderId,
        content: decryptedContent, // Расшифрованный контент для отображения
        encryptedContent:
            encryptedContent, // Зашифрованный контент для хранения
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
      final userId = await getCurrentUserId();
      final isFromMe = senderId == userId;

      if (chat != null) {
        await _chatRepository.saveChat(
          chat.copyWith(
            lastMessage: decryptedContent,
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

  Future<bool> checkEncryptionStatus(String chatId) async {
    try {
      final chatKey = await _chatRepository.getChatKeys(chatId);
      return chatKey != null && chatKey.isComplete;
    } catch (e) {
      debugPrint('Error checking encryption status: $e');
      return false;
    }
  }

  /// Очищает историю сообщений указанного чата.
  Future<void> clearChatHistory(String chatId) async {
    try {
      // Получаем текущий чат
      final chat = await _chatRepository.getChat(chatId);
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
  Future<void> deleteChat(String chatId) async {
    try {
      // Удаляем сообщения
      await _chatRepository.deleteAllMessages(chatId);

      // Удаляем ключи шифрования
      await _chatRepository.deleteChatKeys(chatId);

      // Удаляем сам чат
      await _chatRepository.deleteChat(chatId);

      // Обновляем список чатов
      _loadChats();
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      throw Exception('Не удалось удалить чат: ${e.toString()}');
    }
  }

  /// Повторно инициализирует чат (пересоздает ключи шифрования).
  Future<void> reinitializeChat(String chatId) async {
    try {
      // Получаем информацию о чате
      final chat = await _chatRepository.getChat(chatId);
      if (chat == null) {
        throw Exception('Чат не найден');
      }

      // Удаляем текущие ключи
      await _chatRepository.deleteChatKeys(chatId);

      // Обновляем статус чата на "не инициализирован"
      await _chatRepository.saveChat(
        chat.copyWith(isInitialized: false),
      );

      // Если это серверный режим, инициируем новый обмен ключами
      if (_communicationService.isConnected) {
        // Генерируем новую пару ключей
        final keyPair = await _cryptoService.generateKeyPair();

        // Отправляем запрос на инициализацию чата
        await _webSocketService.sendChatInitialization(
          chat.participantId,
          keyPair.publicKey,
        );

        // Сохраняем временные данные ключей
        await _chatRepository.saveChatKeys(
          ChatKey(
            chatId: chatId,
            userId: chat.participantId,
            publicKey: keyPair.publicKey,
            privateKey: keyPair.privateKey,
            partialKey: await _cryptoService.generateRandomBytes(32),
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
    return _chatRepository.getChats();
  }

  /// Получает сообщения для указанного чата.
  Future<List<ChatMessage>> getMessages(
    String chatId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      // Получаем ключи чата
      final chatKey = await _chatRepository.getChatKeys(chatId);
      if (chatKey == null || !chatKey.isComplete) {
        debugPrint(
            'Warning: Chat keys not found or incomplete for chatId: $chatId');
        return [];
      }

      // Получаем все сообщения для чата
      final allMessages = await _chatRepository.getMessages(chatId);

      // Проверяем, нужно ли расшифровывать какие-либо сообщения
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

      // Отправляем статус на сервер
      await _webSocketService.sendMessageStatus(
        messageId,
        message.chatId,
        'read',
      );

      // Публикуем обновленное сообщение
      _messageSubject.add(message.copyWith(status: MessageStatus.read));
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  /// Открывает существующий чат или создает новый с пользователем.
  Future<String?> openOrCreateChat(String userId, String userName) async {
    try {
      // Пытаемся найти существующий чат с пользователем
      final chats = await getChats();

      final existingChat =
          chats.where((chat) => chat.participantId == userId).firstOrNull;

      if (existingChat != null) {
        return existingChat.id;
      }

      // Если чат не найден, инициируем новый
      final chatId = await initializeChat(userId);

      if (chatId == null) {
        throw Exception('Не удалось создать чат');
      }

      // Создаем локальную запись о чате
      final newChat = Chat(
        id: chatId,
        participantId: userId,
        participantName: userName,
        lastMessage: 'Чат инициализирован',
        lastMessageTime: DateTime.now(),
        isInitialized: false,
      );

      await _chatRepository.saveChat(newChat);

      // Обновляем список чатов
      _loadChats();

      return chatId;
    } catch (e) {
      debugPrint('Error opening or creating chat: $e');
      return null;
    }
  }

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

  void _handleConnectionChange(YuConnectionState state) {
    if (state == YuConnectionState.connected) {
      // При восстановлении соединения пытаемся обработать очередь сообщений
      MessageQueueService().processQueue();
    }
  }

  /// Освобождает ресурсы.
  @override
  void dispose() {
    _messageSubject.close();
    _chatListSubject.close();
    MessageQueueService().stopQueueProcessing();
  }
}
