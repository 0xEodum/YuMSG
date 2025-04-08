// lib/core/services/background/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session/session_service.dart';
import '../../../features/startup/domain/enums/work_mode.dart';

/// Сервис для поддержания фоновых операций и показа уведомлений.
/// Больше не создает отдельное WebSocket соединение.
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  
  // Названия сервисов и каналов
  static const String _serviceId = 'com.yumsg.background_service';
  static const String _notificationChannelId = 'com.yumsg.background_channel';
  static const String _notificationChannelName = 'Messenger Background Service';
  
  // Инстанс флаттер сервиса
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final SessionService _sessionService = SessionService();
  
  // Последнее уведомление для обновления
  String _lastNotificationContent = 'Приложение работает в фоне';
  
  BackgroundService._internal();
  
  /// Проверяет, запущен ли фоновый сервис.
  Future<bool> isRunning() async {
    return _service.isRunning();
  }
  
  /// Инициализирует фоновый сервис.
  Future<void> initialize() async {
    debugPrint('BackgroundService: Initializing');
    
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
    
    debugPrint('BackgroundService: Initialized successfully');
  }
  
  /// Запускает фоновый сервис.
  Future<void> start() async {
    try {
      debugPrint('BackgroundService: Starting');
      
      // Сначала проверяем, нужно ли запускать сервис
      final workMode = await _sessionService.getWorkMode();
      if (workMode != WorkMode.server) {
        debugPrint('BackgroundService: Not in server mode, skipping start');
        return; // В локальном режиме не нужен фоновый сервис
      }
      
      // Проверяем наличие сессии
      final hasSession = await _sessionService.hasFullSession();
      if (!hasSession) {
        debugPrint('BackgroundService: No session, skipping start');
        return; // Нет полной сессии, сервис не нужен
      }
      
      // Запускаем сервис
      await _service.startService();
      
      debugPrint('BackgroundService: Started');
    } catch (e) {
      debugPrint('BackgroundService: Error starting: $e');
    }
  }
  
  /// Останавливает фоновый сервис.
  void stop() {
    debugPrint('BackgroundService: Stopping');
    _service.invoke('stopService');
  }
  
  /// Отправляет обновление уведомления в фоновый сервис.
  void updateNotification(String content) {
    _lastNotificationContent = content;
    _service.invoke('updateNotification', {'content': content});
  }
  
  /// Показывает уведомление о новом сообщении.
  void showMessageNotification(String senderId, String content) {
    debugPrint('BackgroundService: Showing message notification from $senderId');
    updateNotification('Новое сообщение от $senderId');
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
      content: 'Поддержание соединения...',
    );
    
    // Только после настройки уведомления переводим сервис в foreground режим
    service.setAsForegroundService();
  }
  
  // Инициализируем сессию
  final sessionService = SessionService();
  
  // Обработчик команд от основного приложения
  service.on('stopService').listen((event) {
    service.stopSelf();
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
}