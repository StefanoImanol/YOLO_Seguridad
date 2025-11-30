import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/detection_result.dart';
import '../utils/app_config.dart';

/// Servicio de detección que se comunica con el backend
class DetectionService extends ChangeNotifier {
  // Estado de conexión
  bool _isConnected = false;
  bool _isProcessing = false;

  // WebSocket para streaming
  WebSocketChannel? _channel;

  // Última detección
  DetectionResult? _lastDetection;

  // Estadísticas
  int _totalFramesProcessed = 0;
  int _totalDetections = 0;

  // Getters
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  DetectionResult? get lastDetection => _lastDetection;
  int get totalFramesProcessed => _totalFramesProcessed;
  int get totalDetections => _totalDetections;

  /// Inicializa conexión WebSocket para streaming en tiempo real
  Future<void> connectWebSocket() async {
    try {
      final wsUrl = AppConfig.wsUrl;
      print('🔌 Conectando a WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      // Escuchar respuestas del servidor
      _channel!.stream.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('❌ Error WebSocket: $error');
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          print('🔌 WebSocket desconectado');
          _isConnected = false;
          notifyListeners();
        },
      );

      notifyListeners();
      print('✅ WebSocket conectado');
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Desconecta WebSocket
  void disconnectWebSocket() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  /// Envía frame para detección vía WebSocket (más rápido)
  Future<void> sendFrameViaWebSocket(CameraImage image) async {
    if (!_isConnected || _channel == null) {
      return;
    }

    if (_isProcessing) return; // Evitar sobrecarga

    try {
      _isProcessing = true;

      // Convertir CameraImage a JPEG base64
      final jpegBase64 = await _convertCameraImageToJpegBase64(image);

      // Enviar al servidor
      final payload = jsonEncode({
        'frame': jpegBase64,
        'alert_config': {
          'fcm_token': AppConfig.fcmToken,
          'enable_push': AppConfig.enablePushNotifications,
          'enable_sms': AppConfig.enableSMS,
          'phone_number': AppConfig.phoneNumber,
        }
      });

      _channel!.sink.add(payload);
      _totalFramesProcessed++;

      _isProcessing = false;
    } catch (e) {
      print('❌ Error enviando frame: $e');
      _isProcessing = false;
    }
  }

  /// Maneja mensajes recibidos del WebSocket
  void _handleWebSocketMessage(dynamic data) {
    try {
      final json = jsonDecode(data);
      final result = DetectionResult.fromJson(json);

      _lastDetection = result;

      if (result.detected) {
        _totalDetections++;
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error procesando respuesta: $e');
    }
  }

  /// Detecta armas en una imagen única vía HTTP
  Future<DetectionResult?> detectInImage(Uint8List imageBytes) async {
    try {
      final url = Uri.parse('${AppConfig.apiUrl}/detect/image');

      var request = http.MultipartRequest('POST', url);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'image.jpg',
        ),
      );

      // Agregar configuración de alertas
      request.fields['alert_config'] = jsonEncode({
        'fcm_token': AppConfig.fcmToken,
        'enable_push': AppConfig.enablePushNotifications,
        'enable_sms': AppConfig.enableSMS,
        'phone_number': AppConfig.phoneNumber,
      });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody);
        final result = DetectionResult.fromJson(json);

        _lastDetection = result;
        if (result.detected) {
          _totalDetections++;
        }

        notifyListeners();
        return result;
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error en detección: $e');
      return null;
    }
  }

  /// Convierte CameraImage a JPEG base64
  Future<String> _convertCameraImageToJpegBase64(CameraImage image) async {
    try {
      // Convertir CameraImage (YUV420) a RGB
      final int width = image.width;
      final int height = image.height;

      // Crear imagen RGB
      final imgLib = img.Image(width: width, height: height);

      // Conversión YUV420 a RGB (formato común en Android)
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          // YUV a RGB
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

          imgLib.setPixelRgb(x, y, r, g, b);
        }
      }

      // Redimensionar para optimizar (640x640 es ideal para YOLO)
      final resized = img.copyResize(imgLib, width: 640, height: 640);

      // Convertir a JPEG
      final jpeg = img.encodeJpg(resized, quality: 85);

      // Convertir a base64
      return base64Encode(jpeg);
    } catch (e) {
      print('❌ Error convirtiendo imagen: $e');
      rethrow;
    }
  }

  /// Resetea estadísticas
  void resetStats() {
    _totalFramesProcessed = 0;
    _totalDetections = 0;
    _lastDetection = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}
