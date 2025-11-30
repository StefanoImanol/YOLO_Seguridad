import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

/// Servicio de notificaciones push y locales
class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    // Solicitar permisos
    await _requestPermissions();

    // Configurar notificaciones locales
    await _setupLocalNotifications();

    // Obtener token FCM
    await _getFCMToken();

    // Configurar handlers de Firebase
    _setupFirebaseHandlers();
  }

  /// Solicita permisos de notificaciones
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    print('🔔 Permisos de notificaciones: ${settings.authorizationStatus}');
  }

  /// Configura notificaciones locales
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Crear canal de notificaciones de alta prioridad (Android)
    const androidChannel = AndroidNotificationChannel(
      'weapon_alerts',
      'Alertas de Armas',
      description: 'Notificaciones críticas de detección de armas',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Obtiene el token FCM para notificaciones push
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('🔑 FCM Token: $_fcmToken');

      // Escuchar cambios en el token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM Token actualizado: $newToken');
      });
    } catch (e) {
      print('❌ Error obteniendo FCM token: $e');
    }
  }

  /// Configura handlers de Firebase Messaging
  void _setupFirebaseHandlers() {
    // Notificación recibida cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Notificación recibida en foreground');
      _handleMessage(message);
    });

    // Usuario toca la notificación (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notificación tocada (app en background)');
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🔔 App abierta desde notificación');
        _handleNotificationTap(message);
      }
    });
  }

  /// Maneja mensajes recibidos
  void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Mostrar notificación local
      _showLocalNotification(
        title: notification.title ?? '🚨 Alerta de Seguridad',
        body: notification.body ?? 'Se ha detectado un arma',
        payload: data['type'] ?? 'weapon_detection',
      );

      // Reproducir sonido de alerta
      if (data['type'] == 'weapon_detection') {
        _playAlertSound();
      }
    }
  }

  /// Muestra notificación local
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'weapon_alerts',
      'Alertas de Armas',
      channelDescription: 'Notificaciones críticas de detección de armas',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm.aiff',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Reproduce sonido de alerta
  Future<void> _playAlertSound() async {
    try {
      // Reproduce sonido de alarma
      // Asegúrate de tener el archivo en assets/sounds/alarm.mp3
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      print('❌ Error reproduciendo sonido: $e');
    }
  }

  /// Maneja toque en notificación
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    print('📱 Notificación tocada: $data');

    // Aquí puedes navegar a una pantalla específica
    // Por ejemplo, a la pantalla de detecciones recientes
  }

  /// Callback cuando se toca una notificación local
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notificación local tocada: ${response.payload}');
  }

  /// Envía notificación local de prueba
  Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: '🚨 Alerta de Prueba',
      body: 'Esta es una notificación de prueba',
      payload: 'test',
    );
  }

  /// Cancela todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
