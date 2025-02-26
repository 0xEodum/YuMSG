// lib/features/startup/presentation/screens/start_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/navigation/route_arguments.dart';
import '../../../../core/services/navigation/navigation_service.dart';
import '../../../../core/services/session/session_service.dart';
import '../../domain/enums/work_mode.dart';
import '../widgets/work_mode_card.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  WorkMode? _selectedMode;
  final _navigationService = NavigationService();
  final _sessionService = SessionService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingMode();
  }

  Future<void> _checkExistingMode() async {
    try {
      // Проверяем наличие сохраненного режима
      final savedMode = await _sessionService.getWorkMode();
      
      if (savedMode != null) {
        // Если режим уже выбран, сразу переходим дальше
        if (mounted) {
          _handleContinue(savedMode);
        }
        return;
      }
    } catch (e) {
      // В случае ошибки просто показываем экран выбора
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleContinue([WorkMode? mode]) async {
    final selectedMode = mode ?? _selectedMode;
    if (selectedMode == null) return;

    try {
      setState(() => _isLoading = true);

      // Сохраняем выбранный режим
      await _sessionService.saveWorkMode(selectedMode);

      if (selectedMode == WorkMode.server) {
        await _navigationService.navigateTo('/server-connection');
      } else {
        // Для локального режима сразу переходим к авторизации
        await _navigationService.navigateTo(
          '/auth',
          arguments: AuthScreenArgs(workMode: selectedMode),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Произошла ошибка при сохранении режима работы'),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleModeSelection(WorkMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Выберите режим работы',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        WorkModeRadioCard(
                          mode: WorkMode.server,
                          isSelected: _selectedMode == WorkMode.server,
                          onSelected: _handleModeSelection,
                        ),
                        const SizedBox(height: 16),
                        WorkModeRadioCard(
                          mode: WorkMode.local,
                          isSelected: _selectedMode == WorkMode.local,
                          onSelected: _handleModeSelection,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _selectedMode != null 
                              ? () => _handleContinue() 
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: const Text(
                            'Продолжить',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}