// screens/mode_selection_screen.dart
import 'package:flutter/material.dart';
import '../services/app_state_service.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  String? selectedMode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип и название
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  
                  // Основная карточка
                  _buildMainCard(isDark),
                  const SizedBox(height: 16),
                  
                  // Информационный блок
                  _buildVersionInfo(isDark),
                  const SizedBox(height: 8),
                
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Text(
          'YuMSG',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF8B5CF6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard(bool isDark) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Text(
              'Выберите режим работы',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Режим сервера
            _buildModeOption(
              isDark: isDark,
              mode: 'server',
              title: 'Серверный режим',
              description: 'Подключение к корпоративному серверу',
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),
            
            // Локальный режим
            _buildModeOption(
              isDark: isDark,
              mode: 'local',
              title: 'Локальный режим',
              description: 'Работа в локальной сети',
              icon: Icons.computer,
            ),
            const SizedBox(height: 24),
            
            // Кнопка продолжить
            _buildContinueButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required bool isDark,
    required String mode,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = selectedMode == mode;
    
    return InkWell(
      onTap: () => setState(() => selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE5E7EB),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? isDark
                  ? const Color(0xFF374151)
                  : const Color(0xFFF3E8FF)
              : null,
        ),
        child: Row(
          children: [
            // Radio button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF8B5CF6) : null,
              ),
              child: isSelected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF581C87) : const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool isDark) {
    final isEnabled = selectedMode != null;
    
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? const Color(0xFF7C3AED)
              : isDark
                  ? const Color(0xFF374151)
                  : const Color(0xFFE5E7EB),
          foregroundColor: isEnabled
              ? Colors.white
              : isDark
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF9CA3AF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Продолжить',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(bool isDark) {
    return Text(
      'YuMSG Версия 1.0',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF8B5CF6),
      ),
      textAlign: TextAlign.center,
    );
  }


  void _handleContinue() async {
    if (selectedMode == null) return;
    
    // Сохраняем выбранный режим
    await AppStateService.saveAppMode(selectedMode!);
    
    if (!mounted) return;
    
    // Навигация в зависимости от выбранного режима
    if (selectedMode == 'server') {
      Navigator.pushReplacementNamed(context, '/server-connection');
    } else {
      // Для локального режима переходим сразу к авторизации
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }
}