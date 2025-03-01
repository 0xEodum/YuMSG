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
  final String content;       // Расшифрованное содержимое для отображения
  final String? encryptedContent; // Зашифрованное содержимое для хранения
  final String type;
  final DateTime timestamp;
  final MessageStatus status;
  final Map<String, dynamic>? metadata;
  final bool isPending;      // Флаг, указывающий, что сообщение в очереди на отправку

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.encryptedContent,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.metadata,
    this.isPending = false,
  });

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    String? encryptedContent,
    String? type,
    DateTime? timestamp,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
    bool? isPending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      isPending: isPending ?? this.isPending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'encryptedContent': encryptedContent,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'metadata': metadata,
      'isPending': isPending,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      content: json['content'],
      encryptedContent: json['encryptedContent'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.values[json['status']],
      metadata: json['metadata'],
      isPending: json['isPending'] ?? false,
    );
  }
}