// lib/core/services/websocket/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import '../../data/providers/server_data_provider.dart';
import 'websocket_event.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/// Единый сервис для работы с WebSocket соединением.
/// Работает как в активном приложении, так и в фоновом режиме.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final _sessionService = SessionService();
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  
  // Флаг для определения, работаем ли в фоновом режиме
  bool _isBackgroundMode = false;
  FlutterBackgroundService? _backgroundService;

  // Контроллеры для различных типов событий
  final _onConnected = BehaviorSubject<bool>.seeded(false);
  final _onChatInit = PublishSubject<ChatInitEvent>();
  final _onKeyExchange = PublishSubject<KeyExchangeEvent>();
  final _onKeyExchangeComplete = PublishSubject<KeyExchangeCompleteEvent>();
  final _onMessage = PublishSubject<ChatMessageEvent>();
  final _onMessageStatus = PublishSubject<MessageStatusEvent>();
  final _onChatDelete = PublishSubject<ChatDeleteEvent>();

  // Стримы для подписки на события
  Stream<bool> get onConnected => _onConnected.stream;
  Stream<ChatInitEvent> get onChatInit => _onChatInit.stream;
  Stream<KeyExchangeEvent> get onKeyExchange => _onKeyExchange.stream;
  Stream<KeyExchangeCompleteEvent> get onKeyExchangeComplete => _onKeyExchangeComplete.stream;
  Stream<ChatMessageEvent> get onMessage => _onMessage.stream;
  Stream<MessageStatusEvent> get onMessageStatus => _onMessageStatus.stream;
  Stream<ChatDeleteEvent> get onChatDelete => _onChatDelete.stream;

  bool get isConnected => _channel != null;
  
  WebSocketService._internal() {
    // Проверяем, работаем ли в фоновом режиме
    _checkBackgroundMode();
  }
  
  /// Проверяет, запущен ли сервис в фоновом режиме
  void _checkBackgroundMode() {
    try {
      _backgroundService = FlutterBackgroundService();
      _backgroundService!.isRunning().then((isRunning) {
        _isBackgroundMode = isRunning;
        debugPrint('WebSocketService: Background mode: $_isBackgroundMode');
      });
    } catch (e) {
      debugPrint('Error checking background service: $e');
      _isBackgroundMode = false;
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

      debugPrint('Connecting to WebSocket: $uri');
      
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
      _onConnected.add(true);
      
      // Если мы в фоновом режиме, обновляем уведомление
      if (_isBackgroundMode && _backgroundService != null) {
        _updateBackgroundNotification('Соединение установлено');
      }
      
      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      debugPrintStack();
      _handleError(e);
    } finally {
      _isConnecting = false;
    }
  }

  /// Обрабатывает входящие сообщения от сервера.
  void _handleMessage(dynamic message) {
    try {
      final messageStr = message as String;
      debugPrint('Received WebSocket message: ${messageStr.length > 100 ? messageStr.substring(0, 100) + '...' : messageStr}');
    
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
        debugPrint('Invalid message format: missing required fields');
        return;
      }
    
      final senderId = data['sender_id'];
      final messageData = data['data'] ?? {};
    
      debugPrint('Processing message type: $messageType from $senderId');
      
      // Если мы в фоновом режиме, обновляем уведомление о новом сообщении
      if (_isBackgroundMode && _backgroundService != null && messageType == 'chat.message') {
        _updateBackgroundNotification('Новое сообщение от $senderId');
      }
      
      switch (messageType) {
        case 'chat.init':
          debugPrint('Processing chat.init event');
          final event = ChatInitEvent.fromJson(senderId, messageData);
          
          // Публикуем событие в соответствующий поток
          _onChatInit.add(event);
          break;
          
        case 'chat.key_exchange':
          debugPrint('Processing chat.key_exchange event');
          final event = KeyExchangeEvent.fromJson(senderId, messageData);
          
          // Публикуем событие в соответствующий поток
          _onKeyExchange.add(event);
          break;
          
        case 'chat.key_exchange_complete':
          debugPrint('Processing chat.key_exchange_complete event');
          final event = KeyExchangeCompleteEvent.fromJson(senderId, messageData);
          
          // Публикуем событие в соответствующий поток
          _onKeyExchangeComplete.add(event);
          break;
          
        case 'chat.message':
          debugPrint('Processing chat.message event');
          final event = ChatMessageEvent.fromJson(senderId, messageData);
          
          _onMessage.add(event);
          
          // Автоматически отправляем статус "доставлено"
          sendMessageStatus(senderId, event.messageId, 'delivered');
          break;
          
        case 'chat.status':
          debugPrint('Processing chat.status event');
          final event = MessageStatusEvent.fromJson(senderId, messageData);
          
          _onMessageStatus.add(event);
          break;
          
        case 'chat.delete':
          debugPrint('Processing chat.delete event');
          final event = ChatDeleteEvent.fromJson(senderId, messageData);
          
          _onChatDelete.add(event);
          break;
          
        case 'pong':
          debugPrint('Received pong response');
          break;
          
        default:
          debugPrint('Неизвестный тип события: $messageType');
      }
    } catch (e) {
      debugPrint('Ошибка обработки сообщения: $e');
      debugPrintStack();
    }
  }

  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _onConnected.add(false);
    _cleanupConnection();
    _scheduleReconnect();
    
    // Если мы в фоновом режиме, обновляем уведомление
    if (_isBackgroundMode && _backgroundService != null) {
      _updateBackgroundNotification('Ошибка соединения, переподключение...');
    }
  }

  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _cleanupConnection();
    _onConnected.add(false);
    _scheduleReconnect();
    
    // Если мы в фоновом режиме, обновляем уведомление
    if (_isBackgroundMode && _backgroundService != null) {
      _updateBackgroundNotification('Соединение потеряно, переподключение...');
    }
  }

  void _cleanupConnection() {
    try {
      _channel?.sink.close(status.goingAway);
    } catch (e) {
      debugPrint('Error closing WebSocket channel: $e');
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
          debugPrint('Sent ping');
        } catch (e) {
          debugPrint('Error sending ping: $e');
          _handleError(e);
        }
      }
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    _onConnected.add(false);
  }

  /// Обновляет уведомление в фоновом режиме
  void _updateBackgroundNotification(String content) {
    if (_backgroundService != null && _isBackgroundMode) {
      try {
        _backgroundService!.invoke('updateNotification', {
          'content': content
        });
      } catch (e) {
        debugPrint('Error updating background notification: $e');
      }
    }
  }

  Future<void> sendMessage(String type, String recipientId, Map<String, dynamic> data) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    try {
      final message = {
        'type': type,
        'recipient_id': recipientId,
        'data': data
      };
      
      final messageJson = json.encode(message);
      debugPrint('Sending message: ${messageJson.length > 100 ? messageJson.substring(0, 100) + '...' : messageJson}');
      
      _channel!.sink.add(messageJson);
      debugPrint('Message of type $type sent to recipient $recipientId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      _handleError(e);
      throw e;
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

  /// Установление в фоновый режим
  void setBackgroundMode(bool isBackground) {
    _isBackgroundMode = isBackground;
    debugPrint('WebSocketService: Setting background mode to $isBackground');
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _cleanupConnection();
    _onConnected.close();
    _onChatInit.close();
    _onKeyExchange.close();
    _onKeyExchangeComplete.close();
    _onMessage.close();
    _onMessageStatus.close();
    _onChatDelete.close();
  }
}