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
const HAIR := [Color("#16110e"), Color("#33211a"), Color("#563621"), Color("#86603a"),
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
