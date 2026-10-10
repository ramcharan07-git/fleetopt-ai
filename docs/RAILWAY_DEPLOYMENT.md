# FleetOpt AI: Railway FastAPI Deployment Guide

This guide covers deploying the FleetOpt AI FastAPI backend, OR-Tools CP-SAT optimizer, and Scikit-Learn demand predictor to [Railway](https://railway.app).

---

## 1. Prerequisites

- A [Railway Account](https://railway.app).
- Railway CLI or GitHub repository connection.
- Supabase PostgreSQL instance (or Railway PostgreSQL plugin).

---

## 2. Deploying via GitHub Integration

1. Push your repository to GitHub.
2. In Railway, click **New Project** -> **Deploy from GitHub repo**.
3. Select the `fleetopt-ai` repository.
4. Set the Root Directory to `/backend` (or use the root `backend/Dockerfile`).

---

## 3. Environment Variables Configuration

In the Railway service dashboard, open the **Variables** tab and configure:

| Variable | Description | Example Value |
|---|---|---|
| `PORT` | Web server listening port | `8000` |
| `ENVIRONMENT` | Deployment environment | `production` |
| `DATABASE_URL` | Supabase PostgreSQL URI | `postgresql://postgres.xxx:pass@pooler.supabase.com:6543/postgres` |
| `SECRET_KEY` | JWT secret encryption key | `64-character-random-hex-string` |
| `ALGORITHM` | JWT signing algorithm | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Session validity duration | `1440` |
| `SUPABASE_URL` | Supabase endpoint | `https://your-project.supabase.co` |
| `SUPABASE_JWT_SECRET` | Supabase JWT Secret | `your-supabase-jwt-secret` |

---

## 4. Verification

1. Once Railway builds the container, test the health check:
   ```
   GET https://your-railway-app.up.railway.app/api/health
   ```
   Response:
   ```json
   {
     "status": "healthy",
     "service": "FleetOpt AI Backend",
     "version": "1.0.0",
     "optimizer": "Google OR-Tools CP-SAT Enabled",
     "ml": "Scikit-Learn Random Forest Enabled"
   }
   ```
2. Interactive OpenAPI docs are accessible at:
   ```
   https://your-railway-app.up.railway.app/docs
   ```
