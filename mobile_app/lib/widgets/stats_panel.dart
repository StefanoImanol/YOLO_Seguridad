import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/detection_service.dart';

/// Panel de estadísticas en tiempo real
class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DetectionService>(
      builder: (context, service, child) {
        final lastDetection = service.lastDetection;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Estado de detección
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    icon: Icons.video_camera_front,
                    label: 'Frames',
                    value: service.totalFramesProcessed.toString(),
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    icon: Icons.warning,
                    label: 'Detecciones',
                    value: service.totalDetections.toString(),
                    color: Colors.red,
                  ),
                  _buildStatItem(
                    icon: service.isConnected ? Icons.wifi : Icons.wifi_off,
                    label: 'Servidor',
                    value: service.isConnected ? 'Conectado' : 'Desconectado',
                    color: service.isConnected ? Colors.green : Colors.grey,
                  ),
                ],
              ),

              const Divider(),

              // Última detección
              if (lastDetection != null && lastDetection.detected)
                _buildLastDetection(lastDetection, context)
              else
                const Text(
                  '✅ Sin detecciones',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLastDetection(detectionResult, BuildContext context) {
    final detection = detectionResult.detections.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚨 ${detection.className.toUpperCase()} DETECTADA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confianza: ${(detection.confidence * 100).toInt()}% - ${detection.getConfidenceLevel()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                if (detectionResult.alertSent)
                  const Text(
                    '✅ Alerta enviada',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
