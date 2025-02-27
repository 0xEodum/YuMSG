// lib/core/services/background/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yumsg/core/data/providers/server_data_provider.dart';
import '../session/session_service.dart';
import '../websocket/websocket_service.dart';
import '../../../features/startup/domain/enums/work_mode.dart';

/// Сервис для поддержания фоновых операций, включая WebSocket соединение.
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  
  // Названия сервисов и каналов
  static const String _serviceId = 'com.yumsg.background_service';
  static const String _notificationChannelId = 'com.yumsg.background_channel';
  static const String _notificationChannelName = 'Messenger Background Service';
  
  // Инстанс флаттер сервиса
  final FlutterBackgroundService _service = FlutterBackgroundService();
  
  BackgroundService._internal();
  
  /// Проверяет, запущен ли фоновый сервис.
  Future<bool> isRunning() async {
    return _service.isRunning();
  }
  
  /// Инициализирует фоновый сервис.
  Future<void> initialize() async {
    // Инициализируем плагин локальных уведомлений
    final notificationPlugin = FlutterLocalNotificationsPlugin();
    
    // Настройка Android-платформы
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Настройка iOS-платформы
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    
    // Инициализация уведомлений
    await notificationPlugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    
    // Настраиваем фоновый сервис
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Мессенджер работает в фоне',
        initialNotificationContent: 'Вы получаете сообщения',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }
  
  /// Запускает фоновый сервис.
  Future<void> start() async {
    // Сначала проверяем, нужно ли запускать сервис
    final sessionService = SessionService();
    
    // Проверяем режим работы
    final workMode = await sessionService.getWorkMode();
    if (workMode != WorkMode.server) {
      return; // В локальном режиме не нужен фоновый сервис
    }
    
    // Проверяем наличие сессии
    final hasSession = await sessionService.hasFullSession();
    if (!hasSession) {
      return; // Нет полной сессии, сервис не нужен
    }
    
    // Запускаем сервис
    await _service.startService();
  }
  
  /// Останавливает фоновый сервис.
  void stop() {
    _service.invoke('stopService');
  }
  
  /// Отправляет данные в фоновый сервис.
  void sendData(Map<String, dynamic> data) {
    _service.invoke('updateData', data);
  }
}

/// Запуск сервиса в фоновом режиме для iOS.
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  return true;
}

/// Точка входа для фонового сервиса.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  // Для Android настраиваем сервис как foreground service
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
  
  // Инициализируем WebSocket сервис
  WebSocketService webSocketService = WebSocketService();
  SessionService sessionService = SessionService();
  
  bool isConnected = false;
  Timer? reconnectTimer;
  Timer? sessionCheckTimer;
  
  // Обработчик команд от основного приложения
  service.on('stopService').listen((event) {
    webSocketService.disconnect();
    reconnectTimer?.cancel();
    sessionCheckTimer?.cancel();
    service.stopSelf();
  });
  
  // Обновление данных от основного приложения
  service.on('updateData').listen((event) {
    if (event != null && event.containsKey('token')) {
      // Переподключаемся с новым токеном
      webSocketService.disconnect();
      _connectWebSocket(webSocketService, sessionService);
    }
  });
  
  // Подписываемся на статус соединения
  webSocketService.onConnected.listen((connected) {
    isConnected = connected;
    service.invoke('connectionStatus', {'isConnected': connected});
    
    if (!connected) {
      // Планируем переподключение
      reconnectTimer?.cancel();
      reconnectTimer = Timer(const Duration(seconds: 30), () {
        _connectWebSocket(webSocketService, sessionService);
      });
    }
  });
  
  // Подписываемся на события чата
  webSocketService.onMessage.listen((chatMessage) {
    // Обрабатываем сообщение
    service.invoke('newMessage', {
      'chatId': chatMessage.chatId,
      'senderId': chatMessage.senderId,
      'messageId': chatMessage.messageId,
      'content': chatMessage.content,
      'type': chatMessage.type,
    });
    
    // Отправляем уведомление 
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Новое сообщение',
        content: 'У вас новое сообщение',
      );
    }
  });
  
  // Подписываемся на инициализацию чата
  webSocketService.onChatInit.listen((chatInit) {
    service.invoke('chatInit', {
      'chatId': chatInit.chatId,
      'initiatorId': chatInit.initiatorId,
      'publicKey': chatInit.publicKey,
    });
  });
  
  // Запускаем проверку сессии каждый час
  sessionCheckTimer = Timer.periodic(const Duration(hours: 1), (_) async {
    final hasSession = await sessionService.hasFullSession();
    if (!hasSession) {
      // Сессия недействительна, останавливаем сервис
      service.invoke('sessionInvalid', {});
      service.stopSelf();
    }
  });
  
  // Инициируем подключение
  _connectWebSocket(webSocketService, sessionService);
}

/// Подключает WebSocket в фоновом режиме.
Future<void> _connectWebSocket(
  WebSocketService webSocketService,
  SessionService sessionService,
) async {
  try {
    // Получаем данные авторизации и адрес сервера
    final authData = await sessionService.getAuthData();
    final address = await sessionService.getServerAddress();
    
    if (authData == null || address == null) {
      debugPrint('Missing auth data or server address for WebSocket connection');
      return;
    }
    
    // Инициализируем ServerDataProvider, если еще не инициализирован
    if (!ServerDataProvider.isInitialized) {
      ServerDataProvider.initialize('http://$address');
    }
    
    // Подключаемся через WebSocket
    await webSocketService.connect();
  } catch (e) {
    debugPrint('Error connecting WebSocket in background: $e');
  }
}