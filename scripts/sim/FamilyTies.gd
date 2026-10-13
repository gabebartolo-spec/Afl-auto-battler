class_name FamilyTies
extends RefCounted
## Generated families (director, 2026-10-13: "yes of course", fathers and sons
## "doesn't need to be based on reality"). Now and then a generated draftee is
## the brother of a listed player or the son of an older one (still playing, or
## retired). The tie is bio only: it is stored on the draftee as p["family"],
## a list of {"relation": "brother" | "son of", "id", "club", "former"}, and
## the draftee takes the other man's surname. It changes no rating, no draft
## order and nothing a match reads. The rolls use their own seeded stream, so
## the football RNG never moves.
##
## Rates are the director's to call; these are proposals (see the PR body).
const SON_RATE := 0.03
const BROTHER_RATE := 0.04
## A son drafted at 18 needs a father who is at least about 36.
const FATHER_MIN_AGE := 36.0
const FATHER_MAX_AGE := 56.0
const FATHER_MIN_GAP := 17.0
const BROTHER_MIN_AGE := 18.0
const BROTHER_MAX_GAP := 10.0


## Entries for the people a draftee could be related to: {"id", "age" (at the
## draft), "club", "retired", "generic", "real"}.
static func listed_entries(players: Array, age_shift: float) -> Array:
	var out: Array = []
	for p in players:
		out.append({"id": str(p.get("id", "")), "age": float(p.get("age", 0.0)) + age_shift,
				"club": str(p.get("club", "")), "retired": false,
				"generic": str(p.get("generic_name", p.get("name", ""))),
				"real": _real_last(p)})
	return out


## Retired players kept in departed_names (the card carries age, year, club).
static func retired_entries(cards: Dictionary, year: int) -> Array:
	var out: Array = []
	for id in cards:
		var c: Dictionary = cards[id]
		if not c.has("age"):
			continue
		out.append({"id": str(id), "age": float(c["age"]) + float(year - int(c.get("year", year))),
				"club": str(c.get("club", "")), "retired": true,
				"generic": str(c.get("generic_name", "")), "real": _real_last(c)})
	return out


static func _real_last(p: Dictionary) -> String:
	if str(p.get("real_name", "")).strip_edges() == "":
		return ""
	var last := str(p.get("last", "")).strip_edges()
	if last != "":
		return last
	return str(p["real_name"]).strip_edges().get_slice(" ", 1)


static func _surname(label: String) -> String:
	var bits := label.strip_edges().split(" ", false)
	return bits[bits.size() - 1] if bits.size() > 1 else ""


## Roll the class. Returns how many ties were made. Deterministic from the
## year and the career seed.
static func assign(cls: Array, year: int, career_seed: int, entries: Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["family", year, career_seed])
	var pool := entries.duplicate()
	pool.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var used := {}
	var made := 0
	for p in cls:
		if not bool(p.get("generated", false)) or p.has("family"):
			continue
		var roll := rng.randf()
		var pick := rng.randf()   # always drawn, so a change elsewhere never shifts later rolls
		var age := float(p.get("age", 18.0))
		var relation := ""
		var cands: Array = []
		if roll < SON_RATE:
			relation = "son of"
			for e in pool:
				var a: float = e["age"]
				if not used.has(e["id"]) and a >= maxf(FATHER_MIN_AGE, age + FATHER_MIN_GAP) and a <= FATHER_MAX_AGE:
					cands.append(e)
		elif roll < SON_RATE + BROTHER_RATE:
			relation = "brother"
			for e in pool:
				var a: float = e["age"]
				if not used.has(e["id"]) and not bool(e["retired"]) and a >= BROTHER_MIN_AGE \
						and absf(a - age) <= BROTHER_MAX_GAP and str(e["generic"]) != "":
					cands.append(e)
		if relation == "" or cands.is_empty():
			continue
		var other: Dictionary = cands[int(pick * cands.size()) % cands.size()]
		used[other["id"]] = true
		p["family"] = [{"relation": relation, "id": str(other["id"]), "club": str(other["club"]),
				"former": bool(other["retired"])}]
		var last := _surname(str(other["generic"]))
		if last != "":
			var first := str(p.get("generic_name", "")).get_slice(" ", 0)
			p["generic_name"] = "%s %s" % [first, last]
			p["name"] = p["generic_name"]
		if str(other["real"]) != "":
			p["family_real_last"] = str(other["real"])
		made += 1
	return made
