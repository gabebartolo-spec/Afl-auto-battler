class_name FictionalIdentity
extends RefCounted
## FL-005 (ROADMAP 9.3): a generated fictional player's optional nickname and
## one small interest outside footy (data/fictional_identity.json).
## Presentation only - nothing in the match, development, morale, contracts or
## AI reads these. Real players get neither (fictive mode must not hand a real
## player an invented life). Chosen by a cosmetic hash of the player's id, never
## the football RNG, so it is the same every time, survives a transfer or
## retirement, and an old save gets it without storing anything.
## The nickname reuses Club Forge's p["nickname"] (M7-008): set on the player,
## it wins - "" means none - so a user can change or remove it at no cost.

const PATH := "res://data/fictional_identity.json"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"nicknames": {}, "interests": []}
	return _data


## A share of players, picked by id alone: [0, 1) from a cosmetic hash.
static func _roll(p: Dictionary, what: String) -> float:
	return float(posmod(hash(["fl005", what, str(p.get("id", ""))]), 100000)) / 100000.0


## His nickname: one set for him (Club Forge, or changed by you; "" removes
## it), else - for a generated player only - a name-play nickname from his
## surname for about a third of them; "" otherwise.
static func nickname(p: Dictionary) -> String:
	if p.has("nickname"):
		return str(p["nickname"]).strip_edges()
	if not bool(p.get("generated", false)):
		return ""
	var options: Array = (data().get("nicknames", {}) as Dictionary).get(str(p.get("last", "")), [])
	if options.is_empty() or _roll(p, "nick") >= float(data().get("nickname_share", 0.35)):
		return ""
	return str(options[posmod(hash(["fl005", "which", str(p.get("id", ""))]), options.size())])


## One small thing he does outside footy, or "" (a generated player only, and
## not everyone).
static func interest(p: Dictionary) -> String:
	if p.has("interest"):
		return str(p["interest"]).strip_edges()
	if not bool(p.get("generated", false)):
		return ""
	var list: Array = data().get("interests", [])
	if list.is_empty() or _roll(p, "interest") >= float(data().get("interest_share", 0.55)):
		return ""
	return str(list[posmod(hash(["fl005", "what", str(p.get("id", ""))]), list.size())])
