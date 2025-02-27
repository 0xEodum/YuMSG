// lib/features/main/presentation/providers/connection_status_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/communication/connection_state.dart';

/// Провайдер для отслеживания и предоставления статуса соединения в приложении.
class ConnectionStatusProvider with ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  StreamSubscription? _connectionSubscription;
  
  /// Инициализирует провайдер и подписывается на изменения статуса соединения.
  void initialize(CommunicationService communicationService) {
    // Отписываемся от предыдущей подписки, если она существует
    _connectionSubscription?.cancel();
    
    // Устанавливаем начальное состояние
    _isConnected = communicationService.currentConnectionState == YuConnectionState.connected;
    
    // Подписываемся на изменения состояния соединения
    _connectionSubscription = communicationService.connectionState.listen((state) {
      final newIsConnected = state == YuConnectionState.connected;
      if (_isConnected != newIsConnected) {
        _isConnected = newIsConnected;
        notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}