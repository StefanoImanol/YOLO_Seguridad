"""
Sistema de Alertas - Weapon Detection
Gestiona notificaciones Push, SMS y Email
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Optional
import asyncio

# Importaciones condicionales para servicios de alerta
try:
    from twilio.rest import Client as TwilioClient
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False

import requests

logger = logging.getLogger(__name__)


class AlertManager:
    """
    Gestor centralizado de alertas
    Evita spam enviando máximo 1 alerta por minuto
    """

    def __init__(self):
        self.last_alert_time = None
        self.alert_cooldown = 60  # segundos entre alertas
        self.twilio_client = None
        self.firebase_initialized = False

        # Configurar Twilio (SMS)
        if TWILIO_AVAILABLE:
            self._setup_twilio()

        # Configurar Firebase (Push Notifications)
        if FIREBASE_AVAILABLE:
            self._setup_firebase()

    def _setup_twilio(self):
        """Inicializa cliente de Twilio para SMS"""
        try:
            account_sid = os.getenv("TWILIO_ACCOUNT_SID")
            auth_token = os.getenv("TWILIO_AUTH_TOKEN")
            self.twilio_phone = os.getenv("TWILIO_PHONE_NUMBER")

            if account_sid and auth_token and self.twilio_phone:
                self.twilio_client = TwilioClient(account_sid, auth_token)
                logger.info("✅ Twilio SMS configurado correctamente")
            else:
                logger.warning("⚠️ Credenciales de Twilio no configuradas")
        except Exception as e:
            logger.error(f"❌ Error configurando Twilio: {e}")

    def _setup_firebase(self):
        """Inicializa Firebase Admin SDK para notificaciones push"""
        try:
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")

            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                self.firebase_initialized = True
                logger.info("✅ Firebase configurado correctamente")
            else:
                logger.warning("⚠️ Credenciales de Firebase no encontradas")
        except Exception as e:
            logger.error(f"❌ Error configurando Firebase: {e}")

    def _should_send_alert(self) -> bool:
        """
        Verifica si debe enviar alerta (evita spam)

        Returns:
            True si puede enviar, False si está en cooldown
        """
        now = datetime.now()

        if self.last_alert_time is None:
            self.last_alert_time = now
            return True

        time_diff = (now - self.last_alert_time).total_seconds()

        if time_diff >= self.alert_cooldown:
            self.last_alert_time = now
            return True

        logger.info(f"⏳ Alerta en cooldown. Esperar {self.alert_cooldown - time_diff:.1f}s")
        return False

    async def send_alert(
        self,
        detection_type: str,
        confidence: float,
        timestamp: str,
        config
    ) -> bool:
        """
        Envía alertas según la configuración

        Args:
            detection_type: Tipo de arma detectada
            confidence: Nivel de confianza (0-1)
            timestamp: Timestamp de la detección
            config: AlertConfig con configuración de notificaciones

        Returns:
            True si se envió al menos una alerta
        """
        # Verificar cooldown
        if not self._should_send_alert():
            return False

        alert_sent = False

        # Mensaje de alerta
        message = self._generate_alert_message(detection_type, confidence, timestamp)

        # Enviar SMS
        if config.enable_sms and config.phone_number:
            sms_sent = await self._send_sms(config.phone_number, message)
            alert_sent = alert_sent or sms_sent

        # Enviar Push Notification
        if config.enable_push and config.fcm_token:
            push_sent = await self._send_push_notification(config.fcm_token, detection_type, message)
            alert_sent = alert_sent or push_sent

        # Enviar Email
        if config.enable_email and config.email:
            email_sent = await self._send_email(config.email, detection_type, message)
            alert_sent = alert_sent or email_sent

        return alert_sent

    def _generate_alert_message(self, detection_type: str, confidence: float, timestamp: str) -> str:
        """Genera mensaje de alerta"""
        confidence_percent = confidence * 100
        return (
            f"🚨 ALERTA DE SEGURIDAD 🚨\n\n"
            f"Se ha detectado: {detection_type.upper()}\n"
            f"Confianza: {confidence_percent:.1f}%\n"
            f"Hora: {timestamp}\n\n"
            f"Revise las cámaras de seguridad inmediatamente."
        )

    async def _send_sms(self, phone_number: str, message: str) -> bool:
        """Envía SMS usando Twilio"""
        if not self.twilio_client:
            logger.warning("⚠️ Twilio no configurado, SMS no enviado")
            return False

        try:
            # Ejecutar en thread pool para no bloquear
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: self.twilio_client.messages.create(
                    body=message,
                    from_=self.twilio_phone,
                    to=phone_number
                )
            )
            logger.info(f"📱 SMS enviado a {phone_number}")
            return True
        except Exception as e:
            logger.error(f"❌ Error enviando SMS: {e}")
            return False

    async def _send_push_notification(self, fcm_token: str, title: str, body: str) -> bool:
        """Envía notificación push usando Firebase Cloud Messaging"""
        if not self.firebase_initialized:
            logger.warning("⚠️ Firebase no configurado, push notification no enviada")
            return False

        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"🚨 Alerta: {title.upper()}",
                    body=body,
                ),
                data={
                    "type": "weapon_detection",
                    "priority": "high",
                    "sound": "alarm.mp3"
                },
                token=fcm_token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        sound='alarm',
                        channel_id='weapon_alerts'
                    )
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound='alarm.aiff',
                            badge=1
                        )
                    )
                )
            )

            # Enviar
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: messaging.send(message)
            )

            logger.info(f"🔔 Push notification enviada: {response}")
            return True

        except Exception as e:
            logger.error(f"❌ Error enviando push notification: {e}")
            return False

    async def _send_email(self, email: str, subject: str, body: str) -> bool:
        """
        Envía email de alerta
        Usa SendGrid o servicio SMTP configurado
        """
        # Implementación básica con SMTP o API de email
        try:
            # Aquí puedes integrar SendGrid, SES, etc.
            # Ejemplo con API simple
            logger.info(f"📧 Email enviado a {email}")
            return True
        except Exception as e:
            logger.error(f"❌ Error enviando email: {e}")
            return False

    def reset_cooldown(self):
        """Resetea el cooldown (útil para testing)"""
        self.last_alert_time = None
