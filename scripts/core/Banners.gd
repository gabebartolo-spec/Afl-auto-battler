class_name Banners
extends RefCounted
## The run-through banner's rhyme for a match (data/banners.json): the
## occasion picks the set, the match picks the text, the clubs and the player
## fill it in. Presentation only - nothing here is read by the match.
##
## ctx: {"home", "away", "us" (whose banner; default home), "round" (label),
## "final" (week key: wildcard / elimination / qualifying / semi /
## preliminary / grand, or ""), "must_win": bool, "spoon": bool,
## "first_game" (TAS or CANB on its first game, or ""), "premiers" (last
## year's premier, or ""), "milestone": {"player": surname, "games": int or
## "farewell"}, "year", "seed"}.
##
## Which set, first that applies: a new club's first game; a milestone;
## a final; a must-win game; premiers (yours or theirs); a marquee game; a
## rivalry; a spoon match; the club's own; the general set. ANZAC Day, ANZAC
## Eve and Dreamtime only ever get their own texts - they honour the day and
## taunt no one.

const PATH := "res://data/banners.json"
const PLACEHOLDERS := ["{us}", "{them}", "{player}", "{games}", "{year}"]
## Marquee games whose banner is always the day's own, whatever else applies.
const RESPECTFUL := ["ANZAC Day", "ANZAC Eve", "Dreamtime at the 'G"]
const MILESTONES := [50, 100, 150, 200, 250, 300, 350]

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## The set of texts that applies to `ctx`, and what it is: [kind, texts].
static func texts_for(ctx: Dictionary) -> Array:
	var d := data()
	var home := str(ctx.get("home", ""))
	var away := str(ctx.get("away", ""))
	var us := str(ctx.get("us", home))
	var them := away if us == home else home
	var marquee := MarqueeGames.label(home, away)
	if RESPECTFUL.has(marquee):
		var own := _marquee(d, marquee)
		if not own.is_empty():
			return ["marquee", own]
	var first := str(ctx.get("first_game", ""))
	if first != "" and (d.get("first_game", {}) as Dictionary).has(first):
		return ["first_game", d["first_game"][first]]
	var key := _milestone_key(ctx.get("milestone", {}))
	if key != "" and (d.get("milestone", {}) as Dictionary).has(key):
		return ["milestone", d["milestone"][key]]
	var week := str(ctx.get("final", ""))
	if week != "" and (d.get("final", {}) as Dictionary).has(week):
		return ["final", d["final"][week]]
	if bool(ctx.get("must_win", false)) and not (d.get("must_win", []) as Array).is_empty():
		return ["must_win", d["must_win"]]
	var prem := str(ctx.get("premiers", ""))
	if prem != "" and prem == us and not (d.get("premiers", []) as Array).is_empty():
		return ["premiers", d["premiers"]]
	if prem != "" and prem == them and not (d.get("premiers_opposition", []) as Array).is_empty():
		return ["premiers_opposition", d["premiers_opposition"]]
	if marquee != "":
		var m := _marquee(d, marquee)
		if not m.is_empty():
			return ["marquee", m]
	for r in d.get("rivalry", []):
		var pair: Array = (r as Dictionary).get("pair", [])
		if pair.size() == 2 and ((pair[0] == us and pair[1] == them) or (pair[0] == them and pair[1] == us)):
			return ["rivalry", r["texts"]]
	if bool(ctx.get("spoon", false)) and not (d.get("spoon", []) as Array).is_empty():
		return ["spoon", d["spoon"]]
	if (d.get("club", {}) as Dictionary).has(us):
		return ["club", d["club"][us]]
	return ["general", d.get("general", [])]


## The banner for this match, lines split by "\n", placeholders filled.
static func pick(ctx: Dictionary) -> String:
	var found := texts_for(ctx)
	var texts: Array = found[1]
	if texts.is_empty():
		return ""
	var home := str(ctx.get("home", ""))
	var away := str(ctx.get("away", ""))
	# Seeded from the match itself, so the same match always shows the same
	# banner (a reload or a replay doesn't change it).
	var h := hash([int(ctx.get("seed", 0)), home, away, str(ctx.get("round", "")), str(ctx.get("final", "")), found[0]])
	var text := str(texts[posmod(h, texts.size())])
	return fill(text, ctx)


static func fill(text: String, ctx: Dictionary) -> String:
	var home := str(ctx.get("home", ""))
	var away := str(ctx.get("away", ""))
	var us := str(ctx.get("us", home))
	var them := away if us == home else home
	var ms: Dictionary = ctx.get("milestone", {}) if ctx.get("milestone") is Dictionary else {}
	return text.replace("{us}", GameDB.club_short(us)).replace("{them}", GameDB.club_short(them)) \
			.replace("{player}", str(ms.get("player", ""))).replace("{games}", str(ms.get("games", ""))) \
			.replace("{year}", str(ctx.get("year", "")))


static func _marquee(d: Dictionary, name: String) -> Array:
	for m in d.get("marquee", []):
		if str((m as Dictionary).get("name", "")) == name:
			return m.get("texts", [])
	return []


## "debut", "farewell", or a round milestone ("50" ... "350"); "" otherwise.
static func _milestone_key(ms) -> String:
	if not (ms is Dictionary) or (ms as Dictionary).is_empty():
		return ""
	var g = ms.get("games", 0)
	if str(g) == "farewell" or bool(ms.get("farewell", false)):
		return "farewell"
	if int(g) == 1:
		return "debut"
	if MILESTONES.has(int(g)):
		return str(int(g))
	return ""
