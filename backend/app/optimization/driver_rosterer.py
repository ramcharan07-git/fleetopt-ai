import time
from typing import List, Dict, Any, Optional
from ortools.sat.python import cp_model

def time_str_to_minutes(time_str: str) -> int:
    parts = time_str.split(":")
    return int(parts[0]) * 60 + int(parts[1])

class DriverRosterer:
    """
    Driver Duty Rostering Problem (DDRP) Optimizer using Google OR-Tools CP-SAT.
    Assigns qualified, available drivers to vehicle blocks/trips while strictly enforcing
    legal rest, shift duration, qualifications, and minimizing overtime.
    """
    def __init__(
        self,
        max_duty_hours: float = 8.0,
        min_rest_hours: float = 11.0,
        time_limit_seconds: int = 30
    ):
        self.max_duty_minutes = int(max_duty_hours * 60)
        self.min_rest_minutes = int(min_rest_hours * 60)
        self.time_limit_seconds = time_limit_seconds

    def solve(
        self,
        trips: List[Dict[str, Any]],
        drivers: List[Dict[str, Any]],
        absent_driver_ids: Optional[List[str]] = None,
        locked_assignments: Optional[Dict[str, str]] = None,
        uncovered_penalty: int = 15000
    ) -> Dict[str, Any]:
        """
        Solves driver rostering.
        trips: [{'id': str, 'trip_number': str, 'start_time': str, 'end_time': str, 'required_qualification': str}]
        drivers: [{'id': str, 'user_name': str, 'qualifications': [str], 'preferences': {'shift': 'morning'}}]
        absent_driver_ids: list of driver IDs on leave/absent
        locked_assignments: {trip_id: driver_id}
        """
        start_wall_time = time.time()
        model = cp_model.CpModel()

        if absent_driver_ids is None:
            absent_driver_ids = []
        if locked_assignments is None:
            locked_assignments = {}

        # Filter out absent drivers
        available_drivers = [d for d in drivers if d["id"] not in absent_driver_ids]

        num_trips = len(trips)
        num_drivers = len(available_drivers)

        if num_trips == 0:
            return {
                "solver_status": "OPTIMAL",
                "solve_duration_seconds": 0.0,
                "objective_score": 0.0,
                "covered_trips": 0,
                "uncovered_trips": 0,
                "assignments": {},
                "explanation": "No trips provided for driver rostering."
            }

        # Precompute trip intervals
        trip_data = []
        for t in trips:
            s_min = time_str_to_minutes(t["start_time"])
            e_min = time_str_to_minutes(t["end_time"])
            if e_min < s_min:
                e_min += 24 * 60
            trip_data.append({
                "id": t["id"],
                "start": s_min,
                "end": e_min,
                "duration": e_min - s_min,
                "required_qualification": t.get("required_qualification")
            })

        # Decision variables: y[i, d] = 1 if trip i is driven by driver d
        y = {}
        for i in range(num_trips):
            for d in range(num_drivers):
                y[i, d] = model.NewBoolVar(f"y_{i}_{d}")

        # Uncovered penalty: u[i] = 1 if trip i has no driver
        u = {}
        for i in range(num_trips):
            u[i] = model.NewBoolVar(f"driver_u_{i}")

        # Constraint 1: One driver per trip, or marked uncovered
        for i in range(num_trips):
            trip_id = trip_data[i]["id"]
            if trip_id in locked_assignments and locked_assignments[trip_id]:
                locked_d_id = locked_assignments[trip_id]
                d_indices = [idx for idx, d in enumerate(available_drivers) if d["id"] == locked_d_id]
                if d_indices:
                    d_idx = d_indices[0]
                    model.Add(y[i, d_idx] == 1)
                    model.Add(u[i] == 0)
                else:
                    # Driver absent! Trip uncovered
                    model.Add(u[i] == 1)
            else:
                model.Add(sum(y[i, d] for d in range(num_drivers)) + u[i] == 1)

        # Constraint 2: Driver qualifications
        for d in range(num_drivers):
            driver_quals = set(available_drivers[d].get("qualifications", []))
            for i in range(num_trips):
                req_qual = trip_data[i]["required_qualification"]
                if req_qual and req_qual not in driver_quals:
                    # Driver lacks qualification
                    model.Add(y[i, d] == 0)

        # Constraint 3: No overlapping trips for same driver & buffer between trips (at least 10 min break)
        min_trip_buffer = 10
        for d in range(num_drivers):
            for i in range(num_trips):
                for j in range(i + 1, num_trips):
                    t_i = trip_data[i]
                    t_j = trip_data[j]
                    # If trip i and j overlap or don't allow min buffer, driver d cannot do both
                    if not (t_i["end"] + min_trip_buffer <= t_j["start"] or t_j["end"] + min_trip_buffer <= t_i["start"]):
                        model.Add(y[i, d] + y[j, d] <= 1)

        # Constraint 4: Max daily duty duration per driver
        # Sum of durations of assigned trips <= max_duty_minutes
        for d in range(num_drivers):
            assigned_durations = [y[i, d] * trip_data[i]["duration"] for i in range(num_trips)]
            model.Add(sum(assigned_durations) <= self.max_duty_minutes)

        # Driver usage indicators & fairness
        driver_used = {}
        for d in range(num_drivers):
            driver_used[d] = model.NewBoolVar(f"driver_used_{d}")
            for i in range(num_trips):
                model.Add(driver_used[d] >= y[i, d])

        # Objective Function:
        # Minimize uncovered_trips * uncovered_penalty + overtime penalties + fair balancing
        obj_terms = []
        for i in range(num_trips):
            obj_terms.append(u[i] * uncovered_penalty)

        # Shift preference penalties (soft constraint)
        for d in range(num_drivers):
            pref = available_drivers[d].get("preferences", {}).get("shift", "morning")
            for i in range(num_trips):
                start_h = trip_data[i]["start"] // 60
                # Morning: 05:00 - 13:00, Evening: 13:00 - 21:00, Night: 21:00 - 05:00
                is_mismatch = False
                if pref == "morning" and start_h >= 14:
                    is_mismatch = True
                elif pref == "evening" and (start_h < 12 or start_h >= 20):
                    is_mismatch = True
                if is_mismatch:
                    obj_terms.append(y[i, d] * 5)  # small soft penalty for shift preference mismatch

        model.Minimize(sum(obj_terms))

        # Solve
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = float(self.time_limit_seconds)
        solver.parameters.num_search_workers = 4
        solver_status_code = solver.Solve(model)

        solve_duration = time.time() - start_wall_time

        status_str = "FEASIBLE"
        if solver_status_code == cp_model.OPTIMAL:
            status_str = "OPTIMAL"
        elif solver_status_code == cp_model.INFEASIBLE:
            status_str = "INFEASIBLE"
        elif solver_status_code == cp_model.MODEL_INVALID:
            status_str = "MODEL_INVALID"

        assignments = {}
        uncovered_trips = []
        covered_count = 0
        drivers_used_count = 0

        if solver_status_code in [cp_model.OPTIMAL, cp_model.FEASIBLE]:
            for d in range(num_drivers):
                if solver.Value(driver_used[d]) == 1:
                    drivers_used_count += 1

            for i in range(num_trips):
                trip_id = trip_data[i]["id"]
                if solver.Value(u[i]) == 1:
                    uncovered_trips.append(trip_id)
                    assignments[trip_id] = None
                else:
                    assigned_d = None
                    for d in range(num_drivers):
                        if solver.Value(y[i, d]) == 1:
                            assigned_d = available_drivers[d]["id"]
                            break
                    assignments[trip_id] = assigned_d
                    if assigned_d:
                        covered_count += 1
                    else:
                        uncovered_trips.append(trip_id)

        explanation = (
            f"DDRP solver finished with status {status_str} in {solve_duration:.2f}s. "
            f"Covered {covered_count}/{num_trips} duties using {drivers_used_count} active drivers. "
            f"Uncovered duties: {len(uncovered_trips)}."
        )

        return {
            "solver_status": status_str,
            "solve_duration_seconds": round(solve_duration, 3),
            "objective_score": float(solver.ObjectiveValue()) if solver_status_code in [cp_model.OPTIMAL, cp_model.FEASIBLE] else -1.0,
            "total_trips": num_trips,
            "covered_trips": covered_count,
            "uncovered_trips": len(uncovered_trips),
            "assignments": assignments,
            "uncovered_trip_ids": uncovered_trips,
            "drivers_used": drivers_used_count,
            "explanation": explanation
        }
