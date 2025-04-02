// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation/navigation_service.dart';
import 'core/services/navigation/navigation_observer.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'core/services/communication/communication_service.dart';
import 'core/services/background/background_service.dart';
import 'features/main/presentation/providers/connection_status_provider.dart';
import 'core/services/websocket/websocket_service.dart';
import 'features/chat/domain/services/message_queue_service.dart';

class MessengerApp extends StatefulWidget {
  final String initialRoute;
  const MessengerApp({super.key, this.initialRoute = AppRouter.splash});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp> with WidgetsBindingObserver {
  final CommunicationService _communicationService = CommunicationService();
  final AuthService _authService = AuthService();
  final BackgroundService _backgroundService = BackgroundService();
  final WebSocketService _webSocketService = WebSocketService();
  final MessageQueueService _messageQueueService = MessageQueueService();
  
  @override
  void initState() {
    super.initState();
    
    // Добавляем наблюдатель для отслеживания жизненного цикла приложения
    WidgetsBinding.instance.addObserver(this);
    
    // Регистрируем AuthService в провайдере для CommunicationService
    AuthServiceProvider.setService(_authService);
    
    // Инициализируем сервисы
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      // Инициализируем фоновый сервис
      await _backgroundService.initialize();
      
      // Проверяем, запущен ли фоновый сервис
      final isBackgroundRunning = await _backgroundService.isRunning();
      
      // Если фоновый сервис уже запущен, уведомляем WebSocketService
      if (isBackgroundRunning) {
        _webSocketService.setBackgroundMode(true);
      }
      
      // Инициализируем коммуникационный сервис
      await _communicationService.initialize();
      
      // Запускаем обработку очереди сообщений
      _messageQueueService.startQueueProcessing();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // Приложение ушло в фоновый режим, запускаем фоновый сервис
      _backgroundService.start();
    } else if (state == AppLifecycleState.resumed) {
      // Приложение вернулось на передний план
      _webSocketService.setBackgroundMode(false);
    }
  }
  
  @override
  void dispose() {
    // Отключаемся от наблюдателя жизненного цикла
    WidgetsBinding.instance.removeObserver(this);
    
    // Освобождаем ресурсы сервисов
    _communicationService.dispose();
    _messageQueueService.stopQueueProcessing();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          // Создаем провайдер статуса соединения и инициализируем его
          final provider = ConnectionStatusProvider();
          provider.initialize(_communicationService);
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Корпоративный мессенджер',
        theme: AppTheme.light,
        navigatorKey: NavigationService().navigatorKey,
        navigatorObservers: [AppNavigatorObserver()],
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: widget.initialRoute,
      ),
    );
  }
}