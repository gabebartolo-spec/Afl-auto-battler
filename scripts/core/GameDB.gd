extends Node
## GameDB (autoload) - reads the harvested season data once at boot and exposes
## it to every other system.
##
## Data files ship as plain CSV under res://data/. Their .import files set the
## importer to "keep" so Godot exports them verbatim instead of converting them
## into translation resources; FileAccess then reads them at runtime on both
## desktop and mobile. A CSV left on Godot's default (csv_translation) importer
## is missing from an exported build: tools/check_export_data.sh guards this.

## Chronology. The data is the completed 2026 AFL season (stats, ratings,
## careers through 2026, the 2026 draft class); a career starts with the
## 2027 season, taking over the league 2026 produced. Ages are as of the
## start of the first playable season.
const DATA_SEASON := 2026
const START_YEAR := 2027
const START_DATE := "2027-03-01"

const CLUBS_CSV := "res://data/clubs.csv"
## The player pool: 2026 season stats plus bio fields (dob, age, height).
## Required - see _load_players(). data/players_2026.csv (stats only) is the
## Python tools' source and is not read by the game.
const PLAYERS_ENRICHED_CSV := "res://data/players_enriched_2026.csv"
const DRAFTEES_CSV := "res://data/draftees_2026.csv"
const POTENTIAL_CSV := "res://data/potential_overrides.csv"
## Draft pedigree and rated past seasons, built by tools/build_history.py.
const HISTORY_CSV := "res://data/player_history_2026.csv"
## How real players look on the vignette figures (Appearance.gd): skin tone and
## hair colour, drafted from public photos and reviewed by the director.
const APPEARANCE_CSV := "res://data/player_appearance.csv"
## Where each 2026 player came from (a state, or INT), from his recruiting source;
## built by tools/build_player_origin.py. A blank state is left unset.
const ORIGIN_CSV := "res://data/player_origin_2026.csv"
## Curated looks needed before their mix replaces Appearance.DEFAULT_SKIN_MIX.
const MIX_FROM := 100

## Numeric columns, in CSV order, after club/num/last/first. Single source of
## truth lives in Ratings (the prospect pipeline shares it).
const STAT_KEYS := Ratings.STATS_ZERO_KEYS

## Every club the competition has ever fielded, in founding order. Clubs are
## only active from their "enter" year (data/clubs.csv) onward - use
## active_clubs(year) for any list that simulates a particular season.
const CLUB_ORDER := ["ADE", "BRL", "CAR", "COL", "ESS", "FRE", "GEE", "GCS",
		"GWS", "HAW", "MEL", "NTH", "PAD", "RIC", "STK", "SYD", "WCE", "WBD",
		"TAS", "CANB"]

