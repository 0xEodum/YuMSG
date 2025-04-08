// lib/core/services/websocket/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session/session_service.dart';
import '../../data/providers/server_data_provider.dart';
import 'websocket_event.dart';

/// Единый сервис для работы с WebSocket соединением.
/// Работает независимо от режима (активное приложение или фоновый режим).
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final _sessionService = SessionService();
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  
  // Флаг, указывающий, что приложение в фоновом режиме
  bool _isBackgroundMode = false;

  // Состояние соединения
  final _connectionStateController = BehaviorSubject<bool>.seeded(false);
  
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

  bool get isConnected => _channel != null && _connectionStateController.value;
  
  WebSocketService._internal() {
    // Загружаем отложенные сообщения при старте
    _loadPendingMessages();
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

  /// Устанавливает соединение с сервером WebSocket.
  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;

    try {
      // Проверяем, инициализирован ли провайдер
      if (!ServerDataProvider.isInitialized) {
        final address = await _sessionService.getServerAddress();
        if (address == null) {
          throw Exception('Нет адреса сервера');
        }
        ServerDataProvider.initialize('http://$address');
      }
      
      final serverProvider = ServerDataProvider.instance;
      final authData = await _sessionService.getAuthData();
      if (authData == null) {
        throw Exception('Нет данных авторизации');
      }

      // Формируем URL для WebSocket
      String wsUrl = '${serverProvider.baseUrl.replaceFirst('http', 'ws')}/ws';
      if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
        wsUrl = 'ws://${serverProvider.baseUrl.replaceAll('http://', '')}/ws';
      }
      
      final uri = Uri.parse(wsUrl).replace(queryParameters: {
        'token': authData.accessToken,
      });

      debugPrint('WebSocketService: Connecting to WebSocket: $uri');
      
      // Устанавливаем соединение
      _channel = WebSocketChannel.connect(uri);
      
      // Устанавливаем обработчик входящих сообщений
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _startPingTimer();
      _connectionStateController.add(true);
      
      // Отправляем все накопленные сообщения
      _sendPendingMessages();
      
      debugPrint('WebSocketService: Connected successfully');
    } catch (e) {
      debugPrint('WebSocketService: Error connecting to WebSocket: $e');
      debugPrintStack();
      _handleError(e);
    } finally {
      _isConnecting = false;
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
        _channel!.sink.add(jsonEncode(message));
        await Future.delayed(const Duration(milliseconds: 100)); // Небольшая задержка между сообщениями
      } catch (e) {
        debugPrint('WebSocketService: Error sending pending message: $e');
        // Если отправка не удалась, возвращаем сообщение в очередь
        _pendingMessages.add(message);
      }
    }
    
    // Сохраняем оставшиеся отложенные сообщения
    await _savePendingMessages();
  }

  /// Обрабатывает входящие сообщения от сервера.
  void _handleMessage(dynamic message) {
    try {
      final messageStr = message as String;
      debugPrint('WebSocketService: Received: ${messageStr.length > 100 ? messageStr.substring(0, 100) + '...' : messageStr}');
    
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
        debugPrint('WebSocketService: Invalid message format: missing required fields');
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
          
        case 'pong':
          debugPrint('WebSocketService: Received pong response');
          break;
          
        default:
          debugPrint('WebSocketService: Unknown event type: $messageType');
      }
    } catch (e) {
      debugPrint('WebSocketService: Error processing message: $e');
      debugPrintStack();
    }
  }

  void _handleError(dynamic error) {
    debugPrint('WebSocketService: WebSocket error: $error');
    _connectionStateController.add(false);
    _cleanupConnection();
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('WebSocketService: WebSocket disconnected');
    _cleanupConnection();
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _cleanupConnection() {
    try {
      _channel?.sink.close(status.goingAway);
    } catch (e) {
      debugPrint('WebSocketService: Error closing WebSocket channel: $e');
    }
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isConnected) {
        try {
          _channel!.sink.add(jsonEncode({
            'type': 'ping',
          }));
          debugPrint('WebSocketService: Sent ping');
        } catch (e) {
          debugPrint('WebSocketService: Error sending ping: $e');
          _handleError(e);
        }
      }
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    _connectionStateController.add(false);
  }

  /// Отправляет сообщение на сервер, добавляя его в очередь, если нет соединения
  Future<void> sendMessage(String type, String recipientId, Map<String, dynamic> data) async {
    try {
      final message = {
        'type': type,
        'recipient_id': recipientId,
        'data': data
      };
      
      final messageJson = json.encode(message);
      debugPrint('WebSocketService: Sending: ${messageJson.length > 100 ? messageJson.substring(0, 100) + '...' : messageJson}');
      
      if (!isConnected) {
        // Если нет соединения, добавляем сообщение в очередь
        debugPrint('WebSocketService: No connection, adding message to pending queue');
        _pendingMessages.add(message);
        await _savePendingMessages();
        return;
      }
      
      _channel!.sink.add(messageJson);
      debugPrint('WebSocketService: Message of type $type sent to recipient $recipientId');
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
      _handleError(e);
    }
  }

  Future<void> sendChatInit(String recipientId, String publicKey) async {
    await sendMessage('chat.init', recipientId, {
      'public_key': publicKey
    });
  }

  Future<void> sendKeyExchange(String recipientId, String publicKey, String encryptedPartialKey) async {
    await sendMessage('chat.key_exchange', recipientId, {
      'public_key': publicKey,
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  Future<void> sendKeyExchangeComplete(String recipientId, String encryptedPartialKey) async {
    await sendMessage('chat.key_exchange_complete', recipientId, {
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  Future<void> sendChatMessage(String recipientId, String messageId, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    await sendMessage('chat.message', recipientId, {
      'message_id': messageId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      if (metadata != null) 'metadata': metadata
    });
  }

  Future<void> sendMessageStatus(String recipientId, String messageId, String status) async {
    await sendMessage('chat.status', recipientId, {
      'message_id': messageId,
      'status': status
    });
  }

  Future<void> sendChatDelete(String recipientId) async {
    await sendMessage('chat.delete', recipientId, {});
  }

  /// Установить режим работы в фоне
  void setBackgroundMode(bool isBackground) {
    _isBackgroundMode = isBackground;
    debugPrint('WebSocketService: Background mode set to $isBackground');
  }

  /// Получить текущий режим работы
  bool get isBackgroundMode => _isBackgroundMode;
  
  /// Инициировать показ уведомлений через внешний обработчик
  void notifyMessageReceived(String senderId, String content) {
    // Обратный вызов для взаимодействия с BackgroundService
    // Заполняется внешним кодом через метод setNotificationCallback
  }
  
  /// Коллбэк для отображения уведомлений
  Function(String, String)? _notificationCallback;
  
  /// Устанавливает функцию обратного вызова для показа уведомлений
  void setNotificationCallback(Function(String, String) callback) {
    _notificationCallback = callback;
  }

  /// Освобождение ресурсов
  void dispose() {
    _reconnectTimer?.cancel();
    _cleanupConnection();
    _connectionStateController.close();
    _onChatInit.close();
    _onKeyExchange.close();
    _onKeyExchangeComplete.close();
    _onMessage.close();
    _onMessageStatus.close();
    _onChatDelete.close();
  }
}