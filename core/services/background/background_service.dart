// lib/core/services/background/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yumsg/core/services/websocket/websocket_service.dart';
import 'package:yumsg/features/chat/domain/services/chat_service.dart';
import '../session/session_service.dart';
import '../../../features/startup/domain/enums/work_mode.dart';

/// Сервис для поддержания фоновых операций и уведомлений.
/// Больше не дублирует WebSocket функциональность.
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  
  // Названия сервисов и каналов
  static const String _serviceId = 'com.yumsg.background_service';
  static const String _notificationChannelId = 'com.yumsg.background_channel';
  static const String _notificationChannelName = 'Messenger Background Service';
  
  // Инстанс флаттер сервиса
  final FlutterBackgroundService _service = FlutterBackgroundService();
  
  // Подписки на события от фонового сервиса
  final List<StreamSubscription> _eventSubscriptions = [];
  
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
    
    // Создаем канал уведомлений для Android
    const androidNotificationChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      importance: Importance.high,
      enableVibration: false,
      enableLights: false,
      showBadge: false,
    );
    
    // Регистрируем канал уведомлений
    await notificationPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
    
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
    
    // Настраиваем обработчики событий, получаемых от фонового сервиса
    _setupEventHandlers();
  }
  
  /// Настраивает обработчики событий от фонового сервиса
  void _setupEventHandlers() {
    // Отменяем существующие подписки
    for (var subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();
    
    // Подписка на обновление уведомления
    _eventSubscriptions.add(
      _service.on('updateNotification').listen((event) {
        if (event != null && event.containsKey('content')) {
          final content = event['content'] as String;
          
          // Обновляем уведомление
          if (_service is AndroidServiceInstance) {
            (_service as AndroidServiceInstance).setForegroundNotificationInfo(
              title: 'Мессенджер',
              content: content,
            );
          }
        }
      })
    );
  }
  
  /// Запускает фоновый сервис.
  Future<void> start() async {
    try {
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
      
      // Настраиваем обработчики событий
      _setupEventHandlers();
      
      // Запускаем сервис
      await _service.startService();
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
  }
  
  /// Останавливает фоновый сервис.
  void stop() {
    _service.invoke('stopService');
    
    // Отменяем подписки на события
    for (var subscription in _eventSubscriptions) {
      subscription.cancel();
    }
    _eventSubscriptions.clear();
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
  
  // Для Android настраиваем уведомление перед переводом в foreground режим
  if (service is AndroidServiceInstance) {
    // Сначала устанавливаем информацию для уведомления
    service.setForegroundNotificationInfo(
      title: 'Мессенджер работает в фоне',
      content: 'Инициализация...',
    );
    
    // Только после настройки уведомления переводим сервис в foreground режим
    service.setAsForegroundService();
  }
  
  // Импортируем ChatService для работы с сообщениями
  final chatService = ChatService();
  
  // Инициализируем сессию
  final sessionService = SessionService();
  
  // Получаем WebSocketService и устанавливаем ему фоновый режим
  final webSocketService = WebSocketService();
  webSocketService.setBackgroundMode(true);
  
  // Обработчик команд от основного приложения
  service.on('stopService').listen((event) {
    webSocketService.disconnect();
    service.stopSelf();
  });
  
  // Обновление данных от основного приложения
  service.on('updateData').listen((event) {
    if (event != null && event.containsKey('token')) {
      // Переподключаемся с новым токеном
      webSocketService.disconnect();
      webSocketService.connect();
    }
  });
  
  // Обработчик обновления уведомления
  service.on('updateNotification').listen((event) {
    if (event != null && event.containsKey('content')) {
      final content = event['content'] as String;
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Мессенджер',
          content: content,
        );
      }
    }
  });
  
  // Запускаем проверку сессии каждый час
  Timer.periodic(const Duration(hours: 1), (_) async {
    final hasSession = await sessionService.hasFullSession();
    if (!hasSession) {
      // Сессия недействительна, останавливаем сервис
      service.invoke('sessionInvalid', {});
      service.stopSelf();
    }
  });
  
  // Устанавливаем соединение
  try {
    await webSocketService.connect();
    
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Мессенджер работает в фоне',
        content: 'Соединение установлено',
      );
    }
  } catch (e) {
    debugPrint('Error connecting WebSocket from background service: $e');
    
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Мессенджер работает в фоне',
        content: 'Ошибка соединения, переподключение...',
      );
    }
  }
}