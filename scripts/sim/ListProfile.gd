class_name ListProfile
extends RefCounted
## What a list is good at, against the league it is playing in (ARD-M6-006).
## Six strengths, each a word - Elite, Strong, Average, Weak - from where the
## side ranks among every club's side this week, so the words move as the
## league around a list gets better or worse. No score is shown.
##
## Each strength is the engine's own: Contest, Running power and Pressure are
## PlanFit's scores for Win contest, Attacking and Defensive; Control is the
## disposal that beats a press and the discipline that avoids clangers;
## Aerial power is the side's best marks; Finishing is the best forwards'
## kicking for goal and marking up forward. Pure rules on match-day sides.

const DIMS := ["contest", "control", "running", "pressure", "aerial", "finishing"]
const LABEL := {"contest": "Contest", "control": "Control", "running": "Running power",
		"pressure": "Pressure", "aerial": "Aerial power", "finishing": "Finishing"}
## What each strength is, for the player who asks.
const MEANS := {
	"contest": "Winning it at the stoppages: your centre-square midfielders' contested ball and your ruck's tap work.",
	"control": "Keeping the ball: disposal under pressure and discipline with it, right across the side.",
	"running": "Carrying it forward: your runners' carry and their disposal on the move.",
	"pressure": "Making them cough it up: your midfielders' and forwards' pressure.",
	"aerial": "Winning it in the air: your best marks, at both ends.",
	"finishing": "Turning entries into scores: your best forwards' goalkicking, accuracy and marking.",
}
## Where the words fall, as a share of the league from the top.
const ELITE := 0.17
const STRONG := 0.44
const AVERAGE := 0.72
const MARKERS := 6
const CONTROL_W := {"disposal": 0.65, "discipline": 0.35}
const FINISHERS := 5
const FINISH_W := {"goalkicking": 0.5, "accuracy": 0.3, "marking": 0.2}


static func _a(p: Dictionary, key: String) -> float:
	return float((p.get("attr", {}) as Dictionary).get(key, 0.0))


static func _control(p: Dictionary) -> float:
	return CONTROL_W["disposal"] * _a(p, "disposal") + CONTROL_W["discipline"] * _a(p, "discipline")


static func _finish(p: Dictionary) -> float:
	var v := 0.0
	for k in FINISH_W:
		v += float(FINISH_W[k]) * _a(p, k)
	return v


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
		"finishing":
			var tot := 0.0
			var best := leaders(ground, dim, FINISHERS)
			for p in best:
				tot += _finish(p)
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
	elif dim == "finishing":
		pool = pool.filter(func(p): return str(p.get("role", "")) == "FWD")
	var key := func(p) -> float:
		match dim:
			"control": return _control(p)
			"finishing": return _finish(p)
		return _a(p, "marking")
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