## Fictional names: a broad contemporary Australian mix of first names and
## surnames. Each list is shuffled once with a fixed seed and the two are
## walked in step (their lengths share no factor), so every full name is
## unique for lengths-multiplied draws and no surname repeats inside any run
## of FICTIONAL_LAST_NAMES.size() consecutive players - a draft class never
## recycles a surname. A pair that is a real listed player's name is
## skipped. Numbered placeholders and invented words are never used.
const FICTIONAL_FIRST_NAMES := [
	"Jack", "Harry", "Oliver", "Noah", "William", "Thomas", "James", "Lachlan", "Cooper", "Charlie", "Henry", "Max",
	"Lucas", "Ethan", "Liam", "Samuel", "Jacob", "Joshua", "Benjamin", "Alexander", "Isaac", "Hunter", "Archie", "Riley",
	"Oscar", "Hudson", "Mason", "Jaxon", "Leo", "Harrison", "Patrick", "Daniel", "Tyler", "Ryan", "Nathan", "Luke",
	"Mitchell", "Callum", "Zac", "Kai", "Jai", "Flynn", "Angus", "Hamish", "Fraser", "Tom", "Will", "Sam",
	"Ben", "Josh", "Nick", "Matt", "Jake", "Dylan", "Connor", "Jordan", "Brodie", "Darcy", "Toby", "Blake",
	"Jasper", "Felix", "Hugo", "Ollie", "Arlo", "Elijah", "Xavier", "Sebastian", "Owen", "Marcus", "Aidan", "Caleb",
	"Bailey", "Jesse", "Kade", "Luca", "Marco", "Nikolas", "Christian", "Adrian", "Dominic", "Anthony", "Joel", "Elias",
	"Tristan", "Damon", "Leon", "Andre", "Stefan", "Ivan", "Harvey", "Jye", "Jett", "Koby", "Kobe", "Taj",
	"Rhys", "Ewan", "Reuben", "Finn", "Ned", "Alfie", "Jamie", "Logan", "Cody", "Mackenzie", "Brayden", "Jayden",
	"Tyson", "Tate", "Beau", "Lewis", "Reid", "Zane", "Seth", "Gabriel", "Isaiah", "Malachi", "Levi", "Micah",
	"Jonah", "Ari", "Dante", "Mateo", "Nate", "Kyle", "Shaun", "Corey", "Bryce", "Kieran", "Declan", "Rory",
	"Quinn", "Hayden", "Tobias", "Spencer", "Archer", "Joseph", "Jordy", "Carter", "Lincoln", "Austin", "Jeremy", "Travis",
	"Darius", "Marley", "Tahj", "Jarrod",
]
const FICTIONAL_LAST_NAMES := [
	"Anderson", "Baker", "Bennett", "Brooks", "Brown", "Campbell", "Carter", "Clarke", "Collins", "Cook",
	"Cooper", "Davies", "Dixon", "Edwards", "Evans", "Fisher", "Fletcher", "Foster", "Graham", "Grant",
	"Gray", "Hall", "Harris", "Harrison", "Hayes", "Henderson", "Hill", "Hughes", "Hunter", "Jackson",
	"James", "Jenkins", "Johnson", "Jones", "Kelly", "Kennedy", "King", "Knight", "Lane", "Lawson",
	"Lee", "Lewis", "Lloyd", "Marshall", "Martin", "Mason", "Matthews", "McDonald", "McKenzie", "Miller",
	"Mitchell", "Moore", "Morgan", "Morris", "Murphy", "Murray", "Nelson", "Newman", "Parker", "Payne",
	"Pearce", "Phillips", "Porter", "Powell", "Price", "Reid", "Richards", "Roberts", "Robertson", "Robinson",
	"Rogers", "Ross", "Russell", "Ryan", "Saunders", "Scott", "Shaw", "Simpson", "Smith", "Spencer",
	"Stewart", "Sullivan", "Taylor", "Thomas", "Thompson", "Turner", "Walker", "Wallace", "Ward", "Watson",
	"Webb", "Wells", "White", "Williams", "Wilson", "Wood", "Wright", "Young", "Burke", "Byrne",
	"Doyle", "Duffy", "Fitzgerald", "Flanagan", "Gallagher", "Kavanagh", "Keane", "Lynch", "Maguire", "McCarthy",
	"McGrath", "McMahon", "Moloney", "Nolan", "O'Brien", "O'Connor", "Quinlan", "Ryder", "Sheehan", "Walsh",
	"Brennan", "Callaghan", "Costello", "Delaney", "Donnelly", "Fogarty", "Hanlon", "Keogh", "Malone", "Regan",
	"Tierney", "Cullen", "Dunne", "Hogan", "Horan", "Rossi", "Russo", "Romano", "Ricci", "Marino",
	"Greco", "Bruno", "Gallo", "Conti", "Esposito", "Mancini", "Lombardi", "Moretti", "Barbieri", "Ferraro",
	"Rinaldi", "Caruso", "Santoro", "Fabbri", "Bianchi", "Colombo", "Vitale", "Messina", "Testa", "Grasso",
	"Pellegrino", "Silvestri", "Palmieri", "Leone", "Morello", "Papadopoulos", "Georgiou", "Nikolaidis", "Christou", "Dimitriou",
	"Pappas", "Vlahos", "Karras", "Andreou", "Zervas", "Galanis", "Mavros", "Kovac", "Horvat", "Novak",
	"Petrovic", "Jankovic", "Markovic", "Babic", "Juric", "Kralj", "Vukovic", "Peric", "Bozic", "Lukic",
	"Simic", "Tomic", "Haddad", "Khoury", "Nasser", "Saliba", "Hanna", "Farah", "Mansour", "Daher",
	"Issa", "Karam", "Abboud", "Rahme", "Sleiman", "Chidiac", "Habib", "Nguyen", "Tran", "Le",
	"Pham", "Huynh", "Vo", "Dang", "Bui", "Do", "Ho", "Ngo", "Duong", "Ly",
	"Truong", "Lam", "Singh", "Sharma", "Patel", "Kumar", "Gill", "Sandhu", "Dhillon", "Grewal",
	"Bains", "Sidhu", "Chen", "Wong", "Li", "Zhang", "Lin", "Thorne", "Rowe", "Hart",
	"Fox", "Ford", "Frost", "Gale", "Hale", "Holt", "Keen", "Kent", "Lowe", "Marsh",
	"Nash", "Page", "Pike", "Pratt", "Rice", "Rudd", "Shore", "Stone", "Swift", "Todd",
	"Vale", "Wade", "Wolfe", "Yates", "Bishop", "Booth", "Bolton", "Bowman", "Brady", "Buckley",
	"Burgess", "Burton", "Carr", "Chapman", "Coleman", "Cross", "Curtis", "Dawson", "Day", "Dean",
	"Doherty", "Draper", "Eaton", "Ellis", "Farrell", "Ferguson", "Finch", "Gardiner", "Gibson", "Gilbert",
	"Goodwin", "Gordon", "Greenwood", "Griffin", "Hammond", "Hancock", "Hardy", "Harper", "Hawkins", "Haynes",
	"Hicks", "Hodges", "Holland", "Holmes", "Hopkins", "Howard", "Hudson", "Hutchinson", "Ingram", "Jarvis",
	"Jennings", "Kemp", "Lambert", "Lawrence", "Little", "Lucas", "Lyons", "Mann", "Maxwell", "McLean",
	"Mills", "Moss", "Norris", "Oakley", "Osborne", "Owen", "Palmer", "Parsons", "Pearson", "Perry",
	"Pope", "Potter", "Quinn", "Ramsay", "Randall", "Reynolds", "Riley", "Rowley", "Sanders", "Sharp",
	"Sims", "Skinner", "Slater", "Stevens", "Sutton", "Sweeney", "Talbot", "Tucker", "Vaughan", "Walton",
	"Warren", "Waters", "Weaver", "Whitfield", "Wilkins", "Woods", "Briggs", "Bourke", "Crowe", "Donovan",
	"Egan", "Garvey", "Hennessy", "Kirby", "Lacey", "Mahony", "Mulcahy", "Nugent", "Rourke", "Tobin",
	"Whelan", "Ahmed", "Ali", "Hassan", "Hussein", "Karimi", "Omar", "Rahimi", "Sultani", "Yusuf",
	"Barakat", "Coulter", "Dunstan", "Mabey", "Penhall", "Treloar", "Whitehead",
]
const FICTIONAL_NAME_SEED := 260922

