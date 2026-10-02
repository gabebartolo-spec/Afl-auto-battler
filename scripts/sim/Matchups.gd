class_name Matchups
extends RefCounted
## Key forward v key defender (Gate 1.12): the one named match-up the engine
## plays out. When an entry inside 50 goes to a forward who has a direct
## opponent, the marking contest is between those two men - his marking and
## size against the defender's reading of the ball, his own marking and size -
## on top of the lines' strength (MatchSim.resolve_forward50). Everywhere else
## the lines decide as before.
##
## Each side sets a direct opponent on the other side's key forwards (at most
## KEY_FORWARDS). The default is how a coach sets up before he looks closely:
## his best key defenders, by rating, on their best key forwards, by rating.
## Reading who is tall and strong overhead can do better - or worse.
##
## Pure rules on match-day sides; no state.

const KEY_FORWARDS := 2
## The share of a side's entries inside 50 that look for one of its key
## forwards, into his match-up (the rest go wherever the play takes them).
## Kept small so goals still spread as in the real game: a club's top
## goalkicker kicks about 16% of its goals (run_calibration_tests).
const KEY_TARGET := 0.06
## A key forward beaten in the air by his man keeps this share of his chance
## of scoring from the entry (the ball spills or is cleared).
const BEATEN_SHOT := 0.5
## The most a matched forward can mark (the lines alone stop at 0.78).
const DUEL_CAP := 0.90
## Height evidence runs 0 -> 100 across this range (cm); no height on record
## counts as the middle.
const AIR_CM := [178.0, 200.0]
## How far one match-up moves a marking contest: the gap between the two
## men's aerial games over this many points shifts the mark chance by 1.0.
const DUEL_SCALE := 110.0
## The typical gap between a key forward and the key defender a coach puts on
## him by default: a default match-up leaves the lines to decide on average.
const DUEL_CENTRE := 8.0


static func _height_score(p: Dictionary) -> float:
	var h := float(p.get("height_cm", 0.0))
	if h <= 0.0:
		return 50.0
	return clampf((h - AIR_CM[0]) / (AIR_CM[1] - AIR_CM[0]), 0.0, 1.0) * 100.0


static func _a(p: Dictionary, key: String) -> float:
	return float((p.get("attr", {}) as Dictionary).get(key, 50.0))


## A forward's game in the air: his marking and his size.
static func forward_air(p: Dictionary) -> float:
	return 0.7 * _a(p, "marking") + 0.3 * _height_score(p)


## A defender's game in the air: reading the ball, his own marking, his size.
static func defender_air(p: Dictionary) -> float:
	return 0.45 * _a(p, "intercept") + 0.30 * _a(p, "marking") + 0.25 * _height_score(p)


## The shift in the forward's chance of marking when these two contest it.
static func mark_shift(fwd: Dictionary, dfn: Dictionary) -> float:
	return (forward_air(fwd) - defender_air(dfn) - DUEL_CENTRE) / DUEL_SCALE


static func _is_key_forward(p: Dictionary) -> bool:
	return str(p.get("role", "")) == "FWD" and PlayerProfile.forward_type(p) == "Key forward"


## Their forwards who get a direct opponent: key forwards first, best rated
## first; with none, their best rated forward.
static func key_forwards(ground: Array) -> Array:
	var keys := []
	var fwds := []
	for p in ground:
		if str(p.get("role", "")) != "FWD":
			continue
		fwds.append(p)
		if _is_key_forward(p):
			keys.append(p)
	var by_ovr := func(a, b):
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"])
	keys.sort_custom(by_ovr)
	if keys.is_empty() and not fwds.is_empty():
		fwds.sort_custom(by_ovr)
		keys = [fwds[0]]
	return keys.slice(0, KEY_FORWARDS)


## The defenders a coach can put on a forward: the defenders on the ground.
static func defenders(ground: Array) -> Array:
	var out := []
	for p in ground:
		if str(p.get("role", "")) == "DEF":
			out.append(p)
	out.sort_custom(func(a, b):
		var ka := PlayerProfile.player_type(a) == "Key defender"
		var kb := PlayerProfile.player_type(b) == "Key defender"
		if ka != kb:
			return ka
		if int(a["overall"]) != int(b["overall"]):
			return int(a["overall"]) > int(b["overall"])
		return str(a["id"]) < str(b["id"]))
	return out


## The default set-up: key defenders by rating on their key forwards by
## rating. {forward id: defender id}.
static func defaults(attack_ground: Array, defence_ground: Array) -> Dictionary:
	var out := {}
	var defs := defenders(defence_ground)
	var i := 0
	for f in key_forwards(attack_ground):
		if i >= defs.size():
			break
		out[str(f["id"])] = str(defs[i]["id"])
		i += 1
	return out


## Suitability to roam as the spare: reading the ball and marking first,
## defensive pressure second. OVR and height are deliberately not inputs.
static func interceptor_score(p: Dictionary) -> float:
	var score := 0.55 * _a(p, "intercept") + 0.30 * _a(p, "marking") + 0.15 * _a(p, "pressure")
	var traits: Array = Traits.of(p)
	if traits.has("interceptor"):
		score += 6.0
	return score


## Defenders who can be used loose, best football fit first.
static func interceptor_candidates(ground: Array) -> Array:
	var out := defenders(ground)
	out.sort_custom(func(a, b):
		var sa := interceptor_score(a)
		var sb := interceptor_score(b)
		if not is_equal_approx(sa, sb):
			return sa > sb
		return str(a.get("id", "")) < str(b.get("id", "")))
	return out


## Empty when the side has nobody credible enough to justify sacrificing a
## direct assignment for the role.
static func best_interceptor(ground: Array, minimum := 66.0) -> Dictionary:
	var candidates := interceptor_candidates(ground)
	if candidates.is_empty() or interceptor_score(candidates[0]) < minimum:
		return {}
	return candidates[0]


## A player in a coach's words for a match-up: "Key defender, 196 cm".
static func describe(p: Dictionary) -> String:
	var bits := PackedStringArray([PlayerProfile.player_type(p)])
	if float(p.get("height_cm", 0.0)) > 0.0:
		bits.append("%d cm" % int(p["height_cm"]))
	return ", ".join(bits)
