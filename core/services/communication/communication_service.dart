// lib/core/services/communication/communication_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../session/session_service.dart';
import '../websocket/websocket_service.dart';
import '../websocket/socket_connection_manager.dart';
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
  final SocketConnectionManager _socketManager = SocketConnectionManager();
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
    // Добавляем наблюдатель для отслеживания жизненного цикла приложения
    WidgetsBinding.instance.addObserver(this);
    
    // Подписываемся на изменения состояния соединения
    _socketManager.connectionState.listen(_handleConnectionStateChanged);
    
    // Устанавливаем обработчик уведомлений
    _webSocketService.setNotificationCallback(_backgroundService.showMessageNotification);
  }
  
  /// Инициализирует сервис коммуникации.
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
        // Нет полной сессии, соединение невозможно
        _connectionState.add(YuConnectionState.disconnected);
        debugPrint('CommunicationService: No full session available');
        return;
      }
      
      // Инициализируем фоновый сервис
      await _backgroundService.initialize();
      
      // Инициализируем менеджер сокетов
      await _socketManager.initialize();
      
      // Устанавливаем соединение
      _connectionState.add(YuConnectionState.connecting);
      await _socketManager.connect();
      
      // Запускаем таймер для обновления сессии
      _startSessionRefreshTimer();
      
      _isInitialized = true;
      debugPrint('CommunicationService: Initialized successfully');
    } catch (e) {
      debugPrint('CommunicationService: Error initializing: $e');
      _connectionState.add(YuConnectionState.error);
    }
  }
  
  /// Обработчик изменений состояния WebSocket соединения.
  void _handleConnectionStateChanged(bool isConnected) {
    debugPrint('CommunicationService: Connection state changed: $isConnected');
    if (isConnected) {
      _connectionState.add(YuConnectionState.connected);
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else {
      _connectionState.add(YuConnectionState.disconnected);
      _scheduleReconnect();
    }
  }
  
  /// Планирует автоматическое переподключение.
  void _scheduleReconnect() {
    if (!_isAppActive) return; // Не переподключаемся автоматически в фоне
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (currentConnectionState != YuConnectionState.connected) {
        debugPrint('CommunicationService: Attempting to reconnect');
        _connectionState.add(YuConnectionState.connecting);
        try {
          await _socketManager.connect();
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
  
  /// Вызывается, когда приложение возвращается на передний план.
  Future<void> _onAppResumed() async {
    debugPrint('CommunicationService: App resumed');
    _isAppActive = true;
    
    // Проверяем режим работы
    final workMode = await _sessionService.getWorkMode();
    if (workMode != WorkMode.server) return;
    
    // Проверяем наличие сессии
    final hasSession = await _sessionService.hasFullSession();
    if (!hasSession) return;
    
    // Устанавливаем соединение, если его нет
    if (!_socketManager.isConnected) {
      _connectionState.add(YuConnectionState.connecting);
      await _socketManager.connect();
    }
    
    // Останавливаем фоновый сервис
    _backgroundService.stop();
    
    // Обновляем токен и проверяем сессию
    await _refreshSessionIfNeeded();
  }
  
  /// Вызывается, когда приложение уходит на задний план.
  Future<void> _onAppPaused() async {
    debugPrint('CommunicationService: App paused');
    _isAppActive = false;
    
    // Проверяем режим работы
    final workMode = await _sessionService.getWorkMode();
    if (workMode != WorkMode.server) return;
    
    // Проверяем наличие сессии
    final hasSession = await _sessionService.hasFullSession();
    if (!hasSession) return;
    
    // Запускаем фоновый сервис для уведомлений
    await _backgroundService.start();
  }
  
  /// Вызывается, когда приложение закрывается.
  void _onAppDetached() {
    debugPrint('CommunicationService: App detached');
    _isAppActive = false;
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
        
        // Обновляем токен в менеджере сокетов
        await _socketManager.updateToken(result.data!.accessToken);
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