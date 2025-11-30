"""
Sistema de Detección de Armas - Backend API
Procesa video en tiempo real y envía alertas automáticas
"""

from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import cv2
import numpy as np
from ultralytics import YOLO
import base64
import asyncio
from datetime import datetime
from typing import List, Dict
import logging
from pydantic import BaseModel
import os

from .utils.alert_manager import AlertManager
from .utils.detection_logger import DetectionLogger

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inicializar FastAPI
app = FastAPI(
    title="Weapon Detection API",
    description="API de detección de armas en tiempo real usando YOLOv11",
    version="1.0.0"
)

# CORS para permitir conexiones desde la app móvil
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especifica el dominio de tu app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Variables globales
MODEL_PATH = os.getenv("MODEL_PATH", "../runs/detect/train/weights/best.pt")
CONFIDENCE_THRESHOLD = float(os.getenv("CONFIDENCE_THRESHOLD", "0.4"))

try:
    model = YOLO(MODEL_PATH)
    logger.info(f"✅ Modelo cargado exitosamente desde {MODEL_PATH}")
except Exception as e:
    logger.error(f"❌ Error al cargar el modelo: {e}")
    model = None

# Managers
alert_manager = AlertManager()
detection_logger = DetectionLogger()

# Conexiones WebSocket activas
active_connections: List[WebSocket] = []


# ============================================
# MODELOS DE DATOS
# ============================================

class DetectionResponse(BaseModel):
    """Respuesta de detección"""
    detected: bool
    confidence: float
    class_name: str
    timestamp: str
    bounding_boxes: List[Dict]
    alert_sent: bool


class AlertConfig(BaseModel):
    """Configuración de alertas"""
    phone_number: str = None
    fcm_token: str = None
    email: str = None
    enable_sms: bool = False
    enable_push: bool = True
    enable_email: bool = False


# ============================================
# ENDPOINTS PRINCIPALES
# ============================================

@app.get("/")
async def root():
    """Health check"""
    return {
        "status": "online",
        "service": "Weapon Detection API",
        "model_loaded": model is not None,
        "version": "1.0.0"
    }


