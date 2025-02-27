// lib/features/chat/domain/models/chat_message.dart
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String type;
  final DateTime timestamp;
  final MessageStatus status;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.metadata,
  });

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    String? type,
    DateTime? timestamp,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      content: json['content'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.values[json['status']],
      metadata: json['metadata'],
    );
  }
}