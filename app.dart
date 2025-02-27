// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation/navigation_service.dart';
import 'core/services/navigation/navigation_observer.dart';
import 'features/auth/domain/services/auth_service.dart';
import 'core/services/communication/communication_service.dart';
import 'features/main/presentation/providers/connection_status_provider.dart';

class MessengerApp extends StatefulWidget {
  final String initialRoute;
  const MessengerApp({super.key, this.initialRoute = AppRouter.splash});

  @override
  State<MessengerApp> createState() => _MessengerAppState();
}

class _MessengerAppState extends State<MessengerApp> {
  final CommunicationService _communicationService = CommunicationService();
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    
    // Регистрируем AuthService в провайдере для CommunicationService
    AuthServiceProvider.setService(_authService);
  }
  
  @override
  void dispose() {
    _communicationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionStatusProvider()),
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