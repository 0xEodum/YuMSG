// screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../services/app_state_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Имитируем загрузку приложения
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    
    // Определяем стартовый экран на основе состояния
    final startRoute = AppStateService.getStartRoute();
    
    // Переходим на нужный экран с заменой текущего
    Navigator.pushReplacementNamed(context, startRoute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [
                    const Color(0xFF111827), // gray-900
                    const Color(0xFF1F2937), // gray-800
                  ]
                : [
                    const Color(0xFFF3E8FF), // purple-50
                    const Color(0xFFE5E7EB), // gray-200
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Логотип с анимацией
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF8B5CF6) 
                              : const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark 
                                  ? const Color(0xFF8B5CF6) 
                                  : const Color(0xFF7C3AED)).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.message,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // Название приложения
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1200),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Text(
                      'YuMSG',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: isDark 
                            ? const Color(0xFF8B5CF6) 
                            : const Color(0xFF7C3AED),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              
              // Подзаголовок
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1400),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Text(
                      'Безопасные сообщения',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark 
                            ? const Color(0xFF9CA3AF) 
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 64),
              
              // Индикатор загрузки
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark 
                              ? const Color(0xFF8B5CF6) 
                              : const Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}