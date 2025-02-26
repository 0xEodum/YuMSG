import 'package:flutter/material.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/navigation/navigation_service.dart';
import 'core/services/navigation/navigation_observer.dart';

class MessengerApp extends StatelessWidget {
  final String initialRoute;
  const MessengerApp({super.key, this.initialRoute = AppRouter.splash});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Корпоративный мессенджер',
      theme: AppTheme.light,
      navigatorKey: NavigationService().navigatorKey,
      navigatorObservers: [AppNavigatorObserver()],
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: initialRoute,
    );
  }
}