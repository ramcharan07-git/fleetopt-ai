import copy
import time
from typing import Dict, Any, List
from app.optimization.joint_optimizer import JointFleetOptimizer

class WhatIfSimulator:
    """
    Simulates operational perturbations (fleet reductions, driver shortages, demand surges, breakdowns)
    against an optimization baseline without touching live production schedules.
    """
    def __init__(self):
        self.optimizer = JointFleetOptimizer(time_limit_seconds=15)

    def run_simulation(
        self,
        base_trips: List[Dict[str, Any]],
        base_vehicles: List[Dict[str, Any]],
        base_drivers: List[Dict[str, Any]],
        available_buses_count: int = None,
        absent_drivers_count: int = 0,
        trip_multiplier: float = 1.0,
        passenger_demand_percentage: float = 100.0,
        vehicle_breakdowns_count: int = 0,
        priority_mode: str = "balanced"
    ) -> Dict[str, Any]:
        """
        Runs scenario copy through OR-Tools solver and compares against baseline.
        """
        # Baseline run
        baseline_result = self.optimizer.optimize(
            trips=base_trips,
            vehicles=base_vehicles,
            drivers=base_drivers
        )

        # Clone datasets for scenario modification
        sim_trips = copy.deepcopy(base_trips)
        sim_vehicles = copy.deepcopy(base_vehicles)
        sim_drivers = copy.deepcopy(base_drivers)

        # Apply demand adjustment
        demand_factor = passenger_demand_percentage / 100.0
        for t in sim_trips:
            t["demand"] = int(t.get("demand", 40) * demand_factor)

        # Apply trip multiplier (if scaling trips up/down)
        if trip_multiplier < 0.99 or trip_multiplier > 1.01:
            target_trip_count = max(1, int(len(sim_trips) * trip_multiplier))
            if target_trip_count < len(sim_trips):
                sim_trips = sim_trips[:target_trip_count]
            elif target_trip_count > len(sim_trips):
                # Duplicate some trips with shifted offset
                extra_needed = target_trip_count - len(sim_trips)
                for idx in range(extra_needed):
                    template = copy.deepcopy(sim_trips[idx % len(sim_trips)])
                    template["id"] = f"{template['id']}_extra_{idx}"
                    template["trip_number"] = f"{template['trip_number']}-X{idx+1}"
                    sim_trips.append(template)

        # Apply vehicle breakdowns
        if vehicle_breakdowns_count > 0:
            for i in range(min(vehicle_breakdowns_count, len(sim_vehicles))):
                sim_vehicles[i]["status"] = "breakdown"

        # Apply available buses cap if specified
        if available_buses_count is not None and available_buses_count < len(sim_vehicles):
            active_count = 0
            for v in sim_vehicles:
                if v.get("status") == "active":
                    active_count += 1
                    if active_count > available_buses_count:
                        v["status"] = "unavailable"

        # Apply driver absences
        absent_driver_ids = []
        if absent_drivers_count > 0:
            absent_driver_ids = [d["id"] for d in sim_drivers[:absent_drivers_count]]

        # Run simulated optimization
        sim_result = self.optimizer.optimize(
            trips=sim_trips,
            vehicles=sim_vehicles,
            drivers=sim_drivers,
            absent_driver_ids=absent_driver_ids
        )

        constraint_violations = []
        if sim_result["uncovered_trips"] > 0:
            constraint_violations.append(
                f"{sim_result['uncovered_trips']} trips could not be covered due to vehicle/driver resource limits."
            )

        active_buses = len([v for v in sim_vehicles if v.get("status") == "active"])
        active_drivers = len([d for d in sim_drivers if d["id"] not in absent_driver_ids])

        return {
            "baseline_covered": baseline_result["covered_trips"],
            "simulated_covered": sim_result["covered_trips"],
            "baseline_uncovered": baseline_result["uncovered_trips"],
            "simulated_uncovered": sim_result["uncovered_trips"],
            "baseline_cost": baseline_result["estimated_cost"],
            "simulated_cost": sim_result["estimated_cost"],
            "cost_delta": round(sim_result["estimated_cost"] - baseline_result["estimated_cost"], 2),
            "uncovered_delta": sim_result["uncovered_trips"] - baseline_result["uncovered_trips"],
            "active_buses": active_buses,
            "active_drivers": active_drivers,
            "solve_time_seconds": sim_result["solve_duration_seconds"],
            "solver_status": sim_result["solver_status"],
            "constraint_violations": constraint_violations,
            "explanation": (
                f"What-If Simulation with {active_buses} buses, {active_drivers} drivers, "
                f"and {passenger_demand_percentage}% demand resulted in {sim_result['covered_trips']}/{len(sim_trips)} "
                f"covered trips (Cost: ${sim_result['estimated_cost']:.2f})."
            )
        }
