// lib/core/services/websocket/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import '../../data/providers/server_data_provider.dart';
import 'websocket_event.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final _sessionService = SessionService();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  // Контроллеры для различных типов событий
  final _onConnected = BehaviorSubject<bool>.seeded(false);
  final _onChatInit = PublishSubject<ChatInitEvent>();
  final _onKeyExchange = PublishSubject<KeyExchangeEvent>();
  final _onKeyExchangeComplete = PublishSubject<KeyExchangeCompleteEvent>();
  final _onMessage = PublishSubject<ChatMessageEvent>();
  final _onMessageStatus = PublishSubject<MessageStatusEvent>();

  // Стримы для подписки на события
  Stream<bool> get onConnected => _onConnected.stream;
  Stream<ChatInitEvent> get onChatInit => _onChatInit.stream;
  Stream<KeyExchangeEvent> get onKeyExchange => _onKeyExchange.stream;
  Stream<KeyExchangeCompleteEvent> get onKeyExchangeComplete => 
      _onKeyExchangeComplete.stream;
  Stream<ChatMessageEvent> get onMessage => _onMessage.stream;
  Stream<MessageStatusEvent> get onMessageStatus => _onMessageStatus.stream;

  bool get isConnected => _channel != null;

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

      final wsUrl = Uri.parse('${serverProvider.baseUrl.replaceFirst('http', 'ws')}/ws')
          .replace(queryParameters: {
        'token': authData.accessToken,
      });

      _channel = WebSocketChannel.connect(wsUrl);
      
      // Устанавливаем обработчик входящих сообщений
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _startPingTimer();
      _onConnected.add(true);
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      _handleError(e);
    } finally {
      _isConnecting = false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final event = WebSocketEvent.fromJson(data);

      switch (event.type) {
        case 'chat.init':
          _onChatInit.add(ChatInitEvent.fromJson(event.data));
          break;
        case 'chat.key_exchange':
          _onKeyExchange.add(KeyExchangeEvent.fromJson(event.data));
          break;
        case 'chat.key_exchange_complete':
          _onKeyExchangeComplete.add(
            KeyExchangeCompleteEvent.fromJson(event.data)
          );
          break;
        case 'chat.message':
          _onMessage.add(ChatMessageEvent.fromJson(event.data));
          break;
        case 'chat.status':
          _onMessageStatus.add(MessageStatusEvent.fromJson(event.data));
          break;
        case 'pong':
          // Обработка pong-ответа от сервера
          break;
        default:
          debugPrint('Неизвестный тип события: ${event.type}');
      }
    } catch (e) {
      debugPrint('Ошибка обработки сообщения: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _onConnected.add(false);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _cleanupConnection();
    _onConnected.add(false);
    _scheduleReconnect();
  }

  void _cleanupConnection() {
    _channel?.sink.close();
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
        _channel!.sink.add(jsonEncode({
          'type': 'ping',
        }));
      }
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    _onConnected.add(false);
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
  }

  // Методы для отправки событий
  Future<void> sendChatInitialization(String recipientId, String publicKey) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    _channel!.sink.add(jsonEncode({
      'type': 'chat.init',
      'data': {
        'recipientId': recipientId,
        'publicKey': publicKey,
      },
    }));
  }

  Future<void> sendKeyExchangeResponse(
    String chatId,
    String publicKey,
    String encryptedPartialKey,
  ) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    _channel!.sink.add(jsonEncode({
      'type': 'chat.key_exchange',
      'data': {
        'chatId': chatId,
        'publicKey': publicKey,
        'encryptedPartialKey': encryptedPartialKey,
      },
    }));
  }

  Future<void> sendKeyExchangeComplete(
    String chatId,
    String encryptedPartialKey,
  ) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    _channel!.sink.add(jsonEncode({
      'type': 'chat.key_exchange_complete',
      'data': {
        'chatId': chatId,
        'encryptedPartialKey': encryptedPartialKey,
      },
    }));
  }

  Future<void> sendMessage(
    String chatId,
    String content, {
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    _channel!.sink.add(jsonEncode({
      'type': 'chat.message',
      'data': {
        'chatId': chatId,
        'content': content,
        'type': type,
        if (metadata != null) 'metadata': metadata,
      },
    }));
  }

  Future<void> sendMessageStatus(
    String messageId,
    String chatId,
    String status,
  ) async {
    if (!isConnected) throw Exception('WebSocket не подключен');
    
    _channel!.sink.add(jsonEncode({
      'type': 'chat.status',
      'data': {
        'messageId': messageId,
        'chatId': chatId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      },
    }));
  }
}