# 🚀 Quick Start Guide

Guía de inicio rápido para tener el sistema funcionando en **15 minutos**.

---

## ✅ Pre-requisitos Mínimos

- ✔️ Python 3.8+ instalado
- ✔️ Flutter SDK (para móvil)
- ✔️ Modelo YOLOv11 entrenado (`runs/detect/train/weights/best.pt`)
- ✔️ Móvil y computadora en la misma red WiFi

---

## 🎯 Paso 1: Backend (5 minutos)

```bash
# 1. Ir a carpeta backend
cd backend

# 2. Crear entorno virtual
python -m venv venv

# 3. Activar entorno
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 4. Instalar dependencias básicas
pip install fastapi uvicorn ultralytics opencv-python-headless python-multipart

# 5. Copiar configuración
cp .env.example .env

# 6. Iniciar servidor SIN alertas (para testing rápido)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**✅ El servidor está corriendo en:** `http://TU_IP:8000`

Para saber tu IP:
```bash
# Linux/Mac
hostname -I | awk '{print $1}'

# Windows
ipconfig | findstr IPv4
```

---

## 📱 Paso 2: Aplicación Móvil (10 minutos)

### Opción A: Instalación Completa

```bash
# 1. Ir a carpeta móvil
cd mobile_app

# 2. Instalar dependencias
flutter pub get

# 3. Editar configuración
# Abrir lib/utils/app_config.dart
# Cambiar la línea 7:
static const String _defaultApiUrl = 'http://TU_IP_AQUI:8000';

# 4. Ejecutar app (conecta tu dispositivo)
flutter run
```

### Opción B: Sin Firebase (más rápido)

Si quieres probar **sin configurar Firebase**:

1. **Comentar imports de Firebase** en `lib/main.dart`:
```dart
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
```

2. **Comentar inicialización de Firebase**:
```dart
// await Firebase.initializeApp();
```

3. **Ejecutar**:
```bash
flutter run
```

---

## 🎬 Paso 3: Probar el Sistema (2 minutos)

1. **Abrir la app** en tu móvil
2. Permitir permisos de **cámara**
3. Click en **⚙️ Configuración**:
   - Verificar URL del servidor
   - Desactivar SMS (dejar solo Push)
   - Guardar
4. Volver y click en **INICIAR** (botón verde)
5. **Apuntar cámara** hacia una imagen de arma (puede ser en Google Images en otra pantalla)

**✅ Si ves un rectángulo rojo = ¡Funciona!**

---

## 🔍 Verificar que Funciona

### Test del Backend

```bash
# Abrir en navegador
http://TU_IP:8000/docs

# Debería mostrar la documentación de la API
```

### Test de la App

1. En la app, ir a **Configuración**
2. Click en **"Probar Notificación"**
3. Debería aparecer una notificación

---

## ❌ Si Algo Falla

### Error: "No se puede conectar al servidor"

```bash
# 1. Verificar que el backend está corriendo
# Deberías ver algo como: "Uvicorn running on http://0.0.0.0:8000"

# 2. Verificar tu IP
hostname -I  # Linux/Mac
ipconfig     # Windows

# 3. Probar conexión desde el móvil
# Abrir navegador en móvil y visitar: http://TU_IP:8000
# Si abre, la IP es correcta
```

### Error: "Modelo no encontrado"

```bash
# Verificar que existe
ls runs/detect/train/weights/best.pt

# Si no existe, entrenar primero:
jupyter notebook Prueba2.ipynb
# Ejecutar todas las celdas
```

### Error: "Camera permission denied"

- Ir a **Configuración del móvil** → Apps → Weapon Detection → Permisos
- Permitir **Cámara**

---

## 🔥 Modo Simplificado (Solo Backend API)

Si solo quieres probar el **backend** sin app móvil:

```bash
# 1. Iniciar backend
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 2. Probar con curl (imagen de prueba)
curl -X POST "http://localhost:8000/detect/image" \
  -F "file=@imagen_arma.jpg"

# Respuesta (ejemplo):
{
  "detected": true,
  "confidence": 0.87,
  "class_name": "pistol",
  "timestamp": "2025-11-30T10:30:00",
  "bounding_boxes": [...],
  "alert_sent": false
}
```

---

## 📚 Próximos Pasos

Una vez que funcione, configura:

1. **Firebase** (notificaciones push) → Ver [MOBILE_APP_GUIDE.md](MOBILE_APP_GUIDE.md#25-configurar-firebase-en-la-app)
2. **Twilio** (SMS) → Ver [MOBILE_APP_GUIDE.md](MOBILE_APP_GUIDE.md#14-configurar-twilio-sms)
3. **Optimización** → Ver [MOBILE_APP_GUIDE.md](MOBILE_APP_GUIDE.md#parte-6-optimizacion)

---

## 🎉 ¡Listo!

Tu sistema de detección de armas está funcionando.

Para guía completa: [MOBILE_APP_GUIDE.md](MOBILE_APP_GUIDE.md)

Para documentación del proyecto: [README.md](README.md)
