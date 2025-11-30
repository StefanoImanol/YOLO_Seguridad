import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/detection_service.dart';
import '../services/notification_service.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/stats_panel.dart';
import '../utils/app_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreaming = false;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await AppConfig.loadConfig();

    // Obtener FCM token
    final notificationService = context.read<NotificationService>();
    AppConfig.fcmToken = notificationService.fcmToken;
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No se encontraron cámaras');
        return;
      }

      // Usar cámara trasera por defecto
      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Error inicializando cámara: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _startStreaming() async {
    if (!_isInitialized || _cameraController == null) {
      _showError('Cámara no inicializada');
      return;
    }

    final detectionService = context.read<DetectionService>();

    // Conectar WebSocket
    await detectionService.connectWebSocket();

    if (!detectionService.isConnected) {
      _showError('No se pudo conectar al servidor');
      return;
    }

    setState(() {
      _isStreaming = true;
    });

    // Iniciar stream de imágenes
    await _cameraController!.startImageStream((CameraImage image) {
      _frameCount++;

      // Procesar solo 1 de cada N frames (optimización)
      if (_frameCount % AppConfig.frameSkip == 0) {
        detectionService.sendFrameViaWebSocket(image);
      }
    });

    _showSuccess('Detección iniciada');
  }

  Future<void> _stopStreaming() async {
    if (_cameraController == null) return;

    try {
      await _cameraController!.stopImageStream();

      final detectionService = context.read<DetectionService>();
      detectionService.disconnectWebSocket();

      setState(() {
        _isStreaming = false;
        _frameCount = 0;
      });

      _showSuccess('Detección detenida');
    } catch (e) {
      print('Error deteniendo stream: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      _showError('Solo hay una cámara disponible');
      return;
    }

    if (_isStreaming) {
      await _stopStreaming();
    }

    final currentLens = _cameraController!.description.lensDirection;
    final newCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection != currentLens,
      orElse: () => _cameras!.first,
    );

    await _cameraController!.dispose();

    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔫 Weapon Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Vista de cámara
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // Preview de cámara
                      Center(
                        child: AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),

                      // Overlay de detección
                      Consumer<DetectionService>(
                        builder: (context, service, child) {
                          return DetectionOverlay(
                            detectionResult: service.lastDetection,
                            cameraSize: Size(
                              _cameraController!.value.previewSize!.height,
                              _cameraController!.value.previewSize!.width,
                            ),
                          );
                        },
                      ),

                      // Indicador de streaming
                      if (_isStreaming)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'EN VIVO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Panel de estadísticas
                const Expanded(
                  flex: 1,
                  child: StatsPanel(),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Cambiar cámara
          FloatingActionButton(
            heroTag: 'switch_camera',
            onPressed: _switchCamera,
            child: const Icon(Icons.flip_camera_android),
          ),
          const SizedBox(height: 16),

          // Iniciar/Detener detección
          FloatingActionButton.extended(
            heroTag: 'toggle_detection',
            onPressed: _isStreaming ? _stopStreaming : _startStreaming,
            backgroundColor: _isStreaming ? Colors.red : Colors.green,
            icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
            label: Text(_isStreaming ? 'DETENER' : 'INICIAR'),
          ),
        ],
      ),
    );
  }
}
