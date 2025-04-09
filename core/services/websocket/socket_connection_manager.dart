// lib/core/services/websocket/socket_connection_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session/session_service.dart';
import '../../data/providers/server_data_provider.dart';
import 'websocket_event.dart';
import 'websocket_message_storage.dart';

/// Менеджер WebSocket соединений - единственная точка подключения как для основного,
/// так и для фонового режима работы приложения.
class SocketConnectionManager {
  static final SocketConnectionManager _instance = SocketConnectionManager._internal();
  factory SocketConnectionManager() => _instance;
  
  // Методканал для связи с нативным кодом
  static const _platform = MethodChannel('com.yumsg/socket_manager');
  
  // Канал событий для получения событий из нативного кода
  static const _eventChannel = EventChannel('com.yumsg/socket_events');
  
  final _sessionService = SessionService();
  final _messageStorage = WebSocketMessageStorage();
  
  // Флаги состояния
  bool _isInitialized = false;
  bool _isConnected = false;
  StreamSubscription? _nativeEventSubscription;
  Timer? _pingTimer;
  
  // Состояние соединения
  final _connectionState = BehaviorSubject<bool>.seeded(false);
  
  // Контроллеры для типов событий, получаемых через WebSocket
  final _onChatInit = PublishSubject<ChatInitEvent>();
  final _onKeyExchange = PublishSubject<KeyExchangeEvent>();
  final _onKeyExchangeComplete = PublishSubject<KeyExchangeCompleteEvent>();
  final _onMessage = PublishSubject<ChatMessageEvent>();
  final _onMessageStatus = PublishSubject<MessageStatusEvent>();
  final _onChatDelete = PublishSubject<ChatDeleteEvent>();

  // Стримы
  Stream<bool> get connectionState => _connectionState.stream;
  Stream<ChatInitEvent> get onChatInit => _onChatInit.stream;
  Stream<KeyExchangeEvent> get onKeyExchange => _onKeyExchange.stream;
  Stream<KeyExchangeCompleteEvent> get onKeyExchangeComplete => _onKeyExchangeComplete.stream;
  Stream<ChatMessageEvent> get onMessage => _onMessage.stream;
  Stream<MessageStatusEvent> get onMessageStatus => _onMessageStatus.stream;
  Stream<ChatDeleteEvent> get onChatDelete => _onChatDelete.stream;

  bool get isConnected => _isConnected;
  
  SocketConnectionManager._internal() {
    // Слушаем события из нативного кода
    _setupEventChannel();
  }
  
