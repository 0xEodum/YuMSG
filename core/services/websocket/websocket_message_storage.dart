// lib/core/services/websocket/websocket_message_storage.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище для очереди сообщений WebSocket.
/// Используется для сохранения сообщений при отсутствии соединения
/// с возможностью их последующей отправки.
class WebSocketMessageStorage {
  static final WebSocketMessageStorage _instance = WebSocketMessageStorage._internal();
  factory WebSocketMessageStorage() => _instance;
  
  static const String _pendingMessagesKey = 'websocket_pending_messages';
  static const int _maxMessageSize = 4096;
  static const int _maxMessageCount = 100;
  
  List<Map<String, dynamic>> _cachedPendingMessages = [];
  bool _initialized = false;
  
  WebSocketMessageStorage._internal();
  
  /// Инициализирует хранилище, загружая сохраненные сообщения.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await _loadPendingMessages();
      _initialized = true;
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error initializing: $e');
    }
  }
  
  /// Загружает ожидающие отправки сообщения из SharedPreferences.
  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_pendingMessagesKey) ?? [];
      
      _cachedPendingMessages = [];
      
      for (final jsonString in jsonList) {
        try {
          final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
          _cachedPendingMessages.add(jsonMap);
        } catch (e) {
          debugPrint('WebSocketMessageStorage: Error parsing message: $e');
        }
      }
      
      debugPrint('WebSocketMessageStorage: Loaded ${_cachedPendingMessages.length} pending messages');
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error loading pending messages: $e');
    }
  }
  
  /// Сохраняет ожидающие отправки сообщения в SharedPreferences.
  Future<void> _savePendingMessagesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedPendingMessages.map((msg) => json.encode(msg)).toList();
      await prefs.setStringList(_pendingMessagesKey, jsonList);
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error saving pending messages to SharedPreferences: $e');
    }
  }
  
  /// Получает все сохраненные ожидающие отправки сообщения.
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    if (!_initialized) {
      await initialize();
    }
    
    return List<Map<String, dynamic>>.from(_cachedPendingMessages);
  }
  
  /// Сохраняет сообщение для последующей отправки.
  Future<bool> savePendingMessage(Map<String, dynamic> message) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      // Проверяем, не превышен ли лимит сообщений
      if (_cachedPendingMessages.length >= _maxMessageCount) {
        // Удаляем самое старое сообщение
        _cachedPendingMessages.removeAt(0);
      }
      
      // Проверяем размер сообщения
      final jsonString = json.encode(message);
      if (jsonString.length > _maxMessageSize) {
        debugPrint('WebSocketMessageStorage: Message too large (${jsonString.length} bytes), max allowed size: $_maxMessageSize bytes');
        return false;
      }
      
      // Добавляем сообщение в кеш
      _cachedPendingMessages.add(message);
      
      // Сохраняем в SharedPreferences
      await _savePendingMessagesToPrefs();
      
      return true;
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error saving pending message: $e');
      return false;
    }
  }
  
  /// Удаляет сообщение из очереди.
  Future<bool> removePendingMessage(Map<String, dynamic> message) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      // Находим и удаляем сообщение из кеша
      bool removed = false;
      
      // Поскольку Map нельзя сравнивать напрямую, ищем по типу и ID получателя
      final type = message['type'];
      final recipientId = message['recipient_id'];
      final data = message['data'];
      
      if (type != null && recipientId != null) {
        for (int i = 0; i < _cachedPendingMessages.length; i++) {
          final cachedMessage = _cachedPendingMessages[i];
          if (cachedMessage['type'] == type && 
              cachedMessage['recipient_id'] == recipientId &&
              _compareMessageData(cachedMessage['data'], data)) {
            _cachedPendingMessages.removeAt(i);
            removed = true;
            break;
          }
        }
      }
      
      if (removed) {
        // Сохраняем изменения в SharedPreferences
        await _savePendingMessagesToPrefs();
      }
      
      return removed;
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error removing pending message: $e');
      return false;
    }
  }
  
  /// Сравнивает данные сообщений для идентификации уникального сообщения.
  bool _compareMessageData(dynamic data1, dynamic data2) {
    if (data1 == null && data2 == null) return true;
    if (data1 == null || data2 == null) return false;
    
    // Если оба объекта - Map, сравниваем содержимое по ключу message_id
    if (data1 is Map && data2 is Map) {
      final id1 = data1['message_id'];
      final id2 = data2['message_id'];
      if (id1 != null && id2 != null) {
        return id1 == id2;
      }
    }
    
    // В остальных случаях просто сравниваем как строки
    try {
      final str1 = json.encode(data1);
      final str2 = json.encode(data2);
      return str1 == str2;
    } catch (e) {
      return false;
    }
  }
  
  /// Очищает все ожидающие отправки сообщения.
  Future<void> clearPendingMessages() async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      _cachedPendingMessages.clear();
      await _savePendingMessagesToPrefs();
    } catch (e) {
      debugPrint('WebSocketMessageStorage: Error clearing pending messages: $e');
    }
  }
  
  /// Получает количество сообщений в очереди.
  Future<int> getPendingMessageCount() async {
    if (!_initialized) {
      await initialize();
    }
    
    return _cachedPendingMessages.length;
  }
}