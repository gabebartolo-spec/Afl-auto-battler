class_name Appearance
extends RefCounted
## How a player looks on the vignette figures: a skin tone and a hair colour.
## Presentation only - never a gameplay attribute, never read by the sim, and
## never inferred from a name.
##
## Real players: curated in data/player_appearance.csv (GameDB loads it), each
## row drafted from a public photo and reviewed by the director.
## Generated players (future draft classes, expansion lists): a look drawn from
## the player's id alone - stable across saves, independent of ratings, role,
## potential or any other trait - weighted to the real league's mix.
## Real players not curated yet (and the real 2026 draft class until it is):
## one neutral look, UNCURATED - a real person is never given a guessed tone.

## Six skin tones, lightest to deepest (1-6 in the data; 0-5 here).
const SKIN := [Color("#f6d8c2"), Color("#e2ad85"), Color("#b97e52"), Color("#8c5633"),
		Color("#5f361f"), Color("#3a2215")]
const HAIR_KEYS := ["black", "dark_brown", "brown", "light_brown", "blond", "red"]
const UNCURATED := {"skin": 2, "hair": 1}
const HAIR := [Color("#241b16"), Color("#40291f"), Color("#563621"), Color("#86603a"),
		Color("#c19a5b"), Color("#8a3b1d")]

## The league's mix of tones, for players without a curated look. Replaced by
## the curated file's own mix once enough of it is filled in (see GameDB).
const DEFAULT_SKIN_MIX := [22.0, 34.0, 20.0, 10.0, 9.0, 5.0]
## Hair colour given a skin tone (rows: tone; columns: HAIR_KEYS order).
const HAIR_MIX := [
	[18.0, 30.0, 26.0, 12.0, 9.0, 5.0],
	[22.0, 34.0, 26.0, 10.0, 5.0, 3.0],
	[40.0, 36.0, 18.0, 4.0, 1.5, 0.5],
	[64.0, 28.0, 7.0, 1.0, 0.0, 0.0],
	[84.0, 15.0, 1.0, 0.0, 0.0, 0.0],
	[92.0, 8.0, 0.0, 0.0, 0.0, 0.0],
]


## A generated look from the player's id: {"skin": 0-5, "hair": 0-5}.
static func generated(id: String, skin_mix: Array = DEFAULT_SKIN_MIX) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("appearance|" + id)
	var skin := _pick(rng.randf(), skin_mix)
	return {"skin": skin, "hair": _pick(rng.randf(), HAIR_MIX[skin])}


## Long sleeves are a player's own choice (about one in seven, one in four in the
## wet): seeded from his id alone, on its own stream, so nothing else about his look
## changes. Presentation only.
const SLEEVES_SHARE := 0.15
const SLEEVES_SHARE_WET := 0.25


static func long_sleeves(id: String, wet := false) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("appearance-sleeves|" + id)
	return rng.randf() < (SLEEVES_SHARE_WET if wet else SLEEVES_SHARE)


