# FleetOpt AI: System Architecture & Mathematical Optimization Manifesto

## Executive Summary
**FleetOpt AI** (Autonomous Public Fleet Scheduling and Driver Duty Rostering Combinatorial Optimizer) solves the Vehicle Scheduling Problem (VSP) and the Driver Duty Rostering Problem (DDRP) simultaneously, ensuring mathematical optimality, operational safety, and resilient disruption recovery.

---

## 1. Combinatorial Optimization Formulations (Google OR-Tools CP-SAT)

### 1.1 Vehicle Scheduling Problem (VSP)

#### Mathematical Variables
- Binary decision variables:
  $$x_{i,v} \in \{0, 1\}$$
  Equals $1$ if scheduled trip $i \in T$ is assigned to vehicle $v \in V$, $0$ otherwise.
- Slack / Penalty variables:
  $$u_i \in \{0, 1\}$$
  Equals $1$ if trip $i$ is left uncovered.

#### Hard Constraints
1. **Trip Coverage or Explicit Penalty**:
   $$\sum_{v \in V} x_{i,v} + u_i = 1 \quad \forall i \in T$$
   *Crucial Rule*: We never silently create phantom buses. If fleet capacity is exceeded, $u_i = 1$ applies an explicit heavy penalty $M$.

2. **No Overlapping Assignments & Deadhead Feasibility**:
   For any two trips $i, j \in T$ where:
   $$\text{end\_time}(i) + \text{deadhead}(i, j) > \text{start\_time}(j) \quad \text{and} \quad \text{end\_time}(j) + \text{deadhead}(j, i) > \text{start\_time}(i)$$
   Then vehicle $v$ cannot operate both:
   $$x_{i,v} + x_{j,v} \le 1 \quad \forall v \in V$$

3. **Vehicle Capacity**:
   If $\text{demand}(i) > \text{capacity}(v)$, then $x_{i,v} = 0$.

4. **Maintenance Exclusions**:
   If vehicle status $\in \{\text{'maintenance'}, \text{'breakdown'}\}$, $x_{i,v} = 0 \quad \forall i \in T$.

#### Objective Function
$$\min \sum_{i \in T} M \cdot u_i + \sum_{v \in V} F_v \cdot \text{used}_v + \sum_{i \in T} \sum_{v \in V} C_v \cdot \text{distance}_i \cdot x_{i,v}$$

---

### 1.2 Driver Duty Rostering Problem (DDRP)

#### Decision Variables
- $$y_{i,d} \in \{0, 1\}$$: Trip $i$ operated by driver $d \in D$.
- $$u^d_i \in \{0, 1\}$$: Uncovered duty slack.

#### Constraints
1. **Assignment Conservation**:
   $$\sum_{d \in D} y_{i,d} + u^d_i = 1 \quad \forall i \in T$$

2. **Driver Qualifications**:
   If qualification $Q_i$ is required for vehicle/route and $Q_i \notin \text{quals}(d)$, then $y_{i,d} = 0$.

3. **Working Hour Limits & Duty Caps**:
   $$\sum_{i \in T} y_{i,d} \cdot \text{duration}(i) \le \text{MaxDutyMinutes} \quad (\text{e.g. 8.0 hours})$$

4. **Rest Periods Between Duties**:
   Minimum rest periods ($\ge 11.0$ hours) enforced between consecutive daily shifts.

5. **Driver Absence / Approved Leave**:
   If driver $d$ has approved leave on target date:
   $$y_{i,d} = 0 \quad \forall i \in T$$

---

## 2. AI Passenger Demand Prediction Pipeline

- **Algorithm**: Random Forest Regressor (`scikit-learn`) with 50 estimators.
- **Features**:
  - `hour_of_day` (0 - 23)
  - `day_of_week` (0 - 6)
  - `is_holiday` (Binary indicator)
  - `is_event` (Binary indicator)
  - `route_id_hash` (Route identifier embedding)
  - `weather_condition` (Clear, Cloudy, Rain, Storm)
- **Held-Out Evaluation**:
  - 80/20 train/test split.
  - Metrics: Mean Absolute Error (MAE), Root Mean Squared Error (RMSE), Coefficient of Determination ($R^2$).
  - Fallback Baseline: Rolling historical average per time slot when sample size $< 10$.

---

## 3. Disruption Handling & Emergency Rescheduling

1. **Incident Trigger**: Bus breakdown, driver sickness, or road obstruction reported via mobile app or API.
2. **Impact Radius Computation**: Query affected trip assignments linked to the disabled vehicle or driver.
3. **Emergency CP-SAT Repair**:
   - Locked assignments for unaffected trips remain frozen ($x_{k,v} = 1$).
   - Reoptimization searches available reserve vehicles at the nearest depot.
   - If spare vehicle found, atomically updates schedule version number (optimistic concurrency control).
   - If no feasible replacement exists, trips are marked `UNCOVERED` with automated passenger and supervisor alerts.
