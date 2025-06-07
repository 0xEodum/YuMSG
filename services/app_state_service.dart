import 'package:shared_preferences/shared_preferences.dart';
import 'package:yumsg/services/theme_service.dart';

enum AppScreen {
  modeSelection,
  serverConnection,
  auth,
  chatList,
}

class AppStateService {
  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await ThemeService().loadThemeMode();
  }

  static AppScreen determineStartScreen() {
    final appMode = getAppMode();

    if (appMode == null) {
      return AppScreen.modeSelection;
    }
    
    if (appMode == 'server') {
      if (!isServerConfigured()) {
        return AppScreen.serverConnection;
      }
      
      if (!isUserAuthorized()) {
        return AppScreen.auth;
      }
      
      return AppScreen.chatList;
    }
    
    // Локальный режим
    if (appMode == 'local') {
      if (!isLocalUserSet()) {
        return AppScreen.auth;
      }
      
      return AppScreen.chatList;
    }
    
    return AppScreen.modeSelection;
  }

  static String getStartRoute() {
    switch (determineStartScreen()) {
      case AppScreen.modeSelection:
        return '/mode-selection';
      case AppScreen.serverConnection:
        return '/server-connection';
      case AppScreen.auth:
        return '/auth';
      case AppScreen.chatList:
        return '/chat-list';
    }
  }

  static String? getPreviousRoute(AppScreen currentScreen) {
    switch (currentScreen) {
      case AppScreen.modeSelection:
        return null;
        
      case AppScreen.serverConnection:
        return '/mode-selection';
        
      case AppScreen.auth:
        final appMode = getAppMode();
        if (appMode == 'server') {
          return '/server-connection';
        } else {
          return '/mode-selection';
        }
        
      case AppScreen.chatList:
        return '/auth';
    }
  }

  static AppScreen? getCurrentScreen() {
    final screenName = _prefs.getString('current_screen');
    if (screenName == null) return null;
    
    return AppScreen.values.firstWhere(
      (screen) => screen.name == screenName,
      orElse: () => AppScreen.modeSelection,
    );
  }

  static Future<void> setCurrentScreen(AppScreen screen) async {
    await _prefs.setString('current_screen', screen.name);
  }

  static Future<void> saveAppMode(String mode) async {
    await _prefs.setString('app_mode', mode);
    await setCurrentScreen(AppScreen.modeSelection);
  }

  static String? getAppMode() {
    return _prefs.getString('app_mode');
  }

  static Future<void> saveServerConfig({
    required String ip,
    required String port,
    String? organizationName,
  }) async {
    await _prefs.setString('server_ip', ip);
    await _prefs.setString('server_port', port);
    if (organizationName != null) {
      await _prefs.setString('organization_name', organizationName);
    }
    await _prefs.setBool('server_configured', true);
    await setCurrentScreen(AppScreen.serverConnection);
  }

  static Map<String, String?> getServerConfig() {
    return {
      'ip': _prefs.getString('server_ip'),
      'port': _prefs.getString('server_port'),
      'organization_name': _prefs.getString('organization_name'),
    };
  }

  static bool isServerConfigured() {
    return _prefs.getBool('server_configured') ?? false;
  }

  static Future<void> saveLocalUser(String username) async {
    await _prefs.setString('local_username', username);
    await _prefs.setBool('local_user_set', true);
    await _prefs.setBool('first_setup_completed', true);
    await setCurrentScreen(AppScreen.chatList);
  }

  static String? getLocalUser() {
    return _prefs.getString('local_username');
  }

  static bool isLocalUserSet() {
    return _prefs.getBool('local_user_set') ?? false;
  }

  static Future<void> saveUserSession({
    required String username,
    required String token,
    String? organizationId,
  }) async {
    await _prefs.setString('user_username', username);
    await _prefs.setString('user_token', token);
    if (organizationId != null) {
      await _prefs.setString('user_organization_id', organizationId);
    }
    await _prefs.setBool('user_authorized', true);
    await _prefs.setBool('first_setup_completed', true);
    await _prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);
    await setCurrentScreen(AppScreen.chatList);
  }

  static Map<String, String?> getUserSession() {
    return {
      'username': _prefs.getString('user_username'),
      'token': _prefs.getString('user_token'),
      'organization_id': _prefs.getString('user_organization_id'),
    };
  }

  static bool isUserAuthorized() {
    return _prefs.getBool('user_authorized') ?? false;
  }

  static bool isFirstSetupCompleted() {
    return _prefs.getBool('first_setup_completed') ?? false;
  }

  static Future<void> clearAllData() async {
    await _prefs.clear();
    await ThemeService().loadThemeMode();
  }

  static Future<void> clearAuthData() async {
    await _prefs.remove('user_username');
    await _prefs.remove('user_token');
    await _prefs.remove('user_organization_id');
    await _prefs.remove('user_authorized');
    await _prefs.remove('local_user_set');
    await _prefs.remove('login_timestamp');
    await _prefs.setBool('first_setup_completed', false);
    
    final appMode = getAppMode();
    if (appMode == 'server') {
      await setCurrentScreen(AppScreen.serverConnection);
    } else {
      await setCurrentScreen(AppScreen.auth);
    }
  }

  static Future<void> resetToModeSelection() async {
    await clearAllData();
    await setCurrentScreen(AppScreen.modeSelection);
  }
}