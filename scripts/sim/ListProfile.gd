class_name ListProfile
extends RefCounted
## What a list is good at, against the league it is playing in (ARD-M6-006).
## Five strengths, each a word - Elite, Strong, Average, Weak - from where the
## side ranks among every club's side this week, so the words move as the
## league around a list gets better or worse. No score is shown.
##
## Each strength is the engine's own: Contest, Running power and Pressure are
## PlanFit's scores for Win contest, Attacking and Defensive; Control is the
## disposal that beats a press and the discipline that avoids clangers;
## Aerial power is the side's best marks. Pure rules on match-day sides.

const DIMS := ["contest", "control", "running", "pressure", "aerial"]
const LABEL := {"contest": "Contest", "control": "Control", "running": "Running power",
		"pressure": "Pressure", "aerial": "Aerial power"}
## What each strength is, for the player who asks.
const MEANS := {
	"contest": "Winning it at the stoppages: your centre-square midfielders' contested ball and your ruck's tap work.",
	"control": "Keeping the ball: disposal under pressure and discipline with it, right across the side.",
	"running": "Carrying it forward: your runners' carry and their disposal on the move.",
	"pressure": "Making them cough it up: your midfielders' and forwards' pressure.",
	"aerial": "Winning it in the air: your best marks, at both ends.",
}
## Where the words fall, as a share of the league from the top.
const ELITE := 0.17
const STRONG := 0.44
const AVERAGE := 0.72
const MARKERS := 6
const CONTROL_W := {"disposal": 0.65, "discipline": 0.35}


static func _a(p: Dictionary, key: String) -> float:
	return float((p.get("attr", {}) as Dictionary).get(key, 0.0))


static func _control(p: Dictionary) -> float:
	return CONTROL_W["disposal"] * _a(p, "disposal") + CONTROL_W["discipline"] * _a(p, "discipline")


## The side's raw score for a strength. Never shown.
static func score(ground: Array, dim: String) -> float:
	match dim:
		"contest":
			return PlanFit.score(ground, "contest")
		"running":
			return PlanFit.score(ground, "attacking")
		"pressure":
			return PlanFit.score(ground, "defensive")
		"control":
			var tot := 0.0
			var n := 0
			for p in ground:
				if str(p.get("role", "")) != "RUCK":
					tot += _control(p)
					n += 1
			return tot / float(maxi(1, n))
		"aerial":
			var tot := 0.0
			var best := leaders(ground, dim, MARKERS)
			for p in best:
				tot += _a(p, "marking")
			return tot / float(maxi(1, best.size()))
	return 0.0


## Who leads a strength in this side, best first.
static func leaders(ground: Array, dim: String, n := 4) -> Array:
	match dim:
		"contest":
			return PlanFit.carriers(ground, "contest").slice(0, n)
		"running":
			return PlanFit.carriers(ground, "attacking").slice(0, n)
		"pressure":
			return PlanFit.carriers(ground, "defensive").slice(0, n)
	var pool := ground.duplicate()
	if dim == "control":
		pool = pool.filter(func(p): return str(p.get("role", "")) != "RUCK")
	var key := func(p) -> float: return _control(p) if dim == "control" else _a(p, "marking")
	pool.sort_custom(func(a, b):
		var va: float = key.call(a)
		var vb: float = key.call(b)
		if not is_equal_approx(va, vb):
			return va > vb
		return str(a.get("id", "")) < str(b.get("id", "")))
	return pool.slice(0, n)


## The word for a side ranked `rank` (0 = best) in a league of `clubs`.
static func word(rank: int, clubs: int) -> String:
	var share := float(rank) / float(maxi(1, clubs))
	if share < ELITE:
		return "Elite"
	if share < STRONG:
		return "Strong"
	if share < AVERAGE:
		return "Average"
	return "Weak"


## `grounds`: club code -> its match-day side, every club in the league.
## [{dim, label, word, rank}] for `mine`, in DIMS order. A tie ranks level.
static func profile(grounds: Dictionary, mine: String) -> Array:
	var out := []
	if not grounds.has(mine):
		return out
	for dim in DIMS:
		var me := score(grounds[mine], dim)
		var rank := 0
		for code in grounds:
			if str(code) != mine and score(grounds[code], dim) > me + 0.0001:
				rank += 1
		out.append({"dim": dim, "label": LABEL[dim], "word": word(rank, grounds.size()), "rank": rank})
	return out
