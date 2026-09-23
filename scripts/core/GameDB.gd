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
const DRAFTEES_CSV := "res://data/draftees_2026.csv"

## Numeric columns, in CSV order, after club/num/last/first. Single source of
## truth lives in Ratings (the prospect pipeline shares it).
const STAT_KEYS := Ratings.STATS_ZERO_KEYS

const CLUB_ORDER := ["ADE", "BRL", "CAR", "COL", "ESS", "FRE", "GEE", "GCS",
		"GWS", "HAW", "MEL", "NTH", "PAD", "RIC", "SKN", "SYD", "WCE", "WBD"]

## Fictional aliases are shuffled from these invented name parts once at load.
## The fixed seed keeps a player's alias stable across every screen and every
## launch. Numbered placeholders ("Squadmate 001", "Player 001") are never used.
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
var draftees := []         # the shipped draft class, projections applied
var late_draftees := []    # generated future classes registered at runtime
var loaded := false

## Fictional alias cursor shared by the season pool, the draft class and every
## generated intake, so no two displayed players ever collide on an alias.
var _alias_candidates: Array = []
var _alias_next := 0


func _ready() -> void:
	reload()


func reload() -> void:
	clubs = _load_clubs()
	_alias_candidates = []
	_alias_next = 0
	players = _load_players()
	Ratings.derive_all(players)
	draftees = _load_draftees()
	late_draftees = []

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
		print("GameDB: %d players / %d clubs; %d draft-class prospects"
				% [players.size(), clubs.size(), draftees.size()])


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
	for p in draftees:
		if p["id"] == id:
			return p
	for p in late_draftees:
		if p["id"] == id:
			return p
	return null


## Generated future classes register here so pick logs and box scores can still
## resolve their names by stable id after a season rollover.
func register_draftees(list: Array) -> void:
	for p in list:
		late_draftees.append(p)


## Fictional names are the default. Real-name mode shows the AFL name on its
## own ("Jordan Dawson") — never "Squadmate 001 · plays like Jordan Dawson".
## Generated prospects have no real name, so they keep the fictional label.
func player_display_name(player: Dictionary) -> String:
	if player.is_empty():
		return ""
	var generic := str(player.get("generic_name", player.get("name", ""))).strip_edges()
	if GameState.show_real_names:
		var real := str(player.get("real_name", "")).strip_edges()
		if real != "":
			return real
	if generic != "":
		return generic
	return "Player"


func player_display_name_by_id(id: String, fallback := "") -> String:
	var player = player_by_id(id)
	if player != null:
		return player_display_name(player)
	return fallback


## Search can match the real name without showing it while fictional labels are on.
func player_search_text(player: Dictionary) -> String:
	return "%s %s" % [
		str(player.get("generic_name", player.get("name", ""))),
		str(player.get("real_name", ""))]


func player_sort_name(player: Dictionary) -> String:
	return player_display_name(player).to_lower()


## Every player in the competition, best-first. Used as the draft pool.
func all_players_sorted() -> Array:
	var out := players.duplicate()
	out.sort_custom(func(a, b): return a["overall"] > b["overall"])
	return out


## The shipped draft class best-first (projections applied at load).
func all_draftees_sorted() -> Array:
	var out := draftees.duplicate()
	out.sort_custom(func(a, b): return a["overall"] > b["overall"])
	return out


