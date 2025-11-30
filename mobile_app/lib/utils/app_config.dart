import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de la aplicación
class AppConfig {
  // URL del backend (CAMBIAR A TU IP/DOMINIO)
  static const String _defaultApiUrl = 'http://192.168.1.100:8000';
  static String apiUrl = _defaultApiUrl;

  // WebSocket URL
  static String get wsUrl => apiUrl.replaceFirst('http', 'ws') + '/ws/stream';

  // Configuración de alertas
  static String? fcmToken;
  static bool enablePushNotifications = true;
  static bool enableSMS = false;
  static String? phoneNumber;

  // Configuración de cámara
  static double confidenceThreshold = 0.4;
  static int frameSkip = 3; // Procesar 1 de cada N frames

  /// Carga la configuración desde SharedPreferences
  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    apiUrl = prefs.getString('api_url') ?? _defaultApiUrl;
    enablePushNotifications = prefs.getBool('enable_push') ?? true;
    enableSMS = prefs.getBool('enable_sms') ?? false;
    phoneNumber = prefs.getString('phone_number');
    confidenceThreshold = prefs.getDouble('confidence_threshold') ?? 0.4;
    frameSkip = prefs.getInt('frame_skip') ?? 3;
  }

  /// Guarda la configuración
  static Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('api_url', apiUrl);
    await prefs.setBool('enable_push', enablePushNotifications);
    await prefs.setBool('enable_sms', enableSMS);
    if (phoneNumber != null) {
      await prefs.setString('phone_number', phoneNumber!);
    }
    await prefs.setDouble('confidence_threshold', confidenceThreshold);
    await prefs.setInt('frame_skip', frameSkip);
  }

  /// Resetea a valores por defecto
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    apiUrl = _defaultApiUrl;
    enablePushNotifications = true;
    enableSMS = false;
    phoneNumber = null;
    confidenceThreshold = 0.4;
    frameSkip = 3;
  }
}
