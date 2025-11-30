# 📱 Guía Completa - Aplicación Móvil de Detección de Armas

## 🎯 Descripción del Sistema

Sistema completo de detección de armas en tiempo real usando **YOLOv11** con:
- **Backend**: FastAPI + Python (procesamiento con GPU)
- **Mobile**: Flutter (Android/iOS)
- **Alertas**: SMS (Twilio) + Push Notifications (Firebase)
- **Comunicación**: WebSocket para streaming en tiempo real

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐         WebSocket          ┌─────────────────┐
│                 │ ◄─────────────────────────► │                 │
│  App Móvil      │    Frames (base64)          │  Backend        │
│  (Flutter)      │    Detecciones (JSON)       │  (FastAPI)      │
│                 │                             │                 │
└─────────────────┘                             └─────────────────┘
        │                                               │
        │ Push Notifications                            │
        ▼                                               ▼
┌─────────────────┐                             ┌─────────────────┐
│   Firebase      │                             │  YOLOv11        │
│   FCM           │                             │  Modelo         │
└─────────────────┘                             └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │  Twilio SMS     │
                                                └─────────────────┘
```

---

## 📋 PARTE 1: CONFIGURACIÓN DEL BACKEND

### 1.1 Requisitos del Sistema

**Hardware:**
- GPU NVIDIA (recomendado para YOLOv11)
- RAM: 8GB mínimo
- Disco: 10GB libres

**Software:**
- Python 3.8+
- CUDA 11.8+ (para GPU)
- Git

### 1.2 Instalación del Backend

```bash
# 1. Navegar a la carpeta del backend
cd backend

# 2. Crear entorno virtual
python -m venv venv

# 3. Activar entorno virtual
# En Linux/Mac:
source venv/bin/activate
# En Windows:
venv\Scripts\activate

# 4. Instalar dependencias
pip install -r requirements.txt

# 5. Copiar archivo de configuración
cp .env.example .env

# 6. Editar .env con tus credenciales
nano .env
```

### 1.3 Configurar Variables de Entorno

Edita el archivo `.env`:

```bash
# Modelo YOLOv11
MODEL_PATH=../runs/detect/train/weights/best.pt
CONFIDENCE_THRESHOLD=0.4

# Servidor
HOST=0.0.0.0
PORT=8000

# Twilio (SMS) - Obtener en https://www.twilio.com/console
TWILIO_ACCOUNT_SID=tu_account_sid
TWILIO_AUTH_TOKEN=tu_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# Firebase (Push) - Descargar desde Firebase Console
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

### 1.4 Configurar Twilio (SMS)

1. Crear cuenta en [Twilio](https://www.twilio.com/try-twilio)
2. Obtener **Account SID** y **Auth Token** del dashboard
3. Comprar un número de teléfono de Twilio
4. Agregar credenciales al archivo `.env`

### 1.5 Configurar Firebase (Push Notifications)

1. Ir a [Firebase Console](https://console.firebase.google.com/)
2. Crear nuevo proyecto
3. Agregar apps Android/iOS
4. Descargar **Service Account Key**:
   - Settings → Service Accounts → Generate New Private Key
5. Guardar como `backend/firebase-credentials.json`

### 1.6 Iniciar el Servidor

```bash
# Dar permisos de ejecución (Linux/Mac)
chmod +x run_server.sh

# Iniciar servidor
./run_server.sh

# O manualmente:
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**El servidor estará disponible en:**
- API: `http://TU_IP:8000`
- Docs: `http://TU_IP:8000/docs`
- WebSocket: `ws://TU_IP:8000/ws/stream`

### 1.7 Obtener tu IP Local

```bash
# Linux/Mac
hostname -I

# Windows
ipconfig
```

Ejemplo: `192.168.1.100`

---

## 📱 PARTE 2: CONFIGURACIÓN DE LA APP MÓVIL

### 2.1 Requisitos

- Flutter SDK 3.0+
- Android Studio / Xcode
- Dispositivo físico o emulador

### 2.2 Instalación de Flutter

```bash
# Verificar instalación
flutter doctor

# Si no está instalado, descargar de:
# https://docs.flutter.dev/get-started/install
```

### 2.3 Configurar el Proyecto Flutter

```bash
# 1. Navegar a la carpeta móvil
cd mobile_app

# 2. Instalar dependencias
flutter pub get

# 3. Configurar Firebase para Flutter
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar Firebase (autenticarse con tu cuenta Google)
flutterfire configure
```

### 2.4 Configurar Firebase en la App

**Android** (`android/app/build.gradle`):
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Importante para Firebase
        targetSdkVersion 33
    }
}
```

**iOS** (`ios/Runner/Info.plist`):
Agregar permisos de notificaciones.

### 2.5 Agregar Archivos de Assets

Crear carpeta de sonidos:
```bash
mkdir -p assets/sounds
# Agregar archivo alarm.mp3 (puedes descargar uno de internet)
```

### 2.6 Permisos de Cámara

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<uses-feature android:name="android.hardware.camera" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Esta app necesita acceso a la cámara para detectar armas</string>
<key>NSMicrophoneUsageDescription</key>
<string>No se usa el micrófono</string>
```

