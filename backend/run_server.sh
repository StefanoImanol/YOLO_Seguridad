#!/bin/bash
# Script para iniciar el servidor de detección de armas

echo "🚀 Iniciando servidor de detección de armas..."

# Cargar variables de entorno
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ Variables de entorno cargadas"
else
    echo "⚠️ Archivo .env no encontrado. Copiando desde .env.example..."
    cp .env.example .env
    echo "⚠️ Por favor configura el archivo .env con tus credenciales"
fi

# Verificar que el modelo existe
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Modelo no encontrado en: $MODEL_PATH"
    echo "Por favor entrena el modelo primero o ajusta MODEL_PATH en .env"
    exit 1
fi

# Iniciar servidor con uvicorn
echo "🌐 Servidor iniciando en http://${HOST:-0.0.0.0}:${PORT:-8000}"

uvicorn app.main:app \
    --host ${HOST:-0.0.0.0} \
    --port ${PORT:-8000} \
    --reload \
    --log-level ${LOG_LEVEL:-info}
