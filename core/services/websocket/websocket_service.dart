// lib/core/services/websocket/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import 'socket_connection_manager.dart';
import 'websocket_event.dart';

/// Сервис для обмена сообщениями через WebSocket.
/// Использует единое соединение через SocketConnectionManager.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  final _socketManager = SocketConnectionManager();
  final _sessionService = SessionService();
  
  // Состояние соединения
  final _connectionStateController = BehaviorSubject<bool>.seeded(false);
  
  // Контроллеры для различных типов событий
  final _onChatInit = PublishSubject<ChatInitEvent>();
  final _onKeyExchange = PublishSubject<KeyExchangeEvent>();
  final _onKeyExchangeComplete = PublishSubject<KeyExchangeCompleteEvent>();
  final _onMessage = PublishSubject<ChatMessageEvent>();
  final _onMessageStatus = PublishSubject<MessageStatusEvent>();
  final _onChatDelete = PublishSubject<ChatDeleteEvent>();

  // Стримы для подписки на события
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<ChatInitEvent> get onChatInit => _onChatInit.stream;
  Stream<KeyExchangeEvent> get onKeyExchange => _onKeyExchange.stream;
  Stream<KeyExchangeCompleteEvent> get onKeyExchangeComplete => _onKeyExchangeComplete.stream;
  Stream<ChatMessageEvent> get onMessage => _onMessage.stream;
  Stream<MessageStatusEvent> get onMessageStatus => _onMessageStatus.stream;
  Stream<ChatDeleteEvent> get onChatDelete => _onChatDelete.stream;

  bool get isConnected => _socketManager.isConnected;
  
  WebSocketService._internal() {
    // Подписываемся на соответствующие события SocketManager
    _socketManager.connectionState.listen((isConnected) {
      _connectionStateController.add(isConnected);
    });
    
    _socketManager.onChatInit.listen((event) {
      _onChatInit.add(event);
    });
    
    _socketManager.onKeyExchange.listen((event) {
      _onKeyExchange.add(event);
    });
    
    _socketManager.onKeyExchangeComplete.listen((event) {
      _onKeyExchangeComplete.add(event);
    });
    
    _socketManager.onMessage.listen((event) {
      _onMessage.add(event);
    });
    
    _socketManager.onMessageStatus.listen((event) {
      _onMessageStatus.add(event);
    });
    
    _socketManager.onChatDelete.listen((event) {
      _onChatDelete.add(event);
    });
  }
  
  /// Инициализирует WebSocket соединение
  Future<void> initialize() async {
    await _socketManager.initialize();
  }

  /// Устанавливает соединение с сервером WebSocket.
  Future<void> connect() async {
    await _socketManager.connect();
  }

  /// Отключает соединение с сервером.
  Future<void> disconnect() async {
    await _socketManager.disconnect();
  }

  /// Отправляет сообщение, используя менеджер соединений.
  Future<void> sendMessage(String type, String recipientId, Map<String, dynamic> data) async {
    final message = {
      'type': type,
      'recipient_id': recipientId,
      'data': data
    };
    
    await _socketManager.sendMessage(message);
  }

  Future<void> sendChatInit(String recipientId, String publicKey) async {
    await _socketManager.sendChatInit(recipientId, publicKey);
  }

  Future<void> sendKeyExchange(String recipientId, String publicKey, String encryptedPartialKey) async {
    await _socketManager.sendKeyExchange(recipientId, publicKey, encryptedPartialKey);
  }

  Future<void> sendKeyExchangeComplete(String recipientId, String encryptedPartialKey) async {
    await _socketManager.sendKeyExchangeComplete(recipientId, encryptedPartialKey);
  }

  Future<void> sendChatMessage(String recipientId, String messageId, String content, {String type = 'text', Map<String, dynamic>? metadata}) async {
    await _socketManager.sendChatMessage(recipientId, messageId, content, type: type, metadata: metadata);
  }

  Future<void> sendMessageStatus(String recipientId, String messageId, String status) async {
    await _socketManager.sendMessageStatus(recipientId, messageId, status);
  }

  Future<void> sendChatDelete(String recipientId) async {
    await _socketManager.sendChatDelete(recipientId);
  }

  /// Установить режим работы в фоне - больше не требуется, так как используется единый менеджер
  void setBackgroundMode(bool isBackground) {
    // Этот метод оставлен для обратной совместимости
    debugPrint('WebSocketService: Background mode settings ignored, using unified connection manager');
  }

  /// Получить текущий режим работы - больше не требуется
  bool get isBackgroundMode => false;
  
  /// Инициировать показ уведомлений через внешний обработчик
  void notifyMessageReceived(String senderId, String content) {
    // Коллбэк для уведомлений
    _notificationCallback?.call(senderId, content);
  }
  
  /// Коллбэк для отображения уведомлений
  Function(String, String)? _notificationCallback;
  
  /// Устанавливает функцию обратного вызова для показа уведомлений
  void setNotificationCallback(Function(String, String) callback) {
    _notificationCallback = callback;
  }

  /// Освобождает ресурсы
  void dispose() {
    _connectionStateController.close();
    _onChatInit.close();
    _onKeyExchange.close();
    _onKeyExchangeComplete.close();
    _onMessage.close();
    _onMessageStatus.close();
    _onChatDelete.close();
  }
}