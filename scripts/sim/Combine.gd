class_name Combine
extends RefCounted
## The National Draft Combine (ARD-M5-014, director 2026-10-07): the tests a
## prospect sits before the draft, as results with units - the 20 m sprint,
## the 2 km time trial, the running vertical jump and the kicking test. Each
## result comes from what the game knows of him (the same reads as the
## scouts' Combine notes, DraftScouting) plus the day itself, so a quick
## player runs a quick time but not always the same one. Measured, so every
## club sees the same numbers; the scouts' read of his football stays their
## own. A prospect who missed testing has no result, never an invented one.
## Seeded by the draft and the player: a reload shows the same day.

## [key, name, unit, lower is better, what it says about his football]
const TESTS := [
	["sprint", "20 m sprint", "s", true, "Acceleration: getting away from an opponent, or running one down."],
	["trial", "2 km time trial", "", true, "Running capacity: covering the ground and backing up late in a game."],
	["leap", "Running vertical jump", "cm", false, "Spring: getting up in a marking contest or at a ruck contest."],
	["kick", "Kicking test", "/ 30", false, "Clean, accurate kicking over set distances while tired."],
]
const MISSED := 0.07          # share of a class that misses testing (injury, illness)
const DAY_SD := {"sprint": 0.025, "trial": 6.0, "leap": 2.5, "kick": 1.1}


static func test(key: String) -> Array:
	for t in TESTS:
		if str(t[0]) == key:
			return t
	return []


## Did he test? Most of a class does.
static func tested(p: Dictionary, seed: int) -> bool:
	return DraftScouting._unit(_key(p, seed, "missed")) >= MISSED


## His result in one test, in its unit (seconds, cm, points out of 30); -1
## when he did not test.
static func result(p: Dictionary, key: String, seed: int) -> float:
	if not tested(p, seed) or not p.has("attr"):
		return -1.0
	var r := reads(p)
	var day := DraftScouting._normal(_key(p, seed, key)) * float(DAY_SD.get(key, 0.0))
	match key:
		"sprint":
			return snappedf(clampf(3.18 - float(r["move"]) / 100.0 * 0.36 + day, 2.78, 3.30), 0.01)
		"trial":
			return roundf(clampf(410.0 - float(r["repeat"]) / 100.0 * 70.0 + day, 335.0, 430.0))
		"leap":
			return roundf(clampf(56.0 + float(r["aerial"]) / 100.0 * 36.0 + day, 48.0, 98.0))
		"kick":
			return roundf(clampf(13.0 + float(r["kick"]) / 100.0 * 15.0 + day, 8.0, 30.0))
	return -1.0


## The modelled abilities each test reads (0-100), shared with the scouts'
## Combine notes.
static func reads(p: Dictionary) -> Dictionary:
	var a: Dictionary = p.get("attr", {})
	var height := float(p.get("height_cm", 0.0))
	var hs := 50.0 if height <= 0.0 else clampf((height - 170.0) / 38.0 * 100.0, 1.0, 99.0)
	var aerial := 0.45 * float(a.get("marking", 50)) + 0.35 * float(a.get("contested", 50)) + 0.20 * hs
	if str(p.get("role", "")) == "RUCK":
		aerial = 0.45 * float(a.get("ruck", 50)) + 0.30 * float(a.get("contested", 50)) \
				+ 0.15 * float(a.get("marking", 50)) + 0.10 * hs
	return {
		"move": 0.65 * float(a.get("carry", 50)) + 0.35 * float(a.get("pressure", 50)),
		"repeat": 0.65 * float(a.get("pressure", 50)) + 0.35 * float(a.get("durability", 50)),
		"aerial": aerial,
		"kick": 0.60 * float(a.get("disposal", 50)) + 0.40 * float(a.get("accuracy", 50)),
	}


## A result as it reads: "2.94 s", "6:12", "78 cm", "24 / 30", or "Did not test".
static func text(key: String, value: float) -> String:
	if value < 0.0:
		return "Did not test"
	match key:
		"sprint":
			return "%.2f s" % value
		"trial":
			return "%d:%02d" % [int(value) / 60, int(value) % 60]
		"leap":
			return "%d cm" % int(value)
		"kick":
			return "%d / 30" % int(value)
	return str(value)


## Where a result sits in this class, in words: best in the class, top ten,
## above or below the middle. `field` is every tested result in the class.
static func standing(key: String, value: float, field: Array) -> String:
	if value < 0.0 or field.is_empty():
		return ""
	var low_best := bool(test(key)[3])
	var better := 0
	for f in field:
		if (float(f) < value) if low_best else (float(f) > value):
			better += 1
	if better == 0:
		return "Best in the class"
	if better < 10:
		return "Top ten"
	var share := float(better) / float(field.size())
	if share < 0.25:
		return "Top quarter"
	if share < 0.5:
		return "Above the middle"
	if share < 0.75:
		return "Below the middle"
	return "Bottom quarter"


## Every tested result in `pool` for one test.
static func field(pool: Array, key: String, seed: int) -> Array:
	var out := []
	for p in pool:
		var r := result(p, key, seed)
		if r >= 0.0:
			out.append(r)
	return out


## Sort `rows` best first on one test; those who did not test go last.
static func sort_rows(rows: Array, key: String, seed: int) -> Array:
	var low_best := bool(test(key)[3])
	var scored := []
	for p in rows:
		scored.append([result(p, key, seed), p])
	scored.sort_custom(func(a, b):
		var x := float(a[0])
		var y := float(b[0])
		if x < 0.0 or y < 0.0:
			return y < 0.0 and x >= 0.0
		return x < y if low_best else x > y)
	var out := []
	for s in scored:
		out.append(s[1])
	return out


static func _key(p: Dictionary, seed: int, suffix: String) -> String:
	return "combine|%d|%s|%s" % [seed, str(p.get("id", "")), suffix]
