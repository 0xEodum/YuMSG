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
  final WebSocketService _webSocketService = WebSocketService();
  
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addObserver(this);
    
    AuthServiceProvider.setService(_authService);
    
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      await _communicationService.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _communicationService.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
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