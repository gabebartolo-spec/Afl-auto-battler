extends Node
## GameDB (autoload) - reads the harvested season data once at boot and exposes
## it to every other system.
##
## Data files ship as plain CSV under res://data/. Their .import files set the
## importer to "keep" so Godot exports them verbatim instead of converting them
## into translation resources; FileAccess then reads them at runtime on both
## desktop and mobile.

const CLUBS_CSV := "res://data/clubs.csv"
const PLAYERS_CSV := "res://data/players_2026.csv"

## Numeric columns, in CSV order, after club/num/last/first.
const STAT_KEYS := ["gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb",
		"if50", "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi",
		"onepct", "bo", "ga", "pctp"]

const CLUB_ORDER := ["ADE", "BRL", "CAR", "COL", "ESS", "FRE", "GEE", "GCS",
		"GWS", "HAW", "MEL", "NTH", "PAD", "RIC", "SKN", "SYD", "WCE", "WBD"]

var clubs := {}            # code -> {code,name,short,primary,secondary,accent,ground}
var players := []          # Array of player dictionaries, ratings derived
var players_by_club := {}  # code -> Array of player dictionaries
var loaded := false


func _ready() -> void:
	reload()


func reload() -> void:
	clubs = _load_clubs()
	players = _load_players()
	Ratings.derive_all(players)

	players_by_club = {}
	for code in CLUB_ORDER:
		players_by_club[code] = []
	for p in players:
		if not players_by_club.has(p["club"]):
			players_by_club[p["club"]] = []
		players_by_club[p["club"]].append(p)

	loaded = not players.is_empty()
	if not loaded:
		push_error("GameDB: no players loaded. Check that %s exists and that its "
				+ "import type is 'Keep File (exported as is)'." % PLAYERS_CSV)
	else:
		print("GameDB: %d players across %d clubs" % [players.size(), clubs.size()])


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
func club(code: String) -> Dictionary:
	return clubs.get(code, {})


func club_name(code: String) -> String:
	return str(clubs.get(code, {}).get("name", code))


func club_short(code: String) -> String:
	return str(clubs.get(code, {}).get("short", code))


func club_colours(code: String) -> Array:
	var c: Dictionary = clubs.get(code, {})
	return [c.get("primary", Color.WHITE), c.get("secondary", Color.DIM_GRAY),
			c.get("accent", Color.GOLD)]


func club_list(code: String) -> Array:
	return players_by_club.get(code, [])


func player_by_id(id: String):
	for p in players:
		if p["id"] == id:
			return p
	return null


## Every player in the competition, best-first. Used as the draft pool.
func all_players_sorted() -> Array:
	var out := players.duplicate()
	out.sort_custom(func(a, b): return a["overall"] > b["overall"])
	return out


func count_by_role(list: Array) -> Dictionary:
	var out := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	for p in list:
		out[p["role"]] = int(out[p["role"]]) + 1
	return out


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------
func _read_rows(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("GameDB: missing data file %s" % path)
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameDB: cannot open %s" % path)
		return []
	var rows := []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		rows.append(line.split(","))
	f.close()
	return rows


func _load_clubs() -> Dictionary:
	var rows := _read_rows(CLUBS_CSV)
	var out := {}
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var d := {}
		for j in header.size():
			d[header[j]] = cells[j]
		# Pre-convert the hex strings so the UI never has to.
		d["primary"] = _hex(d.get("primary", "#FFFFFF"))
		d["secondary"] = _hex(d.get("secondary", "#808080"))
		d["accent"] = _hex(d.get("accent", "#FFD700"))
		out[str(d["code"])] = d
	return out


func _load_players() -> Array:
	var rows := _read_rows(PLAYERS_CSV)
	var out := []
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in header.size():
		idx[header[j]] = j

	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var p := {}
		p["club"] = str(cells[idx["club"]])
		p["num"] = int(str(cells[idx["num"]]))
		p["last"] = str(cells[idx["last"]])
		p["first"] = str(cells[idx["first"]])
		p["name"] = "%s %s" % [p["first"], p["last"]]
		p["id"] = "%s_%d" % [p["club"], p["num"]]
		p["src"] = int(str(cells[idx["src"]])) if idx.has("src") else 2026
		for k in STAT_KEYS:
			p[k] = float(str(cells[idx[k]])) if idx.has(k) else 0.0
		out.append(p)
	return out


func _hex(s) -> Color:
	if s is Color:
		return s
	return Color.html(str(s))
