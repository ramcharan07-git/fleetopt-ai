# FleetOpt AI: Supabase PostgreSQL Setup & Migration Guide

This guide describes how to configure Supabase as the production PostgreSQL database and authentication engine for FleetOpt AI.

---

## 1. Create a Supabase Project

1. Log in to [Supabase Console](https://supabase.com/dashboard).
2. Click **New Project**.
3. Choose your Organization, enter Project Name: `fleetopt-ai`.
4. Set a strong database password and choose your preferred deployment region.
5. Wait for the database provisioning to complete (~1-2 minutes).

---

## 2. Execute SQL Schema Migrations

1. In the Supabase Dashboard, open the **SQL Editor** from the left navigation.
2. Click **New query**.
3. Copy the entire contents of [`database/migrations/001_initial_schema.sql`](file:///c:/bus%20fleet/database/migrations/001_initial_schema.sql).
4. Paste into the query editor and click **Run**.
5. Verify that all 30 tables are created:
   - `users`, `profiles`, `roles`, `depots`, `vehicles`, `vehicle_types`
   - `drivers`, `driver_qualifications`, `driver_availability`, `driver_leave`, `driver_preferences`
   - `routes`, `stops`, `route_stops`, `trips`
   - `schedules`, `schedule_versions`, `vehicle_assignments`, `driver_duties`, `duty_breaks`
   - `maintenance_records`, `incidents`, `vehicle_locations`
   - `passenger_demand`, `demand_predictions`, `optimization_runs`
   - `notifications`, `attendance`, `duty_swap_requests`, `audit_logs`

---

## 3. Seed Demo Data

Run the database seed script pointing to your Supabase PostgreSQL connection string:

```powershell
$env:DATABASE_URL="postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"
.\backend\venv\Scripts\python.exe database/seeds/seed_demo_data.py
```

This seeds:
- 30 buses
- 40 drivers
- 10 transit routes
- 100 daily trips
- 3 depots
- 700 historical passenger demand records
- Sample breakdown incident and maintenance records

---

## 4. Obtain API Credentials

Navigate to **Project Settings -> API** in the Supabase Dashboard and copy:
- `Project URL`: e.g. `https://xyzproject.supabase.co`
- `anon public key`: Public anonymous key
- `service_role key`: Keep strictly secret on backend only (never in mobile app)
- `JWT Secret`: Used by FastAPI to independently verify client JWT signatures.

Configure these in your `.env` file on Railway / backend.
