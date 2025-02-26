// lib/core/services/navigation/navigation_service.dart
import 'package:flutter/material.dart';
import '../../../features/startup/domain/enums/work_mode.dart';
import '../session/session_service.dart';
import '../../navigation/app_router.dart';
import '../../navigation/route_arguments.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final _sessionService = SessionService();
  
  WorkMode? _currentWorkMode;
  WorkMode? get currentWorkMode => _currentWorkMode;
  
  // Инициализация и управление режимом работы
  Future<void> initWorkMode() async {
    _currentWorkMode = await _sessionService.getWorkMode();
  }

  Future<void> updateWorkMode(WorkMode mode) async {
    _currentWorkMode = mode;
    await _sessionService.saveWorkMode(mode);
  }

  // Методы навигации для конкретных экранов
  Future<void> navigateToStart() async {
    return navigateToAndRemoveUntil(AppRouter.start);
  }

  Future<void> navigateToServerConnection() async {
    return navigateTo(AppRouter.serverConnection);
  }

  Future<void> navigateToAuth(WorkMode workMode) async {
    return navigateTo(
      AppRouter.auth,
      arguments: AuthScreenArgs(workMode: workMode),
    );
  }

  Future<void> navigateToMain() async {
    return navigateToAndRemoveUntil(AppRouter.main);
  }

  // Базовые методы навигации
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed<T, void>(
      routeName,
      arguments: arguments,
    );
  }

  void goBack<T>([T? result]) {
    return navigatorKey.currentState!.pop<T>(result);
  }

  Future<T?> navigateToAndRemoveUntil<T>(
    String routeName, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
  }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  // Вспомогательные методы
  bool canGoBack() {
    return navigatorKey.currentState?.canPop() ?? false;
  }

  void popUntilRoute(String routeName) {
    navigatorKey.currentState?.popUntil(
      (route) => route.settings.name == routeName,
    );
  }
}