var clubs := {}            # code -> {code,name,short,primary,secondary,accent,ground}
## CLUB_ORDER plus a career's created club (Club Forge), in order. Anything that
## walks every club walks this, so a created club is never missed.
var club_order: Array = CLUB_ORDER.duplicate()
var players := []          # Array of player dictionaries, ratings derived
var players_by_club := {}  # code -> Array of player dictionaries
var draftees := []         # the shipped draft class, projections applied
var late_draftees := []    # generated future classes registered at runtime
var appearance := {}       # "first|last|dob" -> {skin, hair, status, club}: curated looks
var skin_mix: Array = Appearance.DEFAULT_SKIN_MIX
var loaded := false
## The 2026 league's mean overall. Each rollover re-anchors the league to it
## (Prospects.renormalise_league), so ratings stay relative to the league.
var baseline_overall := 0.0
var baseline_spread := 0.0   # standard deviation of the 2026 overalls

## Fictional alias cursor shared by the season pool, the draft class and every
## generated intake, so no two displayed players ever collide on an alias.
var _alias_candidates: Array = []
var _alias_next := 0
var _real_names := {}


## A player's age at the start of the first playable season (START_DATE),
## from his date of birth. Without one, the dataset's 2026 age plus a year.
static func age_at_start(dob: String, age_2026: float) -> float:
	if dob.length() >= 10:
		return float(Prospects.days_between(dob, START_DATE)) / 365.25
	return age_2026 + 1.0


