class_name Workload
extends RefCounted
## Load carried between weeks. MatchSim records actual on-ground effort;
## the career applies it once per completed week, then everyone recovers.
## No random rolls and no changes to injuries or permanent player ratings.

const MAX_LOAD := 100.0
const CARRYING := 20.0
const NEEDS_BREAK := 45.0
const WEEK_CARRY := 0.75
const EFFORT_LOAD := 0.16


static func value(p: Dictionary) -> float:
	return clampf(float(p.get("workload", 0.0)), 0.0, MAX_LOAD)


## A loaded player cannot recover to fresh legs on the bench or at a break.
## With no load this is exactly the existing match behaviour.
static func energy_cap(p: Dictionary) -> float:
	return maxf(70.0, 100.0 - value(p) * 0.4)


## Automatic selection weighs freshness alongside ability. Manual selections
## remain the coach's choice; workload never makes a fit player unavailable.
static func selection_factor(p: Dictionary) -> float:
	return 0.75 + 0.25 * energy_cap(p) / 100.0


static func label(p: Dictionary) -> String:
	if value(p) >= NEEDS_BREAK:
		return "Needs a break"
	if value(p) >= CARRYING:
		return "Carrying a load"
	return "Fresh"


static func description(p: Dictionary) -> String:
	if value(p) >= NEEDS_BREAK:
		return "Needs a break. Recent games are still in his legs, even after a spell on the bench. A week out of seniors helps him recover."
	if value(p) >= CARRYING:
		return "Carrying a load. He starts with less in his legs. Lighter game time or a week out of seniors eases the load."
	return "Fresh. Ready for his usual game time."


static func recovery(p: Dictionary) -> float:
	var durability := clampf(float((p.get("attr", {}) as Dictionary).get("durability", 70.0)), 0.0, 100.0)
	var veteran := clampf(float(p.get("age", 25.0)) - 29.0, 0.0, 8.0)
	return 10.0 + durability * 0.10 - veteran * 0.5


## Byes, omitted players and injured players all get the same week's
## recovery. Omitted players still have their existing reserves development;
## this models the extra load of senior football, not a second reserves sim.
static func advance_week(lists: Dictionary, results: Array, week: String,
		recovery_mults: Dictionary = {}) -> void:
	var effort := {}
	for res in results:
		for id in res.get("exertion", {}):
			effort[str(id)] = float(effort.get(str(id), 0.0)) + float(res["exertion"][id])
	for code in lists:
		var recovery_mult := float(recovery_mults.get(code, 1.0))
		for p in lists[code]:
			if str(p.get("workload_week", "")) == week:
				continue
			var training := 6.0 if bool(p.get("heavy_legs", false)) else 0.0
			# High-performance funding changes ordinary week-to-week recovery;
			# an explicit fresh/rest week keeps its existing extra recovery.
			var recover := recovery(p) * recovery_mult \
					+ (8.0 if bool(p.get("fresh", false)) else 0.0)
			p["workload"] = clampf(value(p) * WEEK_CARRY
					+ maxf(0.0, float(effort.get(str(p["id"]), 0.0))) * EFFORT_LOAD
					+ training - recover, 0.0, MAX_LOAD)
			p["workload_week"] = week


static func reset(lists: Dictionary) -> void:
	for code in lists:
		for p in lists[code]:
			p.erase("workload")
			p.erase("workload_week")
