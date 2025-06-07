import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/server_connection_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_list_screen.dart';
import 'services/theme_service.dart';
import 'services/app_state_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStateService.initialize();
  runApp(const YuMSGApp());
}

class YuMSGApp extends StatefulWidget {
  const YuMSGApp({super.key});

  @override
  State<YuMSGApp> createState() => _YuMSGAppState();
}

class _YuMSGAppState extends State<YuMSGApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YuMSG',
      theme: YuMSGThemes.lightTheme,
      darkTheme: YuMSGThemes.darkTheme,
      themeMode: _themeService.themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/mode-selection': (context) => const ModeSelectionScreen(),
        '/server-connection': (context) => const ServerConnectionScreen(),
        '/auth': (context) => const AuthScreen(),
        '/chat-list': (context) => const ChatListScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}