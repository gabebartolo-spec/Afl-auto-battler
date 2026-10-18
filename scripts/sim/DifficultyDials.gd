class_name DifficultyDials
extends RefCounted
## The two difficulty dials chosen at New career (director, 2026-10-18: "two
## named difficulty dials; I set the sizes in playtest"): board patience and
## rival recruiting, each with three named steps. Every size is in
## data/difficulty_dials.json; this file only reads it.
##
## Difficulty never changes how players develop, and it gives the rival clubs
## no hidden information or rating boost: it moves how long the board waits
## and how hard rivals bargain over trades with you, nothing else.

const PATH := "res://data/difficulty_dials.json"
const BOARD := "board_patience"
const RIVALS := "rival_recruiting"
const DIALS := [BOARD, RIVALS]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func _dial(dial: String) -> Dictionary:
	return data().get(dial, {})


static func title(dial: String) -> String:
	return str(_dial(dial).get("title", dial))


## The steps of a dial, mildest first.
static func order(dial: String) -> Array:
	return _dial(dial).get("order", [])


static func default_key(dial: String) -> String:
	return str(_dial(dial).get("default", ""))


## `key` if it is a step of `dial`, else the dial's middle step.
static func normalize(dial: String, key: String) -> String:
	return key if order(dial).has(key) else default_key(dial)


## One step: {"label", "text", ...its sizes}.
static func step(dial: String, key: String) -> Dictionary:
	return (_dial(dial).get("steps", {}) as Dictionary).get(normalize(dial, key), {})


static func label(dial: String, key: String) -> String:
	return str(step(dial, key).get("label", key))


static func text(dial: String, key: String) -> String:
	return str(step(dial, key).get("text", ""))


## The pair an old Easy / Normal / Hard save loads on: {dial: step}. Every old
## save gets the Fair board (the old setting never touched the board); only the
## rivals follow the old setting.
static func from_legacy(difficulty: String) -> Dictionary:
	var legacy: Dictionary = data().get("legacy", {})
	var pair: Array = legacy.get(difficulty, legacy.get("normal", [default_key(BOARD), default_key(RIVALS)]))
	return {BOARD: normalize(BOARD, str(pair[0])), RIVALS: normalize(RIVALS, str(pair[1]))}