func _ready() -> void:
	reload()


func reload() -> void:
	clubs = _load_clubs()
	club_order = CLUB_ORDER.duplicate()
	_alias_candidates = []
	_alias_next = 0
	_real_names = {}
	players = _load_players()
	_load_appearance()
	_apply_origin(players)
	Ratings.derive_all(players)
	_apply_history(players)
	for p in players:
		Potential.assign(p)
	_apply_potential_overrides(players)
	draftees = _load_draftees()
	late_draftees = []

	players_by_club = {}
	for code in club_order:
		players_by_club[code] = []
	for p in players:
		if not players_by_club.has(p["club"]):
			players_by_club[p["club"]] = []
		players_by_club[p["club"]].append(p)

	loaded = not players.is_empty()
	baseline_overall = 0.0
	for p in players:
		baseline_overall += float(p["overall"])
	if loaded:
		baseline_overall /= float(players.size())
		var sq := 0.0
		for p in players:
			sq += pow(float(p["overall"]) - baseline_overall, 2.0)
		baseline_spread = sqrt(sq / float(players.size()))
	if not loaded:
		push_error("GameDB: no players loaded. Check that %s exists, is complete and that its import type is 'Keep File (exported as is)'." % PLAYERS_ENRICHED_CSV)
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


## Clubs whose third colour is a real club colour (Adelaide's gold, the
## Bulldogs' white); the others' "accent" is only a tint for the pitch.
const THREE_COLOUR_CLUBS := ["ADE", "BRL", "GCS", "GWS", "PAD", "STK", "WBD", "TAS", "CANB"]


## The colours a club is known by, for its marker: two or three.
func club_marker_colours(code: String) -> Array:
	var cols := club_colours(code)
	if THREE_COLOUR_CLUBS.has(code) or bool(clubs.get(code, {}).get("custom", false)):
		return cols
	return cols.slice(0, 2)


## Add a created club (ClubForge.make_club) to the competition, after the
## clubs that ship. Registering it again replaces it.
func register_club(row: Dictionary) -> void:
	var code := str(row.get("code", ""))
	if code == "":
		return
	clubs[code] = row
	if not club_order.has(code):
		club_order.append(code)
	if not players_by_club.has(code):
		players_by_club[code] = []


## Take every created club out again (a new career, or loading another save).
func unregister_custom_clubs() -> void:
	for code in clubs.keys():
		if bool(clubs[code].get("custom", false)):
			clubs.erase(code)
			club_order.erase(code)
			players_by_club.erase(code)


## Guernsey designs the vignette figures can wear, in figure.gdshader's numbering.
const GUERNSEY_DESIGNS := ["plain", "stripes", "hoops", "sash", "yoke", "band", "chevrons", "panels",
		"chevron", "sides", "tiers", "shoulders", "map", "suit"]   # suit: the coach, not a club


## A club's home kit, from data/clubs.csv's "guernsey" column:
## "<design>:<base>/<pattern>/<pattern 2>[/<shorts>]". Each colour is p, s or a
## (the club's primary, secondary or accent) or a #RRGGBB colour the club's
## three don't cover (Port Adelaide's white chevron). The base colour is the
## guernsey's and the socks'; the pattern colour draws the design and the sock
## band; the second pattern colour is a design's third colour or trim. Shorts
## left out are the secondary colour, a shade darker. Richmond is "sash:s/p/a":
## a black guernsey with a yellow sash. Unknown or missing: plain.
func club_guernsey(code: String) -> Dictionary:
	var cols := club_colours(code)
	var parts := str(clubs.get(code, {}).get("guernsey", "")).split(":")
	var design := parts[0] if GUERNSEY_DESIGNS.has(parts[0]) else "plain"
	var slots := (parts[1] if parts.size() > 1 else "p/s/a").split("/")
	var pick := func(i: int, fallback: Color) -> Color:
		if i >= slots.size():
			return fallback
		var token := str(slots[i])
		if token.begins_with("#"):
			return Color.from_string(token, fallback)
		var at := "psa".find(token)
		return cols[at] if at >= 0 and token.length() == 1 else fallback
	return {"design": design, "base": pick.call(0, cols[0]), "pattern": pick.call(1, cols[1]),
			"pattern2": pick.call(2, cols[2]), "shorts": pick.call(3, (cols[1] as Color).darkened(0.1)),
			# The third colour is named for this kit (Port's teal, St Kilda's black),
			# not left to the club's accent.
			"own_pattern2": slots.size() > 2 and str(slots[2]) != "a"}


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
	# A class made again (a new seed) replaces its first version, by id.
	var ids := {}
	for p in list:
		ids[str(p.get("id", ""))] = true
	late_draftees = late_draftees.filter(func(q): return not ids.has(str(q.get("id", ""))))
	for p in list:
		late_draftees.append(p)


