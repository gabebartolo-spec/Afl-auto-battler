class_name DraftScouting
extends RefCounted
## Club-specific National Draft scouting. Prospects keep one true football
## model, but clubs see a deterministic estimate. Recruiting funding narrows
## the user's uncertainty without changing the prospect underneath.

const OVR_SD := 2.2
const POT_SD := 3.5
const ERROR_CLAMP := 2.4


static func projection(p: Dictionary, club: String, seed: int,
		uncertainty_mult := 1.0) -> Dictionary:
	var ov := int(p.get("overall", 50))
	var pot := maxi(ov, int(p.get("potential", ov)))
	var certainty := _certainty(p)
	var u := maxf(0.25, float(uncertainty_mult))
	var ov_mid := clampi(int(round(float(ov)
			+ _normal(_key(p, club, seed, "ovr")) * OVR_SD * certainty * u)), 1, 99)
	var pot_mid := clampi(int(round(float(pot)
			+ _normal(_key(p, club, seed, "pot")) * POT_SD * certainty * u)), ov_mid, 99)
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


static func estimated_overall(p: Dictionary, club: String, seed: int,
		uncertainty_mult := 1.0) -> int:
	return int(projection(p, club, seed, uncertainty_mult)["overall_mid"])


static func estimated_potential(p: Dictionary, club: String, seed: int,
		uncertainty_mult := 1.0) -> int:
	return int(projection(p, club, seed, uncertainty_mult)["potential_mid"])


static func scouted_worth(p: Dictionary, club: String, seed: int, pot_weight: float,
		uncertainty_mult := 1.0) -> float:
	var view := projection(p, club, seed, uncertainty_mult)
	var ov := float(view["overall_mid"])
	var pot := maxf(ov, float(view["potential_mid"]))
	return ov * (1.0 - pot_weight) + pot * pot_weight


static func range_text(values: Array) -> String:
	if values.size() < 2:
		return "-"
	return "%d-%d" % [int(values[0]), int(values[1])]


## Consensus-ranked prospects are better known. The top of the class is less
## noisy than a speculative late prospect; funding scales both from there.
static func _certainty(p: Dictionary) -> float:
	var rank := maxi(1, int(p.get("draft_rank", 40)))
	return lerpf(0.65, 1.0, clampf(float(rank - 1) / 39.0, 0.0, 1.0))


static func _key(p: Dictionary, club: String, seed: int, suffix: String) -> String:
	return "%d|%s|%s|%s" % [seed, club, str(p.get("id", "")), suffix]


static func _unit(key: String) -> float:
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
