class_name Achievements
extends RefCounted
## Club-specific achievements: one per club, each tied to a verifiable part
## of that club's history (first flags, dynasties, droughts, near-misses).
##
## Pure data and checks - no simulation. GameState calls check_season() once,
## after the Grand Final settles, with a context of the finished season
## (final ladder, the bracket's slots, the flag history so far, the active
## clubs and each club's entry year). Everything is detectable from stats the
## game already tracks; nothing here requires new logging.
##
## Types:
##   premiership       the club wins the Grand Final
##   grand_final      the club reaches the Grand Final (either side of it)
##   top_ladder       the club tops the home-and-away
##   grand_slam       top ladder and the premiership in the same season
##   wins             win at least `wins_n` home-and-away games
##   flags_window     at least `count` flags in the last `span` seasons
##   second_chance    win the flag after losing a qualifying final
##   debut_finals     make the finals in the club's first season
##   debut_top        finish in the top `top_n` in the club's first season

const DEFINITIONS := [
	{"id": "ade_first_flag", "club": "ADE", "name": "The '97 Crows",
		"desc": "Adelaide win a premiership. The Crows' first flag came in 1997 - and they won again in 1998.",
		"type": "premiership"},
	{"id": "brl_back_to_back", "club": "BRL", "name": "Lions' share",
		"desc": "Brisbane win two premierships in a row. The Lions three-peated in 2001-03 and went back-to-back in 2024-25.",
		"type": "flags_window", "count": 2, "span": 2},
	{"id": "car_top_ladder", "club": "CAR", "name": "Blue Revolution",
		"desc": "Carlton top the home-and-away ladder. Sixteen times the Blues lifted the flag, from the 1906-08 three-peat to 1995.",
		"type": "top_ladder"},
	{"id": "col_four_peat", "club": "COL", "name": "Four in a row",
		"desc": "Collingwood win four premierships in a row. Only the Magpies have done it - 1927 to 1930.",
		"type": "flags_window", "count": 4, "span": 4},
	{"id": "ess_back_to_back", "club": "ESS", "name": "Bendigo Bank",
		"desc": "Essendon win back-to-back premierships. The Bombers did it in 1949-50 and again in 1984-85.",
		"type": "flags_window", "count": 2, "span": 2},
	{"id": "fre_first_flag", "club": "FRE", "name": "Dock of the bay",
		"desc": "Fremantle win a premiership. The Dockers' first flag - they came within a game of one in 2013.",
		"type": "premiership"},
	{"id": "gee_dynasty", "club": "GEE", "name": "Cats' dynasty",
		"desc": "Geelong win three premierships in five seasons, the way the 2007-11 dynasty took flags in 2007, 2009 and 2011.",
		"type": "flags_window", "count": 3, "span": 5},
	{"id": "gcs_first_gf", "club": "GCS", "name": "Sunrise",
		"desc": "Gold Coast make the Grand Final. A first for the Suns.",
		"type": "grand_final"},
	{"id": "gws_first_flag", "club": "GWS", "name": "Giants' flag",
		"desc": "GWS win a premiership. The Giants' first flag - they fell one game short in 2019.",
		"type": "premiership"},
	{"id": "haw_three_peat", "club": "HAW", "name": "The '10s standard",
		"desc": "Hawthorn win three premierships in a row, like the 2013-15 run.",
		"type": "flags_window", "count": 3, "span": 3},
	{"id": "mel_the_fifties", "club": "MEL", "name": "The '50s",
		"desc": "Melbourne win five premierships in six seasons, the way the Demons took five from 1955 to 1960.",
		"type": "flags_window", "count": 5, "span": 6},
	{"id": "nth_kangaroo_power", "club": "NTH", "name": "Kangaroo power",
		"desc": "North Melbourne win two premierships in three seasons, the way the Kangaroos took 1975 and 1977.",
		"type": "flags_window", "count": 2, "span": 3},
	{"id": "pad_first_flag", "club": "PAD", "name": "Power of the '00s",
		"desc": "Port Adelaide win a premiership. The Power's first flag came in 2004.",
		"type": "premiership"},
	{"id": "ric_back_to_back", "club": "RIC", "name": "Tigers' streak",
		"desc": "Richmond win back-to-back premierships, as in 1973-74 and 2019-20.",
		"type": "flags_window", "count": 2, "span": 2},
	{"id": "skn_long_wait", "club": "SKN", "name": "The long wait ends",
		"desc": "St Kilda win a premiership. The Saints' last flag was 1966 - end the long wait.",
		"type": "premiership"},
	{"id": "syd_grand_slam", "club": "SYD", "name": "Grand slam",
		"desc": "Sydney top the home-and-away and win the premiership in the same season.",
		"type": "grand_slam"},
	{"id": "wce_second_chance", "club": "WCE", "name": "Second chances",
		"desc": "West Coast win the flag after losing a qualifying final. Second chances are how the Eagles are built.",
		"type": "second_chance"},
	{"id": "wbd_bulldog_grit", "club": "WBD", "name": "Bulldog grit",
		"desc": "Western Bulldogs win 15 home-and-away games. Bulldog grit, the Footscray way.",
		"type": "wins", "wins_n": 15},
	{"id": "tas_debut_finals", "club": "TAS", "name": "Devil's island",
		"desc": "Tasmania make the finals in their first season. The Devils' 2028 debut has to count for something.",
		"type": "debut_finals"},
	{"id": "canb_debut_top", "club": "CANB", "name": "Capital idea",
		"desc": "Canberra finish in the top 12 in their first season. A debut that counts.",
		"type": "debut_top", "top_n": 12},
]


