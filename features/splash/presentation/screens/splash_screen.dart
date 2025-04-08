// lib/features/splash/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/data/providers/server_data_provider.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_arguments.dart';
import '../../../../core/services/background/background_service.dart';
import '../../../../core/services/communication/communication_service.dart';
import '../../../../core/services/navigation/navigation_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../../auth/domain/services/auth_service.dart';
import '../../../startup/domain/enums/work_mode.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _navigationService = NavigationService();
  final _sessionService = SessionService();
  final _authService = AuthService();
  final _communicationService = CommunicationService();
  final _backgroundService = BackgroundService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Инициализируем фоновый сервис
      await _backgroundService.initialize();
      
      // Регистрируем AuthService в провайдере для CommunicationService
      AuthServiceProvider.setService(_authService);
      
      // Получаем и проверяем режим работы
      final mode = await _sessionService.getWorkMode();
      final address = await _sessionService.getServerAddress();

      // Инициализируем провайдер данных сервера, если мы в серверном режиме и есть адрес
      if (mode == WorkMode.server && address != null) {
        // Избегаем повторной инициализации, если провайдер уже инициализирован
        if (!ServerDataProvider.isInitialized) {
          final provider = ServerDataProvider.initialize('http://$address');
          _authService.setDataProvider(provider);
        } else {
          _authService.setDataProvider(ServerDataProvider.instance);
        }
      }

      // 1. Проверяем наличие полной сессии
      if (await _sessionService.hasFullSession()) {
        // Проверяем доступность сервера
        if (await _checkServerAvailability()) {
          // Проверяем валидность токена
          if (await _validateSession()) {
            // Инициализируем коммуникационный сервис
            await _communicationService.initialize();
            
            // Запускаем фоновый сервис для серверного режима
            if (mode == WorkMode.server) {
              await _backgroundService.start();
            }
            
            await _navigateToMain();
            return;
          }
        }
        // Если что-то не так - очищаем всю сессию и останавливаем сервисы
        _backgroundService.stop();
        await _sessionService.clearSession();
        await _navigateToStart();
        return;
      }

      // 2. Проверяем наличие адреса сервера
      if (await _sessionService.hasServerConfig()) {
        // Проверяем доступность
        if (await _checkServerAvailability()) {
          await _navigateToAuth();
          return;
        }
        // Если сервер недоступен - очищаем его адрес
        await _sessionService.clearServerData();
        await _navigateToServerConnection();
        return;
      }

      // 3. Проверяем наличие выбранного режима
      if (await _sessionService.hasWorkMode()) {
        await _navigateToServerConnection();
        return;
      }

      // 4. Если ничего нет - начинаем с выбора режима
      await _navigateToStart();
    } catch (e) {
      // В случае любой ошибки очищаем сессию и начинаем сначала
      debugPrint('Error during app initialization: $e');
      await _sessionService.clearSession();
      await _navigateToStart();
    }
  }

  Future<bool> _checkServerAvailability() async {
    try {
      final address = await _sessionService.getServerAddress();
      if (address == null) return false;

      final status = await _authService.dataProvider.checkConnection(address);
      return status.isValid;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _validateSession() async {
    try {
      final authData = await _sessionService.getAuthData();
      if (authData == null) return false;

      final result = await _authService.refreshToken(
        authData.refreshToken,
        authData.deviceId,
      );

      if (result.success) {
        await _sessionService.saveAuthData(result.data!);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _navigateToMain() async {
    await _navigationService.navigateToAndRemoveUntil('/main');
  }

  Future<void> _navigateToAuth() async {
    final workMode = await _sessionService.getWorkMode();
    final actualWorkMode = workMode ?? WorkMode.server;
    
    await _navigationService.replaceTo(
      AppRouter.auth,
      arguments: AuthScreenArgs(workMode: actualWorkMode),
    );
  }

  Future<void> _navigateToServerConnection() async {
    await _navigationService.replaceTo(AppRouter.serverConnection);
  }

  Future<void> _navigateToStart() async {
    await _navigationService.replaceTo(AppRouter.start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Инициализация...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}