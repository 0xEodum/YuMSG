// lib/core/services/communication/communication_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:yumsg/core/data/providers/server_data_provider.dart';
import '../session/session_service.dart';
import '../websocket/websocket_service.dart';
import '../../../features/auth/domain/models/auth_data.dart';
import '../../../features/startup/domain/enums/work_mode.dart';
import '../../crypto/services/crypto_service.dart';
import 'connection_state.dart';

/// Сервис для управления коммуникациями с сервером.
/// 
/// Этот сервис управляет WebSocket соединением, отслеживает состояние соединения,
/// обрабатывает события приложения и обеспечивает автоматическое переподключение.
class CommunicationService with WidgetsBindingObserver {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  
  final WebSocketService _webSocketService = WebSocketService();
  final SessionService _sessionService = SessionService();
  final YuCryptoService _cryptoService = YuCryptoService();
  
  // Состояние соединения
  final _connectionState = BehaviorSubject<YuConnectionState>.seeded(YuConnectionState.disconnected);
  
  // Флаги состояния
  bool _isInitialized = false;
  bool _isAppActive = false;
  Timer? _reconnectTimer;
  Timer? _sessionRefreshTimer;
  
  Stream<YuConnectionState> get connectionState => _connectionState.stream;
  YuConnectionState get currentConnectionState => _connectionState.value;
  bool get isConnected => currentConnectionState == YuConnectionState.connected;
  
  CommunicationService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
    // Подписка на события WebSocket
    _webSocketService.onConnected.listen(_handleConnectionStatusChanged);
  }
  
  /// Инициализирует сервис коммуникации.
  /// 
  /// Вызывается при запуске приложения для проверки существующей сессии
  /// и инициализации WebSocket соединения при необходимости.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final workMode = await _sessionService.getWorkMode();
      if (workMode != WorkMode.server) {
        // В локальном режиме WebSocket не используется
        _connectionState.add(YuConnectionState.disconnected);
        return;
      }
      
      final hasSession = await _sessionService.hasFullSession();
      if (!hasSession) {
        // Нет полной сессии, соединение невозможно
        _connectionState.add(YuConnectionState.disconnected);
        return;
      }
      
      // Убедимся, что ServerDataProvider инициализирован перед подключением
      final address = await _sessionService.getServerAddress();
      if (address != null && !ServerDataProvider.isInitialized) {
        ServerDataProvider.initialize('http://$address');
      }
      
      await _startConnection();
      _startSessionRefreshTimer();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing CommunicationService: $e');
      _connectionState.add(YuConnectionState.error);
    }
  }
  
  /// Обработчик изменения состояния жизненного цикла приложения.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Не требуют обработки
        break;
    }
  }
  
  /// Вызывается, когда приложение возвращается на передний план.
  Future<void> _onAppResumed() async {
    _isAppActive = true;
    
    // Если мы не в серверном режиме, пропускаем
    final workMode = await _sessionService.getWorkMode();
    if (workMode != WorkMode.server) return;
    
    // Проверяем наличие сессии
    final hasSession = await _sessionService.hasFullSession();
    if (!hasSession) return;
    
    // Обновляем токен и подключаемся
    await _refreshSessionIfNeeded();
    
    if (!isConnected) {
      await _startConnection();
    }
    
    // Устанавливаем статус онлайн
    await _setOnlineStatus(true);
  }
  
  /// Вызывается, когда приложение уходит на задний план.
  Future<void> _onAppPaused() async {
    _isAppActive = false;
    
    // Устанавливаем статус оффлайн при уходе приложения в фон,
    // но сохраняем соединение для получения сообщений
    await _setOnlineStatus(false);
  }
  
  /// Вызывается, когда приложение закрывается.
  void _onAppDetached() {
    _isAppActive = false;
    // В реальном приложении здесь стоит сохранить состояние сервиса
    // или выполнить другие действия при закрытии приложения
  }
  
  /// Запускает WebSocket соединение.
  Future<void> _startConnection() async {
    try {
      _connectionState.add(YuConnectionState.connecting);
      await _webSocketService.connect();
    } catch (e) {
      _connectionState.add(YuConnectionState.error);
      debugPrint('Error starting WebSocket connection: $e');
    }
  }
  
  /// Обработчик изменения статуса WebSocket соединения.
  void _handleConnectionStatusChanged(bool isConnected) {
    if (isConnected) {
      _connectionState.add(YuConnectionState.connected);
    } else {
      _connectionState.add(YuConnectionState.disconnected);
    }
  }
  
  /// Планирует переподключение через определенный интервал.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () async {
      if (!isConnected) {
        await _startConnection();
      }
    });
  }
  
  /// Запускает таймер для периодического обновления сессии.
  void _startSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(minutes: 15), // Проверяем каждые 15 минут
      (_) => _refreshSessionIfNeeded(),
    );
  }
  
  /// Обновляет сессию, если токен близок к истечению срока действия.
  Future<void> _refreshSessionIfNeeded() async {
    try {
      // Получаем данные авторизации
      final authData = await _sessionService.getAuthData();
      if (authData == null) return;
      
      // В реальном приложении здесь нужно проверить, истекает ли токен
      // Здесь предполагаем, что всегда обновляем для демонстрации
      
      // Обновляем токен через сервис авторизации
      final authService = AuthServiceProvider.getService();
      final result = await authService.refreshToken(
        authData.refreshToken, 
        authData.deviceId,
      );
      
      if (result.success && result.data != null) {
        // Сохраняем новые данные авторизации
        await _sessionService.saveAuthData(result.data!);
        
        // Переподключаемся с новым токеном, если уже подключены
        if (isConnected) {
          await _webSocketService.disconnect();
          await _startConnection();
        }
      } else {
        // Ошибка обновления токена
        debugPrint('Failed to refresh session: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
  }
  
  /// Устанавливает статус онлайн/оффлайн пользователя.
  Future<void> _setOnlineStatus(bool isOnline) async {
    if (!isConnected) return;
    
    try {
      // Отправляем статус через WebSocket
      // В реальном приложении нужно реализовать метод отправки статуса
      // Пример реализации:
      /* 
      await _webSocketService.sendStatusUpdate({
        'type': 'user.status',
        'data': {
          'status': isOnline ? 'online' : 'offline',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
      */
    } catch (e) {
      debugPrint('Error setting online status: $e');
    }
  }
  
  /// Закрывает соединение и освобождает ресурсы.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _sessionRefreshTimer?.cancel();
    await _webSocketService.disconnect();
    _connectionState.close();
    _isInitialized = false;
  }
}

/// Провайдер для получения сервиса авторизации.
/// Это обходное решение для избежания циклических зависимостей.
class AuthServiceProvider {
  static dynamic _authService;
  
  static void setService(dynamic service) {
    _authService = service;
  }
  
  static dynamic getService() {
    if (_authService == null) {
      throw StateError('AuthService not set in AuthServiceProvider');
    }
    return _authService;
  }
}