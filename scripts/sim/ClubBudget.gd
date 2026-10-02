class_name ClubBudget
extends RefCounted
## Annual discretionary club spending. This is not a bank account: every
## off-season the board gives the same fixed departmental budget and the
## coach allocates it for the coming season.
##
## Four buckets, four funding levels, one explicit football effect each.
## Standard in all four costs exactly the full annual budget.

const ANNUAL_M := 12.0
const STANDARD := 1
const YOUNG_AGE := 22.0

const AREA_ORDER := ["recruiting", "development", "high_performance", "football"]
const AREA_LABEL := {
	"recruiting": "Recruiting",
	"development": "Development",
	"high_performance": "High performance",
	"football": "Football department",
}
const LEVELS := [
	{"key": "minimal", "label": "Minimal", "cost_m": 1.5},
	{"key": "standard", "label": "Standard", "cost_m": 3.0},
	{"key": "strong", "label": "Strong", "cost_m": 4.5},
	{"key": "elite", "label": "Elite", "cost_m": 6.0},
]

## Multipliers relative to Standard. The final step is deliberately smaller
## than the first so Elite is specialization, not an automatic destination.
const SCOUT_UNCERTAINTY := [1.25, 1.00, 0.80, 0.65]
const DEVELOPMENT_XP := [0.90, 1.00, 1.10, 1.15]
const RECOVERY := [0.90, 1.00, 1.10, 1.20]
const TACTICS_EXEC := [0.95, 1.00, 1.05, 1.08]


static func defaults() -> Dictionary:
	return {
		"recruiting": STANDARD,
		"development": STANDARD,
		"high_performance": STANDARD,
		"football": STANDARD,
	}


static func valid_area(area: String) -> bool:
	return AREA_ORDER.has(area)


static func clamp_level(level: int) -> int:
	return clampi(level, 0, LEVELS.size() - 1)


static func level_label(level: int) -> String:
	return str((LEVELS[clamp_level(level)] as Dictionary)["label"])


static func cost_m(level: int) -> float:
	return float((LEVELS[clamp_level(level)] as Dictionary)["cost_m"])


static func total_m(allocation: Dictionary) -> float:
	var total := 0.0
	for area in AREA_ORDER:
		total += cost_m(int(allocation.get(area, STANDARD)))
	return total


static func remaining_m(allocation: Dictionary) -> float:
	return ANNUAL_M - total_m(allocation)


static func scouting_mult(level: int) -> float:
	return float(SCOUT_UNCERTAINTY[clamp_level(level)])


static func development_mult(level: int) -> float:
	return float(DEVELOPMENT_XP[clamp_level(level)])


static func recovery_mult(level: int) -> float:
	return float(RECOVERY[clamp_level(level)])


static func tactics_mult(level: int) -> float:
	return float(TACTICS_EXEC[clamp_level(level)])


## The UI uses these exact statements before the player spends.
static func benefit_text(area: String, level: int) -> String:
	level = clamp_level(level)
	match area:
		"recruiting":
			match level:
				0: return "Prospect scouting uncertainty is 25% wider than standard."
				1: return "Prospect scouting uncertainty is at the standard level."
				2: return "Prospect scouting uncertainty is 20% narrower than standard."
				3: return "Prospect scouting uncertainty is 35% narrower than standard."
		"development":
			match level:
				0: return "Players aged 22 and under earn 10% less development XP."
				1: return "Players aged 22 and under earn standard development XP."
				2: return "Players aged 22 and under earn 10% more development XP."
				3: return "Players aged 22 and under earn 15% more development XP."
		"high_performance":
			match level:
				0: return "Weekly workload recovery is 10% lower than standard."
				1: return "Weekly workload recovery is at the standard rate."
				2: return "Weekly workload recovery is 10% higher than standard."
				3: return "Weekly workload recovery is 20% higher than standard."
		"football":
			match level:
				0: return "Gameplan execution is 5% lower than standard."
				1: return "Gameplan execution is at the standard level."
				2: return "Gameplan execution is 5% higher than standard."
				3: return "Gameplan execution is 8% higher than standard."
	return ""
