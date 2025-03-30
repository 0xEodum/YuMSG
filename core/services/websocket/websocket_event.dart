// lib/core/services/websocket/websocket_event.dart
// Обновленная версия моделей для новой архитектуры чатов

import 'package:flutter/foundation.dart';

/// Базовый класс для всех WebSocket событий
class WebSocketEvent {
  final String type;
  final String senderId;
  final Map<String, dynamic> data;

  WebSocketEvent({
    required this.type,
    required this.senderId,
    required this.data,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String,
      senderId: json['sender_id'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

/// Событие инициализации чата от другого пользователя
class ChatInitEvent {
  final String senderId;
  final String initiatorName;
  final String publicKey;

  ChatInitEvent({
    required this.senderId,
    required this.initiatorName,
    required this.publicKey,
  });

  factory ChatInitEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return ChatInitEvent(
      senderId: senderId,
      initiatorName: json['initiator_name'] as String? ?? 'Неизвестно', 
      publicKey: json['public_key'] as String,
    );
  }
}

/// Событие обмена ключами между участниками чата
class KeyExchangeEvent {
  final String senderId;
  final String responderName;
  final String publicKey;
  final String encryptedPartialKey;

  KeyExchangeEvent({
    required this.senderId,
    required this.responderName,
    required this.publicKey,
    required this.encryptedPartialKey,
  });

  factory KeyExchangeEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return KeyExchangeEvent(
      senderId: senderId,
      responderName: json['responder_name'] as String? ?? 'Неизвестно',
      publicKey: json['public_key'] as String,
      encryptedPartialKey: json['encrypted_partial_key'] as String,
    );
  }
}

/// Событие завершения обмена ключами
class KeyExchangeCompleteEvent {
  final String senderId;
  final String encryptedPartialKey;

  KeyExchangeCompleteEvent({
    required this.senderId,
    required this.encryptedPartialKey,
  });

  factory KeyExchangeCompleteEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return KeyExchangeCompleteEvent(
      senderId: senderId,
      encryptedPartialKey: json['encrypted_partial_key'] as String,
    );
  }
}

/// Событие сообщения чата
class ChatMessageEvent {
  final String senderId;
  final String messageId;
  final String content;
  final String timestamp;
  final String type;
  final Map<String, dynamic>? metadata;

  ChatMessageEvent({
    required this.senderId,
    required this.messageId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory ChatMessageEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return ChatMessageEvent(
      senderId: senderId,
      messageId: json['message_id'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as String,
      type: json['type'] as String? ?? 'text',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Событие статуса сообщения
class MessageStatusEvent {
  final String senderId;
  final String messageId;
  final String status;

  MessageStatusEvent({
    required this.senderId,
    required this.messageId,
    required this.status,
  });

  factory MessageStatusEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return MessageStatusEvent(
      senderId: senderId,
      messageId: json['message_id'] as String,
      status: json['status'] as String,
    );
  }
}

/// Событие удаления чата
class ChatDeleteEvent {
  final String senderId;

  ChatDeleteEvent({
    required this.senderId,
  });

  factory ChatDeleteEvent.fromJson(String senderId, Map<String, dynamic> json) {
    return ChatDeleteEvent(
      senderId: senderId,
    );
  }
}