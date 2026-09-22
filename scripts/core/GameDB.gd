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
const PLAYERS_ENRICHED_CSV := "res://data/players_enriched_2026.csv"

## Numeric columns, in CSV order, after club/num/last/first.
const STAT_KEYS := ["gm", "ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb",
		"if50", "cl", "cg", "ff", "fa", "br", "cp", "up", "cm", "mi",
		"onepct", "bo", "ga", "pctp"]

const CLUB_ORDER := ["ADE", "BRL", "CAR", "COL", "ESS", "FRE", "GEE", "GCS",
		"GWS", "HAW", "MEL", "NTH", "PAD", "RIC", "SKN", "SYD", "WCE", "WBD"]

## Fictional aliases are shuffled from these invented-ish name parts once at
## load time. The fixed seed makes a player's alias stable across every screen
## and every launch, while avoiding numbered placeholders in the UI.
const FICTIONAL_FIRST_NAMES := [
	"Ari", "Bex", "Cato", "Dax", "Elio", "Fenn", "Gavi", "Hux", "Ivo", "Jori",
	"Kavi", "Luma", "Miro", "Nilo", "Oren", "Pax", "Quill", "Rumi", "Savi", "Taro",
	"Umi", "Vero", "Wilo", "Yori", "Zeno", "Arlo", "Bardo", "Ceri", "Dori", "Eno",
	"Fia", "Gilo", "Hani", "Juno", "Koda", "Lior", "Mavi", "Nori", "Olli", "Piri",
	"Roka", "Sora", "Tavi", "Udo", "Vali", "Wren", "Xeno", "Yara", "Zavi",
]
const FICTIONAL_LAST_NAMES := [
	"Bramble", "Cinder", "Dapple", "Ember", "Fallow", "Glint", "Hush", "Jumble",
	"Kestrel", "Lattice", "Morrow", "Nettle", "Orbit", "Puddle", "Quiver", "Riddle",
	"Sable", "Tangle", "Umber", "Vesper", "Wicket", "Yarrow", "Zephyr", "Barlow",
	"Crinkle", "Dovetail", "Evers", "Flint", "Gossamer", "Hallow", "Juniper", "Kibble",
	"Lumen", "Mica", "Nimbus", "Oxbow", "Plover", "Rook", "Sprocket", "Thimble",
	"Upland", "Velvet", "Xylo", "Yonder", "Zinnia", "Bracken", "Cobble", "Drift",
	"Fizz", "Grouse",
]
const FICTIONAL_NAME_SEED := 260922

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
		push_error("GameDB: no players loaded. Check that %s exists and that its import type is 'Keep File (exported as is)'." % PLAYERS_CSV)
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


## The default label is intentionally fictional. When the optional educational
## view is enabled, keep that label and add the real-player comparison instead
## of pretending the fictional character is the real athlete.
func player_display_name(player: Dictionary) -> String:
	if player.is_empty():
		return ""
	var generic := str(player.get("generic_name", player.get("name", "Player")))
	if not GameState.show_real_names:
		return generic
	var real := str(player.get("real_name", ""))
	if real == "":
		return generic
	return "%s  ·  plays like %s" % [generic, real]


func player_display_name_by_id(id: String, fallback := "") -> String:
	var player = player_by_id(id)
	if player != null:
		return player_display_name(player)
	return fallback


## Search may use the comparison name without exposing it in the fictional UI.
func player_search_text(player: Dictionary) -> String:
	return "%s %s" % [
		str(player.get("generic_name", player.get("name", ""))),
		str(player.get("real_name", ""))]


func player_sort_name(player: Dictionary) -> String:
	if GameState.show_real_names and str(player.get("real_name", "")) != "":
		return str(player["real_name"]).to_lower()
	return str(player.get("generic_name", player.get("name", ""))).to_lower()


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
		rows.append(Array(line.split(",")))
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
		for j in range(header.size()):
			d[header[j]] = cells[j]
		# Pre-convert the hex strings so the UI never has to.
		d["primary"] = _hex(d.get("primary", "#FFFFFF"))
		d["secondary"] = _hex(d.get("secondary", "#808080"))
		d["accent"] = _hex(d.get("accent", "#FFD700"))
		out[str(d["code"])] = d
	return out


func _assign_fictional_names(list: Array) -> void:
	var candidates := []
	for first in FICTIONAL_FIRST_NAMES:
		for last in FICTIONAL_LAST_NAMES:
			candidates.append("%s %s" % [first, last])
	var rng := RandomNumberGenerator.new()
	rng.seed = FICTIONAL_NAME_SEED
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap

	for i in range(list.size()):
		var label := str(candidates[i]) if i < candidates.size() else "Squadmate %03d" % (i + 1)
		list[i]["generic_name"] = label
		list[i]["name"] = label


func _load_players() -> Array:
	# Prefer enriched if present (100% height coverage via afltables_bio_cache.json), fallback to base
	var csv_path := PLAYERS_ENRICHED_CSV if FileAccess.file_exists(PLAYERS_ENRICHED_CSV) else PLAYERS_CSV
	if csv_path == PLAYERS_ENRICHED_CSV:
		print("GameDB: using enriched CSV with bio fields")
	var rows := _read_rows(csv_path)
	var out := []
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j

	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var p := {}
		p["club"] = str(cells[idx["club"]])
		p["num"] = int(str(cells[idx["num"]])) if idx.has("num") else 0
		p["last"] = str(cells[idx["last"]]) if idx.has("last") else ""
		p["first"] = str(cells[idx["first"]]) if idx.has("first") else ""
		p["real_name"] = "%s %s" % [p["first"], p["last"]]
		# Keep the underlying comparison data, but never make the real name the
		# default display value. The fictional alias is assigned below after the
		# full pool has been loaded.
		p["generic_name"] = ""
		p["name"] = ""
		p["id"] = "%s_%d" % [p["club"], p["num"]]
		p["src"] = int(str(cells[idx["src"]])) if idx.has("src") else 2026
		for k in STAT_KEYS:
			p[k] = float(str(cells[idx[k]])) if idx.has(k) else 0.0
		# Optional enriched fields — defaults keep Ratings.gd backward-compatible
		p["real_pos"] = str(cells[idx["real_pos"]]) if idx.has("real_pos") else ""
		p["dob"] = str(cells[idx["dob"]]) if idx.has("dob") else ""
		p["age"] = float(str(cells[idx["age"]])) if idx.has("age") and str(cells[idx["age"]]) != "" else 0.0
		p["height_cm"] = float(str(cells[idx["height_cm"]])) if idx.has("height_cm") and str(cells[idx["height_cm"]]) != "" else 0.0
		p["weight_kg"] = float(str(cells[idx["weight_kg"]])) if idx.has("weight_kg") and str(cells[idx["weight_kg"]]) != "" else 0.0
		p["debut"] = str(cells[idx["debut"]]) if idx.has("debut") else ""
		p["height_source"] = str(cells[idx["height_source"]]) if idx.has("height_source") else ""
		out.append(p)
	_assign_fictional_names(out)
	return out


func _hex(s) -> Color:
	if s is Color:
		return s
	return Color.html(str(s))
