# FleetOpt AI — External API & Database Setup Guide

This document specifies all external credentials, database connections, and third-party service configurations required for **FleetOpt AI – Autonomous Public Fleet Scheduling and Driver Duty Rostering Combinatorial Optimizer**.

---

## 1. Credentials Inventory & Architecture Placement

| Credential / Variable | Target System | Official Provider | Default / Fallback Behavior |
| :--- | :--- | :--- | :--- |
| `MYSQL_DATABASE_URL` | **FastAPI Backend** (`.env`) | MySQL 8.x / AWS RDS / GCP Cloud SQL | Reports disconnected on `/api/health/mysql` without crashing |
| `MONGODB_URI` | **FastAPI Backend** (`.env`) | MongoDB Atlas / Local MongoDB | High-frequency telemetry switches to memory store fallback |
| `MONGODB_DATABASE` | **FastAPI Backend** (`.env`) | MongoDB Atlas / Local MongoDB | Default: `fleetopt_ai` |
| `JWT_SECRET_KEY` | **FastAPI Backend** (`.env`) | Internal / OpenSSL | Built-in default key in dev mode |
| `GOOGLE_MAPS_API_KEY` | **Flutter APK & Backend** | Google Cloud Console (Maps Platform) | Fallback OpenStreetMap / Canvas / External Maps launch |
| `ROUTING_API_KEY` | **FastAPI Backend** (`.env`) | Google Routes API / OSRM | Road-geometry kinematic interpolator with maneuvers |
| `FIREBASE_CREDENTIALS_PATH` | **FastAPI Backend** (`.env`) | Firebase Console (FCM Service Account) | Real-time WebSocket dispatcher (`/api/ws/notifications`) |
| `OPENWEATHER_API_KEY` | **FastAPI Backend** (`.env`) | OpenWeatherMap | Standard metropolitan weather assumptions |

---

## 2. Detailed Configuration & Generation Instructions

### 2.1 MySQL Database (`MYSQL_DATABASE_URL`)
* **Role**: Authoritative relational database for all 17 transactional tables (`users`, `drivers`, `vehicles`, `depots`, `routes`, `stops`, `trips`, `driver_availability`, `driver_duties`, `schedules`, `vehicle_assignments`, `maintenance`, `attendance`, `driver_leave`, `optimization_runs`, `incidents`, `audit_logs`).
* **Format**:
  ```text
  mysql+pymysql://<DB_USER>:<DB_PASSWORD>@<DB_HOST>:<DB_PORT>/<DB_NAME>
  ```
* **Provider Options**:
  1. **Local MySQL Server 8.x**:
     ```sql
     CREATE DATABASE fleetopt_ai CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
     CREATE USER 'fleet_user'@'localhost' IDENTIFIED BY 'YourStrongPassword123!';
     GRANT ALL PRIVILEGES ON fleetopt_ai.* TO 'fleet_user'@'localhost';
     FLUSH PRIVILEGES;
     ```
  2. **Cloud MySQL (AWS RDS / GCP Cloud SQL / Aiven / PlanetScale)**:
     - Provision MySQL 8.0 instance.
     - Allow inbound connections on port 3306 from backend IP.
* **Schema Migration**:
  Execute `database/migrations/mysql_schema.sql` against the database to create all 17 tables, foreign keys, and indexes:
  ```bash
  mysql -u fleet_user -p fleetopt_ai < database/migrations/mysql_schema.sql
  ```
* **Validation & Connection Test**:
  ```bash
  curl http://127.0.0.1:8000/api/health/mysql
  # Expected output when connected:
  # {"status":"healthy","database":"mysql","message":"MySQL connection active","pool_size":10}
  ```

---

### 2.2 MongoDB Atlas (`MONGODB_URI` & `MONGODB_DATABASE`)
* **Role**: High-throughput GPS breadcrumb store, real-time vehicle locations, telemetry events, and geospatial queries (`2dsphere` indexes).
* **Format**:
  ```text
  mongodb+srv://<USERNAME>:<PASSWORD>@<CLUSTER>.mongodb.net/?retryWrites=true&w=majority
  ```
  *(Local format: `mongodb://127.0.0.1:27017`)*
