import 'package:flutter/material.dart';
import '../models/detection_result.dart';

/// Overlay que dibuja bounding boxes sobre la cámara
class DetectionOverlay extends StatelessWidget {
  final DetectionResult? detectionResult;
  final Size cameraSize;

  const DetectionOverlay({
    super.key,
    required this.detectionResult,
    required this.cameraSize,
  });

  @override
  Widget build(BuildContext context) {
    if (detectionResult == null || !detectionResult!.detected) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _DetectionPainter(
        detections: detectionResult!.detections,
        cameraSize: cameraSize,
      ),
      child: Container(),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size cameraSize;

  _DetectionPainter({
    required this.detections,
    required this.cameraSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var detection in detections) {
      _drawBoundingBox(canvas, size, detection);
    }
  }

  void _drawBoundingBox(Canvas canvas, Size size, Detection detection) {
    final bbox = detection.bbox;

    // Escalar coordenadas del modelo (640x640) a la pantalla
    final scaleX = size.width / 640;
    final scaleY = size.height / 640;

    final rect = Rect.fromLTRB(
      bbox.x1 * scaleX,
      bbox.y1 * scaleY,
      bbox.x2 * scaleX,
      bbox.y2 * scaleY,
    );

    // Color según confianza
    final color = _getColorForConfidence(detection.confidence);

    // Dibujar rectángulo
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(rect, paint);

    // Dibujar fondo para el texto
    final textSpan = TextSpan(
      text: '${detection.className.toUpperCase()} ${(detection.confidence * 100).toInt()}%',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top - 24,
      textPainter.width + 8,
      20,
    );

    // Fondo del label
    final bgPaint = Paint()..color = color;
    canvas.drawRect(labelRect, bgPaint);

    // Texto
    textPainter.paint(
      canvas,
      Offset(rect.left + 4, rect.top - 22),
    );
  }

  Color _getColorForConfidence(double confidence) {
    if (confidence >= 0.8) {
      return Colors.red; // Alta confianza
    } else if (confidence >= 0.5) {
      return Colors.orange; // Media confianza
    } else {
      return Colors.yellow; // Baja confianza
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}