static func _pick(roll: float, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var at := roll * total
	for i in range(weights.size()):
		at -= float(weights[i])
		if at < 0.0:
			return i
	return weights.size() - 1

# ---------------------------------------------------------------------------
# The full look (Club Forge, ARD-M7-009 "Create a player"; art agent contract
# 2026-10-06). Colours above stay indices the figures draw with; the rest are
# string ids the art pipeline maps to its sheets (it emits the id -> index
# table), so a save never stores sheet positions. Cosmetic only: nothing here
# is read by the sim. Dominant foot, number and nickname are not looks and
# live on the player.
# ---------------------------------------------------------------------------
const HAIR_STYLES := ["bald", "buzz", "short_crop", "crew", "side_part", "textured_short",
		"messy_medium", "swept_back", "mullet", "mullet_long", "curly_short", "curly_medium",
		"afro", "long", "tied_back", "dreadlocks"]
const BEARDS := ["clean", "stubble_light", "stubble_heavy", "moustache", "short_beard",
		"full_beard", "goatee", "beard_moustache"]
const BOOTS := ["classic", "modern"]
const SOCKS := ["tall", "short"]
const TATTOO_PLACES := ["forearm_l", "forearm_r", "upper_arm_l", "upper_arm_r", "calf_l", "calf_r", "hand_r"]
## None / light / heavy for bandaging.
const LEVELS := 3

## A look with nothing chosen: a short crop, clean shaven, tall socks, plain
## skin - what a real player shows until his look is curated (never a guess).
const BASE_LOOK := {"hair_style": "short_crop", "beard": "clean", "beard_colour": -1,
		"headband": false, "boots": "classic", "boot_colour": 0, "socks": "tall",
		"tattoos": [], "bandage": 0}

## How often generated players have each, so a league doesn't look uniform.
const HAIR_STYLE_MIX := {"bald": 4.0, "buzz": 12.0, "short_crop": 22.0, "crew": 10.0, "side_part": 6.0,
		"textured_short": 12.0, "messy_medium": 8.0, "swept_back": 5.0, "mullet": 6.0, "mullet_long": 2.0,
		"curly_short": 5.0, "curly_medium": 3.0, "afro": 1.5, "long": 2.0, "tied_back": 1.5}
const BEARD_MIX := {"clean": 46.0, "stubble_light": 18.0, "stubble_heavy": 12.0, "moustache": 4.0,
		"short_beard": 9.0, "full_beard": 5.0, "goatee": 2.0, "beard_moustache": 4.0}


## The full look of a player: skin and hair colours as the figures already
## draw them, then everything else.
##  - `chosen`: what was set for him (Club Forge); kept as given where valid.
##  - generated players get seeded variety from their id;
##  - anyone else (a real player) gets BASE_LOOK - never a guessed style.
static func full(colours: Dictionary, id: String, generated_player: bool, chosen: Dictionary = {}) -> Dictionary:
	var out := BASE_LOOK.duplicate(true)
	out["skin"] = int(colours.get("skin", UNCURATED["skin"]))
	out["hair"] = int(colours.get("hair", UNCURATED["hair"]))
	if generated_player:
		out.merge(_variety(id), true)
	for k in chosen:
		if valid(k, chosen[k]):
			out[k] = chosen[k].duplicate(true) if chosen[k] is Array else chosen[k]
	if int(out["beard_colour"]) < 0:
		out["beard_colour"] = int(out["hair"])
	return out


## Whether `value` is a valid choice for `key` (unknown keys aren't).
static func valid(key: String, value) -> bool:
	match key:
		"skin", "hair":
			return value is int and int(value) >= 0 and int(value) < 6
		"beard_colour":
			return value is int and int(value) >= -1 and int(value) < 6
		"hair_style":
			return HAIR_STYLES.has(str(value))
		"beard":
			return BEARDS.has(str(value))
		"boots":
			return BOOTS.has(str(value))
		"boot_colour":
			return value is int and int(value) >= 0 and int(value) < 8
		"socks":
			return SOCKS.has(str(value))
		"headband":
			return value is bool
		"bandage":
			return value is int and int(value) >= 0 and int(value) < LEVELS
		"tattoos":
			if not value is Array:
				return false
			for t in value:
				if not (t is Dictionary and TATTOO_PLACES.has(str(t.get("place", ""))) and str(t.get("design", "")) != ""):
					return false
			return true
	return false


## Seeded from the id alone (a separate stream from the colours), so it never
## depends on ratings, role or anything else about him.
static func _variety(id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("appearance-style|" + id)
	var out := {}
	out["hair_style"] = _pick_key(rng.randf(), HAIR_STYLE_MIX)
	out["beard"] = _pick_key(rng.randf(), BEARD_MIX)
	# Facial hair usually matches the hair; now and then it doesn't.
	out["beard_colour"] = -1 if rng.randf() < 0.85 else rng.randi_range(0, 5)
	out["headband"] = rng.randf() < 0.04 and not ["afro", "tied_back", "long"].has(out["hair_style"])
	out["boots"] = BOOTS[rng.randi_range(0, BOOTS.size() - 1)]
	out["boot_colour"] = rng.randi_range(0, 7)
	out["socks"] = "short" if rng.randf() < 0.15 else "tall"
	var ink := rng.randf()
	var n := 0 if ink < 0.70 else (1 if ink < 0.92 else 3)
	var places := TATTOO_PLACES.duplicate()
	var tats := []
	for i in n:
		var at := rng.randi_range(0, places.size() - 1)
		tats.append({"place": places[at], "design": "design_%d" % rng.randi_range(1, 12)})
		places.remove_at(at)
	out["tattoos"] = tats
	# Freckles and scars are gone (director, 2026-10-06); both rolls stay so every
	# other part of a generated player's look is as it was.
	rng.randf()
	rng.randf()
	out["bandage"] = _pick(rng.randf(), [85.0, 12.0, 3.0])
	return out


static func _pick_key(roll: float, mix: Dictionary) -> String:
	var keys := mix.keys()
	var weights := []
	for k in keys:
		weights.append(float(mix[k]))
	return str(keys[_pick(roll, weights)])
