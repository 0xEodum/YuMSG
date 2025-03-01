// lib/core/navigation/app_router.dart
import 'package:flutter/material.dart';
import 'package:yumsg/features/chat/presentation/screens/chat_screen.dart';
import 'package:yumsg/features/main/presentation/screens/main_screen.dart';
import '../services/session/session_service.dart';
import '../../features/server_connection/presentation/screens/server_connection_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/startup/presentation/screens/start_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import 'route_arguments.dart';

class AppRouter {
  // Routes
  static const String splash = '/splash';
  static const String start = '/';
  static const String serverConnection = '/server-connection';
  static const String auth = '/auth';
  static const String main = '/main';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String storage = '/storage';
  static const String sett1ngs = '/settings';

  // Routes requiring arguments
  static const List<String> _routesRequiringArgs = [
    auth,
    chat,
  ];

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Check for required arguments
    if (_routesRequiringArgs.contains(settings.name) && settings.arguments == null) {
      return _errorRoute('Route ${settings.name} requires arguments');
    }

    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
        
      case start:
        return MaterialPageRoute(builder: (_) => const StartScreen());
        
      case serverConnection:
        return MaterialPageRoute(builder: (_) => const ServerConnectionScreen());
        
      case auth:
        if (settings.arguments is! AuthScreenArgs) {
          return _errorRoute(
            'AuthScreen requires AuthScreenArgs but got ${settings.arguments.runtimeType}'
          );
        }
        final args = settings.arguments as AuthScreenArgs;
        return MaterialPageRoute(
          builder: (_) => AuthScreen(workMode: args.workMode),
        );
        
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());

      case chat:
        if (settings.arguments is! ChatScreenArgs) {
          return _errorRoute(
            'ChatScreen requires ChatScreenArgs but got ${settings.arguments.runtimeType}'
          );
        }
        final args = settings.arguments as ChatScreenArgs;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: args.chatId,
            participantName: args.chatName,
          ),
        );

      case profile:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('Profile Screen')),
          ),
        );

      case storage:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Storage')),
            body: const Center(child: Text('Storage Screen')),
          ),
        );

      case sett1ngs:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const Center(child: Text('Settings Screen')),
          ),
        );

      default:
        return _errorRoute('Route ${settings.name} not found');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for route checking
  static bool isAuthRoute(String? route) => route == auth;
  static bool isServerConnectionRoute(String? route) => route == serverConnection;
  static bool isStartRoute(String? route) => route == start;
  static bool isMainRoute(String? route) => route == main;
  static bool isChatRoute(String? route) => route == chat;
}