static func definition(id: String) -> Dictionary:
	for d in DEFINITIONS:
		if str(d["id"]) == id:
			return d
	return {}


static func definition_by_club(code: String) -> Dictionary:
	for d in DEFINITIONS:
		if str(d["club"]) == code:
			return d
	return {}


## The ids that become true this season, given what is already unlocked.
static func check_season(unlocked: Dictionary, ctx: Dictionary) -> Array:
	var out := []
	for d in DEFINITIONS:
		var id := str(d["id"])
		if unlocked.has(id):
			continue
		if _met(d, ctx):
			out.append(id)
	return out


static func _met(d: Dictionary, ctx: Dictionary) -> bool:
	var code := str(d["club"])
	match str(d["type"]):
		"premiership":
			return str(ctx.get("premier", "")) == code
		"grand_final":
			return str(ctx.get("premier", "")) == code \
					or str(ctx.get("runner_up", "")) == code
		"top_ladder":
			var rows := _ladder_sorted(ctx)
			return not rows.is_empty() and str(rows[0].get("code", "")) == code
		"grand_slam":
			var rows := _ladder_sorted(ctx)
			return str(ctx.get("premier", "")) == code \
					and not rows.is_empty() and str(rows[0].get("code", "")) == code
		"wins":
			var row: Dictionary = (ctx.get("ladder", {}) as Dictionary).get(code, {})
			return int(row.get("w", 0)) >= int(d.get("wins_n", 15))
		"flags_window":
			var need := int(d.get("count", 2))
			return _flags_in_window(ctx, code, need, int(d.get("span", 2))) >= need
		"second_chance":
			return _second_chance(ctx, code)
		"debut_finals":
			return _is_debut_season(ctx, code) \
					and (ctx.get("finalists", []) as Array).has(code)
		"debut_top":
			if not _is_debut_season(ctx, code):
				return false
			var rows := _ladder_sorted(ctx)
			var n := int(d.get("top_n", 12))
			var pos := 0
			for row in rows:
				pos += 1
				if str(row.get("code", "")) == code:
					return pos <= n
			return false
	return false


## The club's flags in the last `span` seasons (this season included).
static func _flags_in_window(ctx: Dictionary, code: String,
		count: int, span: int) -> int:
	var year := int(ctx.get("year", 0))
	var history: Array = ctx.get("history", [])
	var window := [year - span + 1, year]
	var flags := 0
	for entry in history:
		var e: Array = entry
		if int(e[0]) >= window[0] and int(e[0]) <= window[1] \
				and str(e[1]) == code:
			flags += 1
	if str(ctx.get("premier", "")) == code:
		flags += 1
	return flags


static func _is_debut_season(ctx: Dictionary, code: String) -> bool:
	var enter: Dictionary = ctx.get("enter", {})
	return enter.has(code) and int(enter[code]) == int(ctx.get("year", 0))


## The QF-loser path: QF -> SF -> PF -> GF, bracket positions are fixed.
static func _second_chance(ctx: Dictionary, code: String) -> bool:
	var s: Dictionary = ctx.get("finals_slots", {})
	if str(s.get("L_QF1", "")) == code:
		return str(s.get("W_SF1", "")) == code \
				and str(s.get("W_PF1", "")) == code and str(s.get("W_GF", "")) == code
	if str(s.get("L_QF2", "")) == code:
		return str(s.get("W_SF2", "")) == code \
				and str(s.get("W_PF2", "")) == code and str(s.get("W_GF", "")) == code
	return false


static func _ladder_sorted(ctx: Dictionary) -> Array:
	var ladder: Dictionary = ctx.get("ladder", {})
	var rows: Array = []
	for code in ladder:
		rows.append(ladder[code])
	rows.sort_custom(func(a, b):
		if int(a["pts"]) != int(b["pts"]):
			return int(a["pts"]) > int(b["pts"])
		if not is_equal_approx(float(a["pct"]), float(b["pct"])):
			return float(a["pct"]) > float(b["pct"])
		return int(a["pf"]) > int(b["pf"]))
	return rows