### 2.7 Configurar IP del Servidor

Edita `lib/utils/app_config.dart`:

```dart
static const String _defaultApiUrl = 'http://192.168.1.100:8000';
```

**Reemplaza `192.168.1.100` con la IP de tu servidor.**

### 2.8 Compilar y Ejecutar

```bash
# Conectar dispositivo físico o iniciar emulador

# Verificar dispositivos conectados
flutter devices

# Ejecutar app
flutter run

# O compilar APK (Android)
flutter build apk --release

# O compilar IPA (iOS)
flutter build ios --release
```

---

## 🚀 PARTE 3: USO DE LA APLICACIÓN

### 3.1 Primera Ejecución

1. **Abrir la app**
2. Permitir permisos de cámara
3. Permitir notificaciones
4. Ir a **Configuración (⚙️)**

### 3.2 Configurar la Aplicación

En la pantalla de **Configuración**:

1. **URL del Backend**: Verificar que sea correcta
   - Debe ser la IP de tu servidor (ej: `http://192.168.1.100:8000`)

2. **Alertas**:
   - ✅ **Notificaciones Push**: Activar
   - 📱 **SMS**: Activar si deseas SMS
   - Si activas SMS, ingresa número de teléfono (formato internacional: `+52 123 456 7890`)

3. **Detección**:
   - **Umbral de Confianza**: 40-60% recomendado
   - **Frames a procesar**: 3-5 (mayor = más rápido, menos preciso)

4. **Probar Notificación**: Click en el botón para verificar

5. **Guardar Configuración** ✅

### 3.3 Iniciar Detección

1. Volver a la pantalla principal
2. Apuntar cámara hacia el área a monitorear
3. Click en **INICIAR** (botón verde)
4. Verás indicador "**EN VIVO**" en rojo

### 3.4 Interpretación de Resultados

**En pantalla verás:**

- **Bounding Boxes**: Rectángulos de colores sobre armas detectadas
  - 🔴 **Rojo**: Alta confianza (>80%)
  - 🟠 **Naranja**: Media confianza (50-80%)
  - 🟡 **Amarillo**: Baja confianza (<50%)

- **Panel Inferior**:
  - **Frames**: Cuántos frames se han procesado
  - **Detecciones**: Cantidad de armas detectadas
  - **Servidor**: Estado de conexión

**Cuando detecte un arma:**
- ⚠️ Rectángulo rojo con etiqueta
- 🔔 Notificación push automática
- 📱 SMS (si está configurado)
- 🔊 Sonido de alarma

---

## 📊 PARTE 4: ENDPOINTS DE LA API

### 4.1 Endpoints Disponibles

#### **GET** `/`
Health check del servidor.

```bash
curl http://TU_IP:8000/
```

#### **POST** `/detect/image`
Detecta armas en una imagen única.

```bash
curl -X POST "http://TU_IP:8000/detect/image" \
  -F "file=@imagen.jpg"
```

#### **POST** `/detect/frame`
Detecta armas en un frame de video (base64).

```json
{
  "frame": "base64_encoded_image",
  "alert_config": {
    "fcm_token": "token_firebase",
    "enable_push": true,
    "enable_sms": false,
    "phone_number": "+521234567890"
  }
}
```

#### **WebSocket** `/ws/stream`
Streaming en tiempo real.

```javascript
const ws = new WebSocket('ws://TU_IP:8000/ws/stream');

ws.send(JSON.stringify({
  frame: "base64_image",
  alert_config: { ... }
}));

ws.onmessage = (event) => {
  const result = JSON.parse(event.data);
  console.log(result.detected);
};
```

#### **GET** `/stats/detections`
Obtiene estadísticas de detecciones.

```bash
curl http://TU_IP:8000/stats/detections
```

### 4.2 Documentación Interactiva

Visita: `http://TU_IP:8000/docs` (Swagger UI)

---

## 🔧 PARTE 5: TROUBLESHOOTING

### Problema 1: "No se puede conectar al servidor"

