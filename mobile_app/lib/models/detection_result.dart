/// Modelo para resultados de detección
class DetectionResult {
  final bool detected;
  final List<Detection> detections;
  final String timestamp;
  final bool alertSent;

  DetectionResult({
    required this.detected,
    required this.detections,
    required this.timestamp,
    this.alertSent = false,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      detected: json['detected'] ?? false,
      detections: (json['detections'] as List?)
              ?.map((d) => Detection.fromJson(d))
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      alertSent: json['alert_sent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detected': detected,
      'detections': detections.map((d) => d.toJson()).toList(),
      'timestamp': timestamp,
      'alert_sent': alertSent,
    };
  }
}

/// Detección individual de un arma
class Detection {
  final String className;
  final double confidence;
  final BoundingBox bbox;

  Detection({
    required this.className,
    required this.confidence,
    required this.bbox,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      className: json['class'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      bbox: BoundingBox.fromJson(json['bbox']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class': className,
      'confidence': confidence,
      'bbox': bbox.toJson(),
    };
  }

  /// Obtiene el color según la confianza
  String getConfidenceLevel() {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }
}

/// Bounding box de la detección
class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(dynamic json) {
    if (json is List && json.length >= 4) {
      return BoundingBox(
        x1: (json[0] ?? 0.0).toDouble(),
        y1: (json[1] ?? 0.0).toDouble(),
        x2: (json[2] ?? 0.0).toDouble(),
        y2: (json[3] ?? 0.0).toDouble(),
      );
    } else if (json is Map) {
      return BoundingBox(
        x1: (json['x1'] ?? 0.0).toDouble(),
        y1: (json['y1'] ?? 0.0).toDouble(),
        x2: (json['x2'] ?? 0.0).toDouble(),
        y2: (json['y2'] ?? 0.0).toDouble(),
      );
    }
    return BoundingBox(x1: 0, y1: 0, x2: 0, y2: 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
    };
  }

  /// Ancho del bounding box
  double get width => x2 - x1;

  /// Alto del bounding box
  double get height => y2 - y1;
}