* **Provider**: [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
  1. Create a free M0 cluster on MongoDB Atlas.
  2. In **Database Access**, create a user with `readWriteAnyDatabase` or scoped to `fleetopt_ai`.
  3. In **Network Access**, add your backend's IP address (or `0.0.0.0/0` with secure password for testing).
  4. Under **Connect** > **Drivers (Python)**, copy the connection URI.
* **Automated Collections & Indexes**:
  FastAPI automatically initializes collections with `2dsphere` indexes on startup:
  - `vehicle_locations` (`location: "2dsphere"`, `vehicle_id: 1`)
  - `gps_history` (`location: "2dsphere"`, `vehicle_id: 1`, `timestamp: -1`)
  - `navigation_sessions`
  - `traffic_events`
  - `route_deviations`
  - `location_alerts`
  - `telemetry_events`
* **Validation & Connection Test**:
  ```bash
  curl http://127.0.0.1:8000/api/health/mongodb
  # Expected output when connected:
  # {"status":"healthy","database":"mongodb","message":"MongoDB connection active","collections":["vehicle_locations",...]}
  ```

---

### 2.3 Google Maps Platform (`GOOGLE_MAPS_API_KEY`)
* **Role**: Native Android vector map rendering and web route visualization.
* **Provider**: [Google Cloud Console](https://console.cloud.google.com/)
  1. Create a Google Cloud Project (e.g., `fleetopt-ai-prod`).
  2. Navigate to **APIs & Services** > **Library**.
  3. Enable:
     - **Maps SDK for Android**
     - **Maps JavaScript API** (for Web Dashboard)
     - **Geocoding API**
  4. Navigate to **Credentials** > **Create Credentials** > **API Key**.
  5. Under **API restrictions**, restrict to the enabled Maps APIs.
  6. Under **Application restrictions**, restrict the Android key using the package name `com.fleetopt.ai` and your SHA-1 signing fingerprint:
     ```bash
     keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
* **Placement**:
  - **Android APK**: Placed in `mobile/android/app/src/main/AndroidManifest.xml`:
    ```xml
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="AIzaSyYourGeneratedMapsApiKeyHere" />
    ```
  - **Flutter Runtime**: Passed during compilation or launch:
    ```bash
    flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=AIzaSy...
    flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=AIzaSy...
    ```

---

### 2.4 Google Routes API / OSRM (`ROUTING_API_KEY`)
* **Role**: Turn-by-turn road geometry, step-by-step driving maneuvers, traffic-aware travel time, and distance calculation.
* **Provider**:
  - **Google Routes API**: Enable **Routes API** in Google Cloud Console. Uses the same `AIzaSy...` key.
  - **OpenRouteService / OSRM**: If using OpenRouteService, obtain a token from [openrouteservice.org](https://openrouteservice.org/).
* **Placement**: Backend `.env`:
  ```text
  ROUTING_API_KEY=AIzaSyYourRoutesApiKeyHere
  ```
* **Validation & Connection Test**:
  ```bash
  curl "http://127.0.0.1:8000/api/navigation/route?origin_lat=12.9716&origin_lng=77.5946&dest_lat=12.9352&dest_lng=77.6245"
  ```
  Returns `coordinates` array, `distance_km`, `duration_minutes`, and step-by-step `maneuvers`.

---

### 2.5 Firebase Cloud Messaging (`FIREBASE_CREDENTIALS_PATH`)
* **Role**: Push notifications for route disruptions, emergency driver duty reassignments, and breakdown alerts.
* **Provider**: [Firebase Console](https://console.firebase.google.com/)
  1. Create a Firebase project and add an Android app with package name `com.fleetopt.ai`.
  2. Download `google-services.json` and place it in `mobile/android/app/`.
  3. Navigate to **Project Settings** > **Service Accounts** > **Firebase Admin SDK**.
  4. Click **Generate new private key** and download the JSON file (e.g. `firebase-credentials.json`).
  5. Store securely in `backend/firebase-credentials.json` (do not commit to Git).
* **Placement**: Backend `.env`:
  ```text
  FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
  FIREBASE_PROJECT_ID=fleetopt-ai
  ```
* **WebSocket Fallback**:
  If FCM credentials are not configured, the application automatically falls back to the in-app WebSocket notification stream (`/api/ws/notifications`), delivering alerts instantly to active driver and admin apps without losing messages.

---

### 2.6 OpenWeatherMap (`OPENWEATHER_API_KEY`)
* **Role**: Real-time precipitation and adverse weather inputs for demand forecasting and dynamic road travel speed adjustments.
* **Provider**: [OpenWeatherMap](https://home.openweathermap.org/api_keys)
  1. Sign up and copy the 32-character key from API Keys.
* **Placement**: Backend `.env`:
  ```text
  OPENWEATHER_API_KEY=32characterhexkeyhere
  ```

---

### 2.7 JWT Secret Key (`JWT_SECRET_KEY`)
* **Role**: Cryptographic signing for HS256 authentication tokens exchanged between Flutter APK and FastAPI.
* **Generation**:
  ```bash
  python -c "import secrets; print(secrets.token_hex(32))"
  ```
* **Placement**: Backend `.env`:
  ```text
  JWT_SECRET_KEY=4a8f9c2d1e0b...
  ```

---

## 3. Environment File Reference

### Backend `.env`
```ini
# Authoritative Relational Database (MySQL 8.x)
MYSQL_DATABASE_URL=mysql+pymysql://fleet_user:YourStrongPassword123!@localhost:3306/fleetopt_ai

# High-Frequency Geospatial Breadcrumb Store (MongoDB Atlas)
MONGODB_URI=mongodb+srv://fleet_admin:AtlasPassword@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
MONGODB_DATABASE=fleetopt_ai

# Security & Authentication
JWT_SECRET_KEY=4a8f9c2d1e0b6f8a9c2d1e0b6f8a9c2d1e0b6f8a9c2d1e0b6f8a9c2d1e0b6f8a
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480

# External Cloud Services
GOOGLE_MAPS_API_KEY=AIzaSyC...
ROUTING_API_KEY=AIzaSyC...
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
FIREBASE_PROJECT_ID=fleetopt-ai
OPENWEATHER_API_KEY=

# Server Configuration
PORT=8000
HOST=0.0.0.0
DEBUG=False
CORS_ORIGINS=["*"]
```

---

## 4. Verification & Health Check Commands

Execute these verification commands to validate connectivity across all components:

```bash
# 1. General System Health
curl http://127.0.0.1:8000/api/health

# 2. MySQL Relational Database Verification
curl http://127.0.0.1:8000/api/health/mysql

# 3. MongoDB Geospatial Store Verification
curl http://127.0.0.1:8000/api/health/mongodb

# 4. Turn-by-Turn Road Route & Polyline Generation
curl "http://127.0.0.1:8000/api/navigation/route?origin_lat=12.9716&origin_lng=77.5946&dest_lat=12.9352&dest_lng=77.6245"

# 5. Nearest Replacement Bus Optimization Query
curl "http://127.0.0.1:8000/api/replacements/nearest?breakdown_lat=12.9716&breakdown_lng=77.5946&min_capacity=40"

# 6. Flutter Test Suite
cd mobile
flutter test
```
