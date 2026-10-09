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


# ---------------------------------------------------------------------------
# Favourite club (FL-005 director addition, 2026-10-06): the club he barracked
# for growing up, before he was drafted - not his employer. Presentation only.
# ---------------------------------------------------------------------------
## Real players: only a sourced fact (data/player_favourite_club.csv: first,
## last, dob, club code, source URL, date checked). No source: "" (the card
## says "Not recorded"); never inferred from his club, hometown or name.
const FAV_PATH := "res://data/player_favourite_club.csv"
## Share of generated kids who follow a club from their own state.
const FAV_HOME_SHARE := 0.7

static var _fav_sourced := {}
static var _fav_loaded := false


static func _sourced() -> Dictionary:
	if _fav_loaded:
		return _fav_sourced
	_fav_loaded = true
	var f := FileAccess.open(FAV_PATH, FileAccess.READ)
	if f == null:
		return _fav_sourced
	var header := f.get_csv_line()
	var at := {}
	for i in range(header.size()):
		at[header[i].strip_edges()] = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size() or str(row[0]).strip_edges() == "":
			continue
		var key := "%s|%s|%s" % [row[at["first"]].strip_edges().to_lower().replace("'", ""),
				row[at["last"]].strip_edges().to_lower().replace("'", ""),
				row[at["dob"]].strip_edges()]
		_fav_sourced[key] = row[at["club"]].strip_edges()
	return _fav_sourced


## His favourite club's code, or "" when it isn't known. Set on the player
## (a created prospect's choice) it wins; a real player's comes only from the
## sourced file; a generated player's is picked once from his id (mostly a club
## from his own state), never from the football RNG, so it survives a trade,
## retirement and an old save without being stored.
static func favourite_club(p: Dictionary) -> String:
	if p.has("fav_club"):
		return str(p["fav_club"]).strip_edges()
	if not bool(p.get("generated", false)):
		var key := "%s|%s|%s" % [str(p.get("first", "")).to_lower().replace("'", ""),
				str(p.get("last", "")).to_lower().replace("'", ""),
				str(p.get("dob", ""))]
		return str(_sourced().get(key, ""))
	var founding: Array = []
	var home: Array = []
	var state := str(p.get("state", p.get("home_state", "")))
	for code in TradeRequests.CLUB_STATES:
		if str(code) == "TAS":
			continue   # a kid born before 2028 grew up without a Tasmanian club
		founding.append(str(code))
		if state != "" and str(TradeRequests.CLUB_STATES[code]) == state:
			home.append(str(code))
	var pool := home if not home.is_empty() and _roll(p, "fav_home") < FAV_HOME_SHARE else founding
	return str(pool[posmod(hash(["fl005", "fav", str(p.get("id", ""))]), pool.size())])
