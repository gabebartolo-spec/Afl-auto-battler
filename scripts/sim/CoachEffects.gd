class_name CoachEffects
extends RefCounted
## What the coaching staff does on the field (Coaching Phase 5). Three small,
## capped modifiers, all read straight from the coach records - nothing is
## stored, so older saves need nothing:
##
##   Teaching        -> match XP (the one place XP is paid, GameState._grant_xp)
##   Tactics         -> how well a game plan is executed, and how sharply an
##                      AI club reads the match when it picks its plan
##   Man-management  -> how much being left out hurts a player's morale
##
## Each works from the coaches in the jobs that fit it, not one staff total:
## the forwards coach teaches the forwards, the development coach the kids
## and the reserves. A coach's skill is centred on 70 (a Good coach adds
## nothing); a vacant job counts as a weak one.

## Skill -> -0.75 .. +1.0 around a Good (70) coach.
static func level(v: float) -> float:
	return clampf((v - 70.0) / 20.0, -0.75, 1.0)


const VACANT := 58.0


static func _skill(staff: Dictionary, job: String, key: String) -> float:
	var c: Dictionary = staff.get(job, {})
	return float((c.get("skills", {}) as Dictionary).get(key, VACANT)) if not c.is_empty() else VACANT


static func _fit(staff: Dictionary, job: String) -> float:
	var c: Dictionary = staff.get(job, {})
	return Coaches.role_fit(c, job) if not c.is_empty() else VACANT


## The line coach for a player: midfield & ruck for mids and rucks.
static func line_job(p: Dictionary) -> String:
	match str(p.get("role", "")):
		"FWD":
			return "FWD"
		"DEF":
			return "DEF"
	return "MID"


# ---------------------------------------------------------------------------
# Teaching
# ---------------------------------------------------------------------------
const TEACH_LINE := 0.06     # his line coach, by fit for the job
const TEACH_DEV := 0.05      # the development coach, for kids and the reserves
const TEACH_DEV_OTHER := 0.02
const TEACH_SA := 0.02       # the senior assistant, a little for everyone
const TEACH_MIN := -0.05
const TEACH_MAX := 0.10
const YOUNG := 22.0

## Multiplier on one player's match XP: 0.95 .. 1.10.
static func xp_mult(staff: Dictionary, p: Dictionary, on_ground: bool) -> float:
	var young := float(p.get("age", 25.0)) <= YOUNG or not on_ground
	var b := TEACH_LINE * level(_fit(staff, line_job(p)))
	b += (TEACH_DEV if young else TEACH_DEV_OTHER) * level(_fit(staff, "DEV"))
	b += TEACH_SA * level(_skill(staff, "SA", "teach"))
	return 1.0 + clampf(b, TEACH_MIN, TEACH_MAX)


# ---------------------------------------------------------------------------
# Tactics
# ---------------------------------------------------------------------------
const EXEC_RANGE := 0.25     # a plan's upside scaled 0.81 .. 1.25

## The club's tactical brain: the senior coach and his assistant. At your
## club you are the senior coach, so it is your assistant's.
static func tactics_skill(staff: Dictionary, mine: bool) -> float:
	if mine:
		return _skill(staff, "SA", "tactics")
	return 0.6 * _skill(staff, "SC", "tactics") + 0.4 * _skill(staff, "SA", "tactics")


## {exec, read}: exec scales how much a plan's upside gives (its costs are
## the plan's own);
## read (-0.75 .. 1) is how sharply an AI club reads the match.
static func tactics(staff: Dictionary, mine: bool) -> Dictionary:
	var l := level(tactics_skill(staff, mine))
	return {"exec": 1.0 + EXEC_RANGE * l, "read": l}


## Every club's tactics for the round's matches, derived fresh from the
## records (never saved). Empty outside a career: matches play as before.
static var table := {}


static func set_table(coaches: Dictionary, clubs: Array, my_club: String) -> void:
	table = {}
	var by := staffs(coaches)
	for club in clubs:
		table[club] = tactics(by.get(club, {}), club == my_club)
		table[club]["ai"] = club != my_club
		table[club]["assistant"] = club == my_club


static func for_club(code: String) -> Dictionary:
	return table.get(code, {})


## Give a match squad its club's tactics (no-op outside a career).
static func apply(sq: Squad) -> void:
	var t: Dictionary = for_club(sq.code)
	if t.is_empty():
		return
	sq.tactics_exec = float(t["exec"])
	sq.tactics_read = float(t["read"])
	sq.ai_plans = bool(t["ai"])
	sq.assistant = bool(t.get("assistant", false))


## club -> {job: record}, in one pass over the records.
static func staffs(coaches: Dictionary) -> Dictionary:
	var out := {}
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) != "club":
			continue
		var club := str(c.get("club", ""))
		if not out.has(club):
			out[club] = {}
		out[club][str(c.get("job", ""))] = c
	return out


# ---------------------------------------------------------------------------
# Man-management
# ---------------------------------------------------------------------------
const SOFTEN_MAX := 0.40

## How much of the morale a left-out player loses is spared: 0 .. 0.40. A
## poor man-manager spares nothing; he never makes anyone unhappier.
static func soften(staff: Dictionary, p: Dictionary) -> float:
	var m := 0.6 * _skill(staff, "SA", "manage") + 0.4 * _skill(staff, line_job(p), "manage")
	return SOFTEN_MAX * clampf((m - 65.0) / 25.0, 0.0, 1.0)


## A morale loss after the man-management softening (never below 0 lost).
static func softened(loss: int, s: float) -> int:
	return int(round(float(loss) * (1.0 - s)))