@app.post("/detect/image", response_model=DetectionResponse)
async def detect_weapon_in_image(
    file: UploadFile = File(...),
    alert_config: AlertConfig = None
):
    """
    Detecta armas en una imagen única

    Args:
        file: Imagen a analizar
        alert_config: Configuración de alertas (opcional)

    Returns:
        DetectionResponse con resultados de detección
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Modelo no disponible")

    try:
        # Leer imagen
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # Ejecutar detección
        results = model(img, conf=CONFIDENCE_THRESHOLD)

        # Procesar resultados
        detected = False
        bounding_boxes = []
        max_confidence = 0.0
        detected_class = "none"

        for result in results:
            boxes = result.boxes
            for box in boxes:
                conf = float(box.conf[0])
                cls = int(box.cls[0])
                class_name = model.names[cls]

                # Extraer coordenadas
                x1, y1, x2, y2 = box.xyxy[0].tolist()

                bounding_boxes.append({
                    "class": class_name,
                    "confidence": conf,
                    "bbox": {
                        "x1": x1,
                        "y1": y1,
                        "x2": x2,
                        "y2": y2
                    }
                })

                if conf > max_confidence:
                    max_confidence = conf
                    detected_class = class_name

                detected = True

        # Timestamp
        timestamp = datetime.now().isoformat()

        # Enviar alerta si se detectó un arma
        alert_sent = False
        if detected and alert_config:
            alert_sent = await alert_manager.send_alert(
                detection_type=detected_class,
                confidence=max_confidence,
                timestamp=timestamp,
                config=alert_config
            )

        # Registrar detección
        if detected:
            detection_logger.log_detection(
                class_name=detected_class,
                confidence=max_confidence,
                timestamp=timestamp,
                alert_sent=alert_sent
            )

        return DetectionResponse(
            detected=detected,
            confidence=max_confidence,
            class_name=detected_class,
            timestamp=timestamp,
            bounding_boxes=bounding_boxes,
            alert_sent=alert_sent
        )

    except Exception as e:
        logger.error(f"Error en detección: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/detect/frame")
async def detect_weapon_in_frame(
    frame_data: dict,
    alert_config: AlertConfig = None
):
    """
    Detecta armas en un frame de video (base64)
    Optimizado para streaming desde móvil

    Args:
        frame_data: {"frame": "base64_encoded_image"}
        alert_config: Configuración de alertas

    Returns:
        Resultado de detección
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Modelo no disponible")

    try:
        # Decodificar frame base64
        frame_base64 = frame_data.get("frame")
        if not frame_base64:
            raise HTTPException(status_code=400, detail="Frame no proporcionado")

        # Convertir base64 a imagen
        img_bytes = base64.b64decode(frame_base64)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # Redimensionar para optimizar velocidad (opcional)
        img = cv2.resize(img, (640, 640))

        # Ejecutar detección
        results = model(img, conf=CONFIDENCE_THRESHOLD, verbose=False)

        # Procesar resultados
        detected = False
        detections = []
        max_conf = 0.0

        for result in results:
            boxes = result.boxes
            for box in boxes:
                conf = float(box.conf[0])
                cls = int(box.cls[0])
                class_name = model.names[cls]
                x1, y1, x2, y2 = box.xyxy[0].tolist()

                detections.append({
                    "class": class_name,
                    "confidence": round(conf, 3),
                    "bbox": [int(x1), int(y1), int(x2), int(y2)]
                })

                if conf > max_conf:
                    max_conf = conf

                detected = True

        # Enviar alerta si es necesario
        alert_sent = False
        if detected and alert_config:
            timestamp = datetime.now().isoformat()
            alert_sent = await alert_manager.send_alert(
                detection_type=detections[0]["class"],
                confidence=max_conf,
                timestamp=timestamp,
                config=alert_config
            )

        return {
            "detected": detected,
            "detections": detections,
            "frame_processed": True,
            "alert_sent": alert_sent
        }

    except Exception as e:
        logger.error(f"Error procesando frame: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# WEBSOCKET PARA STREAMING EN TIEMPO REAL
# ============================================

@app.websocket("/ws/stream")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket para streaming de video en tiempo real
    Más eficiente que HTTP para video continuo
    """
    await websocket.accept()
    active_connections.append(websocket)

    logger.info("🔌 Nueva conexión WebSocket establecida")

    try:
        while True:
            # Recibir frame
            data = await websocket.receive_json()

            frame_base64 = data.get("frame")
            alert_config_data = data.get("alert_config", {})

            if not frame_base64:
                continue

            # Decodificar y procesar
            img_bytes = base64.b64decode(frame_base64)
            nparr = np.frombuffer(img_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            # Detección
            results = model(img, conf=CONFIDENCE_THRESHOLD, verbose=False)

            detected = False
            detections = []

            for result in results:
                boxes = result.boxes
                for box in boxes:
                    conf = float(box.conf[0])
                    cls = int(box.cls[0])
                    class_name = model.names[cls]
                    x1, y1, x2, y2 = box.xyxy[0].tolist()

                    detections.append({
                        "class": class_name,
                        "confidence": round(conf, 3),
                        "bbox": [int(x1), int(y1), int(x2), int(y2)]
                    })
                    detected = True

            # Enviar respuesta
            await websocket.send_json({
                "detected": detected,
                "detections": detections,
                "timestamp": datetime.now().isoformat()
            })

            # Enviar alerta si se detectó arma
            if detected and alert_config_data:
                config = AlertConfig(**alert_config_data)
                await alert_manager.send_alert(
                    detection_type=detections[0]["class"],
                    confidence=detections[0]["confidence"],
                    timestamp=datetime.now().isoformat(),
                    config=config
                )

    except WebSocketDisconnect:
        active_connections.remove(websocket)
        logger.info("🔌 Conexión WebSocket cerrada")
    except Exception as e:
        logger.error(f"Error en WebSocket: {e}")
        active_connections.remove(websocket)


# ============================================
# ENDPOINTS DE CONFIGURACIÓN
# ============================================

@app.post("/config/alert")
async def configure_alerts(config: AlertConfig):
    """Configura las alertas del sistema"""
    # Guardar configuración (podrías usar Redis o base de datos)
    return {"status": "success", "message": "Configuración de alertas actualizada"}


@app.get("/stats/detections")
async def get_detection_stats():
    """Obtiene estadísticas de detecciones"""
    stats = detection_logger.get_stats()
    return stats


# ============================================
# STARTUP Y SHUTDOWN
# ============================================

@app.on_event("startup")
async def startup_event():
    """Inicialización al arrancar el servidor"""
    logger.info("🚀 Iniciando servidor de detección de armas...")
    logger.info(f"📊 Modelo: {MODEL_PATH}")
    logger.info(f"🎯 Confianza mínima: {CONFIDENCE_THRESHOLD}")


@app.on_event("shutdown")
async def shutdown_event():
    """Limpieza al cerrar el servidor"""
    logger.info("🛑 Cerrando servidor...")
    # Cerrar conexiones activas
    for connection in active_connections:
        await connection.close()
