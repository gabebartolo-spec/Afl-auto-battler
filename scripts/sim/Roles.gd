class_name Roles
extends RefCounted
## A footballer's job on match day, beyond his position. Deliberately small:
## only jobs the match engine actually rewards.
##
##  - Wing (position MID). Two of the five midfield spots are the wings. A
##    wing is not at the stoppage: the engine counts contested ball only from
##    the three centre-square midfielders, and on the wing a player gets more
##    of the ball in transition, where his carry and disposal gain the ground.
##    So a natural wing - a runner who uses it - beats a better-rated inside
##    midfielder out there, and a ball-winner is wasted on the wing.
##  - Tagger (position MID, a stopper: pressure well ahead of his own
##    ball-winning). When you tag an opponent in
##    the coach box, a tagger on the ground takes more of the ball off him.
##  - Everyone else keeps the identity his attributes give him (inside
##    midfielder, key forward, ...), from the same vocabulary Training uses.

const WING_SLOTS := 2
## A MID whose running game outweighs his ball-winning by this much (both
## as a share of 2026 midfielders) reads as a wing.
const WING_MARGIN := 0.12
## How much more of the transition ball a wing gets, and how much less of
## the stoppage ball (MatchSim.pick_carrier / _stoppage).
const WING_TRANSITION := 1.6
const WING_STOPPAGE := 0.4
## A tag with a tagger on the ground: the tagged player's share of the ball
## (MatchSim; 0.55 without one).
const TAG_WITH_TAGGER := 0.42
const TAG_PLAIN := 0.55
## A tagger's pressure, as a share of 2026 midfielders, and how far it must
## outrun his contested ball.
const TAGGER_PRESSURE := 0.70
const TAGGER_MARGIN := 0.20


## What the wing rewards: carry and disposal. Raw attribute blend.
static func wing_fit(p: Dictionary) -> float:
	var a: Dictionary = p.get("attr", {})
	return 0.55 * float(a.get("carry", 0)) + 0.45 * float(a.get("disposal", 0))


## What the centre square rewards: contested ball first.
static func centre_fit(p: Dictionary) -> float:
	var a: Dictionary = p.get("attr", {})
	return 0.75 * float(a.get("contested", 0)) + 0.25 * float(a.get("disposal", 0))


static func is_mid(p: Dictionary) -> bool:
	return str(p.get("role", "")) == "MID" or str(p.get("role2", "")) == "MID"


## A natural wing: a midfielder whose running game (against other 2026
## midfielders) clearly outweighs his ball-winning.
static func is_wing(p: Dictionary) -> bool:
	if not is_mid(p) or str(p.get("role", "")) == "RUCK":
		return false
	var mid_view := p.duplicate()
	mid_view["role"] = "MID"
	var run := 0.5 * (PlayerProfile.percentile(mid_view, "carry") + PlayerProfile.percentile(mid_view, "disposal"))
	var win := PlayerProfile.percentile(mid_view, "contested")
	return run - win >= WING_MARGIN


## A tagger: a midfielder whose game is stopping others - elite pressure
## that clearly outweighs both his ball-winning and his running. A star
## ball-winner who can also tackle is an inside midfielder, not a tagger.
static func is_tagger(p: Dictionary) -> bool:
	if str(p.get("role", "")) != "MID" or not p.has("attr"):
		return false
	var mid_view := p.duplicate()
	mid_view["role"] = "MID"
	var press := PlayerProfile.percentile(mid_view, "pressure")
	var win := PlayerProfile.percentile(mid_view, "contested")
	var run := 0.5 * (PlayerProfile.percentile(mid_view, "carry") + PlayerProfile.percentile(mid_view, "disposal"))
	return press >= TAGGER_PRESSURE and press - maxf(win, run) >= TAGGER_MARGIN


## His football identity in two or three words: "Wing", "Tagger",
## "Inside midfielder", "Key forward", "Ruck"...
static func label(p: Dictionary) -> String:
	if p.is_empty() or not p.has("attr"):
		return ""
	var role := str(p.get("role", ""))
	if role == "MID":
		if is_tagger(p):
			return "Tagger"
		if is_wing(p):
			return "Wing"
		return "Inside midfielder"
	return PlayerProfile.player_type(p)


## Which of the midfielders on the ground play the wings: the named ones
## first, then the best runners among the rest. Marks copy["line"] = "WING"
## on the slot copies (never the list player). `ground` holds slot copies.
static func mark_wings(ground: Array, named: Array = []) -> void:
	var mids := []
	for p in ground:
		if str(p.get("role", "")) == "MID":
			p.erase("line")
			mids.append(p)
	var wings := []
	for p in mids:
		if named.has(str(p["id"])) and wings.size() < WING_SLOTS:
			wings.append(p)
	var rest := []
	for p in mids:
		if not wings.has(p):
			rest.append(p)
	# The rest: whoever the stoppage misses least, so a star ball-winner is
	# never parked on a wing; among equals, the better runner.
	rest.sort_custom(func(a, b):
		var ca := centre_fit(a)
		var cb := centre_fit(b)
		if not is_equal_approx(ca, cb):
			return ca < cb
		if not is_equal_approx(wing_fit(a), wing_fit(b)):
			return wing_fit(a) > wing_fit(b)
		return str(a["id"]) < str(b["id"]))
	for p in rest:
		if wings.size() >= WING_SLOTS or mids.size() - wings.size() <= 1:
			break
		wings.append(p)
	for p in wings:
		p["line"] = "WING"


static func on_wing(p: Dictionary) -> bool:
	return str(p.get("line", "")) == "WING"


## A fact for the Selection row, or "": a player named on a wing who is
## not a natural one. (A natural wing named in the centre square already
## reads "Wing" - no advice either way.)
static func fit_note(p: Dictionary, slot: String) -> String:
	if slot == "WING" and not is_wing(p):
		return "Not a natural wing"
	return ""
