// lib/features/chat/domain/managers/chat_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../repositories/chat_repository.dart';

/// Менеджер для управления чатами и их связями с пользователями.
/// Абстрагирует логику создания ID чатов и связывания их с пользователями.
class ChatManager {
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  
  final ChatRepository _chatRepository = ChatRepository();
  
  ChatManager._internal();
  
  /// Генерирует локальный ID чата на основе ID пользователя
  String generateChatId(String userId) {
    return 'chat_with_$userId';
  }
  
  /// Получает или создает чат с указанным пользователем
  Future<Chat> getOrCreateChatWithUser(
    String userId, 
    String userName, 
    {bool isInitialized = false}
  ) async {
    final chatId = generateChatId(userId);
    
    try {
      // Пытаемся найти существующий чат
      final existingChat = await _chatRepository.getChat(chatId);
      if (existingChat != null) {
        return existingChat;
      }
    } catch (e) {
      debugPrint('Error getting chat: $e');
    }
    
    // Если чат не найден, создаем новый
    final newChat = Chat(
      id: chatId,
      participantId: userId,
      participantName: userName,
      lastMessage: isInitialized ? 'Чат создан' : 'Инициализация чата...',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      isInitialized: isInitialized,
    );
    
    await _chatRepository.saveChat(newChat);
    debugPrint('Created new chat with user $userName ($userId), id: $chatId');
    return newChat;
  }
  
  /// Проверяет, существует ли чат с указанным пользователем
  Future<bool> hasChatWithUser(String userId) async {
    final chatId = generateChatId(userId);
    return await _chatRepository.chatExists(chatId);
  }
  
  /// Получает чат с указанным пользователем, если он существует
  Future<Chat?> getChatWithUser(String userId) async {
    final chatId = generateChatId(userId);
    return await _chatRepository.getChat(chatId);
  }
  
  /// Пометка чата с пользователем как удаленного
  Future<void> markChatWithUserAsDeleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedUsers = prefs.getStringList('deleted_chat_users') ?? [];
    
    if (!deletedUsers.contains(userId)) {
      deletedUsers.add(userId);
      await prefs.setStringList('deleted_chat_users', deletedUsers);
      debugPrint('Marked chat with user $userId as deleted');
    }
  }
  
  /// Проверка, был ли чат с пользователем удален
  Future<bool> isChatWithUserDeleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedUsers = prefs.getStringList('deleted_chat_users') ?? [];
    return deletedUsers.contains(userId);
  }
  
  /// Удаление чата с пользователем
  Future<bool> deleteChatWithUser(String userId) async {
    try {
      final chatId = generateChatId(userId);
      
      // Удаляем все данные чата
      await _chatRepository.deleteAllMessages(chatId);
      await _chatRepository.deleteChatKeys(chatId);
      await _chatRepository.deleteChat(chatId);
      
      // Помечаем чат как удаленный
      await markChatWithUserAsDeleted(userId);
      
      debugPrint('Deleted chat with user $userId');
      return true;
    } catch (e) {
      debugPrint('Error deleting chat with user $userId: $e');
      return false;
    }
  }
  
  /// Очистка маркера удаления чата с пользователем
  Future<void> clearDeletedChatMark(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedUsers = prefs.getStringList('deleted_chat_users') ?? [];
    
    if (deletedUsers.contains(userId)) {
      deletedUsers.remove(userId);
      await prefs.setStringList('deleted_chat_users', deletedUsers);
      debugPrint('Cleared deleted mark for chat with user $userId');
    }
  }
  
  /// Обновляет имя пользователя в чате
  Future<void> updateUserName(String userId, String newName) async {
    final chat = await getChatWithUser(userId);
    if (chat != null) {
      await _chatRepository.saveChat(
        chat.copyWith(participantName: newName)
      );
      debugPrint('Updated name for user $userId to $newName');
    }
  }
  
}