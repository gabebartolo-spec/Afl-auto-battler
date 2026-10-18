class_name InternationalProspects
extends RefCounted
## International prospects in the generated draft classes (director, 2026-10-14:
## "1-2 each draft like USA, African countries, New Zealand, Ireland").
##
## One or two prospects in each generated class come from another country and
## another code - Gaelic football, rugby, college basketball, athletics. They
## are raw: lower rating today, a bigger ceiling, and recruiters are less sure
## of them (DraftScouting widens their range). Once drafted they are ordinary
## players. Everything about them sits in data/international_prospects.json.
##
## Behind the "international_prospects" switch (Features.gd). Switched off,
## apply() does nothing and generate_class() is identical to before.

const PATH := "res://data/international_prospects.json"
const FEATURE := "international_prospects"
## A raw prospect's rating today sits this far under his rank's, and his
## ceiling this far over (the Potential room), because he is new to the game.
const RAW_SHIFT := -5.0
const RAW_CEILING := 5.0
## How much wider recruiters' ranges on him are.
const SCOUT_UNCERTAINTY := 1.5

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"countries": []}
	return _data


static func countries() -> Array:
	return data().get("countries", [])


static func country(id: String) -> Dictionary:
	for c in countries():
		if str(c["id"]) == id:
			return c
	return {}


static func is_international(p: Dictionary) -> bool:
	return str(p.get("intl", "")) != ""


## "Ireland", "the USA" for a prospect; "" for anyone else.
static func country_name(p: Dictionary) -> String:
	return str(country(str(p.get("intl", ""))).get("name", ""))


## "ireland", "nz", "usa" or "africa" for a prospect; "" for anyone else (the story cards use it).
static func region(p: Dictionary) -> String:
	return str(country(str(p.get("intl", ""))).get("region", ""))


## A short plain note for his profile: where from and why scouts are unsure.
static func note(p: Dictionary) -> String:
	if not is_international(p):
		return ""
	var c := country(str(p["intl"]))
	if c.is_empty():
		return ""
	return "International prospect from %s. New to our game, so recruiters are less sure of him." \
			% str(c.get("from", c["name"]))


## Adds the class's international prospects. Called by Prospects.generate_class
## once the class exists (after names are handed out). Own seeded dice by year
## only, so the rest of the class is untouched.
static func apply(cls: Array, year: int) -> void:
	if not Features.on(FEATURE) or cls.is_empty():
		return
	var d := data()
	var all: Array = countries()
	if all.is_empty():
		return
	var rng := Prospects._rng_for("intl-class-%d" % year)
	var n := 2 if rng.randf() < float(d.get("class_chance_of_two", 0.3)) else 1
	var min_rank := int(d.get("min_rank", 11))
	var used_countries := {}
	var used_slots := {}
	for _i in range(n):
		var c := _pick_weighted(all, rng, used_countries)
		if c.is_empty():
			break
		used_countries[str(c["id"])] = true
		var slot := rng.randi_range(min_rank - 1, cls.size() - 1)
		while used_slots.has(slot) or bool(cls[slot].get("unicorn", false)):   # the class's Unicorn stays
			slot = rng.randi_range(min_rank - 1, cls.size() - 1)
		used_slots[slot] = true
		var taken := {}   # surnames already in this class, bar the player he replaces
		for j in range(cls.size()):
			if j != slot:
				var nm := str(cls[j].get("generic_name", ""))
				taken[nm.substr(nm.find(" ") + 1)] = true
		_make(cls[slot], c, year, rng, taken)


static func _pick_weighted(list: Array, rng: RandomNumberGenerator, skip := {}) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for c in list:
		if skip.has(str(c.get("id", ""))):
			continue
		pool.append(c)
		total += float(c.get("weight", 1))
	if pool.is_empty():
		return {}
	var roll := rng.randf() * total
	for c in pool:
		roll -= float(c.get("weight", 1))
		if roll < 0.0:
			return c
	return pool[pool.size() - 1]


static func _pick_role(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	var last := "MID"
	for k in weights:
		last = str(k)
		roll -= float(weights[k])
		if roll < 0.0:
			return last
	return last


static func _span(r: Array, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(int(r[0]), int(r[1]))


## Turns a generated prospect into the country's: who he is, where from, how he
## plays. The slot (draft rank, id, class shifts) stays his.
static func _make(p: Dictionary, c: Dictionary, year: int, rng: RandomNumberGenerator, taken := {}) -> void:
	var group := _pick_weighted(c["groups"], rng)
	var first := str(group["first"][rng.randi_range(0, (group["first"] as Array).size() - 1)])
	var last := str(group["last"][rng.randi_range(0, (group["last"] as Array).size() - 1)])
	for _t in range(30):   # no two players in a class share a surname
		if not taken.has(last):
			break
		last = str(group["last"][rng.randi_range(0, (group["last"] as Array).size() - 1)])
	var role := _pick_role(c["roles"], rng)
	var h := float(_span(c["height"], rng))
	match role:
		"RUCK": h = maxf(h, 198.0)
		"FWD": h = maxf(h, float(Prospects.FWD_MIN_CM))
		_: pass
	h = minf(h, 208.0)
	var way: Dictionary = c["pathways"][rng.randi_range(0, (c["pathways"] as Array).size() - 1)]
	var age_years := _span(c["age"], rng)
	p["role"] = role
	p["role2"] = Prospects._generated_secondary(role, rng)
	p["height_cm"] = h
	p["dob"] = "%04d-%02d-%02d" % [year - age_years, rng.randi_range(1, 12), rng.randi_range(1, 28)]
	p["age"] = float(Prospects.days_between(str(p["dob"]), "%d-11-20" % year)) / 365.25
	p["club"] = str(way["team"])
	p["draft_team"] = str(way["team"])
	p["draft_league"] = str(way["league"])
	p["draft_state"] = str(c["name"])
	p["state"] = ""
	var u: Dictionary = c["u18"]
	p["u18_gm"] = float(_span(u["gm"], rng))
	p["u18_di"] = float(_span(u["di"], rng))
	p["u18_mk"] = float(_span(u["mk"], rng))
	p["u18_tk"] = float(_span(u["tk"], rng))
	p["u18_gl"] = float(rng.randi_range(0, 8)) / 10.0 if role != "FWD" else float(rng.randi_range(3, 15)) / 10.0
	p["u18_if50"] = float(rng.randi_range(0, 3))
	p["u18_ho"] = float(rng.randi_range(8, 16)) if role == "RUCK" else 0.0
	p["intl"] = str(c["id"])
	p["intl_first"] = first
	p["intl_last"] = last
	p["generic_name"] = "%s %s" % [first, last]
	p["name"] = p["generic_name"]
	p["real_name"] = ""
	p["attr_bias"] = c.get("bias", {}).duplicate()
	p["class_shift"] = float(p.get("class_shift", 0.0)) + RAW_SHIFT
	p["class_ceiling"] = float(p.get("class_ceiling", 0.0)) + RAW_CEILING
	p["real_pos"] = Ratings.ROLE_SHORT_TO_POS.get(role, "MID")
	p.erase("family")
	p.erase("family_real_last")
	Prospects.project(p)
