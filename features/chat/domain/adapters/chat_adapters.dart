// lib/features/chat/domain/adapters/chat_adapters.dart
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../../../main/domain/models/chat_data.dart';

/// Класс-адаптер для преобразования моделей чатов между разными частями приложения.
class ChatAdapters {
  
  /// Преобразует Chat в ChatData для отображения в списке чатов.
  static ChatData chatToChatData(Chat chat) {
    // Форматируем время для отображения
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd.MM.yyyy');
    
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    
    String formattedTime;
    
    // Если сообщение отправлено сегодня, показываем только время
    if (chat.lastMessageTime.day == now.day &&
        chat.lastMessageTime.month == now.month &&
        chat.lastMessageTime.year == now.year) {
      formattedTime = timeFormat.format(chat.lastMessageTime);
    }
    // Если вчера, показываем "Вчера"
    else if (chat.lastMessageTime.day == yesterday.day &&
        chat.lastMessageTime.month == yesterday.month &&
        chat.lastMessageTime.year == yesterday.year) {
      formattedTime = 'Вчера';
    }
    // Иначе показываем дату
    else {
      formattedTime = dateFormat.format(chat.lastMessageTime);
    }
    
    return ChatData(
      id: chat.id,
      name: chat.participantName ?? 'Неизвестно',
      lastMessage: chat.lastMessage,
      time: formattedTime,
      unreadCount: chat.unreadCount,
      avatarUrl: chat.participantAvatar,
    );
  }
  
  /// Преобразует список Chat в список ChatData.
  static List<ChatData> chatsToCharDataList(List<Chat> chats) {
    return chats.map((chat) => chatToChatData(chat)).toList();
  }
  
  /// Преобразует строку статуса сообщения в enum MessageStatus.
  static MessageStatus stringToMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'error':
        return MessageStatus.error;
      default:
        return MessageStatus.sent;
    }
  }
  
  /// Преобразует MessageStatus в строку для отправки на сервер.
  static String messageStatusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 'sending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
      case MessageStatus.error:
        return 'error';
    }
  }
}