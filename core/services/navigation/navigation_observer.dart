// lib/core/services/navigation/navigation_observer.dart
import 'package:flutter/material.dart';
import '../session/session_service.dart';

class AppNavigatorObserver extends NavigatorObserver {
  final _sessionService = SessionService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('PUSH', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('POP', route.settings.name, previousRoute?.settings.name);
    _handlePopNavigation(route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigation('REMOVE', route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logNavigation(
      'REPLACE',
      newRoute?.settings.name,
      oldRoute?.settings.name,
    );
  }

  void _logNavigation(
    String action,
    String? currentRoute,
    String? previousRoute,
  ) {
    debugPrint(
      'Navigation: $action from ${previousRoute ?? 'null'} '
      'to ${currentRoute ?? 'null'}',
    );
  }

  Future<void> _handlePopNavigation(
    String? currentRoute,
    String? previousRoute,
  ) async {
    // Если возвращаемся с экрана авторизации на экран подключения
    if (currentRoute == '/auth' && previousRoute == '/server-connection') {
      await _sessionService.clearServerData();
    }
    // Если возвращаемся с экрана подключения на стартовый экран
    else if (currentRoute == '/server-connection' && previousRoute == '/') {
      await _sessionService.clearWorkMode();
    }
  }
}