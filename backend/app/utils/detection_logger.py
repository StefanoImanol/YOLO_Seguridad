"""
Logger de Detecciones - Weapon Detection
Registra todas las detecciones en base de datos/archivos
"""

import json
import os
from datetime import datetime
from typing import List, Dict
import logging
from collections import defaultdict

logger = logging.getLogger(__name__)


class DetectionLogger:
    """
    Registra detecciones en JSON local
    En producción, usar base de datos (MongoDB, PostgreSQL)
    """

    def __init__(self, log_dir: str = "logs"):
        self.log_dir = log_dir
        self.log_file = os.path.join(log_dir, "detections.jsonl")
        self.stats_cache = defaultdict(int)

        # Crear directorio de logs si no existe
        os.makedirs(log_dir, exist_ok=True)

        logger.info(f"📝 Logger inicializado: {self.log_file}")

    def log_detection(
        self,
        class_name: str,
        confidence: float,
        timestamp: str,
        alert_sent: bool = False,
        metadata: Dict = None
    ):
        """
        Registra una detección

        Args:
            class_name: Tipo de arma detectada
            confidence: Nivel de confianza
            timestamp: Timestamp ISO
            alert_sent: Si se envió alerta
            metadata: Información adicional (ubicación, cámara, etc.)
        """
        try:
            detection_entry = {
                "timestamp": timestamp,
                "class": class_name,
                "confidence": confidence,
                "alert_sent": alert_sent,
                "metadata": metadata or {}
            }

            # Escribir en archivo JSONL (JSON Lines)
            with open(self.log_file, "a") as f:
                f.write(json.dumps(detection_entry) + "\n")

            # Actualizar cache de estadísticas
            self.stats_cache[class_name] += 1
            self.stats_cache["total_detections"] += 1
            if alert_sent:
                self.stats_cache["total_alerts_sent"] += 1

            logger.info(f"✅ Detección registrada: {class_name} ({confidence:.2f})")

        except Exception as e:
            logger.error(f"❌ Error registrando detección: {e}")

    def get_stats(self) -> Dict:
        """
        Obtiene estadísticas de detecciones

        Returns:
            Diccionario con estadísticas
        """
        try:
            # Leer todas las detecciones
            detections = self._read_all_detections()

            # Calcular estadísticas
            total = len(detections)
            by_class = defaultdict(int)
            alerts_sent = 0
            avg_confidence = 0

            for det in detections:
                by_class[det["class"]] += 1
                if det.get("alert_sent"):
                    alerts_sent += 1
                avg_confidence += det["confidence"]

            if total > 0:
                avg_confidence /= total

            # Últimas 10 detecciones
            recent_detections = detections[-10:] if len(detections) > 10 else detections

            return {
                "total_detections": total,
                "alerts_sent": alerts_sent,
                "average_confidence": round(avg_confidence, 3),
                "detections_by_class": dict(by_class),
                "recent_detections": recent_detections
            }

        except Exception as e:
            logger.error(f"❌ Error obteniendo estadísticas: {e}")
            return {
                "total_detections": 0,
                "alerts_sent": 0,
                "average_confidence": 0,
                "detections_by_class": {},
                "recent_detections": []
            }

    def _read_all_detections(self) -> List[Dict]:
        """Lee todas las detecciones del archivo"""
        detections = []

        if not os.path.exists(self.log_file):
            return detections

        try:
            with open(self.log_file, "r") as f:
                for line in f:
                    if line.strip():
                        detections.append(json.loads(line))
        except Exception as e:
            logger.error(f"❌ Error leyendo detecciones: {e}")

        return detections

    def get_detections_by_date(self, date: str) -> List[Dict]:
        """
        Obtiene detecciones de una fecha específica

        Args:
            date: Fecha en formato YYYY-MM-DD

        Returns:
            Lista de detecciones
        """
        all_detections = self._read_all_detections()
        return [
            det for det in all_detections
            if det["timestamp"].startswith(date)
        ]

    def clear_logs(self):
        """Limpia todos los logs (usar con precaución)"""
        try:
            if os.path.exists(self.log_file):
                os.remove(self.log_file)
            self.stats_cache.clear()
            logger.info("🗑️ Logs eliminados")
        except Exception as e:
            logger.error(f"❌ Error eliminando logs: {e}")
