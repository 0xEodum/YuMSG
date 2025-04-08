// lib/core/services/communication/communication_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import '../websocket/websocket_service.dart';
import '../background/background_service.dart';
import '../../../features/auth/domain/models/auth_data.dart';
import '../../../features/startup/domain/enums/work_mode.dart';
import 'connection_state.dart';

/// Координатор коммуникаций с сервером.
/// 
/// Этот сервис координирует работу WebSocketService и BackgroundService,
/// отслеживает состояние соединения и жизненный цикл приложения.
class CommunicationService with WidgetsBindingObserver {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  
  final WebSocketService _webSocketService = WebSocketService();
  final SessionService _sessionService = SessionService();
  final BackgroundService _backgroundService = BackgroundService();
  
  // Состояние соединения
  final _connectionState = BehaviorSubject<YuConnectionState>.seeded(YuConnectionState.disconnected);
  
  // Флаги состояния
  bool _isInitialized = false;
  bool _isAppActive = true;
  Timer? _sessionRefreshTimer;
  Timer? _reconnectTimer;
  
  Stream<YuConnectionState> get connectionState => _connectionState.stream;
  YuConnectionState get currentConnectionState => _connectionState.value;
  bool get isConnected => currentConnectionState == YuConnectionState.connected;
  
  CommunicationService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
    _webSocketService.connectionState.listen(_handleWebSocketStateChanged);
    
    _webSocketService.setNotificationCallback(_backgroundService.showMessageNotification);
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
      
      await _backgroundService.initialize();
      
      _connectionState.add(YuConnectionState.connecting);
      await _webSocketService.connect();
      
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
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else {
      _connectionState.add(YuConnectionState.disconnected);
      _scheduleReconnect();
    }
  }
  
  void _scheduleReconnect() {
    if (!_isAppActive) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (currentConnectionState != YuConnectionState.connected) {
        debugPrint('CommunicationService: Attempting to reconnect');
        _connectionState.add(YuConnectionState.connecting);
        try {
          await _webSocketService.connect();
        } catch (e) {
          debugPrint('CommunicationService: Reconnect attempt failed: $e');
          _connectionState.add(YuConnectionState.error);
        }
      }
    });
  }
  
  /// Обработчик изменения состояния жизненного цикла приложения.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('CommunicationService: App lifecycle state changed to $state');
    
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
  
  Future<void> _onAppResumed() async {
    debugPrint('CommunicationService: App resumed');
    _isAppActive = true;
    
    final workMode = await _sessionService.getWorkMode();
    if (workMode != WorkMode.server) return;
    
    final hasSession = await _sessionService.hasFullSession();
    if (!hasSession) return;
    
    _webSocketService.setBackgroundMode(false);
    
    if (!isConnected) {
      _connectionState.add(YuConnectionState.connecting);
      await _webSocketService.connect();
    }
    
    if (await _backgroundService.isRunning()) {
      _backgroundService.stop();
    }
    
    await _refreshSessionIfNeeded();
  }
  
  Future<void> _onAppPaused() async {
    debugPrint('CommunicationService: App paused');
    _isAppActive = false;
    
    final workMode = await _sessionService.getWorkMode();
    if (workMode != WorkMode.server) return;
    
    final hasSession = await _sessionService.hasFullSession();
    if (!hasSession) return;
    
    _webSocketService.setBackgroundMode(true);
    
    await _backgroundService.start();
  }
  
  void _onAppDetached() {
    debugPrint('CommunicationService: App detached');
    _isAppActive = false;
    // Если приложение закрывается, отключаемся от WebSocket
    // _webSocketService.disconnect();
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
        
        // Переподключаемся с новым токеном, если уже подключены
        if (isConnected) {
          await _webSocketService.disconnect();
          await _webSocketService.connect();
        }
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