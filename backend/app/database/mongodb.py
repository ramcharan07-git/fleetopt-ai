import logging
import time
from typing import Dict, Any, List, Optional
from datetime import datetime
from pymongo import MongoClient, ASCENDING, DESCENDING, GEOSPHERE
from app.core.config import settings

logger = logging.getLogger("fleetopt.mongodb")

COLLECTIONS = [
    "vehicle_locations",
    "gps_history",
    "navigation_sessions",
    "traffic_events",
    "route_deviations",
    "location_alerts",
    "telemetry_events"
]

class InMemoryMongoCollection:
    """Mock fallback collection for offline environments and testing."""
    def __init__(self, name: str):
        self.name = name
        self._docs: List[Dict[str, Any]] = []

    def insert_one(self, doc: Dict[str, Any]):
        doc_copy = dict(doc)
        if "_id" not in doc_copy:
            doc_copy["_id"] = str(len(self._docs) + 1)
        self._docs.append(doc_copy)
        return type("InsertResult", (), {"inserted_id": doc_copy["_id"]})()

    def find_one(self, filter_query: Optional[Dict[str, Any]] = None, sort: Optional[List] = None):
        res = self.find(filter_query, sort=sort, limit=1)
        return res[0] if res else None

    def find(self, filter_query: Optional[Dict[str, Any]] = None, sort: Optional[List] = None, limit: int = 100):
        docs = self._docs
        if filter_query:
            docs = [d for d in docs if all(d.get(k) == v for k, v in filter_query.items() if not k.startswith("$"))]
        if sort:
            key, direction = sort[0]
            docs = sorted(docs, key=lambda d: d.get(key, 0), reverse=(direction == -1 or direction == DESCENDING))
        return docs[:limit]

    def update_one(self, filter_query: Dict[str, Any], update: Dict[str, Any], upsert: bool = False):
        set_vals = update.get("$set", {})
        for d in self._docs:
            if all(d.get(k) == v for k, v in filter_query.items()):
                d.update(set_vals)
                return type("UpdateResult", (), {"matched_count": 1, "modified_count": 1})()
        if upsert:
            new_doc = {**filter_query, **set_vals}
            self.insert_one(new_doc)
            return type("UpdateResult", (), {"matched_count": 0, "upserted_id": new_doc.get("_id")})()
        return type("UpdateResult", (), {"matched_count": 0, "modified_count": 0})()

    def count_documents(self, filter_query: Optional[Dict[str, Any]] = None) -> int:
        if not filter_query:
            return len(self._docs)
        return len(self.find(filter_query))

    def create_index(self, *args, **kwargs):
        pass


class MongoDBManager:
    """Manages MongoDB Atlas connection, collections, GeoJSON indexes, and fallback."""
    def __init__(self):
        self.client: Optional[MongoClient] = None
        self.db = None
        self.is_connected = False
        self._in_memory_db: Dict[str, InMemoryMongoCollection] = {
            c: InMemoryMongoCollection(c) for c in COLLECTIONS
        }
        self._init_connection()

    def _init_connection(self):
        uri = settings.MONGODB_URI
        if uri:
            try:
                self.client = MongoClient(
                    uri,
                    serverSelectionTimeoutMS=2500,
                    connectTimeoutMS=3000,
                    retryWrites=True
                )
                # Test connectivity
                self.client.admin.command('ping')
                self.db = self.client[settings.MONGODB_DATABASE]
                self.is_connected = True
                self._ensure_indexes()
                logger.info("[MongoDB] Connected successfully to MongoDB Atlas.")
            except Exception as e:
                logger.warning(f"[MongoDB] Atlas connection unreached: {e}. Active fallback mode enabled.")
                self.is_connected = False
                self.db = None
        else:
            logger.info("[MongoDB] No MONGODB_URI configured. In-memory telemetry mode active.")
            self.is_connected = False

    def _ensure_indexes(self):
        if not self.is_connected or self.db is None:
            return
        try:
            # 1. 2dsphere index on vehicle_locations GeoJSON coordinates
            self.db.vehicle_locations.create_index([("location", GEOSPHERE)])
            self.db.vehicle_locations.create_index([("vehicle_id", ASCENDING)], unique=True)
            self.db.vehicle_locations.create_index([("timestamp", DESCENDING)])

            # 2. 2dsphere index on gps_history GeoJSON coordinates + compound indexes
            self.db.gps_history.create_index([("location", GEOSPHERE)])
            self.db.gps_history.create_index([("vehicle_id", ASCENDING), ("timestamp", DESCENDING)])
            self.db.gps_history.create_index([("trip_id", ASCENDING), ("timestamp", DESCENDING)])

            # 3. navigation_sessions indexes
            self.db.navigation_sessions.create_index([("session_id", ASCENDING)], unique=True)
            self.db.navigation_sessions.create_index([("vehicle_id", ASCENDING), ("status", ASCENDING)])

            logger.info("[MongoDB] GeoJSON 2dsphere & compound indexes verified.")
        except Exception as e:
            logger.error(f"[MongoDB] Index creation error: {e}")

    def get_collection(self, name: str):
        if self.is_connected and self.db is not None:
            return self.db[name]
        return self._in_memory_db.get(name, InMemoryMongoCollection(name))

    def health_check(self) -> Dict[str, Any]:
        start = time.perf_counter()
        if not settings.MONGODB_URI:
            return {
                "status": "not_configured",
                "connected": False,
                "latency_ms": 0.0,
                "mode": "in_memory_fallback",
                "collections": COLLECTIONS,
                "note": "MONGODB_URI environment variable is empty. Telemetry operating in local memory."
            }

        if self.is_connected and self.client:
            try:
                self.client.admin.command('ping')
                latency = round((time.perf_counter() - start) * 1000, 2)
                return {
                    "status": "healthy",
                    "connected": True,
                    "latency_ms": latency,
                    "database": settings.MONGODB_DATABASE,
                    "mode": "mongodb_atlas",
                    "collections": COLLECTIONS
                }
            except Exception as e:
                latency = round((time.perf_counter() - start) * 1000, 2)
                return {
                    "status": "unhealthy",
                    "connected": False,
                    "latency_ms": latency,
                    "error": str(e),
                    "mode": "in_memory_fallback"
                }
        return {
            "status": "disconnected",
            "connected": False,
            "latency_ms": round((time.perf_counter() - start) * 1000, 2),
            "mode": "in_memory_fallback"
        }

# Global MongoDB instance
mongo_manager = MongoDBManager()

def get_mongo_db():
    """Returns active Mongo database or fallback dictionary collection manager."""
    return mongo_manager
