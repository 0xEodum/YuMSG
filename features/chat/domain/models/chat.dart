// lib/features/chat/domain/models/chat.dart
class Chat {
  final String id;
  final String participantId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isInitialized;
  final String? participantName;
  final String? participantAvatar;

  const Chat({
    required this.id,
    required this.participantId,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isInitialized = false,
    this.participantName,
    this.participantAvatar,
  });

  Chat copyWith({
    String? id,
    String? participantId,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isInitialized,
    String? participantName,
    String? participantAvatar,
  }) {
    return Chat(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isInitialized: isInitialized ?? this.isInitialized,
      participantName: participantName ?? this.participantName,
      participantAvatar: participantAvatar ?? this.participantAvatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantId': participantId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'isInitialized': isInitialized,
      'participantName': participantName,
      'participantAvatar': participantAvatar,
    };
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      participantId: json['participantId'],
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'],
      isInitialized: json['isInitialized'],
      participantName: json['participantName'],
      participantAvatar: json['participantAvatar'],
    );
  }
}