**Soluciones:**
1. Verificar que el backend esté corriendo
2. Verificar que móvil y servidor estén en la misma red WiFi
3. Verificar IP en `app_config.dart`
4. Verificar firewall/antivirus del servidor
5. Ping al servidor: `ping 192.168.1.100`

### Problema 2: "Modelo no encontrado"

**Solución:**
```bash
# Verificar que existe el modelo entrenado
ls runs/detect/train/weights/best.pt

# Si no existe, entrenar primero ejecutando el notebook
```

### Problema 3: "WebSocket connection failed"

**Soluciones:**
1. Verificar URL del WebSocket en logs
2. Asegurar que no hay proxy bloqueando
3. Usar HTTP en lugar de HTTPS temporalmente

### Problema 4: "Notificaciones no llegan"

**Soluciones:**
1. Verificar permisos de notificaciones en el dispositivo
2. Verificar FCM token en Configuración
3. Verificar `firebase-credentials.json` en backend
4. Revisar logs del servidor

### Problema 5: "SMS no se envían"

**Soluciones:**
1. Verificar credenciales de Twilio en `.env`
2. Verificar saldo de Twilio
3. Verificar formato del número (+código país)
4. Revisar logs del backend

### Problema 6: "Cámara no funciona"

**Soluciones:**
1. Verificar permisos de cámara
2. Reiniciar app
3. Verificar que la cámara no esté siendo usada por otra app

---

## ⚡ PARTE 6: OPTIMIZACIÓN

### 6.1 Optimizar Velocidad de Detección

**En el móvil:**
- Aumentar `frameSkip` (procesar menos frames)
- Reducir resolución de cámara
- Reducir calidad JPEG a 70-80%

**En el backend:**
- Usar modelo más ligero: `yolo11n.pt` (nano)
- Reducir `imgsz` a 416 o 320
- Usar GPU si es posible

### 6.2 Optimizar Precisión

- Entrenar modelo con más epochs
- Usar modelo más grande: `yolo11m.pt` o `yolo11l.pt`
- Ajustar umbral de confianza
- Mejorar iluminación de la cámara

### 6.3 Reducir False Positives

- Aumentar `CONFIDENCE_THRESHOLD` a 0.6 o más
- Entrenar con más datos negativos
- Usar ensemble de modelos

---

## 📈 PARTE 7: PRODUCCIÓN

### 7.1 Deploy del Backend

**Opción 1: VPS (DigitalOcean, AWS, etc.)**
```bash
# Instalar dependencias del sistema
sudo apt update
sudo apt install python3-pip python3-venv nginx

# Configurar Nginx como reverse proxy
# Usar Gunicorn en lugar de uvicorn
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

**Opción 2: Docker**
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 7.2 Seguridad

1. **HTTPS**: Usar certificado SSL (Let's Encrypt)
2. **CORS**: Restringir orígenes permitidos
3. **API Key**: Agregar autenticación
4. **Rate Limiting**: Limitar requests por IP
5. **Logs**: Configurar logging a archivo
6. **Backup**: Backup automático de detecciones

### 7.3 Monitoreo

- Usar **Prometheus** + **Grafana** para métricas
- Logs centralizados con **ELK Stack**
- Alertas de disponibilidad

---

## 📝 PARTE 8: PRÓXIMOS PASOS

### Mejoras Sugeridas

1. **Base de Datos**:
   - PostgreSQL o MongoDB para detecciones
   - Redis para caché

2. **Dashboard Web**:
   - Visualización de detecciones en tiempo real
   - Estadísticas históricas
   - Gestión de cámaras

3. **Múltiples Cámaras**:
   - Soporte para IP cameras (RTSP)
   - Múltiples streams simultáneos

4. **Machine Learning**:
   - Re-entrenamiento automático
   - Detección de anomalías
   - Tracking de personas

5. **Integración con Sistemas**:
   - Alarmas físicas
   - Control de acceso
   - CCTV existente

---

## 🆘 SOPORTE

### Recursos

- **Documentación YOLOv11**: https://docs.ultralytics.com/
- **Flutter**: https://flutter.dev/docs
- **FastAPI**: https://fastapi.tiangolo.com/
- **Firebase**: https://firebase.google.com/docs
- **Twilio**: https://www.twilio.com/docs

### Contacto

Para preguntas o problemas, crear un Issue en el repositorio.

---

## 📄 LICENCIA

Este proyecto es de código abierto. Úsalo bajo tu propia responsabilidad.

---

**¡Listo! Tu sistema de detección de armas está operativo. 🚀**