  /// Настраивает канал событий для получения сообщений от нативного кода.
  void _setupEventChannel() {
    _nativeEventSubscription?.cancel();
    _nativeEventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleNativeEvent, onError: (error) {
      debugPrint('Error from native event channel: $error');
    });
  }
  
  /// Обрабатывает событие, полученное от нативного кода.
  void _handleNativeEvent(dynamic event) {
    try {
      if (event is! Map) return;
      
      final type = event['type'] as String?;
      if (type == null) return;
      
      switch (type) {
        case 'connectionChanged':
          final isConnected = event['isConnected'] as bool? ?? false;
          _isConnected = isConnected;
          _connectionState.add(isConnected);
          debugPrint('Socket connection state changed: $isConnected');
          break;
        
        case 'message':
          final messageData = event['data'] as String?;
          if (messageData != null) {
            _handleMessage(messageData);
          }
          break;
          
        case 'error':
          final errorMessage = event['message'] as String? ?? 'Unknown error';
          debugPrint('Socket error from native: $errorMessage');
          break;
      }
    } catch (e) {
      debugPrint('Error handling native event: $e');
    }
  }
  
  /// Инициализирует менеджер сокетов.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('SocketConnectionManager: Initializing');
      
      // Инициализируем хранилище сообщений
      await _messageStorage.initialize();
      
      // Проверяем наличие аутентификации
      final authData = await _sessionService.getAuthData();
      if (authData == null) {
        debugPrint('No auth data available, skipping socket initialization');
        return;
      }
      
      // Получаем адрес сервера
      final serverAddress = await _sessionService.getServerAddress();
      if (serverAddress == null) {
        debugPrint('No server address available, skipping socket initialization');
        return;
      }
      
      // Инициализируем WebSocket через нативный код
      await _platform.invokeMethod('initialize', {
        'serverAddress': serverAddress,
        'token': authData.accessToken,
      });
      
      _isInitialized = true;
      debugPrint('SocketConnectionManager: Initialized successfully');
    } catch (e) {
      debugPrint('SocketConnectionManager: Error initializing: $e');
    }
  }
  
  /// Устанавливает соединение с сервером.
  Future<bool> connect() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      debugPrint('SocketConnectionManager: Connecting to socket');
      final result = await _platform.invokeMethod('connect') as bool? ?? false;
      
      if (result) {
        // Запускаем таймер для ping сообщений
        _startPingTimer();
        
        // Отправляем накопившиеся сообщения
        await _sendPendingMessages();
      }
      
      return result;
    } catch (e) {
      debugPrint('SocketConnectionManager: Error connecting to socket: $e');
      return false;
    }
  }
  
  /// Отправляет все накопленные сообщения.
  Future<void> _sendPendingMessages() async {
    try {
      final pendingMessages = await _messageStorage.getPendingMessages();
      if (pendingMessages.isEmpty) return;
      
      debugPrint('SocketConnectionManager: Sending ${pendingMessages.length} pending messages');
      
      for (final message in pendingMessages) {
        await sendMessage(message);
      }
      
      // Очищаем отправленные сообщения
      await _messageStorage.clearPendingMessages();
    } catch (e) {
      debugPrint('SocketConnectionManager: Error sending pending messages: $e');
    }
  }
  
  /// Закрывает соединение с сервером.
  Future<bool> disconnect() async {
    try {
      _pingTimer?.cancel();
      
      final result = await _platform.invokeMethod('disconnect') as bool? ?? true;
      return result;
    } catch (e) {
      debugPrint('SocketConnectionManager: Error disconnecting socket: $e');
      return false;
    }
  }
  
  /// Запускает таймер для отправки ping сообщений.
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected) {
        sendRawMessage(json.encode({'type': 'ping'}));
      }
    });
  }
  
  /// Обрабатывает сообщение, полученное от сервера.
  void _handleMessage(String messageStr) {
    try {
      debugPrint('SocketConnectionManager: Received message: ${messageStr.length > 100 ? messageStr.substring(0, 100) + '...' : messageStr}');
      
      final data = jsonDecode(messageStr);
      
      if (!data.containsKey('type')) {
        debugPrint('Invalid message format: missing type field');
        return;
      }
      
      final messageType = data['type'];
      
      if (messageType == 'pong') {
        debugPrint('Received pong response');
        return;
      }
      
      if (!data.containsKey('sender_id')) {
        debugPrint('Invalid message format: missing sender_id field');
        return;
      }
      
      final senderId = data['sender_id'];
      final messageData = data['data'] ?? {};
      
      debugPrint('Processing message type: $messageType from $senderId');
      
      switch (messageType) {
        case 'chat.init':
          final event = ChatInitEvent.fromJson(senderId, messageData);
          _onChatInit.add(event);
          break;
          
        case 'chat.key_exchange':
          final event = KeyExchangeEvent.fromJson(senderId, messageData);
          _onKeyExchange.add(event);
          break;
          
        case 'chat.key_exchange_complete':
          final event = KeyExchangeCompleteEvent.fromJson(senderId, messageData);
          _onKeyExchangeComplete.add(event);
          break;
          
        case 'chat.message':
          final event = ChatMessageEvent.fromJson(senderId, messageData);
          _onMessage.add(event);
          
          // Автоматически отправляем статус доставки
          sendMessageStatus(senderId, event.messageId, 'delivered');
          break;
          
        case 'chat.status':
          final event = MessageStatusEvent.fromJson(senderId, messageData);
          _onMessageStatus.add(event);
          break;
          
        case 'chat.delete':
          final event = ChatDeleteEvent.fromJson(senderId, messageData);
          _onChatDelete.add(event);
          break;
      }
    } catch (e) {
      debugPrint('Error processing received message: $e');
    }
  }
  
  /// Отправляет сырое сообщение через сокет.
  Future<bool> sendRawMessage(String message) async {
    try {
      if (!isConnected) {
        debugPrint('SocketConnectionManager: Cannot send message, socket not connected');
        return false;
      }
      
      final result = await _platform.invokeMethod('sendMessage', {
        'message': message
      }) as bool? ?? false;
      
      return result;
    } catch (e) {
      debugPrint('SocketConnectionManager: Error sending message: $e');
      return false;
    }
  }
  
  /// Отправляет сообщение, сохраняя его локально, если соединение недоступно.
  Future<bool> sendMessage(Map<String, dynamic> messageData) async {
    try {
      final messageJson = json.encode(messageData);
      
      if (!isConnected) {
        // Если нет соединения, сохраняем сообщение локально
        await _messageStorage.savePendingMessage(messageData);
        debugPrint('SocketConnectionManager: Message saved for later sending');
        return false;
      }
      
      final result = await sendRawMessage(messageJson);
      if (!result) {
        // Если отправка не удалась, сохраняем сообщение локально
        await _messageStorage.savePendingMessage(messageData);
        debugPrint('SocketConnectionManager: Failed to send message, saved for later');
      }
      
      return result;
    } catch (e) {
      debugPrint('SocketConnectionManager: Error sending message: $e');
      
      // Сохраняем сообщение для последующей отправки
      try {
        await _messageStorage.savePendingMessage(messageData);
      } catch (storageError) {
        debugPrint('SocketConnectionManager: Error saving message: $storageError');
      }
      
      return false;
    }
  }
  
  /// Отправляет инициализацию чата.
  Future<bool> sendChatInit(String recipientId, String publicKey) async {
    return await sendMessage({
      'type': 'chat.init',
      'recipient_id': recipientId,
      'data': {'public_key': publicKey}
    });
  }
  
  /// Отправляет обмен ключами.
  Future<bool> sendKeyExchange(String recipientId, String publicKey, String encryptedPartialKey) async {
    return await sendMessage({
      'type': 'chat.key_exchange',
      'recipient_id': recipientId,
      'data': {
        'public_key': publicKey,
        'encrypted_partial_key': encryptedPartialKey
      }
    });
  }
  
  /// Отправляет завершение обмена ключами.
  Future<bool> sendKeyExchangeComplete(String recipientId, String encryptedPartialKey) async {
    return await sendMessage({
      'type': 'chat.key_exchange_complete',
      'recipient_id': recipientId,
      'data': {'encrypted_partial_key': encryptedPartialKey}
    });
  }
  
  /// Отправляет сообщение чата.
  Future<bool> sendChatMessage(String recipientId, String messageId, String content, {
    String type = 'text',
    Map<String, dynamic>? metadata
  }) async {
    return await sendMessage({
      'type': 'chat.message',
      'recipient_id': recipientId,
      'data': {
        'message_id': messageId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        if (metadata != null) 'metadata': metadata
      }
    });
  }
  
  /// Отправляет статус сообщения.
  Future<bool> sendMessageStatus(String recipientId, String messageId, String status) async {
    return await sendMessage({
      'type': 'chat.status',
      'recipient_id': recipientId,
      'data': {
        'message_id': messageId,
        'status': status
      }
    });
  }
  
  /// Отправляет уведомление об удалении чата.
  Future<bool> sendChatDelete(String recipientId) async {
    return await sendMessage({
      'type': 'chat.delete',
      'recipient_id': recipientId,
      'data': {}
    });
  }
  
  /// Обновляет токен авторизации после его обновления.
  Future<void> updateToken(String token) async {
    try {
      await _platform.invokeMethod('updateToken', {
        'token': token
      });
      debugPrint('SocketConnectionManager: Auth token updated');
    } catch (e) {
      debugPrint('SocketConnectionManager: Error updating token: $e');
    }
  }
  
  /// Освобождает ресурсы.
  void dispose() {
    _pingTimer?.cancel();
    _nativeEventSubscription?.cancel();
    _connectionState.close();
    _onChatInit.close();
    _onKeyExchange.close();
    _onKeyExchangeComplete.close();
    _onMessage.close();
    _onMessageStatus.close();
    _onChatDelete.close();
  }
}