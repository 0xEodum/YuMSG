class ChatData {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String? avatarUrl;

  const ChatData({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    this.avatarUrl,
  });
}