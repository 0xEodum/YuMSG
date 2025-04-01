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
import '../../../features/chat/domain/services/chat_service.dart'; // Добавлен импорт

/// Сервис для работы с WebSocket соединением.
/// Управляет соединением с сервером и обработкой входящих/исходящих сообщений.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final _sessionService = SessionService();
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  ChatService? _chatService; // Ссылка на ChatService

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
    // Инициализируем сервис с задержкой, чтобы дать время другим сервисам создаться
    Future.delayed(Duration.zero, () {
      _initializeChatService();
    });
  }
  
  /// Инициализирует ссылку на ChatService и подписывается на события
  void _initializeChatService() {
    try {
      _chatService = ChatService();
      debugPrint('WebSocketService: ChatService initialized');
    } catch (e) {
      debugPrint('Error initializing ChatService in WebSocketService: $e');
      // Повторная попытка через некоторое время
      Future.delayed(const Duration(seconds: 1), _initializeChatService);
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
      
      switch (messageType) {
        case 'chat.init':
          debugPrint('Processing chat.init event');
          final event = ChatInitEvent.fromJson(senderId, messageData);
          
          _onChatInit.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.init to ChatService');
            _chatService!.handleChatInitEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.init');
          }
          break;
          
        case 'chat.key_exchange':
          debugPrint('Processing chat.key_exchange event');
          final event = KeyExchangeEvent.fromJson(senderId, messageData);
          
          _onKeyExchange.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.key_exchange to ChatService');
            _chatService!.handleKeyExchangeEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.key_exchange');
          }
          break;
          
        case 'chat.key_exchange_complete':
          debugPrint('Processing chat.key_exchange_complete event');
          final event = KeyExchangeCompleteEvent.fromJson(senderId, messageData);
          
          _onKeyExchangeComplete.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.key_exchange_complete to ChatService');
            _chatService!.handleKeyExchangeCompleteEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.key_exchange_complete');
          }
          break;
          
        case 'chat.message':
          debugPrint('Processing chat.message event');
          final event = ChatMessageEvent.fromJson(senderId, messageData);
          
          _onMessage.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.message to ChatService');
            _chatService!.handleMessageEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.message');
          }
          break;
          
        case 'chat.status':
          debugPrint('Processing chat.status event');
          final event = MessageStatusEvent.fromJson(senderId, messageData);
          
          _onMessageStatus.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.status to ChatService');
            _chatService!.handleMessageStatusEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.status');
          }
          break;
          
        case 'chat.delete':
          debugPrint('Processing chat.delete event');
          final event = ChatDeleteEvent.fromJson(senderId, messageData);
          
          _onChatDelete.add(event);
          
          if (_chatService != null) {
            debugPrint('Directly passing chat.delete to ChatService');
            _chatService!.handleChatDeleteEvent(event);
          } else {
            debugPrint('WARNING: ChatService is null, cannot process chat.delete');
          }
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
  }

  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _cleanupConnection();
    _onConnected.add(false);
    _scheduleReconnect();
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