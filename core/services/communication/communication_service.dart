// lib/core/services/communication/communication_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import '../websocket/websocket_service.dart';
import '../../../features/auth/domain/models/auth_data.dart';
import '../../../features/startup/domain/enums/work_mode.dart';
import 'connection_state.dart';

/// Координатор коммуникаций с сервером.
/// 
/// Этот сервис координирует работу WebSocketService,
/// отслеживает состояние соединения и управляет обновлением сессии.
class CommunicationService with WidgetsBindingObserver {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  
  final WebSocketService _webSocketService = WebSocketService();
  final SessionService _sessionService = SessionService();
  
  // Состояние соединения
  final _connectionState = BehaviorSubject<YuConnectionState>.seeded(YuConnectionState.disconnected);
  
  // Флаги состояния
  bool _isInitialized = false;
  Timer? _sessionRefreshTimer;
  
  Stream<YuConnectionState> get connectionState => _connectionState.stream;
  YuConnectionState get currentConnectionState => _connectionState.value;
  bool get isConnected => currentConnectionState == YuConnectionState.connected;
  
  CommunicationService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
    // Слушаем состояние WebSocket соединения
    _webSocketService.connectionState.listen(_handleWebSocketStateChanged);
  }
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('CommunicationService: Initializing');
      
      final workMode = await _sessionService.getWorkMode();
      if (workMode != WorkMode.server) {
        // В локальном режиме WebSocket не используется
        _connectionState.add(YuConnectionState.disconnected);
        debugPrint('CommunicationService: Local mode, no server connection needed');
        return;
      }
      
      final hasSession = await _sessionService.hasFullSession();
      if (!hasSession) {
        _connectionState.add(YuConnectionState.disconnected);
        debugPrint('CommunicationService: No full session available');
        return;
      }
      
      // Инициализируем WebSocket-сервис (который инициализирует нативный)
      _connectionState.add(YuConnectionState.connecting);
      await _webSocketService.initialize();
      
      // Запускаем таймер обновления токена сессии
      _startSessionRefreshTimer();
      
      _isInitialized = true;
      debugPrint('CommunicationService: Initialized successfully');
    } catch (e) {
      debugPrint('CommunicationService: Error initializing: $e');
      _connectionState.add(YuConnectionState.error);
    }
  }
  
  void _handleWebSocketStateChanged(bool isConnected) {
    debugPrint('CommunicationService: WebSocket state changed: $isConnected');
    if (isConnected) {
      _connectionState.add(YuConnectionState.connected);
    } else {
      _connectionState.add(YuConnectionState.disconnected);
    }
  }
  
  /// Обработчик изменения состояния жизненного цикла приложения.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('CommunicationService: App lifecycle state changed to $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // При возвращении в активное состояние проверяем и обновляем токен
        _refreshSessionIfNeeded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Не требуют специальной обработки, т.к. нативный сервис продолжает работать
        break;
    }
  }
  
  void _startSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _refreshSessionIfNeeded(),
    );
  }
  
  Future<void> _refreshSessionIfNeeded() async {
    try {
      debugPrint('CommunicationService: Checking session for refresh');
      
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
        debugPrint('CommunicationService: Session refreshed successfully');
        
        // Обновляем токен в WebSocket сервисе
        await _webSocketService.updateToken(result.data!.accessToken);
      } else {
        // Ошибка обновления токена
        debugPrint('CommunicationService: Failed to refresh session: ${result.error}');
      }
    } catch (e) {
      debugPrint('CommunicationService: Error refreshing session: $e');
    }
  }
  
  /// Закрывает соединение и освобождает ресурсы.
  Future<void> dispose() async {
    debugPrint('CommunicationService: Disposing');
    WidgetsBinding.instance.removeObserver(this);
    _sessionRefreshTimer?.cancel();
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