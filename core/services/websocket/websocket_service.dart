// lib/core/services/websocket/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session/session_service.dart';
import '../../data/providers/server_data_provider.dart';
import 'websocket_event.dart';

/// Сервис для работы с WebSocket соединением.
/// Реализует фасад к нативному SocketService.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final SessionService _sessionService = SessionService();
  
  // Method channel для взаимодействия с нативным кодом
  static const MethodChannel _methodChannel = MethodChannel('com.yumsg/socket_manager');
  static const EventChannel _eventChannel = EventChannel('com.yumsg/socket_events');
  
  // Потоки для событий
  final _connectionStateController = BehaviorSubject<bool>.seeded(false);
  final _messageSubject = PublishSubject<Map<String, dynamic>>();
  
  // Контроллеры для различных типов событий
  final _onChatInit = PublishSubject<ChatInitEvent>();
  final _onKeyExchange = PublishSubject<KeyExchangeEvent>();
  final _onKeyExchangeComplete = PublishSubject<KeyExchangeCompleteEvent>();
  final _onMessage = PublishSubject<ChatMessageEvent>();
  final _onMessageStatus = PublishSubject<MessageStatusEvent>();
  final _onChatDelete = PublishSubject<ChatDeleteEvent>();

  // Очередь сообщений для отправки после восстановления соединения
  final List<Map<String, dynamic>> _pendingMessages = [];
  static const String _pendingMessagesKey = 'websocket_pending_messages';

  // Стримы для подписки на события
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<ChatInitEvent> get onChatInit => _onChatInit.stream;
  Stream<KeyExchangeEvent> get onKeyExchange => _onKeyExchange.stream;
  Stream<KeyExchangeCompleteEvent> get onKeyExchangeComplete => _onKeyExchangeComplete.stream;
  Stream<ChatMessageEvent> get onMessage => _onMessage.stream;
  Stream<MessageStatusEvent> get onMessageStatus => _onMessageStatus.stream;
  Stream<ChatDeleteEvent> get onChatDelete => _onChatDelete.stream;

  bool get isConnected => _connectionStateController.value;
  
  // Инициализирован ли сервис
  bool _isInitialized = false;
  
  // Коллбэк для отображения уведомлений
  Function(String, String)? _notificationCallback;
  
  WebSocketService._internal() {
    // Запускаем слушатель событий от нативного кода
    _setupEventChannel();
    
    // Загружаем отложенные сообщения при старте
    _loadPendingMessages();
  }
  
  /// Инициализирует WebSocket сервис.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('WebSocketService: Initializing');
      
      // Получаем данные для подключения
      final address = await _sessionService.getServerAddress();
      final authData = await _sessionService.getAuthData();
      
      if (address == null || authData == null) {
        debugPrint('WebSocketService: Missing address or auth data');
        return;
      }
      
      // Инициализируем нативный сервис
      await _methodChannel.invokeMethod('initialize', {
        'serverAddress': address,
        'token': authData.accessToken,
      });
      
      // Подключаемся к серверу
      await _methodChannel.invokeMethod('connect');
      
      _isInitialized = true;
      debugPrint('WebSocketService: Initialized successfully');
    } catch (e) {
      debugPrint('WebSocketService: Error initializing: $e');
    }
  }
  
  /// Настраивает слушателя событий от нативного кода
  void _setupEventChannel() {
    _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map<dynamic, dynamic>) return;
        
        final Map<String, dynamic> eventMap = Map<String, dynamic>.from(event);
        final eventType = eventMap['type'] as String?;
        
        if (eventType == 'connectionChanged') {
          final isConnected = eventMap['isConnected'] as bool? ?? false;
          _connectionStateController.add(isConnected);
          
          // Если соединение восстановлено, отправляем накопленные сообщения
          if (isConnected) {
            _sendPendingMessages();
          }
        } else if (eventType == 'message') {
          final messageData = eventMap['data'] as String?;
          if (messageData != null) {
            _processIncomingMessage(messageData);
          }
        }
      },
      onError: (error) {
        debugPrint('WebSocketService: Event channel error: $error');
      }
    );
  }
  
  /// Загружает отложенные сообщения из хранилища
  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_pendingMessagesKey) ?? [];
      
      _pendingMessages.clear();
      for (final json in jsonList) {
        try {
          _pendingMessages.add(jsonDecode(json) as Map<String, dynamic>);
        } catch (_) {}
      }
      
      debugPrint('WebSocketService: Loaded ${_pendingMessages.length} pending messages');
    } catch (e) {
      debugPrint('WebSocketService: Error loading pending messages: $e');
    }
  }
  
  /// Сохраняет отложенные сообщения в хранилище
  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _pendingMessages.map((msg) => jsonEncode(msg)).toList();
      await prefs.setStringList(_pendingMessagesKey, jsonList);
    } catch (e) {
      debugPrint('WebSocketService: Error saving pending messages: $e');
    }
  }
  
  /// Обрабатывает входящее сообщение от сервера
  void _processIncomingMessage(String messageStr) {
    try {
      debugPrint('WebSocketService: Processing incoming message');
      
      final data = jsonDecode(messageStr);
      
      if (!data.containsKey('type')) {
        debugPrint('WebSocketService: Invalid message format: missing type field');
        return;
      }
      
      final messageType = data['type'];
      
      if (messageType == 'pong') {
        debugPrint('WebSocketService: Received pong response');
        return;
      }
      
      if (!data.containsKey('sender_id')) {
        debugPrint('WebSocketService: Invalid message format: missing sender_id field');
        return;
      }
      
      final senderId = data['sender_id'];
      final messageData = data['data'] ?? {};
      
      debugPrint('WebSocketService: Processing message type: $messageType from $senderId');
      
      switch (messageType) {
        case 'chat.init':
          debugPrint('WebSocketService: Processing chat.init event');
          final event = ChatInitEvent.fromJson(senderId, messageData);
          _onChatInit.add(event);
          break;
          
        case 'chat.key_exchange':
          debugPrint('WebSocketService: Processing chat.key_exchange event');
          final event = KeyExchangeEvent.fromJson(senderId, messageData);
          _onKeyExchange.add(event);
          break;
          
        case 'chat.key_exchange_complete':
          debugPrint('WebSocketService: Processing chat.key_exchange_complete event');
          final event = KeyExchangeCompleteEvent.fromJson(senderId, messageData);
          _onKeyExchangeComplete.add(event);
          break;
          
        case 'chat.message':
          debugPrint('WebSocketService: Processing chat.message event');
          final event = ChatMessageEvent.fromJson(senderId, messageData);
          _onMessage.add(event);
          
          // Вызываем коллбэк уведомления, если он задан и есть что показать
          if (_notificationCallback != null) {
            _notificationCallback!(senderId, event.content);
          }
          
          // Автоматически отправляем статус "доставлено"
          sendMessageStatus(senderId, event.messageId, 'delivered');
          break;
          
        case 'chat.status':
          debugPrint('WebSocketService: Processing chat.status event');
          final event = MessageStatusEvent.fromJson(senderId, messageData);
          _onMessageStatus.add(event);
          break;
          
        case 'chat.delete':
          debugPrint('WebSocketService: Processing chat.delete event');
          final event = ChatDeleteEvent.fromJson(senderId, messageData);
          _onChatDelete.add(event);
          break;
          
        default:
          debugPrint('WebSocketService: Unknown event type: $messageType');
      }
    } catch (e) {
      debugPrint('WebSocketService: Error processing message: $e');
    }
  }
  
  /// Отправляет все отложенные сообщения
  Future<void> _sendPendingMessages() async {
    if (_pendingMessages.isEmpty) return;
    
    debugPrint('WebSocketService: Sending ${_pendingMessages.length} pending messages');
    
    // Создаем копию списка, чтобы избежать проблем при изменении коллекции
    final messagesToSend = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();
    
    for (final message in messagesToSend) {
      try {
        final success = await sendMessage(
          message['type'], 
          message['recipient_id'], 
          message['data']
        );
        
        if (!success) {
          // Если отправка не удалась, возвращаем сообщение в очередь
          _pendingMessages.add(message);
        }
        
        // Небольшая задержка между сообщениями
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('WebSocketService: Error sending pending message: $e');
        // Если возникла ошибка, возвращаем сообщение в очередь
        _pendingMessages.add(message);
      }
    }
    
    // Сохраняем оставшиеся отложенные сообщения
    await _savePendingMessages();
  }
  
  /// Отправляет сообщение на сервер, добавляя его в очередь, если нет соединения
  Future<bool> sendMessage(String type, String recipientId, Map<String, dynamic> data) async {
    try {
      final message = {
        'type': type,
        'recipient_id': recipientId,
        'data': data
      };
      
      final messageJson = json.encode(message);
      debugPrint('WebSocketService: Sending message: ${messageJson.length > 100 ? messageJson.substring(0, 100) + '...' : messageJson}');
      
      // Проверяем состояние соединения
      final isConnected = await _methodChannel.invokeMethod<bool>('isConnected') ?? false;
      
      if (!isConnected) {
        // Если нет соединения, добавляем сообщение в очередь
        debugPrint('WebSocketService: No connection, adding message to pending queue');
        _pendingMessages.add(message);
        await _savePendingMessages();
        return false;
      }
      
      // Отправляем сообщение через нативный сервис
      final success = await _methodChannel.invokeMethod<bool>(
        'sendMessage', 
        {'message': messageJson}
      ) ?? false;
      
      if (!success) {
        // Если отправка не удалась, добавляем в очередь
        _pendingMessages.add(message);
        await _savePendingMessages();
        return false;
      }
      
      debugPrint('WebSocketService: Message of type $type sent to recipient $recipientId');
      return true;
    } catch (e) {
      debugPrint('WebSocketService: Error sending message: $e');
      
      // В случае ошибки добавляем сообщение в очередь
      final message = {
        'type': type,
        'recipient_id': recipientId,
        'data': data
      };
      
      _pendingMessages.add(message);
      await _savePendingMessages();
      return false;
    }
  }
  
  /// Обновляет токен авторизации в нативном сервисе
  Future<void> updateToken(String token) async {
    try {
      await _methodChannel.invokeMethod('updateToken', {'token': token});
      debugPrint('WebSocketService: Token updated successfully');
    } catch (e) {
      debugPrint('WebSocketService: Error updating token: $e');
    }
  }
  
  /// Устанавливает функцию обратного вызова для показа уведомлений
  void setNotificationCallback(Function(String, String) callback) {
    _notificationCallback = callback;
  }
  
  // Методы отправки различных типов сообщений (обертки над sendMessage)
  
  Future<bool> sendChatInit(String recipientId, String publicKey) async {
    return await sendMessage('chat.init', recipientId, {
      'public_key': publicKey
    });
  }

  Future<bool> sendKeyExchange(String recipientId, String publicKey, String encryptedPartialKey) async {
    return await sendMessage('chat.key_exchange', recipientId, {
      'public_key': publicKey,
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  Future<bool> sendKeyExchangeComplete(String recipientId, String encryptedPartialKey) async {
    return await sendMessage('chat.key_exchange_complete', recipientId, {
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  Future<bool> sendChatMessage(String recipientId, String messageId, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    return await sendMessage('chat.message', recipientId, {
      'message_id': messageId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      if (metadata != null) 'metadata': metadata
    });
  }

  Future<bool> sendMessageStatus(String recipientId, String messageId, String status) async {
    return await sendMessage('chat.status', recipientId, {
      'message_id': messageId,
      'status': status
    });
  }

  Future<bool> sendChatDelete(String recipientId) async {
    return await sendMessage('chat.delete', recipientId, {});
  }

  /// Освобождение ресурсов
  void dispose() {
    _connectionStateController.close();
    _messageSubject.close();
    _onChatInit.close();
    _onKeyExchange.close();
    _onKeyExchangeComplete.close();
    _onMessage.close();
    _onMessageStatus.close();
    _onChatDelete.close();
  }
}