## Real names are the default, and fictional labels are opt-in. Real-name mode shows the AFL name on its
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
	# A player who joined a list during the career: name him from the lists.
	if id != "":
		var listed := GameState.season_player_name(id)
		if listed != "":
			return listed
	return fallback


## A surname for a caption or a tight label: the real last name in real-name
## mode, otherwise the last word of the fictional name. A long one is cut
## ("Papaioannou" reads "Papaioann.").
func player_surname(player: Dictionary) -> String:
	var raw := ""
	if GameState.show_real_names and str(player.get("last", "")) != "":
		raw = str(player["last"])
	else:
		var generic := str(player.get("generic_name", player.get("name", "Player")))
		var parts := generic.split(" ", false)
		raw = parts[parts.size() - 1] if not parts.is_empty() else "Player"
	if raw.length() > 10:
		raw = raw.substr(0, 9) + "."
	return raw


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
		# The class drafted in November 2026 joins lists for 2027: aged as of
		# the first playable season, like everyone else.
		p["age"] = age_at_start(str(p["dob"]), 17.3)
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
## How a player looks on the vignette figures - {"skin": 0-5, "hair": 0-5},
## indices into Appearance.SKIN and Appearance.HAIR. A real player's curated
## row; a generated player's look drawn from his id alone (never from ratings or
## traits); a real player not yet curated, Appearance.UNCURATED - never a guess.
func player_looks(p: Dictionary) -> Dictionary:
	# Colours chosen for him in Club Forge come first.
	var chosen = p.get("look")
	if chosen is Dictionary and Appearance.valid("skin", chosen.get("skin")) and Appearance.valid("hair", chosen.get("hair")):
		return {"skin": int(chosen["skin"]), "hair": int(chosen["hair"])}
	var row: Dictionary = appearance.get(_look_key(p), {})
	if not row.is_empty():
		return {"skin": int(row["skin"]), "hair": int(row["hair"])}
	if bool(p.get("generated", false)):
		return Appearance.generated(str(p.get("id", "")), skin_mix)
	return Appearance.UNCURATED


## A player's whole look (Appearance.full): his colours as player_looks gives
## them, plus hair style, facial hair, boots, socks, tattoos and the rest -
## what he was given in Club Forge (p["look"]), seeded variety for a generated
## player, the plain base look for a real one.
func player_appearance(p: Dictionary) -> Dictionary:
	return Appearance.full(player_looks(p), str(p.get("id", "")), bool(p.get("generated", false)),
			p.get("look", {}) if p.get("look") is Dictionary else {})


## What a figure needs to draw him: his colours (player_looks), his hair style and
## whether he wears long sleeves today (more do in the wet).
func figure_look(p: Dictionary, wet := false) -> Dictionary:
	var out := player_looks(p).duplicate()
	out["hair_style"] = str(player_appearance(p)["hair_style"])
	out["long_sleeves"] = Appearance.long_sleeves(str(p.get("id", "")), wet)
	return out


static func _look_key(p: Dictionary) -> String:
	return "%s|%s|%s" % [str(p.get("first", "")).to_lower(), str(p.get("last", "")).to_lower(), str(p.get("dob", ""))]


