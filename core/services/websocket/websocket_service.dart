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
  
  WebSocketService._internal();
  
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
      
      // Проверяем необходимые поля
      if (!data.containsKey('type') || !data.containsKey('sender_id')) {
        debugPrint('Invalid message format: missing required fields');
        return;
      }
      
      final messageType = data['type'];
      final senderId = data['sender_id'];
      final messageData = data['data'] ?? {};
      
      debugPrint('Processing message type: $messageType from $senderId');
      
      // Маршрутизируем событие по типу
      switch (messageType) {
        case 'chat.init':
          debugPrint('Processing chat.init event');
          _onChatInit.add(ChatInitEvent.fromJson(senderId, messageData));
          break;
        case 'chat.key_exchange':
          debugPrint('Processing chat.key_exchange event');
          _onKeyExchange.add(KeyExchangeEvent.fromJson(senderId, messageData));
          break;
        case 'chat.key_exchange_complete':
          debugPrint('Processing chat.key_exchange_complete event');
          _onKeyExchangeComplete.add(KeyExchangeCompleteEvent.fromJson(senderId, messageData));
          break;
        case 'chat.message':
          debugPrint('Processing chat.message event');
          _onMessage.add(ChatMessageEvent.fromJson(senderId, messageData));
          break;
        case 'chat.status':
          debugPrint('Processing chat.status event');
          _onMessageStatus.add(MessageStatusEvent.fromJson(senderId, messageData));
          break;
        case 'chat.delete':
          debugPrint('Processing chat.delete event');
          _onChatDelete.add(ChatDeleteEvent.fromJson(senderId, messageData));
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

  /// Обрабатывает ошибки WebSocket соединения.
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _onConnected.add(false);
    _cleanupConnection();
    _scheduleReconnect();
  }

  /// Обрабатывает отключение WebSocket соединения.
  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _cleanupConnection();
    _onConnected.add(false);
    _scheduleReconnect();
  }

  /// Очищает ресурсы соединения.
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

  /// Планирует переподключение через определенное время.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  /// Запускает таймер отправки ping-сообщений для поддержания соединения.
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

  /// Закрывает соединение.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    _onConnected.add(false);
  }

  /// Отправляет сообщение через WebSocket.
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

  /// Отправляет запрос на инициализацию чата.
  Future<void> sendChatInit(String recipientId, String initiatorName, String publicKey) async {
    await sendMessage('chat.init', recipientId, {
      'initiator_name': initiatorName,
      'public_key': publicKey
    });
  }

  /// Отправляет ответ на инициализацию чата с ключом.
  Future<void> sendKeyExchange(String recipientId, String responderName, String publicKey, String encryptedPartialKey) async {
    await sendMessage('chat.key_exchange', recipientId, {
      'responder_name': responderName,
      'public_key': publicKey,
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  /// Отправляет сообщение о завершении обмена ключами.
  Future<void> sendKeyExchangeComplete(String recipientId, String encryptedPartialKey) async {
    await sendMessage('chat.key_exchange_complete', recipientId, {
      'encrypted_partial_key': encryptedPartialKey
    });
  }

  /// Отправляет текстовое сообщение.
  Future<void> sendChatMessage(String recipientId, String messageId, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    await sendMessage('chat.message', recipientId, {
      'message_id': messageId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      if (metadata != null) 'metadata': metadata
    });
  }

  /// Отправляет статус сообщения.
  Future<void> sendMessageStatus(String recipientId, String messageId, String status) async {
    await sendMessage('chat.status', recipientId, {
      'message_id': messageId,
      'status': status
    });
  }

  /// Отправляет уведомление об удалении чата.
  Future<void> sendChatDelete(String recipientId) async {
    await sendMessage('chat.delete', recipientId, {});
  }

  /// Освобождает ресурсы.
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