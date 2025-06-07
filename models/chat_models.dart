// models/chat_models.dart

enum MessageStatus { sending, sent, delivered, read }
enum SignatureStatus { verified, invalid }

class ChatContact {
  final String name;
  final String avatar;
  final bool isOnline;

  ChatContact({
    required this.name,
    required this.avatar,
    required this.isOnline,
  });
}

class ChatMessage {
  final int id;
  final String text;
  final bool isOwn;
  final DateTime timestamp;
  final MessageStatus status;
  final FileAttachment? file;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isOwn,
    required this.timestamp,
    required this.status,
    this.file,
  });
}

class FileAttachment {
  final String name;
  final String type;
  final String size;
  final SignatureStatus signatureStatus;

  FileAttachment({
    required this.name,
    required this.type,
    required this.size,
    required this.signatureStatus,
  });
}

class ChatInfo {
  final int id;
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final String avatar;
  final bool isOnline;
  final bool isGroup;

  ChatInfo({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.avatar,
    required this.isOnline,
    this.isGroup = false,
  });
}