## Set p["home_state"] from data/player_origin_2026.csv, matched on club,
## number, first and last name. A player with no row or a blank state keeps
## no home_state.
func _apply_origin(list: Array) -> void:
	var rows := _read_rows(ORIGIN_CSV)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[str(header[j]).strip_edges()] = j
	for key in ["club", "num", "first", "last", "state"]:
		if not idx.has(key):
			push_error("GameDB: %s has no '%s' column" % [ORIGIN_CSV, key])
			return
	var state_of := {}
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var st := str(cells[idx["state"]]).strip_edges()
		if st == "":
			continue
		state_of["%s|%s|%s|%s" % [str(cells[idx["club"]]), str(cells[idx["num"]]),
				str(cells[idx["first"]]), str(cells[idx["last"]])]] = st
	for p in list:
		var key := "%s|%d|%s|%s" % [str(p["club"]), int(p["num"]), str(p["first"]), str(p["last"])]
		if state_of.has(key):
			p["home_state"] = state_of[key]


## data/player_appearance.csv: first,last,dob,club,skin (1-6),hair (a HAIR_KEYS
## key),status (draft / unsure / confirmed),source. Rows that don't parse are
## skipped with an error; a missing file just means no curated looks yet.
func _load_appearance() -> void:
	appearance = {}
	skin_mix = Appearance.DEFAULT_SKIN_MIX
	if not FileAccess.file_exists(APPEARANCE_CSV):
		return
	var rows := _read_rows(APPEARANCE_CSV)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var counts := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var r := {}
		for j in range(header.size()):
			r[str(header[j])] = str(cells[j]).strip_edges()
		var skin := int(r.get("skin", "0")) - 1
		var hair := Appearance.HAIR_KEYS.find(str(r.get("hair", "")))
		if skin < 0 or skin >= Appearance.SKIN.size() or hair < 0:
			push_error("GameDB: bad appearance row %d in %s" % [i + 1, APPEARANCE_CSV])
			continue
		appearance[_look_key(r)] = {"skin": skin, "hair": hair, "status": str(r.get("status", "draft")),
				"club": str(r.get("club", ""))}
		counts[skin] += 1.0
	if appearance.size() >= MIX_FROM:
		skin_mix = counts


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
		d["enter"] = int(d.get("enter", "2026"))
		out[str(d["code"])] = d
	return out


## The year a club first fields a team (2026 for the founding eighteen).
func enter_year(code: String) -> int:
	return int(clubs.get(code, {}).get("enter", 2026))


## The clubs active in a given season year, in club order. Fixtures, ladders,
## drafts and selections all iterate this - never CLUB_ORDER - so expansion
## clubs (and a created one) join the competition on schedule without any
## club-specific code.
func active_clubs(year: int) -> Array:
	var out := []
	for code in club_order:
		if enter_year(code) <= year:
			out.append(code)
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
	# A real listed player's name is never handed out as an alias.
	for p in list:
		var real := str(p.get("real_name", ""))
		if real != "":
			_real_names[real] = true
	for i in range(list.size()):
		var label := _alias_at(_alias_next)
		_alias_next += 1
		while _real_names.has(label):
			label = _alias_at(_alias_next)
			_alias_next += 1
		list[i]["generic_name"] = label
		list[i]["name"] = label


func _alias_at(idx: int) -> String:
	return str(_alias_candidates[idx]) if idx < _alias_candidates.size() \
			else _overflow_alias(idx - _alias_candidates.size())


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
	var firsts := _shuffled(FICTIONAL_FIRST_NAMES, FICTIONAL_NAME_SEED)
	var lasts := _shuffled(FICTIONAL_LAST_NAMES, FICTIONAL_NAME_SEED + 1)
	var candidates := []
	for k in range(firsts.size() * lasts.size()):
		candidates.append("%s %s" % [firsts[k % firsts.size()], lasts[k % lasts.size()]])
	_alias_candidates = candidates


static func _shuffled(words: Array, seed: int) -> Array:
	var out := words.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


