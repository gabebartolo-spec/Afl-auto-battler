class_name DraftScouting
extends RefCounted
## Shared National Draft scouting view. Prospects keep one true football model,
## but clubs only see a deterministic estimate of it. The human and AI use the
## same uncertainty rules; future recruiter/scout quality can narrow these
## estimates without changing the prospect underneath.

const OVR_SD := 2.2
const POT_SD := 3.5
const ERROR_CLAMP := 2.4
const COMBINE_NOISE := 4.0


static func projection(p: Dictionary, club: String, seed: int, uncertainty_mult := 1.0) -> Dictionary:
	var ov := int(p.get("overall", 50))
	var pot := maxi(ov, int(p.get("potential", ov)))
	var certainty := _certainty(p)
	var u := maxf(0.25, float(uncertainty_mult))
	var ov_mid := clampi(int(round(float(ov) + _normal(_key(p, club, seed, "ovr")) * OVR_SD * certainty * u)), 1, 99)
	var pot_mid := clampi(int(round(float(pot) + _normal(_key(p, club, seed, "pot")) * POT_SD * certainty * u)), ov_mid, 99)
	var base_ov_half := 2 if certainty < 0.82 else 3
	var base_pot_half := 4 if certainty < 0.82 else 5
	var ov_half := maxi(1, int(round(float(base_ov_half) * u)))
	var pot_half := maxi(2, int(round(float(base_pot_half) * u)))
	return {
		"overall_mid": ov_mid,
		"potential_mid": pot_mid,
		"overall": [maxi(1, ov_mid - ov_half), mini(99, ov_mid + ov_half)],
		"potential": [maxi(ov_mid, pot_mid - pot_half), mini(99, pot_mid + pot_half)],
	}


static func estimated_overall(p: Dictionary, club: String, seed: int, uncertainty_mult := 1.0) -> int:
	return int(projection(p, club, seed, uncertainty_mult)["overall_mid"])


static func estimated_potential(p: Dictionary, club: String, seed: int, uncertainty_mult := 1.0) -> int:
	return int(projection(p, club, seed, uncertainty_mult)["potential_mid"])


static func scouted_worth(p: Dictionary, club: String, seed: int, pot_weight: float, uncertainty_mult := 1.0) -> float:
	var view := projection(p, club, seed, uncertainty_mult)
	var ov := float(view["overall_mid"])
	var pot := maxf(ov, float(view["potential_mid"]))
	return ov * (1.0 - pot_weight) + pot * pot_weight


static func range_text(values: Array) -> String:
	if values.size() < 2:
		return "-"
	return "%d-%d" % [int(values[0]), int(values[1])]


## A short Combine report built only from attributes the football model
## actually uses. We deliberately do not invent fake 20m-sprint seconds or
## vertical-jump centimetres that the simulation does not model.
static func combine_lines(p: Dictionary, club: String, seed: int, uncertainty_mult := 1.0) -> Array:
	var a: Dictionary = p.get("attr", {})
	if a.is_empty():
		return []
	var movement := 0.65 * float(a.get("carry", 50)) + 0.35 * float(a.get("pressure", 50))
	var repeat := 0.65 * float(a.get("pressure", 50)) + 0.35 * float(a.get("durability", 50))
	var height_score := _height_score(float(p.get("height_cm", 0.0)))
	var aerial := 0.45 * float(a.get("marking", 50)) + 0.35 * float(a.get("contested", 50)) + 0.20 * height_score
	var role := str(p.get("role", "MID"))
	var craft := 50.0
	var craft_label := "Football craft"
	match role:
		"MID":
			craft_label = "Inside work"
			craft = 0.60 * float(a.get("contested", 50)) + 0.25 * float(a.get("disposal", 50)) + 0.15 * float(a.get("pressure", 50))
		"DEF":
			craft_label = "Defensive craft"
			craft = 0.55 * float(a.get("intercept", 50)) + 0.30 * float(a.get("pressure", 50)) + 0.15 * float(a.get("contested", 50))
		"FWD":
			craft_label = "Forward craft"
			craft = 0.45 * float(a.get("goalkicking", 50)) + 0.25 * float(a.get("marking", 50)) + 0.20 * float(a.get("creating", 50)) + 0.10 * float(a.get("accuracy", 50))
		"RUCK":
			craft_label = "Ruck craft"
			craft = 0.70 * float(a.get("ruck", 50)) + 0.20 * float(a.get("contested", 50)) + 0.10 * height_score
			aerial = 0.45 * float(a.get("ruck", 50)) + 0.30 * float(a.get("contested", 50)) + 0.15 * float(a.get("marking", 50)) + 0.10 * height_score
	return [
		_line("Movement", movement, p, club, seed, "move", uncertainty_mult),
		_line("Repeat effort", repeat, p, club, seed, "repeat", uncertainty_mult),
		_line("Aerial / contest", aerial, p, club, seed, "aerial", uncertainty_mult),
		_line(craft_label, craft, p, club, seed, "craft", uncertainty_mult),
	]


static func _line(label: String, score: float, p: Dictionary, club: String, seed: int, suffix: String,
		uncertainty_mult := 1.0) -> Dictionary:
	var seen := clampf(score + _normal(_key(p, club, seed, suffix)) * COMBINE_NOISE * maxf(0.25, uncertainty_mult), 1.0, 99.0)
	return {"label": label, "grade": _grade(seen)}


static func _grade(score: float) -> String:
	if score >= 78.0:
		return "Standout"
	if score >= 68.0:
		return "Strong"
	if score >= 58.0:
		return "Above average"
	if score >= 46.0:
		return "Solid"
	if score >= 36.0:
		return "Developing"
	return "Below average"


static func _height_score(height: float) -> float:
	if height <= 0.0:
		return 50.0
	return clampf((height - 170.0) / 38.0 * 100.0, 1.0, 99.0)


## Consensus-ranked prospects are better known. The range still exists, but
## the top of the pool is less noisy than a late speculative prospect.
static func _certainty(p: Dictionary) -> float:
	var rank := maxi(1, int(p.get("draft_rank", 40)))
	return lerpf(0.65, 1.0, clampf(float(rank - 1) / 39.0, 0.0, 1.0))


static func _key(p: Dictionary, club: String, seed: int, suffix: String) -> String:
	return "%d|%s|%s|%s" % [seed, club, str(p.get("id", "")), suffix]


static func _unit(key: String) -> float:
	# Avalanche String.hash() before using it as a random draw. Nearby keys
	# ("ovr" / "pot", adjacent prospect IDs) should not produce nearby errors.
	var h := key.hash() & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x85ebca6b) & 0xFFFFFFFF
	h ^= h >> 13
	h = (h * 0xc2b2ae35) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFFFF) / float(0x1000000)


static func _normal(key: String) -> float:
	var u1 := maxf(0.000001, _unit("a|" + key))
	var u2 := _unit("b|" + key)
	var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return clampf(z, -ERROR_CLAMP, ERROR_CLAMP)