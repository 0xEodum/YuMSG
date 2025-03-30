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
      
      // Запускаем сервис
      await _service.startService();
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
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
  
  // Для Android настраиваем уведомление перед переводом в foreground режим
  if (service is AndroidServiceInstance) {
    // Сначала устанавливаем информацию для уведомления
    service.setForegroundNotificationInfo(
      title: 'Мессенджер работает в фоне',
      content: 'Вы получаете сообщения',
    );
    
    // Только после настройки уведомления переводим сервис в foreground режим
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
  
  // Обработка сообщений чата (новый формат)
  webSocketService.onMessage.listen((chatMessage) {
    try {
      // Обрабатываем сообщение - извлекаем ID отправителя
      final senderId = chatMessage.senderId;
      
      // Формируем ID чата по новой схеме
      final chatId = 'chat_with_$senderId';
      
      // Отправляем в основное приложение
      service.invoke('newMessage', {
        'chatId': chatId,
        'senderId': senderId,
        'messageId': chatMessage.messageId,
        'content': chatMessage.content,
        'type': chatMessage.type,
        'timestamp': chatMessage.timestamp,
      });
      
      // Обновляем уведомление при получении сообщения
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Новое сообщение',
          content: 'У вас новое сообщение от ${senderId}',
        );
      }
      
      // Автоматически отправляем статус "доставлено"
      webSocketService.sendMessageStatus(
        senderId,
        chatMessage.messageId,
        'delivered'
      );
    } catch (e) {
      debugPrint('Error handling message in background service: $e');
    }
  });
  
  // Подписываемся на инициализацию чата (новый формат)
  webSocketService.onChatInit.listen((event) {
    final senderId = event.senderId;
    final initiatorName = event.initiatorName;
    final publicKey = event.publicKey;
    
    service.invoke('chatInit', {
      'senderId': senderId,
      'initiatorName': initiatorName,
      'publicKey': publicKey,
    });
  });
  
  // Подписываемся на обмен ключами (новый формат)
  webSocketService.onKeyExchange.listen((event) {
    final senderId = event.senderId;
    final responderName = event.responderName;
    final publicKey = event.publicKey;
    final encryptedPartialKey = event.encryptedPartialKey;
    
    service.invoke('keyExchange', {
      'senderId': senderId,
      'responderName': responderName,
      'publicKey': publicKey,
      'encryptedPartialKey': encryptedPartialKey,
    });
  });
  
  // Подписываемся на завершение обмена ключами (новый формат)
  webSocketService.onKeyExchangeComplete.listen((event) {
    final senderId = event.senderId;
    final encryptedPartialKey = event.encryptedPartialKey;
    
    service.invoke('keyExchangeComplete', {
      'senderId': senderId,
      'encryptedPartialKey': encryptedPartialKey,
    });
  });
  
  // Подписываемся на статусы сообщений (новый формат)
  webSocketService.onMessageStatus.listen((event) {
    final senderId = event.senderId;
    final messageId = event.messageId;
    final status = event.status;
    
    service.invoke('messageStatus', {
      'senderId': senderId,
      'messageId': messageId,
      'status': status,
    });
  });
  
  // Подписываемся на удаление чата (новый формат)
  webSocketService.onChatDelete.listen((event) {
    final senderId = event.senderId;
    
    service.invoke('chatDelete', {
      'senderId': senderId,
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
    try {
      if (!ServerDataProvider.isInitialized) {
        ServerDataProvider.initialize('http://$address');
      }
    } catch (e) {
      debugPrint('Error initializing ServerDataProvider: $e');
    }
    
    // Подключаемся через WebSocket
    try {
      await webSocketService.connect();
    } catch (e) {
      debugPrint('Error connecting WebSocket: $e');
    }
  } catch (e) {
    debugPrint('Error in _connectWebSocket: $e');
  }
}