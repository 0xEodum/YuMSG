// lib/features/chat/domain/repositories/chat_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import '../models/chat_key.dart';
import '../models/chat_message.dart';

/// Репозиторий для хранения и управления данными чатов.
class ChatRepository {
  static const String _chatsKey = 'chats';
  static const String _messagesPrefix = 'messages_';
  static const String _keysPrefix = 'chat_keys_';
  
  /// Получает список всех чатов из хранилища.
  Future<List<Chat>> getChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = prefs.getStringList(_chatsKey) ?? [];
    
    return chatsJson
        .map((jsonStr) => Chat.fromJson(jsonDecode(jsonStr)))
        .toList();
  }
  
  /// Получает чат по его ID.
  Future<Chat?> getChat(String chatId) async {
    final chats = await getChats();
    return chats.where((chat) => chat.id == chatId).firstOrNull;
  }
  
  /// Сохраняет чат в хранилище.
  Future<void> saveChat(Chat chat) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getChats();
    
    // Удаляем существующий чат с таким же ID, если есть
    final filteredChats = chats.where((c) => c.id != chat.id).toList();
    
    // Добавляем обновленный чат
    filteredChats.add(chat);
    
    // Сохраняем список чатов
    await prefs.setStringList(
      _chatsKey,
      filteredChats.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }
  
  /// Удаляет чат из хранилища.
  Future<void> deleteChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getChats();
    
    // Удаляем чат по ID
    final filteredChats = chats.where((c) => c.id != chatId).toList();
    
    // Сохраняем обновленный список
    await prefs.setStringList(
      _chatsKey,
      filteredChats.map((c) => jsonEncode(c.toJson())).toList(),
    );
    
    // Удаляем связанные сообщения
    await prefs.remove('$_messagesPrefix$chatId');
    
    // Удаляем ключи чата
    await prefs.remove('$_keysPrefix$chatId');
  }
  
  /// Получает список сообщений для указанного чата.
  Future<List<ChatMessage>> getMessages(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getStringList('$_messagesPrefix$chatId') ?? [];
    
    return messagesJson
        .map((jsonStr) => ChatMessage.fromJson(jsonDecode(jsonStr)))
        .toList();
  }
  
  /// Получает сообщение по его ID.
  Future<ChatMessage?> getMessage(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    // Ищем ключи, которые содержат префикс сообщений
    final messageKeys = keys.where((key) => key.startsWith(_messagesPrefix));
    
    // Проверяем каждый чат на наличие сообщения с указанным ID
    for (final key in messageKeys) {
      final messagesJson = prefs.getStringList(key) ?? [];
      for (final jsonStr in messagesJson) {
        final message = ChatMessage.fromJson(jsonDecode(jsonStr));
        if (message.id == messageId) {
          return message;
        }
      }
    }
    
    return null;
  }
  
  /// Сохраняет сообщение в хранилище.
  Future<void> saveMessage(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = await getMessages(message.chatId);
    
    // Удаляем существующее сообщение с таким же ID, если есть
    final filteredMessages = messages.where((m) => m.id != message.id).toList();
    
    // Добавляем обновленное сообщение
    filteredMessages.add(message);
    
    // Сортируем сообщения по времени
    filteredMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Сохраняем список сообщений
    await prefs.setStringList(
      '$_messagesPrefix${message.chatId}',
      filteredMessages.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }
  
  /// Получает ключи для указанного чата.
  Future<ChatKey?> getChatKeys(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final keyJson = prefs.getString('$_keysPrefix$chatId');
    
    if (keyJson == null) return null;
    
    return ChatKey.fromJson(jsonDecode(keyJson));
  }
  
  /// Сохраняет ключи чата в хранилище.
  Future<void> saveChatKeys(ChatKey chatKey) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(
      '$_keysPrefix${chatKey.chatId}',
      jsonEncode(chatKey.toJson()),
    );
  }
  
  /// Удаляет ключи чата из хранилища.
  Future<void> deleteChatKeys(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keysPrefix$chatId');
  }
}