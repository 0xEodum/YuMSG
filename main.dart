import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/websocket/websocket_service.dart';

void main() {
  // Обеспечиваем инициализацию Flutter binding перед запуском приложения
  WidgetsFlutterBinding.ensureInitialized();
  
  // Настраиваем обработчик возрождения приложения после его уничтожения системой
  setupAppLifecycleHandlers();
  
  runApp(const MessengerApp());
}

/// Настраивает обработчики жизненного цикла приложения
void setupAppLifecycleHandlers() {
  // При возрождении приложения после его уничтожения системой
  // (например, при низком уровне памяти или после смахивания приложения)
  WidgetsBinding.instance.addObserver(
    _AppLifecycleObserver(),
  );
}

/// Наблюдатель за жизненным циклом приложения
class _AppLifecycleObserver extends WidgetsBindingObserver {
  // Флаг, указывающий, было ли приложение полностью закрыто
  bool _wasDetached = false;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycleObserver: App state changed to $state');
    
    if (state == AppLifecycleState.resumed && _wasDetached) {
      _wasDetached = false;
      
      // Приложение было восстановлено после полного закрытия
      // Переинициализируем соединение с сервисом WebSocket
      _reconnectWebSocketService();
    } else if (state == AppLifecycleState.detached) {
      _wasDetached = true;
    }
  }
  
  /// Переподключает WebSocket сервис к нативному слою
  Future<void> _reconnectWebSocketService() async {
    debugPrint('AppLifecycleObserver: Reconnecting WebSocket service after app resurrection');
    try {
      // Получаем WebSocketService и переинициализируем EventChannel
      await WebSocketService().reconnectEventChannel();
    } catch (e) {
      debugPrint('AppLifecycleObserver: Error reconnecting WebSocket service: $e');
    }
  }
}