## The enriched file is required. There is deliberately no fallback to the
## stats-only players_2026.csv: it has no dob/age, and loading it silently
## gave every player age 0 (every exported build did this while the enriched
## CSV was on the csv_translation importer), which breaks ageing, potential,
## retirement and the Rising Star. Missing or incomplete bio data is an error
## and loads no players, so the main menu reports it instead of a career
## starting on bad data.
func _load_players() -> Array:
	var rows := _read_rows(PLAYERS_ENRICHED_CSV)
	var out := []
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j
	for key in ["dob", "age", "height_cm"]:
		if not idx.has(key):
			push_error("GameDB: %s has no '%s' column; refusing to load players without bio data." % [PLAYERS_ENRICHED_CSV, key])
			return []

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
		if float(p["age"]) <= 0.0:
			push_error("GameDB: %s has no age for %s %s (%s); refusing to load incomplete player data." % [
					PLAYERS_ENRICHED_CSV, p["first"], p["last"], p["club"]])
			return []
		p["age"] = age_at_start(str(p["dob"]), float(p["age"]))
		# The club he played the 2026 season for: his career record takes the
		# real 2026 season there when a career starts (GameState.start_season).
		p["data_club"] = str(p["club"])
		out.append(p)
	_assign_fictional_names(out)
	return out


## Attach each player's AFL draft pedigree (drafted_year / drafted_type /
## drafted_pick) and his rated recent seasons (history: [[year, overall,
## games], ...]) for the potential model. Missing file: no history, POT
## falls back to age headroom. Also his AFL career to 2025 (p["career"], see
## Career.gd): a player the file does not cover has an unknown past, not none.
func _apply_history(list: Array) -> void:
	_apply_history_rows(list)
	for p in list:
		if not p.has("career"):
			p["career"] = Career.from_source("?")


func _apply_history_rows(list: Array) -> void:
	if not FileAccess.file_exists(HISTORY_CSV):
		return
	var rows := _read_rows(HISTORY_CSV)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[str(header[j]).strip_edges()] = j
	var by_id := {}
	for p in list:
		by_id[str(p["id"])] = p
	var seen := {}
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var key := "%s_%s" % [str(cells[idx["club"]]), str(cells[idx["num"]])]
		# The career follows the row to its own player: a second row on one
		# number (Sydney's #36) is that club's "_2" player, as ids are made.
		# Draft and history keep their long-standing club + number match.
		var nth := int(seen.get(key, 0)) + 1
		seen[key] = nth
		if idx.has("career"):
			var own = by_id.get(key if nth == 1 else "%s_%d" % [key, nth])
			if own != null:
				own["career"] = Career.from_source(str(cells[idx["career"]]))
		var p = by_id.get(key)
		if p == null:
			continue
		var pick := str(cells[idx["draft_pick"]])
		if pick != "":
			p["drafted_year"] = int(str(cells[idx["draft_year"]]))
			p["drafted_type"] = str(cells[idx["draft_type"]])
			p["drafted_pick"] = int(pick)
		var hist := []
		for chunk in str(cells[idx["seasons"]]).split(";", false):
			var parts := chunk.split(":")
			if parts.size() == 3:
				hist.append([int(parts[0]), int(parts[1]), int(parts[2])])
		if not hist.is_empty():
			p["history"] = hist


## Hand-set potentials, matched on club + first + last name. An unmatched row
## is reported rather than silently ignored, so a typo is easy to spot.
func _apply_potential_overrides(list: Array) -> void:
	if not FileAccess.file_exists(POTENTIAL_CSV):
		return
	var rows := _read_rows(POTENTIAL_CSV)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[str(header[j]).strip_edges()] = j
	for key in ["club", "first", "last", "potential"]:
		if not idx.has(key):
			push_warning("GameDB: %s needs a '%s' column" % [POTENTIAL_CSV, key])
			return
	var by_key := {}
	for p in list:
		by_key["%s|%s|%s" % [p["club"], str(p["first"]).to_lower(), str(p["last"]).to_lower()]] = p
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var key := "%s|%s|%s" % [str(cells[idx["club"]]).strip_edges(),
				str(cells[idx["first"]]).strip_edges().to_lower(),
				str(cells[idx["last"]]).strip_edges().to_lower()]
		if not by_key.has(key):
			push_warning("GameDB: potential override matches no player: %s" % key)
			continue
		Potential.set_override(by_key[key], int(str(cells[idx["potential"]])))


func _hex(s) -> Color:
	if s is Color:
		return s
	return Color.html(str(s))
