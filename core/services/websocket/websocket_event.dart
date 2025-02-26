// lib/core/services/websocket/websocket_event.dart
class WebSocketEvent {
  final String type;
  final Map<String, dynamic> data;

  WebSocketEvent({
    required this.type,
    required this.data,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class ChatInitEvent {
  final String chatId;
  final String initiatorId;
  final String publicKey;

  ChatInitEvent({
    required this.chatId,
    required this.initiatorId,
    required this.publicKey,
  });

  factory ChatInitEvent.fromJson(Map<String, dynamic> json) {
    return ChatInitEvent(
      chatId: json['chatId'] as String,
      initiatorId: json['initiatorId'] as String,
      publicKey: json['publicKey'] as String,
    );
  }
}

class KeyExchangeEvent {
  final String chatId;
  final String senderId;
  final String publicKey;
  final String encryptedPartialKey;

  KeyExchangeEvent({
    required this.chatId,
    required this.senderId,
    required this.publicKey,
    required this.encryptedPartialKey,
  });

  factory KeyExchangeEvent.fromJson(Map<String, dynamic> json) {
    return KeyExchangeEvent(
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      publicKey: json['publicKey'] as String,
      encryptedPartialKey: json['encryptedPartialKey'] as String,
    );
  }
}

class KeyExchangeCompleteEvent {
  final String chatId;
  final String senderId;
  final String encryptedPartialKey;

  KeyExchangeCompleteEvent({
    required this.chatId,
    required this.senderId,
    required this.encryptedPartialKey,
  });

  factory KeyExchangeCompleteEvent.fromJson(Map<String, dynamic> json) {
    return KeyExchangeCompleteEvent(
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      encryptedPartialKey: json['encryptedPartialKey'] as String,
    );
  }
}

class ChatMessageEvent {
  final String messageId;
  final String chatId;
  final String senderId;
  final String content;
  final String timestamp;
  final String type;
  final Map<String, dynamic>? metadata;

  ChatMessageEvent({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory ChatMessageEvent.fromJson(Map<String, dynamic> json) {
    return ChatMessageEvent(
      messageId: json['messageId'] as String,
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as String,
      type: json['type'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class MessageStatusEvent {
  final String messageId;
  final String chatId;
  final String senderId;
  final String status;
  final String timestamp;

  MessageStatusEvent({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.status,
    required this.timestamp,
  });

  factory MessageStatusEvent.fromJson(Map<String, dynamic> json) {
    return MessageStatusEvent(
      messageId: json['messageId'] as String,
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      status: json['status'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}