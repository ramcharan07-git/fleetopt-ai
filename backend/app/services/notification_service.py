import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
import httpx
from app.core.config import settings

logger = logging.getLogger("fleetopt.notifications")

class NotificationService:
    """Firebase Cloud Messaging (FCM) & In-App notification manager."""
    def __init__(self):
        self.fcm_key = settings.FCM_SERVER_KEY
        self.creds_path = settings.FIREBASE_CREDENTIALS_PATH
        self._sent_notifications: List[Dict[str, Any]] = []

    def is_fcm_configured(self) -> bool:
        return bool(self.fcm_key and not self.fcm_key.startswith("mock-"))

    async def send_driver_notification(
        self,
        driver_id: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        token: Optional[str] = None
    ) -> Dict[str, Any]:
        """Sends an operational notification to an assigned driver."""
        payload = {
            "driver_id": driver_id,
            "title": title,
            "body": body,
            "data": data or {},
            "timestamp": datetime.utcnow().isoformat(),
            "channel": "fcm" if self.is_fcm_configured() and token else "in_app_broadcast"
        }

        if self.is_fcm_configured() and token:
            try:
                headers = {
                    "Authorization": f"key={self.fcm_key}",
                    "Content-Type": "application/json"
                }
                fcm_body = {
                    "to": token,
                    "notification": {"title": title, "body": body},
                    "data": data or {}
                }
                async with httpx.AsyncClient(timeout=4.0) as client:
                    resp = await client.post("https://fcm.googleapis.com/fcm/send", json=fcm_body, headers=headers)
                    payload["fcm_status_code"] = resp.status_code
            except Exception as e:
                logger.warning(f"[FCM] Delivery failed: {e}. Delivered via in-app channel.")

        self._sent_notifications.append(payload)
        logger.info(f"[Notification] Delivered to driver {driver_id}: {title} - {body}")
        return payload

    async def broadcast_disruption_alert(
        self,
        incident_type: str,
        description: str,
        vehicle_id: Optional[str] = None,
        severity: str = "high"
    ) -> Dict[str, Any]:
        """Broadcasts emergency disruption to active dispatchers and drivers."""
        payload = {
            "title": f"FLEET ALERT: {incident_type.upper().replace('_', ' ')}",
            "body": description,
            "severity": severity,
            "vehicle_id": vehicle_id,
            "timestamp": datetime.utcnow().isoformat(),
            "broadcast": True
        }
        self._sent_notifications.append(payload)
        logger.warning(f"[Disruption Broadcast] {payload['title']}: {description}")
        return payload

    def get_recent_notifications(self, limit: int = 20) -> List[Dict[str, Any]]:
        return list(reversed(self._sent_notifications[-limit:]))

notification_service = NotificationService()
