class_name Injuries
extends RefCounted
## Match injuries. Rolled after each game for the 18 who took the field -
## outside MatchSim, so the engine's RNG and calibration are untouched - and
## seeded by season, round and player, so a reloaded save replays the same
## injuries. Durability finally matters: it scales the chance from about half
## the base rate (99) to about 1.3x (low). An injured player carries
## injury_weeks and misses that many of his club's matches; everyone heals
## over the off-season.

## Base chance per player per game. With 18 on the ground this lands near
## real AFL rates: a new injury for most sides most weeks.
const BASE_CHANCE := 0.042
## [weeks_min, weeks_max, share]: mostly short, the odd season-ender.
const SEVERITY := [[1, 1, 0.42], [2, 2, 0.24], [3, 4, 0.19], [5, 8, 0.12], [9, 16, 0.03]]
const KINDS := ["hamstring", "ankle", "knee", "shoulder", "calf", "concussion",
		"groin", "quad", "hip", "foot", "back", "hand"]


## Chance this player is injured in a game he plays.
static func chance(p: Dictionary) -> float:
	var dur := float((p.get("attr", {}) as Dictionary).get("durability", 50))
	var sore := 4.0 if bool(p.get("sore", false)) else 1.0
	return BASE_CHANCE * clampf(1.5 - dur / 100.0, 0.5, 1.3) * sore


## After a match: roll for everyone who took the field. `lists` maps club
## code -> list. Returns the new injuries: [{id, club, weeks, kind}].
static func roll_match(res: Dictionary, lists: Dictionary, season_seed: int, round_no: int) -> Array:
	var out := []
	var roster: Array = res.get("roster", [])
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	for side in range(mini(2, roster.size())):
		var code: String = codes[side]
		if not lists.has(code):
			continue
		var by_id := {}
		for p in lists[code]:
			by_id[str(p["id"])] = p
		for r in roster[side]:
			var p = by_id.get(str(r["id"]))
			if p == null or int(p.get("injury_weeks", 0)) > 0:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("inj|%d|%d|%s" % [season_seed, round_no, str(p["id"])])
			if rng.randf() >= chance(p):
				continue
			var weeks := _severity(rng)
			var kind: String = KINDS[rng.randi_range(0, KINDS.size() - 1)]
			p["injury_weeks"] = weeks
			p["injury_kind"] = kind
			out.append({"id": str(p["id"]), "club": code, "weeks": weeks, "kind": kind})
	return out


## A week passes for a club that just played: every existing injury is one
## game closer to healed. Call before rolling that round's new injuries.
static func tick(list: Array) -> void:
	for p in list:
		var w := int(p.get("injury_weeks", 0))
		if w > 0:
			p["injury_weeks"] = w - 1
			if w - 1 == 0:
				p.erase("injury_kind")


static func heal_all(lists: Dictionary) -> void:
	for code in lists:
		for p in lists[code]:
			p.erase("injury_weeks")
			p.erase("injury_kind")


static func injured(list: Array) -> Array:
	var out := []
	for p in list:
		if int(p.get("injury_weeks", 0)) > 0:
			out.append(p)
	return out


static func _severity(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var acc := 0.0
	for band in SEVERITY:
		acc += float(band[2])
		if roll <= acc:
			return rng.randi_range(int(band[0]), int(band[1]))
	return 1
