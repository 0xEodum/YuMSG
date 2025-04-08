// lib/features/main/presentation/providers/connection_status_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/communication/connection_state.dart';

class ConnectionStatusProvider with ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  StreamSubscription? _connectionSubscription;
  
  void initialize(CommunicationService communicationService) {
    _connectionSubscription?.cancel();
    
    _isConnected = communicationService.currentConnectionState == YuConnectionState.connected;
    
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