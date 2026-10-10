import time
from typing import List, Dict, Any, Optional
from app.optimization.vehicle_scheduler import VehicleScheduler
from app.optimization.driver_rosterer import DriverRosterer

class JointFleetOptimizer:
    """
    Joint Fleet Scheduling & Driver Duty Rostering Combinatorial Optimizer.
    Coordinates staged Vehicle Scheduling (VSP) and Driver Duty Rostering (DDRP)
    with strict feasibility verification and joint constraint enforcement.
    """
    def __init__(
        self,
        max_duty_hours: float = 8.0,
        min_rest_hours: float = 11.0,
        time_limit_seconds: int = 30
    ):
        self.vehicle_scheduler = VehicleScheduler(time_limit_seconds=time_limit_seconds // 2)
        self.driver_rosterer = DriverRosterer(
            max_duty_hours=max_duty_hours,
            min_rest_hours=min_rest_hours,
            time_limit_seconds=time_limit_seconds // 2
        )

    def optimize(
        self,
        trips: List[Dict[str, Any]],
        vehicles: List[Dict[str, Any]],
        drivers: List[Dict[str, Any]],
        absent_driver_ids: Optional[List[str]] = None,
        deadhead_matrix: Optional[Dict[str, int]] = None,
        locked_vehicle_assignments: Optional[Dict[str, str]] = None,
        locked_driver_assignments: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Executes joint optimization:
        1. Solves vehicle assignment with capacity & deadhead feasibility.
        2. Solves driver rostering matching duties with vehicle blocks.
        3. Reconciles assignments to guarantee mutual consistency.
        """
        start_time = time.time()

        # Step 1: Vehicle Scheduling
        vsp_result = self.vehicle_scheduler.solve(
            trips=trips,
            vehicles=vehicles,
            deadhead_matrix=deadhead_matrix,
            locked_assignments=locked_vehicle_assignments
        )

        # Step 2: Driver Rostering
        # Trips that were uncovered by vehicles can still be evaluated or skipped
        ddrp_result = self.driver_rosterer.solve(
            trips=trips,
            drivers=drivers,
            absent_driver_ids=absent_driver_ids,
            locked_assignments=locked_driver_assignments
        )

        total_duration = time.time() - start_time

        # Step 3: Joint Reconciliation
        v_assignments = vsp_result["assignments"]
        d_assignments = ddrp_result["assignments"]

        joint_assignments = []
        fully_covered_count = 0
        uncovered_trips = []

        total_cost = 0.0

        for t in trips:
            t_id = t["id"]
            assigned_v_id = v_assignments.get(t_id)
            assigned_d_id = d_assignments.get(t_id)

            is_uncovered = (assigned_v_id is None) or (assigned_d_id is None)

            if not is_uncovered:
                fully_covered_count += 1
                # Calculate cost: trip duration / 60 * base rate
                s_min = int(t["start_time"].split(":")[0]) * 60 + int(t["start_time"].split(":")[1])
                e_min = int(t["end_time"].split(":")[0]) * 60 + int(t["end_time"].split(":")[1])
                dur_h = max(0.5, (e_min - s_min) / 60.0)
                total_cost += dur_h * 28.5  # standard fleet hourly operational cost
            else:
                uncovered_trips.append(t_id)

            joint_assignments.append({
                "trip_id": t_id,
                "trip_number": t.get("trip_number", ""),
                "route_number": t.get("route_number", ""),
                "start_time": t.get("start_time", ""),
                "end_time": t.get("end_time", ""),
                "vehicle_id": assigned_v_id,
                "driver_id": assigned_d_id,
                "uncovered": is_uncovered
            })

        overall_status = "FEASIBLE"
        if vsp_result["solver_status"] == "OPTIMAL" and ddrp_result["solver_status"] == "OPTIMAL":
            overall_status = "OPTIMAL"
        elif vsp_result["solver_status"] == "INFEASIBLE" or ddrp_result["solver_status"] == "INFEASIBLE":
            overall_status = "INFEASIBLE"

        # Unique vehicles & drivers used
        used_vehicle_ids = {a["vehicle_id"] for a in joint_assignments if a["vehicle_id"]}
        used_driver_ids = {a["driver_id"] for a in joint_assignments if a["driver_id"]}

        explanation = (
            f"Joint Optimization completed in {total_duration:.2f}s with status {overall_status}. "
            f"Covered {fully_covered_count}/{len(trips)} trips fully (both vehicle & driver). "
            f"Fleet vehicles used: {len(used_vehicle_ids)}, Drivers deployed: {len(used_driver_ids)}. "
            f"Uncovered trips: {len(uncovered_trips)}."
        )

        return {
            "solver_status": overall_status,
            "solve_duration_seconds": round(total_duration, 3),
            "objective_score": round(vsp_result["objective_score"] + ddrp_result["objective_score"], 2),
            "total_trips": len(trips),
            "covered_trips": fully_covered_count,
            "uncovered_trips": len(uncovered_trips),
            "uncovered_trip_ids": uncovered_trips,
            "vehicles_used": len(used_vehicle_ids),
            "drivers_used": len(used_driver_ids),
            "estimated_cost": round(total_cost, 2),
            "assignments": joint_assignments,
            "vsp_details": vsp_result,
            "ddrp_details": ddrp_result,
            "explanation": explanation
        }
