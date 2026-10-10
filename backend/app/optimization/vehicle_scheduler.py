import time
from typing import List, Dict, Any, Optional
from ortools.sat.python import cp_model

def time_str_to_minutes(time_str: str) -> int:
    """Converts HH:MM string to minutes from midnight."""
    parts = time_str.split(":")
    return int(parts[0]) * 60 + int(parts[1])

def minutes_to_time_str(minutes: int) -> str:
    """Converts minutes from midnight to HH:MM string."""
    h = (minutes // 60) % 24
    m = minutes % 60
    return f"{h:02d}:{m:02d}"

class VehicleScheduler:
    """
    Vehicle Scheduling Problem (VSP) Combinatorial Optimizer using Google OR-Tools CP-SAT.
    Allocates available vehicles to scheduled trips to minimize uncovered trips and operating costs.
    """
    def __init__(self, time_limit_seconds: int = 30):
        self.time_limit_seconds = time_limit_seconds

    def solve(
        self,
        trips: List[Dict[str, Any]],
        vehicles: List[Dict[str, Any]],
        deadhead_matrix: Optional[Dict[str, int]] = None,
        uncovered_penalty: int = 10000,
        locked_assignments: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Solves vehicle scheduling with CP-SAT.
        trips: [{'id': str, 'trip_number': str, 'start_time': str, 'end_time': str, 'route_id': str, 'demand': int}]
        vehicles: [{'id': str, 'plate_number': str, 'capacity': int, 'status': str, 'cost_per_km': float}]
        deadhead_matrix: {f"{from_route}_{to_route}": buffer_minutes}
        locked_assignments: {trip_id: vehicle_id}
        """
        start_wall_time = time.time()
        model = cp_model.CpModel()

        if deadhead_matrix is None:
            deadhead_matrix = {}
        if locked_assignments is None:
            locked_assignments = {}

        # Filter only active vehicles
        available_vehicles = [v for v in vehicles if v.get("status") == "active"]
        
        num_trips = len(trips)
        num_vehicles = len(available_vehicles)

        if num_trips == 0:
            return {
                "solver_status": "OPTIMAL",
                "solve_duration_seconds": 0.0,
                "objective_score": 0.0,
                "covered_trips": 0,
                "uncovered_trips": 0,
                "assignments": {},
                "explanation": "No trips provided for scheduling."
            }

        # Precompute trip intervals in minutes
        trip_data = []
        for t in trips:
            s_min = time_str_to_minutes(t["start_time"])
            e_min = time_str_to_minutes(t["end_time"])
            if e_min < s_min:
                e_min += 24 * 60  # spans past midnight
            trip_data.append({
                "id": t["id"],
                "start": s_min,
                "end": e_min,
                "demand": t.get("demand", 40),
                "route_id": t.get("route_id", "")
            })

        # Decision variables: x[i, v] = 1 if trip i is assigned to vehicle v
        x = {}
        for i in range(num_trips):
            for v in range(num_vehicles):
                x[i, v] = model.NewBoolVar(f"x_{i}_{v}")

        # Uncovered penalty variables: u[i] = 1 if trip i has no assigned vehicle
        u = {}
        for i in range(num_trips):
            u[i] = model.NewBoolVar(f"u_{i}")

        # Constraint 1: Each trip must be covered by at most one vehicle, or marked uncovered
        for i in range(num_trips):
            trip_id = trip_data[i]["id"]
            if trip_id in locked_assignments and locked_assignments[trip_id]:
                # Respect locked assignment
                locked_v_id = locked_assignments[trip_id]
                veh_indices = [idx for idx, v in enumerate(available_vehicles) if v["id"] == locked_v_id]
                if veh_indices:
                    v_idx = veh_indices[0]
                    model.Add(x[i, v_idx] == 1)
                    model.Add(u[i] == 0)
                else:
                    # Locked vehicle is no longer available!
                    model.Add(u[i] == 1)
            else:
                model.Add(sum(x[i, v] for v in range(num_vehicles)) + u[i] == 1)

        # Constraint 2: Non-overlapping and deadhead travel feasibility for each vehicle
        # If trips i and j overlap or lack deadhead travel time, vehicle v cannot do both
        for v in range(num_vehicles):
            veh_capacity = available_vehicles[v].get("capacity", 50)
            for i in range(num_trips):
                # Capacity constraint check
                if trip_data[i]["demand"] > veh_capacity:
                    model.Add(x[i, v] == 0)
                    continue

                for j in range(i + 1, num_trips):
                    t_i = trip_data[i]
                    t_j = trip_data[j]

                    deadhead_ij = deadhead_matrix.get(f"{t_i['route_id']}_{t_j['route_id']}", 15)
                    deadhead_ji = deadhead_matrix.get(f"{t_j['route_id']}_{t_i['route_id']}", 15)

                    # Check collision: i cannot follow j and j cannot follow i if times overlap
                    cannot_do_both = False
                    if not (t_i["end"] + deadhead_ij <= t_j["start"] or t_j["end"] + deadhead_ji <= t_i["start"]):
                        cannot_do_both = True

                    if cannot_do_both:
                        model.Add(x[i, v] + x[j, v] <= 1)

        # Vehicle usage indicator
        veh_used = {}
        for v in range(num_vehicles):
            veh_used[v] = model.NewBoolVar(f"veh_used_{v}")
            # veh_used[v] >= x[i, v] for all i
            for i in range(num_trips):
                model.Add(veh_used[v] >= x[i, v])

        # Objective Function:
        # Minimize (uncovered_penalty * uncovered_trips) + (vehicle_fixed_cost * veh_used) + (operating_costs)
        objective_terms = []
        for i in range(num_trips):
            objective_terms.append(u[i] * uncovered_penalty)

        for v in range(num_vehicles):
            fixed_cost = int(available_vehicles[v].get("fixed_cost", 200))
            objective_terms.append(veh_used[v] * fixed_cost)

        model.Minimize(sum(objective_terms))

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

        # Extract results
        assignments = {}
        uncovered_trips = []
        covered_count = 0

        if solver_status_code in [cp_model.OPTIMAL, cp_model.FEASIBLE]:
            for i in range(num_trips):
                trip_id = trip_data[i]["id"]
                if solver.Value(u[i]) == 1:
                    uncovered_trips.append(trip_id)
                    assignments[trip_id] = None
                else:
                    assigned_v = None
                    for v in range(num_vehicles):
                        if solver.Value(x[i, v]) == 1:
                            assigned_v = available_vehicles[v]["id"]
                            break
                    assignments[trip_id] = assigned_v
                    if assigned_v:
                        covered_count += 1
                    else:
                        uncovered_trips.append(trip_id)

        explanation = (
            f"VSP solver finished with status {status_str} in {solve_duration:.2f}s. "
            f"Covered {covered_count}/{num_trips} trips with {num_vehicles} active vehicles. "
            f"Uncovered: {len(uncovered_trips)}."
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
            "explanation": explanation
        }