## data/draftees_2026.csv - the real 2026 national-draft class (Rookie Me
## Central August-2026 top 50 plus six names it missed). These players have
## no AFL season line, so Ratings.derive_all is skipped in favour of a
## projection from draft rank, role and reported U18 production.
func _load_draftees() -> Array:
	if not FileAccess.file_exists(DRAFTEES_CSV):
		push_warning("GameDB: no draft-class file (%s); the intake draft will fall back to generated classes." % DRAFTEES_CSV)
		return []
	var rows := _read_rows(DRAFTEES_CSV)
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
		var rank := _cell_int(cells, idx, "rank")
		p["first"] = _cell_str(cells, idx, "first")
		p["last"] = _cell_str(cells, idx, "last")
		p["real_name"] = "%s %s" % [p["first"], p["last"]]
		p["generic_name"] = ""
		p["name"] = ""
		p["id"] = "D2026_%02d" % rank
		# "club" carries the recruiting team until the player is drafted;
		# the intake then reassigns club/num like a real list move.
		p["club"] = _cell_str(cells, idx, "team")
		p["num"] = rank
		p["src"] = "U18"
		for k in STAT_KEYS:
			p[k] = 0.0
		var role := _cell_str(cells, idx, "pos")
		if role == "RUC":
			role = "RUCK"
		p["role"] = role
		var role2 := _cell_str(cells, idx, "pos2")
		if role2 == "RUC":
			role2 = "RUCK"
		p["role2"] = role2 if role2 != role else ""
		p["real_pos"] = _cell_str(cells, idx, "pos")
		p["height_cm"] = float(_cell_int(cells, idx, "height_cm"))
		p["weight_kg"] = 0.0
		p["dob"] = _cell_str(cells, idx, "dob")
		var as_of := "2026-11-20"
		var age := 18.0
		if str(p["dob"]).length() >= 10:
			age = float(Prospects.days_between(str(p["dob"]), as_of)) / 365.25
		p["age"] = age
		p["debut"] = ""
		p["height_source"] = "draft class"
		p["draft_year"] = 2026
		p["draft_rank"] = rank
		p["draft_team"] = _cell_str(cells, idx, "team")
		p["draft_league"] = _cell_str(cells, idx, "league")
		p["draft_state"] = _cell_str(cells, idx, "state")
		p["tied_club"] = _cell_str(cells, idx, "tied_club")
		p["tied_type"] = _cell_str(cells, idx, "tied_type")
		p["u18_gm"] = float(_cell_int(cells, idx, "u18_gm"))
		p["u18_di"] = _cell_float(cells, idx, "u18_di")
		p["u18_gl"] = _cell_float(cells, idx, "u18_gl")
		p["u18_mk"] = _cell_float(cells, idx, "u18_mk")
		p["u18_tk"] = _cell_float(cells, idx, "u18_tk")
		p["u18_if50"] = _cell_float(cells, idx, "u18_if50")
		p["u18_ho"] = _cell_float(cells, idx, "u18_ho")
		p["note"] = _cell_str(cells, idx, "note")
		p["data_src"] = _cell_str(cells, idx, "data_src")
		Prospects.project(p)
		out.append(p)
	_assign_fictional_names(out)
	return out


func _cell_str(cells: Array, idx: Dictionary, key: String) -> String:
	if not idx.has(key):
		return ""
	return str(cells[idx[key]])


func _cell_int(cells: Array, idx: Dictionary, key: String) -> int:
	if not idx.has(key) or str(cells[idx[key]]) == "":
		return 0
	return int(str(cells[idx[key]]))


func _cell_float(cells: Array, idx: Dictionary, key: String) -> float:
	if not idx.has(key) or str(cells[idx[key]]) == "":
		return 0.0
	return float(str(cells[idx[key]]))



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
	assign_aliases(list)


## Draw labels from one shuffled pool for every human in the game - season
## pool, draft class and generated intakes - so aliases never collide and a
## player's label is stable for the whole career. The cursor advances by one
## name per player. Adding the loop index on top of the cursor skips names
## quadratically, exhausts the pool, and used to fall back to "Squadmate 001".
func assign_aliases(list: Array) -> void:
	_ensure_alias_pool()
	var start := _alias_next
	for i in range(list.size()):
		var idx := start + i
		var label := str(_alias_candidates[idx]) if idx < _alias_candidates.size() \
				else _overflow_alias(idx - _alias_candidates.size())
		list[i]["generic_name"] = label
		list[i]["name"] = label
	_alias_next = start + list.size()


## Still a generated name once the shuffled pairs run out. Three tokens cannot
## collide with the two-token pool, and nothing here is a numbered placeholder.
func _overflow_alias(n: int) -> String:
	var firsts := FICTIONAL_FIRST_NAMES.size()
	var lasts := FICTIONAL_LAST_NAMES.size()
	var block := firsts * lasts
	var f := n % firsts
	var l := int(n / firsts) % lasts
	var m := int(n / block) % firsts
	var cycle := int(n / (block * firsts))
	var first := str(FICTIONAL_FIRST_NAMES[f])
	var mid := str(FICTIONAL_FIRST_NAMES[(f + 1 + m) % firsts])
	var last := str(FICTIONAL_LAST_NAMES[l])
	var label := "%s %s %s" % [first, mid, last]
	if cycle > 0:
		label = "%s %s" % [label, str(FICTIONAL_LAST_NAMES[cycle % lasts])]
	return label


func _ensure_alias_pool() -> void:
	if not _alias_candidates.is_empty():
		return
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
	_alias_candidates = candidates


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

	var seen_ids := {}
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
		# real_name stays available for the optional real-name view. The default
		# display value is the generated alias, assigned after the pool loads.
		p["generic_name"] = ""
		p["name"] = ""
		# Club + guernsey is the id, but a list can carry two players on one
		# number (Sydney's #36 in the 2026 data). A shared id would let the
		# draft treat both as one player, so later duplicates get a suffix.
		var id := "%s_%d" % [p["club"], p["num"]]
		var dupe := 2
		while seen_ids.has(id):
			id = "%s_%d_%d" % [p["club"], p["num"], dupe]
			dupe += 1
		seen_ids[id] = true
		p["id"] = id
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
