extends Node
## GameDB (autoload) - reads the harvested season data once at boot and exposes
## it to every other system.
##
## Data files ship as plain CSV under res://data/. Their .import files set the
## importer to "keep" so Godot exports them verbatim instead of converting them
## into translation resources; FileAccess then reads them at runtime on both
## desktop and mobile. A CSV left on Godot's default (csv_translation) importer
## is missing from an exported build: tools/check_export_data.sh guards this.

## Chronology. The data is one completed AFL season (stats, ratings, careers
## through it, the draft class after it); a career starts with the next
## season, taking over the league that season produced. Ages are as of the
## start of the first playable season. Which season is the career's choice
## (Datasets, Legacy mode row 142): reload(dataset) sets these from its row.
## Today's start is the 2026 data and a 2027 first season. The names keep the
## upper case they had as constants, so every reader stays as it was.
var dataset_id := Datasets.DEFAULT
var DATA_SEASON := 2026
var START_YEAR := 2027
var START_DATE := "2027-03-01"

const CLUBS_CSV := "res://data/clubs.csv"
## The dataset's files (Datasets.FILE_KEYS), set by reload(); "" is a file the
## era has none of. The player pool: the data season's stats plus bio fields
## (dob, age, height). Required - see _load_players(). For 2026,
## data/players_2026.csv (stats only) is the Python tools' source and is not
## read by the game.
var PLAYERS_ENRICHED_CSV := "res://data/players_enriched_2026.csv"
var DRAFTEES_CSV := "res://data/draftees_2026.csv"
var POTENTIAL_CSV := "res://data/potential_overrides.csv"
## The season's coaching staff and captains (Datasets keys coaches, leadership).
var COACHES_CSV := "res://data/coaches_2026.csv"
var LEADERSHIP_CSV := "res://data/leadership_2026.csv"
var OVR_CSV := "res://data/ovr_overrides.csv"
## Which override rows (file|club|first|last) found their player, and the rows
## that found nobody in the players or the list additions.
var override_hits := {}
var override_unmatched: Array = []
## Tests that measure how the rules spread players over the underlying data (not
## the director's hand-set numbers) turn the OVR rows off for a reload; tools/run_tests.sh
## turns them off for every suite but the ratings one (AFL_SKIP_OVR_ROWS=1).
var skip_ovr_overrides := OS.get_environment("AFL_SKIP_OVR_ROWS") == "1"
## Draft pedigree and rated past seasons, built by tools/build_history.py.
var HISTORY_CSV := "res://data/player_history_2026.csv"
## How real players look on the vignette figures (Appearance.gd): skin tone and
## hair colour, drafted from public photos and reviewed by the director.
const APPEARANCE_CSV := "res://data/player_appearance.csv"
## Where each 2026 player came from (a state, or INT), from his recruiting source;
## built by tools/build_player_origin.py. A blank state is left unset.
var ORIGIN_CSV := "res://data/player_origin_2026.csv"
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
## Players registered on 2026 lists who played no senior game in 2026
## (data/list_additions_2026.csv, sourced club by club): they complete each
## club's real list in a real-lists career (ARD-M5-016). No 2026 numbers exist
## for them, so they are rated as the prospects they still are (Prospects.
## project), by age and list type; their position is estimated from height.
## Not in the League redraft pool.
var list_additions := []
var LIST_ADDITIONS_CSV := "res://data/list_additions_2026.csv"
## Senior numbers for the additions who have played AFL before (built by
## tools/build_addition_stats.py from AFL Tables, season in the "src" column):
## they are rated from that record through Ratings.derive_all, like any listed
## player, not as draft prospects.
var LIST_ADDITION_STATS_CSV := "res://data/list_additions_stats.csv"
## Which players who played a 2026 game were on a rookie list, not the senior
## list (data/list_types_2026.csv, from DraftGuru's 2026 lists, club by club):
## "rookie" (Category A) or "cat_b" (Category B). Everyone else in
## players_2026.csv is a senior-listed player. Read into p["list_type"], the key
## the list additions carry, so a real-lists career splits each club's list the
## way the club really had it (RookieList.seed_lists).
var LIST_TYPES_CSV := "res://data/list_types_2026.csv"
## Who left a list at the end of 2026, before the National Draft: the key
## "first|last|dob" (lower case) to the kind ("retired", "delisted",
## "rookie_delisted", "catb_delisted").
var departures := {}
var DEPARTURES_CSV := "res://data/departures_2026.csv"
## Who changed club in the 2026 trade period and free agency, after the 2026
## season and before the National Draft: the key "first|last|dob" (lower case)
## to {"from", "to", "kind"} ("traded" or "free_agent"). The 2026 season record
## (players_2026.csv, checked club by club against AFL Tables) stays as it was
## played; a real-lists career moves these players when it opens
## (GameState.begin_real_lists).
var club_moves := {}
var CLUB_MOVES_CSV := "res://data/club_moves_2026.csv"
var late_draftees := []    # generated future classes registered at runtime
## The launch lists at their peak, for "Plays like" (PlaysLike.build_pool): taken at
## load, before a career ages anyone, so the comparison never moves.
var plays_like_pool := []
var appearance := {}       # "first|last|dob" -> {skin, hair, status, club}: curated looks
var skin_mix: Array = Appearance.DEFAULT_SKIN_MIX
var loaded := false
## True from a reload until a career takes the data (GameState.reset() clears it):
## a career mutates the player dicts in place, so only an untouched load is reused.
var pristine := false
## The 2026 league's mean overall. Each rollover re-anchors the league to it
## (Prospects.renormalise_league), so ratings stay relative to the league.
var baseline_overall := 0.0
var baseline_spread := 0.0   # standard deviation of the 2026 overalls

## Fictional alias cursor shared by the season pool, the draft class and every
## generated intake, so no two displayed players ever collide on an alias.
var _alias_candidates: Array = []
var _alias_next := 0
var _real_names := {}
var _state_aliases := {}   # alias -> true: labels given to state league men

## The state leagues (TODO row 128): the VFL, SANFL and WAFL of the data season,
## loaded only by a dataset whose row names a state_leagues folder (2026). They
## sit beside the AFL, never in it: clubs, club_order, players and
## players_by_club stay the AFL's, and loading them moves no AFL rating, id or
## alias. club(), club_name(), club_short() and club_colours() also answer for
## a state code.
var STATE_LEAGUES_DIR := ""
const STATE_LEAGUE_IDS := ["VFL", "SANFL", "WAFL"]
## The 2026 League stat columns a state file may carry; a league that does not
## record one leaves it blank, and the man's stat_cols lists only those it has.
const STATE_STAT_KEYS := ["gm", "gl", "bh", "di", "ki", "hb", "mk", "tk", "ho", "cl", "if50", "rb", "cm",
		"ff", "fa"]
const STATE_INT_KEYS := ["res_gm", "res_gl", "colts_gm", "colts_gl", "career_gm_pre2026"]
var state_leagues := {}          # id -> leagues.csv row, numbers typed
var state_clubs := {}            # code -> club row: league, kind, afl_club, colours as Color
var state_players := []          # state-only men; AFL-listed men are in state_links, not here
var state_players_by_club := {}  # code -> Array of state_players rows
var state_links := []            # afl_links rows: an AFL id and the state club he also played for


## A player's age at the start of the first playable season (START_DATE),
## from his date of birth. Without one, his data-season age plus a year.
func age_at_start(dob: String, age_in_data: float) -> float:
	if dob.length() >= 10:
		return float(Prospects.days_between(dob, START_DATE)) / 365.25
	return age_in_data + 1.0


func _ready() -> void:
	reload()


## Full loads of the data files this run: tests count them.
var reloads := 0


## Load a dataset (Datasets): today's 2026 set unless a career chose another.
## An unknown id loads nothing and says so; the last load stays.
func reload(dataset := Datasets.DEFAULT) -> void:
	var row := Datasets.get_set(dataset)
	if row.is_empty():
		push_error("GameDB: no dataset '%s'; nothing reloaded." % dataset)
		return
	reloads += 1
	_use_dataset(dataset, row)
	clubs = _load_clubs()
	club_order = CLUB_ORDER.duplicate()
	era_pins = {}
	colour_shades = {}
	_load_club_years()
	apply_era(START_YEAR)
	_alias_candidates = []
	_alias_next = 0
	_real_names = {}
	_state_aliases = {}
	players = _load_players()
	_apply_list_types(players)
	_load_appearance()
	_apply_origin(players)
	Ratings.era_anchors = {}
	Ratings.derive_all(players)
	# A past start scales each position on its own data season (director
	# 2026-11-13, "Scale each position per season"); a set on today's season
	# (2026's, or a test copy of it) keeps 2026's.
	if DATA_SEASON != int(Datasets.get_set(Datasets.DEFAULT).get("data_season", DATA_SEASON)):
		Ratings.fit_era_anchors(players)
	_apply_history(players)
	for p in players:
		Ratings.rate_on_record(p, DATA_SEASON)
		Ratings.rate_on_honours(p)
	override_hits = {}
	for p in players:
		Potential.assign(p)
	_apply_ovr_overrides(players)
	_apply_potential_overrides(players)
	# The lists first: the prospects below borrow their shapes from these players
	# (Prospects._shape_for). Built later, the boot load drew them from nothing and
	# every reload from the lists of the load before it.
	players_by_club = {}
	for code in club_order:
		players_by_club[code] = []
	for p in players:
		if not players_by_club.has(p["club"]):
			players_by_club[p["club"]] = []
		players_by_club[p["club"]].append(p)
	Prospects.forget_cache()
	draftees = _load_draftees()
	list_additions = _load_list_additions()
	# List additions become real players here, so the hand-set numbers reach
	# them too; a row that matched nobody in either list is reported.
	_apply_ovr_overrides(list_additions)
	_apply_potential_overrides(list_additions)
	override_unmatched = _report_unmatched_overrides()
	departures = _load_departures()
	club_moves = _load_club_moves()
	mark_unicorns(players + draftees)
	plays_like_pool = PlaysLike.build_pool(players)
	late_draftees = []
	# Last, so every AFL list, rating and alias above is drawn as before.
	_load_state_leagues()


	loaded = not players.is_empty()
	pristine = loaded
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


## Point the season and every file at one dataset's row.
func _use_dataset(id: String, row: Dictionary) -> void:
	dataset_id = id
	DATA_SEASON = int(row["data_season"])
	Potential.peak_from_year = DATA_SEASON - 3
	START_YEAR = int(row["start_year"])
	START_DATE = str(row["start_date"])
	PLAYERS_ENRICHED_CSV = str(row.get("players", ""))
	DRAFTEES_CSV = str(row.get("draftees", ""))
	HISTORY_CSV = str(row.get("history", ""))
	ORIGIN_CSV = str(row.get("origin", ""))
	LIST_ADDITIONS_CSV = str(row.get("list_additions", ""))
	LIST_ADDITION_STATS_CSV = str(row.get("list_addition_stats", ""))
	LIST_TYPES_CSV = str(row.get("list_types", ""))
	DEPARTURES_CSV = str(row.get("departures", ""))
	CLUB_MOVES_CSV = str(row.get("club_moves", ""))
	LADDER_PATH = str(row.get("ladder", ""))
	OVR_CSV = str(row.get("ovr_overrides", ""))
	POTENTIAL_CSV = str(row.get("potential_overrides", ""))
	# A set that names no staff or captains (a test league) keeps 2026's.
	COACHES_CSV = str(row.get("coaches", Coaches.SEED_CSV))
	LEADERSHIP_CSV = str(row.get("leadership", Leadership.PATH))
	Leadership.use(LEADERSHIP_CSV, START_YEAR, CLUB_CODE_ALIASES)
	STATE_LEAGUES_DIR = str(row.get(Datasets.STATE_LEAGUES_KEY, ""))
	second_tier = SecondTier.load_dir(str(row.get(Datasets.SECOND_TIER_KEY, "")))
	second_tier_year = 0


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
## An AFL club, or a state league club by its state code.
func club(code: String) -> Dictionary:
	return clubs.get(code, state_clubs.get(code, {}))


func club_name(code: String) -> String:
	return str(club(code).get("name", code))


func club_short(code: String) -> String:
	return str(club(code).get("short", code))


func club_colours(code: String) -> Array:
	var c: Dictionary = club(code)
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
	pristine = false
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
	pristine = false
	for code in clubs.keys():
		if bool(clubs[code].get("custom", false)):
			clubs.erase(code)
			club_order.erase(code)
			players_by_club.erase(code)


## Guernsey designs the vignette figures can wear, in figure.gdshader's numbering.
const GUERNSEY_DESIGNS := ["plain", "stripes", "hoops", "sash", "yoke", "band", "chevrons", "panels",
		"chevron", "sides", "tiers", "shoulders", "map", "suit",   # suit: the coach, not a club
		# A real club's own design (from its home guernsey), not offered in Club Forge.
		"lowhoops", "giants", "wings", "twohoops",
		# Designs clubs wore in earlier seasons (Legacy mode, data/legacy/clubs_by_year.csv).
		"anchor", "power97", "eagles00", "swans90", "giants12", "saints97", "lions10",
		"dogs90", "dogs97", "crows06"]


## A club's home kit, from data/clubs.csv's "guernsey" column:
## "<design>:<base>/<pattern>/<pattern 2>[/<shorts>[/<pattern 3>]]". Each colour is p, s or a
## (the club's primary, secondary or accent) or a #RRGGBB colour the club's
## three don't cover (Port Adelaide's white chevron). The base colour is the
## guernsey's and the socks'; the pattern colour draws the design and the sock
## band; the second pattern colour is a design's third colour or trim. Shorts
## left out are the secondary colour, a shade darker. The third pattern colour is
## only the anchor's (Fremantle 1995-2010: white, green and red on purple); left out,
## it is the second. Richmond is "sash:s/p/a":
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
	var out := {"design": design, "base": pick.call(0, cols[0]), "pattern": pick.call(1, cols[1]),
			"pattern2": pick.call(2, cols[2]), "shorts": pick.call(3, (cols[1] as Color).darkened(0.1)),
			"pattern3": pick.call(4, pick.call(2, cols[2])),
			# The third colour is named for this kit (Port's teal, St Kilda's black),
			# not left to the club's accent.
			"own_pattern2": slots.size() > 2 and str(slots[2]) != "a"}
	# A Legacy season's real guernsey: its picture in the kit atlas (the design above still
	# gives the oval's discs and the colours).
	if clubs.get(code, {}).has("kit"):
		out["kit_cell"] = int(clubs[code]["kit"])
	return out


func club_list(code: String) -> Array:
	return players_by_club.get(code, [])


## The dataset's own final ladder (data/ladder_2026.csv for 2026, sourced).
var LADDER_PATH := "res://data/ladder_2026.csv"
## Each decade's real ladders, one file per decade with a "year" column (the
## Legacy mode data, data/legacy/<decade>s/ladders.csv).
const LEGACY_LADDERS := "res://data/legacy/%ds/ladders.csv"


## A real season's final ladder: rows of {"pos", "club", "finals"} in ladder
## order. The data season reads the dataset's own ladder, any other season
## its decade's file. [] when no file has that season.
func ladder_of(season: int) -> Array:
	var out := []
	if season == DATA_SEASON and LADDER_PATH != "":
		out = _read_ladder(LADDER_PATH, season)
	if out.is_empty():
		out = _read_ladder(LEGACY_LADDERS % (season - posmod(season, 10)), season)
	return out


func _read_ladder(path: String, season: int) -> Array:
	var out := []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header := f.get_csv_line()
	var at := {}
	for i in range(header.size()):
		at[header[i].strip_edges()] = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size() or str(row[0]).strip_edges() == "":
			continue
		# A file of many seasons keeps the one asked for; a one-season file has no year.
		if at.has("year") and int(row[at["year"]]) != season:
			continue
		out.append({"pos": int(row[at["pos"]]), "club": club_code(str(row[at["club"]]).strip_edges()),
				"finals": str(row[at["finals"]]).strip_edges() if at.has("finals") else ""})
	out.sort_custom(func(a, b): return int(a["pos"]) < int(b["pos"]))
	return out


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
	pristine = false
	# A class made again (a new seed) replaces its first version, by id.
	var ids := {}
	for p in list:
		ids[str(p.get("id", ""))] = true
	late_draftees = late_draftees.filter(func(q): return not ids.has(str(q.get("id", ""))))
	for p in list:
		late_draftees.append(p)


## A real player is always shown under his AFL name, on its own ("Jordan
## Dawson"; director, 2026-11-12: "Real Names only"). A generated prospect has
## no real name, so he keeps the name he was given.
func player_display_name(player: Dictionary) -> String:
	if player.is_empty():
		return ""
	var generic := str(player.get("generic_name", player.get("name", ""))).strip_edges()
	var real := str(player.get("real_name", "")).strip_edges()
	if real != "":
		return real
	# A generated son or brother of a real player carries his real surname.
	var fam := str(player.get("family_real_last", "")).strip_edges()
	if fam != "" and generic != "":
		return "%s %s" % [generic.get_slice(" ", 0), fam]
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


## The surname on a player card. Generated draftees and expansion players carry
## "last": "" (the key exists, so a plain get() never falls back), which left
## their cards without a name. Empty last: the last word of the shown name.
func card_surname(player: Dictionary) -> String:
	var last := str(player.get("last", "")).strip_edges()
	if last != "":
		return last
	var full := player_display_name(player)
	var parts := full.split(" ", false)
	return parts[parts.size() - 1] if not parts.is_empty() else full


## A surname for a caption or a tight label: his last name, or for a generated
## player without one the last word of his name. A long one is cut
## ("Papaioannou" reads "Papaioann.").
func player_surname(player: Dictionary) -> String:
	var raw := ""
	if str(player.get("last", "")) != "":
		raw = str(player["last"])
	else:
		var generic := str(player.get("generic_name", player.get("name", "Player")))
		var parts := generic.split(" ", false)
		raw = parts[parts.size() - 1] if not parts.is_empty() else "Player"
	if raw.length() > 10:
		raw = raw.substr(0, 9) + "."
	return raw


## What a search matches: his real name and, for a generated player, his given one.
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
## The Unicorns at the start of a career, picked by the director
## (2026-10-08): real players and the 2026 draft class, by their own names.
## Traits.is_unicorn reads the flag this sets.
const UNICORNS := ["Luke Jackson", "Sam Darcy", "Mark Blicavs", "Xavier Ladbrook"]


## Flag the hand-picked Unicorns among `list` by real name (a player keeps
## his name wherever the draft sends him), never a generated player. A save
## from before the flag gets it back on load (GameState).
func mark_unicorns(list: Array) -> void:
	pristine = false
	for p in list:
		if bool(p.get("generated", false)):
			continue
		if UNICORNS.has("%s %s" % [str(p.get("first", "")), str(p.get("last", ""))]):
			p["unicorn"] = true


func _load_draftees() -> Array:
	if DRAFTEES_CSV == "":
		return []   # an era whose classes the draft years load, not the dataset
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
		p["id"] = "D%d_%02d" % [DATA_SEASON, rank]
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
		p["draft_year"] = DATA_SEASON
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
		p["draft_class"] = true  # a draft class: rated on Prospects.DRAFT_NIGHT_SCALE (row 65)
		Prospects.project(p)
		out.append(p)
	_assign_fictional_names(out)
	return out


func _load_list_additions() -> Array:
	var out := []
	if not FileAccess.file_exists(LIST_ADDITIONS_CSV):
		return out
	var rows := _read_rows(LIST_ADDITIONS_CSV)
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j
	var record := _load_addition_stats()
	var established := []
	var n := 0
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size() or _cell_str(cells, idx, "club") == "":
			continue
		n += 1
		var p := {}
		p["first"] = _cell_str(cells, idx, "first")
		p["last"] = _cell_str(cells, idx, "last")
		p["real_name"] = "%s %s" % [p["first"], p["last"]]
		p["generic_name"] = ""
		p["name"] = ""
		var club := _cell_str(cells, idx, "club")
		p["id"] = "L%d_%s_%03d" % [DATA_SEASON, club, n]
		p["club"] = club
		p["num"] = 0
		p["src"] = "LIST"
		for k in STAT_KEYS:
			p[k] = 0.0
		p["height_cm"] = float(_cell_int(cells, idx, "height_cm"))
		p["weight_kg"] = 0.0
		p["dob"] = _cell_str(cells, idx, "dob")
		p["age"] = age_at_start(str(p["dob"]), 20.0)
		p["debut"] = ""
		p["height_source"] = "club list"
		var list_type := _cell_str(cells, idx, "list")
		p["list_type"] = list_type
		if _cell_str(cells, idx, "peak") != "":
			p["real_peak"] = _cell_int(cells, idx, "peak")
		if _cell_str(cells, idx, "last_season") != "":
			p["real_last"] = _cell_int(cells, idx, "last_season")
		var pos := _cell_str(cells, idx, "position")
		p["role"] = pos if pos in ["RUCK", "MID", "DEF", "FWD"] else listed_role(p)
		p["role2"] = ""
		p["real_pos"] = Ratings.ROLE_SHORT_TO_POS.get(str(p["role"]), "MID")
		p["role_estimated"] = pos == ""
		var rec = record.get("%s|%s|%s" % [club, p["first"], p["last"]])
		if rec != null:
			# Played AFL before: rated on that season, as any listed player is.
			for k in STAT_KEYS:
				p[k] = float(rec.get(k, 0.0))
			p["real_pos"] = pos if pos != "" else ""
			p["role_estimated"] = false
			p["stats_year"] = int(rec.get("src", 0))
			p["data_src"] = "listed %d, rated on his %d season" % [DATA_SEASON, int(rec.get("src", 0))]
			p["draft_year"] = DATA_SEASON
			p["draft_rank"] = 0
			p["draft_team"] = ""
			p["draft_league"] = ""
			p["draft_state"] = ""
			p["tied_club"] = ""
			p["tied_type"] = ""
			for k in ["u18_gm", "u18_di", "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho"]:
				p[k] = 0.0
			p["note"] = ""
			established.append(p)
			continue
		# Rated as the prospect he still is: a recent draftee about where a
		# mid-first-round pick sits, an older or rookie-listed player lower.
		var h := absi(hash(str(p["id"])))
		var age := float(p["age"])
		var rank := 22 + h % 20
		if age >= 21.5 or list_type == "cat_b" or list_type == "catb":
			rank = 45 + h % 15
		elif list_type == "rookie" or age >= 20.5:
			rank = 35 + h % 15
		p["draft_year"] = DATA_SEASON
		p["draft_rank"] = rank
		p["draft_team"] = ""
		p["draft_league"] = ""
		p["draft_state"] = ""
		p["tied_club"] = ""
		p["tied_type"] = ""
		for k in ["u18_gm", "u18_di", "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho"]:
			p[k] = 0.0
		p["note"] = ""
		p["data_src"] = "listed %d, no senior game" % DATA_SEASON
		Prospects.project(p)
		out.append(p)
	if not established.is_empty():
		Ratings.derive_all(established, players)
		for p in established:
			# A position the list gives him is his first position, whatever
			# one season's numbers read (Powell-Pepper is a midfielder).
			var listed := str(p.get("real_pos", ""))
			if listed in ["RUCK", "MID", "DEF", "FWD"] and listed != str(p["role"]):
				p["role"] = listed
				p["role2"] = Ratings.assign_secondary(p)
				p["overall"] = Ratings.rate_overall(p["attr"], listed, float(p["gm"]))
				p["value"] = Ratings.salary_value(int(p["overall"]))
			p["career"] = Career.from_source("?")
			p["data_club"] = str(p["club"])
			Potential.assign(p)
		_apply_potential_overrides(established)
		out.append_array(established)
	_assign_fictional_names(out)
	return out


## club|first|last -> the stats row (strings read as numbers) for each
## addition in LIST_ADDITION_STATS_CSV.
func _load_addition_stats() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(LIST_ADDITION_STATS_CSV):
		return out
	var rows := _read_rows(LIST_ADDITION_STATS_CSV)
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size():
			continue
		var d := {}
		for j in range(header.size()):
			d[str(header[j]).strip_edges()] = str(cells[j]).strip_edges()
		out["%s|%s|%s" % [d["club"], d["first"], d["last"]]] = d
	return out


## A listed player's position when no source gives one: from his height, the
## tall ones split between the key posts by a stable roll on his id.
static func listed_role(p: Dictionary) -> String:
	var h := float(p.get("height_cm", 0.0))
	var roll := absi(hash("role|" + str(p.get("id", "")))) % 100
	if h >= 200.0:
		return "RUCK"
	if h >= 192.0:
		return "DEF" if roll < 50 else "FWD"
	if roll < 45:
		return "MID"
	return "DEF" if roll < 72 else "FWD"


## A club's 2026 listed players who played no senior game (list_additions).
func club_additions(code: String) -> Array:
	return list_additions.filter(func(q): return str(q.get("club", "")) == code)


## Mark the rookie-listed players of the data season (LIST_TYPES_CSV) by
## club, first and last name. A row that matches nobody is reported.
func _apply_list_types(list: Array) -> void:
	if LIST_TYPES_CSV == "" or not FileAccess.file_exists(LIST_TYPES_CSV):
		return
	var rows := _read_rows(LIST_TYPES_CSV)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j
	var want := {}
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size() or _cell_str(cells, idx, "list") == "":
			continue
		var key := ("%s|%s|%s" % [_cell_str(cells, idx, "club"), _cell_str(cells, idx, "first"),
				_cell_str(cells, idx, "last")]).to_lower()
		want[key] = _cell_str(cells, idx, "list")
	var hit := {}
	for p in list:
		var key := ("%s|%s|%s" % [str(p.get("club", "")), str(p.get("first", "")), str(p.get("last", ""))]).to_lower()
		if want.has(key):
			p["list_type"] = want[key]
			hit[key] = true
	for key in want:
		if not hit.has(key):
			push_warning("GameDB: %s names %s, who is not in the players file." % [LIST_TYPES_CSV, key])


func _load_departures() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(DEPARTURES_CSV):
		return out
	var rows := _read_rows(DEPARTURES_CSV)
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size() or _cell_str(cells, idx, "kind") == "":
			continue
		var key := _look_key({"first": _cell_str(cells, idx, "first"),
				"last": _cell_str(cells, idx, "last"), "dob": _cell_str(cells, idx, "dob")})
		out[key] = _cell_str(cells, idx, "kind")
	return out


## How this player left his list at the end of 2026 ("" if he stayed).
func departure_kind(p: Dictionary) -> String:
	return str(departures.get(_look_key(p), ""))


func _load_club_moves() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(CLUB_MOVES_CSV):
		return out
	var rows := _read_rows(CLUB_MOVES_CSV)
	if rows.size() < 2:
		return out
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[header[j]] = j
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if cells.size() < header.size() or _cell_str(cells, idx, "to_club") == "":
			continue
		var key := _look_key({"first": _cell_str(cells, idx, "first"),
				"last": _cell_str(cells, idx, "last"), "dob": _cell_str(cells, idx, "dob")})
		out[key] = {"from": _cell_str(cells, idx, "from_club"), "to": _cell_str(cells, idx, "to_club"),
				"kind": _cell_str(cells, idx, "kind"), "list": _cell_str(cells, idx, "list")}
	return out


## The club this player joined in the 2026 trade period or free agency, as
## {"from", "to", "kind", "list"}; {} if he stayed where he played 2026. "list"
## is the list he joined where a source names it ("rookie" or "cat_b"; "" or
## "senior" is the senior list).
func club_move(p: Dictionary) -> Dictionary:
	return club_moves.get(_look_key(p), {})


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
	# His premiership years on the bicep (PremiershipInk), hidden under a long sleeve.
	out["flag_ink"] = 0 if bool(out["long_sleeves"]) else PremiershipInk.years(p).size()
	return out


## Punctuation does not matter to the key: a career saved before the data kept
## "O'Sullivan" still has "OSullivan" in its players and finds his look.
static func _look_key(p: Dictionary) -> String:
	return "%s|%s|%s" % [str(p.get("first", "")).to_lower().replace("'", ""),
			str(p.get("last", "")).to_lower().replace("'", ""), str(p.get("dob", ""))]


## Set p["home_state"] from data/player_origin_2026.csv, matched on club,
## number, first and last name. A player with no row or a blank state keeps
## no home_state.
func _apply_origin(list: Array) -> void:
	if ORIGIN_CSV == "":
		return
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
	var out := _load_club_rows(CLUBS_CSV)
	if out.is_empty():
		return out
	var past := _load_club_rows(PAST_CLUBS_CSV)
	for code in past:
		if not out.has(code):
			out[code] = past[code]
	return out


func _load_club_rows(path: String) -> Dictionary:
	var rows := _read_rows(path)
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
		d["enter_data"] = int(d["enter"])
		out[str(d["code"])] = d
	return out


## The year a club first fields a team (2026 for the founding eighteen).
func enter_year(code: String) -> int:
	return int(clubs.get(code, {}).get("enter", 2026))


## The entry year the data gives a club, whatever this career changed.
func data_enter_year(code: String) -> int:
	return int(clubs.get(code, {}).get("enter_data", enter_year(code)))


## Change when a club first fields a team, for this career only (a club the
## career leaves out gets a year that never comes). reload() puts the data's
## own year back.
func set_enter_year(code: String, year: int) -> void:
	pristine = false
	if clubs.has(code):
		(clubs[code] as Dictionary)["enter"] = year


## A club the data has leave keeps playing, for this career only (Fitzroy,
## when they fight off the merger). reload() puts the data's year back.
func keep_club(code: String) -> void:
	pristine = false
	if clubs.has(code):
		(clubs[code] as Dictionary)["leave"] = 0


## Keep `code` looking as it did in `year` from then on, for this career only.
func pin_era(code: String, year: int) -> void:
	pristine = false
	era_pins[code] = year
	if era_year > 0:
		apply_era(era_year)


## Let `code` follow its own looks by year again (a pin_era undone).
func unpin_era(code: String) -> void:
	pristine = false
	era_pins.erase(code)
	if era_year > 0:
		apply_era(era_year)


## Reshade `code`'s colours for this career ({} puts its own back).
func shade_colours(code: String, shades: Dictionary) -> void:
	pristine = false
	if shades.is_empty():
		colour_shades.erase(code)
	else:
		colour_shades[code] = shades
	if era_year > 0:
		apply_era(era_year)


## The clubs active in a given season year, in club order. Fixtures, ladders,
## drafts and selections all iterate this - never CLUB_ORDER - so expansion
## clubs (and a created one) join the competition on schedule without any
## club-specific code.
func active_clubs(year: int) -> Array:
	var out := []
	for code in club_order:
		if enter_year(code) <= year and (leave_year(code) == 0 or year <= leave_year(code)):
			out.append(code)
	return out


# ---------------------------------------------------------------------------
# Clubs by year (Legacy mode): one club code across eras
# ---------------------------------------------------------------------------
## A club's name, short name, colours, guernsey and home ground by year range
## (data/legacy/clubs_by_year.csv). A blank cell is the club's own value in
## data/clubs.csv; a club's rows also bound the years it fields a team. The
## legacy files sit outside data/*.csv, so the pre-made histories' data stamp
## (PremadeHistory.LIST_FILES) does not move with them.
const CLUBS_BY_YEAR_CSV := "res://data/legacy/clubs_by_year.csv"
## Every name a ground has carried, by year range, sourced (tools/legacy_1990s
## writes it). A row with no years only says what the ground was called; it
## renames nothing.
const GROUND_NAMES_CSV := "res://data/legacy/ground_names.csv"
## The ground each ground_names.csv id is in the game (fixtures, looks, weather):
## its name today, or the last name it had while the AFL played there. An id
## not listed is its own row's name.
const GROUND_KEYS := {"docklands": "Marvel Stadium", "kardinia_park": "GMHBA Stadium",
		"football_park": "Football Park", "subiaco": "Subiaco Oval", "princes_park": "Ikon Park",
		"western_oval": "Whitten Oval", "waverley_park": "Waverley Park", "stadium_australia": "Accor Stadium",
		"carrara": "People First Stadium", "mcg": "MCG", "scg": "SCG", "waca": "WACA", "gabba": "The Gabba"}
## Names the club and rules tables use for a ground that are none of its
## recorded names.
const GROUND_ALIASES := {"Carrara": "People First Stadium"}
## Clubs that have left the competition, in clubs.csv's columns (Fitzroy).
const PAST_CLUBS_CSV := "res://data/legacy/past_clubs.csv"
## Codes the historical data uses for a club that is one club across eras:
## the Brisbane Bears are the Lions' club, Footscray the Bulldogs'.
const CLUB_CODE_ALIASES := {"BRB": "BRL", "FOO": "WBD"}
## Clubs that have left the competition, each loaded only by a dataset whose
## years include it, in the place CLUB_ORDER would give it.
const PAST_CLUBS := {"FIT": "FRE"}
## The fields a year's row may set.
const ERA_FIELDS := ["name", "short", "primary", "secondary", "accent", "guernsey", "ground"]
const COLOUR_FIELDS := ["primary", "secondary", "accent"]

## Every club's real home guernsey season by season to 2025, each a picture in the kit atlas
## (tools/kits/kit_atlas.py draws both from tools/kits/kits.txt). 2026 on is clubs.csv's own.
const KITS_CSV := "res://data/legacy/kits.csv"
const KIT_ATLAS := "res://assets/vignette/kits_atlas.png"
## The atlas's cells a row, and each side's pixels (as kit_atlas.py draws them).
const KIT_PER_ROW := 12
const KIT_SIDE := 80
var _kits := {}           # code -> Array of {from, to, cell, guernsey}
var _kit_tex: Texture2D = null

var _club_years := {}     # code -> Array of {from, to, field: value} rows, oldest first
var _club_base := {}      # code -> the clubs.csv values of ERA_FIELDS
var _ground_names := {}   # ground key -> Array of {from, to, name}, oldest first
var _ground_keys := {}    # any id or name a ground has had -> its key
## The year the clubs' names and colours are shown for (apply_era).
var era_year := 0
## code -> the last year whose look a club keeps, for this career only (the
## Bears stay the Bears when Fitzroy fight off the merger; LegacyRollover).
## reload() clears it.
var era_pins := {}
## A club's colours reshaded for this career only (Legacy: Fitzroy beside the
## Bears or Lions, director 2026-11-13): code -> {primary/secondary/accent: Color}.
var colour_shades := {}


## The one code a club has in every era (BRB is BRL, FOO is WBD).
static func club_code(code: String) -> String:
	return str(CLUB_CODE_ALIASES.get(code, code))


## The last year a club fields a team, or 0 while it still does.
func leave_year(code: String) -> int:
	return int(clubs.get(code, {}).get("leave", 0))


## Read the year rows and fit the clubs to this dataset's years: a club that
## first played after the data season enters that year, one already playing
## is there from the start, and one whose last season came before the first
## playable year is not loaded at all.
func _load_club_years() -> void:
	_club_years = {}
	_club_base = {}
	_load_ground_names()
	_kits = {}
	for r in _read_dicts(KITS_CSV):
		var kc := club_code(str(r.get("code", "")))
		if int(r.get("from", "0")) <= 0:
			continue   # a picture no season wears (a one-off, or a mid-season change)
		if not _kits.has(kc):
			_kits[kc] = []
		(_kits[kc] as Array).append({"from": int(r["from"]), "to": int(r["to"]), "cell": int(r["cell"]),
				"guernsey": str(r["guernsey"])})
	for r in _read_dicts(CLUBS_BY_YEAR_CSV):
		var code := club_code(str(r.get("code", "")))
		if code == "":
			continue
		var row := {"from": int(r.get("from", "0")), "to": int(r.get("to", "0")) if str(r.get("to", "")) != "" else 0}
		for k in ERA_FIELDS:
			if str(r.get(k, "")) != "":
				row[k] = ground_key(str(r[k])) if k == "ground" else str(r[k])
		if not _club_years.has(code):
			_club_years[code] = []
		(_club_years[code] as Array).append(row)
	for code in _club_years:
		(_club_years[code] as Array).sort_custom(func(a, b): return int(a["from"]) < int(b["from"]))
	for code in clubs.keys():
		var d: Dictionary = clubs[code]
		var base := {}
		for k in ERA_FIELDS:
			base[k] = d.get(k, "")
		_club_base[code] = base
		var rows: Array = _club_years.get(code, [])
		if rows.is_empty():
			continue
		var first := int(rows[0]["from"])
		var last := 0
		var open := false
		for r in rows:
			open = open or int(r["to"]) == 0
			last = maxi(last, int(r["to"]))
		if open:
			last = 0
		if first > DATA_SEASON:
			d["enter"] = first
		else:
			d["enter"] = mini(int(d["enter"]), DATA_SEASON)
		d["enter_data"] = int(d["enter"])
		d["leave"] = last
	for code in clubs.keys():
		var gone := leave_year(code)
		if gone > 0 and gone < START_YEAR:
			clubs.erase(code)
			_club_base.erase(code)
		elif PAST_CLUBS.has(code) and not club_order.has(code):
			var at := club_order.find(PAST_CLUBS[code])
			club_order.insert(at if at >= 0 else club_order.size(), code)


## A club as it was in `year`: its clubs.csv values with that year's row laid
## over them. Colours come back as Colors. A created club is as it was made.
func club_era(code: String, year: int) -> Dictionary:
	var out := _era_look(code, year)
	var kit := season_kit(code, year)
	# The season's picture is drawn in that season's colours, so it is worn only while the club
	# looks as it did that season. A career can keep a club's older look or reshade it (Legacy
	# rollovers); then the spec's own drawing shows in the colours the club has.
	if not kit.is_empty() and _as_worn(code, year, out) and str(kit["guernsey"]) == str(out["guernsey"]):
		out["kit"] = kit["cell"]
	return out


## True when `look` has the spec and colours data/legacy/clubs_by_year.csv gives `code` in `year`.
func _as_worn(code: String, year: int, look: Dictionary) -> bool:
	var want := {}
	for k in COLOUR_FIELDS + ["guernsey"]:
		want[k] = (_club_base.get(code, {}) as Dictionary).get(k)
	for r in _club_years.get(code, []):
		if int(r["from"]) <= year and (int(r["to"]) == 0 or year <= int(r["to"])):
			for k in want:
				if r.has(k):
					want[k] = _hex(r[k]) if COLOUR_FIELDS.has(k) else r[k]
			break
	for k in want:
		if look.get(k) != want[k]:
			return false
	return true


func _era_look(code: String, year: int) -> Dictionary:
	var out: Dictionary = (_club_base.get(code, {}) as Dictionary).duplicate()
	if out.is_empty():
		return out
	if era_pins.has(code):
		year = mini(year, int(era_pins[code]))
	for r in _club_years.get(code, []):
		if int(r["from"]) <= year and (int(r["to"]) == 0 or year <= int(r["to"])):
			for k in ERA_FIELDS:
				if r.has(k):
					out[k] = _hex(r[k]) if COLOUR_FIELDS.has(k) else r[k]
			break
	for k in (colour_shades.get(code, {}) as Dictionary):
		out[k] = colour_shades[code][k]
	return out


## The real guernsey a club wore in `year` ({from, to, cell, guernsey}), or {} (2026 on, a
## created club, or a season with no picture).
func season_kit(code: String, year: int) -> Dictionary:
	for k in _kits.get(code, []):
		if int(k["from"]) <= year and year <= int(k["to"]):
			return k
	return {}


## The kit atlas (loaded once; null when the file is missing).
func kit_atlas() -> Texture2D:
	if _kit_tex == null and ResourceLoader.exists(KIT_ATLAS):
		_kit_tex = load(KIT_ATLAS)
	return _kit_tex


## The atlas's cells a row and rows, for figure.gdshader's kit_grid.
func kit_grid() -> Vector2i:
	var t := kit_atlas()
	return Vector2i(KIT_PER_ROW, maxi(1, int(t.get_height()) / KIT_SIDE) if t != null else 1)


## Show every club as it was in `year`: the career calls this when a season
## starts, so the Bears are the Bears until 1997. Today's clubs in today's
## years are their clubs.csv selves, unchanged.
func apply_era(year: int) -> void:
	era_year = year
	for code in _club_base:
		if not clubs.has(code):
			continue
		var d: Dictionary = clubs[code]
		var now := club_era(code, year)
		for k in ERA_FIELDS:
			if d.get(k) != now[k]:
				d[k] = now[k]
				pristine = false
		# The season's guernsey picture, only while there is one (today's clubs carry no key).
		if now.has("kit"):
			if d.get("kit") != now["kit"]:
				d["kit"] = now["kit"]
				pristine = false
		elif d.has("kit"):
			d.erase("kit")
	apply_second_tier(year)


## Read ground_names.csv: each ground's dated names under its key, and every
## id and name it has had pointing at that key.
func _load_ground_names() -> void:
	_ground_names = {}
	_ground_keys = GROUND_ALIASES.duplicate()
	for r in _read_dicts(GROUND_NAMES_CSV):
		var id := str(r.get("ground", ""))
		var name := str(r.get("name", ""))
		var key := str(GROUND_KEYS.get(id, name))
		_ground_keys[id] = key
		_ground_keys[name] = key
		_ground_keys[key] = key
		var from := str(r.get("from_year", ""))
		var to := str(r.get("to_year", ""))
		if from == "" and to == "":
			continue
		if not _ground_names.has(key):
			_ground_names[key] = []
		(_ground_names[key] as Array).append({"from": int(from) if from != "" else 0,
				"to": int(to) if to != "" else 0, "name": name})
	for key in _ground_names:
		(_ground_names[key] as Array).sort_custom(func(a, b): return int(a["from"]) < int(b["from"]))


## The game's one name for a ground, from any id or name it has had
## ("princes_park", "Optus Oval" and "Princes Park" are all Ikon Park).
func ground_key(ground: String) -> String:
	return str(_ground_keys.get(ground, ground))


## A ground's name in `year` (Docklands was Colonial Stadium in 2000); a year
## no dated name covers keeps the ground's own name.
func ground_name(ground: String, year: int) -> String:
	var key := ground_key(ground)
	for r in _ground_names.get(key, []):
		if int(r["from"]) <= year and (int(r["to"]) == 0 or year <= int(r["to"])):
			return str(r["name"])
	return key


## A ground as the screens show it: its name in `year`, or in the season the
## clubs are shown for (apply_era) when no year is given.
func ground_shown(ground: String, year := 0) -> String:
	if ground == "":
		return ""
	var y := year if year > 0 else era_year
	return ground_name(ground, y) if y > 0 else ground_key(ground)


## The name a ground carried the season before `year`, when that is a dated
## name and `year` brings another one (Princes Park became Optus Oval in
## 1994); "" otherwise. A ground opening under a name is not a rename.
func ground_renamed_from(ground: String, year: int) -> String:
	var key := ground_key(ground)
	var before := ""
	var now := ""
	for r in _ground_names.get(key, []):
		var covers := func(y: int) -> bool: return int(r["from"]) <= y and (int(r["to"]) == 0 or y <= int(r["to"]))
		if covers.call(year - 1):
			before = str(r["name"])
		if covers.call(year):
			now = str(r["name"])
	return before if before != "" and now != "" and before != now else ""


## Rows of a small CSV as dictionaries keyed by its header (quoted cells allowed).
func _read_dicts(path: String) -> Array:
	var out := []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header := f.get_csv_line()
	while not f.eof_reached():
		var cells := f.get_csv_line()
		if cells.size() < header.size() or str(cells[0]).strip_edges() == "":
			continue
		var d := {}
		for i in range(header.size()):
			d[header[i].strip_edges()] = cells[i].strip_edges()
		out.append(d)
	f.close()
	return out


# ---------------------------------------------------------------------------
# State leagues (TODO row 128)
# ---------------------------------------------------------------------------
func _load_state_leagues() -> void:
	state_leagues = {}
	state_clubs = {}
	state_players = []
	state_players_by_club = {}
	state_links = []
	if STATE_LEAGUES_DIR == "":
		apply_second_tier(START_YEAR)
		return
	var season := DATA_SEASON
	for row in _read_dicts("%s/leagues.csv" % STATE_LEAGUES_DIR):
		var id := str(row["league"])
		for k in ["clubs", "rounds", "games_each", "byes_each", "finals_teams"]:
			row[k] = int(row[k])
		for k in ["points_per_team_game", "points_sd", "goal_accuracy"]:
			row[k] = float(row[k])
		state_leagues[id] = row
	for id in STATE_LEAGUE_IDS:
		if not state_leagues.has(id):
			continue
		var stem := "%s/%s_%%s_%d.csv" % [STATE_LEAGUES_DIR, str(id).to_lower(), season]
		var codes := []
		for row in _read_dicts(stem % "clubs"):
			row["primary"] = _hex(row["primary"])
			row["secondary"] = _hex(row["secondary"])
			# A club with no third colour (most of the WAFL) tints with its second.
			row["accent"] = _hex(row["accent"]) if str(row["accent"]) != "" else row["secondary"]
			state_clubs[str(row["code"])] = row
			state_players_by_club[str(row["code"])] = []
			codes.append(str(row["code"]))
		state_leagues[id]["club_codes"] = codes
		for row in _read_dicts(stem % "players"):
			var p := _state_player(row)
			state_players.append(p)
			if state_players_by_club.has(p["club"]):
				state_players_by_club[p["club"]].append(p)
	state_links = _read_dicts("%s/afl_links_%d.csv" % [STATE_LEAGUES_DIR, season])
	_assign_state_aliases(state_players)
	if not state_leagues.is_empty():
		print("GameDB: state leagues %s: %d clubs, %d state-only players, %d AFL links"
				% ["/".join(state_leagues.keys()), state_clubs.size(), state_players.size(), state_links.size()])


## One state man from his file row. His id is the file's sid (club_first_last),
## never an AFL id. Stats stay as the 2026 League totals; stat_cols names the
## columns his league records (ratings come later, step 3).
func _state_player(row: Dictionary) -> Dictionary:
	var p := {
		"id": str(row["sid"]), "league": str(row["league"]), "club": str(row["club"]),
		"list": str(row["list"]), "num": int(row["num"]) if str(row["num"]).is_valid_int() else 0,
		"first": str(row["first"]), "last": str(row["last"]),
		"dob": str(row["dob"]), "dob_src": str(row["dob_src"]),
		"height_cm": float(row["height_cm"]) if str(row["height_cm"]) != "" else 0.0,
		"height_src": str(row["height_src"]),
		"weight_kg": float(row["weight_kg"]) if str(row["weight_kg"]) != "" else 0.0,
		"real_pos": str(row["pos"]), "junior_club": str(row["junior_club"]), "note": str(row["note"]),
		"data_club": str(row["club"]), "src": DATA_SEASON,
	}
	p["real_name"] = "%s %s" % [p["first"], p["last"]]
	p["age"] = age_at_start(str(p["dob"]), 0.0)
	var cols := []
	for k in STATE_STAT_KEYS:
		if str(row.get(k, "")) != "":
			p[k] = float(row[k])
			cols.append(k)
	p["stat_cols"] = cols
	for k in STATE_INT_KEYS:
		p[k] = int(row[k]) if str(row.get(k, "")).is_valid_int() else 0
	return p


## A state league's club codes, in file order ([] for a league not loaded).
func league_clubs(id: String) -> Array:
	return state_leagues.get(id, {}).get("club_codes", [])


## True for a state league club's code.
func is_state_club(code: String) -> bool:
	return state_clubs.has(code)


## The state league side an AFL club fields (its reserves or aligned side), or "".
## An era side aligned with two clubs (Sandringham with St Kilda and Melbourne)
## lists both in afl_clubs.
func state_side_of(afl_code: String) -> String:
	for code in state_clubs:
		var row: Dictionary = state_clubs[code]
		if str(row["afl_club"]) == afl_code or (row.get("afl_clubs", []) as Array).has(afl_code):
			return str(code)
	return ""


# ---------------------------------------------------------------------------
# The second tier by season (Legacy mode, TODO row 142, L7)
# ---------------------------------------------------------------------------
## A Legacy dataset's real second tier (SecondTier, data/legacy/second_tier/).
## Each season start (apply_era) lays that season's shape over the state
## leagues: state_leagues and state_clubs hold the leagues and sides of the
## season being played, with no rosters (the era has no state lists). A
## dataset with a state_leagues folder (2026) never reads it, so a 2026
## career is exactly as before.
var second_tier := SecondTier.new()
var second_tier_year := 0     # the season whose shape is laid over the state leagues
var _today_state_rows := {}   # code -> 2026 state club row (colours for sides that live on)


func apply_second_tier(year: int) -> void:
	if second_tier.is_empty() or STATE_LEAGUES_DIR != "":
		return
	second_tier_year = year
	state_leagues = {}
	state_clubs = {}
	state_players = []
	state_players_by_club = {}
	state_links = []
	var shape := second_tier.shape(year)
	var rows := second_tier.sides_in(year)
	for id in shape:
		var codes: Array = shape[id]["clubs"]
		state_leagues[id] = {"league": id, "name": str(shape[id]["name"]), "clubs": codes.size(),
				"club_codes": codes.duplicate()}
		for code in codes:
			state_clubs[code] = _era_side(rows[code], year)
			state_players_by_club[code] = []


## Where an AFL club's players went below the seniors in `year` (SecondTier.of_club),
## or {} for a dataset without a second tier.
func second_tier_of(afl_code: String, year: int) -> Dictionary:
	return second_tier.of_club(afl_code, year)


## A side as a state club row. Colours: an AFL club's own side wears that
## club's colours of the year; a side still playing in 2026 wears its 2026
## colours; any other keeps the default (club_colours).
func _era_side(s: Dictionary, year: int) -> Dictionary:
	var afl: Array = s["afl_clubs"]
	var row := {"code": str(s["code"]), "name": str(s["name"]), "short": str(s["name"]),
			"league": str(s["league"]), "kind": str(s["kind"]),
			"afl_club": str(afl[0]) if afl.size() == 1 else "", "afl_clubs": afl.duplicate(),
			"future_afl_club": "", "ground": "", "era": year}
	var today := _today_state_row(str(s["code"]))
	if str(s["kind"]) == "reserves" and afl.size() == 1 and clubs.has(club_code(str(afl[0]))):
		var c := club_era(club_code(str(afl[0])), year)
		for k in COLOUR_FIELDS:
			row[k] = c[k]
	elif not today.is_empty():
		for k in COLOUR_FIELDS:
			row[k] = today[k]
	if not today.is_empty() and str(today["name"]) == row["name"]:
		row["short"] = str(today["short"])
	return row


func _today_state_row(code: String) -> Dictionary:
	if _today_state_rows.is_empty():
		var dir := str(Datasets.file(Datasets.DEFAULT, Datasets.STATE_LEAGUES_KEY))
		var season := int(Datasets.get_set(Datasets.DEFAULT).get("data_season", 0))
		for id in STATE_LEAGUE_IDS:
			for r in _read_dicts("%s/%s_clubs_%d.csv" % [dir, str(id).to_lower(), season]):
				r["primary"] = _hex(r["primary"])
				r["secondary"] = _hex(r["secondary"])
				r["accent"] = _hex(r["accent"]) if str(r["accent"]) != "" else r["secondary"]
				_today_state_rows[str(r["code"])] = r
	return _today_state_rows.get(code, {})


func state_list(code: String) -> Array:
	return state_players_by_club.get(code, [])


func _assign_fictional_names(list: Array) -> void:
	assign_aliases(list)


## Draw labels from one shuffled pool for every human in the game - season
## pool, draft class and generated intakes - so aliases never collide and a
## player's label is stable for the whole career. The cursor advances by one
## name per player. Adding the loop index on top of the cursor skips names
## quadratically, exhausts the pool, and used to fall back to "Squadmate 001".
func assign_aliases(list: Array) -> void:
	pristine = false
	_ensure_alias_pool()
	# A real listed player's name is never handed out as an alias.
	for p in list:
		var real := str(p.get("real_name", ""))
		if real != "":
			_real_names[real] = true
	for i in range(list.size()):
		var label := _alias_at(_alias_next)
		_alias_next += 1
		while _real_names.has(label) or alias_is_double(label) or _state_aliases.has(label):
			label = _alias_at(_alias_next)
			_alias_next += 1
		list[i]["generic_name"] = label
		list[i]["name"] = label


## State league men draw their labels from the far end of the same pool,
## walking back, so the AFL's cursor above hands out exactly the labels it did
## before the state leagues loaded; the two meet only after tens of thousands of
## generated players, and then the cursor skips a state label. A state label is
## never an AFL man's real name nor a state man's.
func _assign_state_aliases(list: Array) -> void:
	_ensure_alias_pool()
	var state_real := {}
	for p in list:
		state_real[str(p.get("real_name", ""))] = true
	var back := _alias_candidates.size() - 1
	for p in list:
		var label := ""
		while label == "" or _real_names.has(label) or state_real.has(label) or alias_is_double(label) \
				or _state_aliases.has(label):
			label = _alias_at(back) if back >= 0 else _overflow_alias(STATE_ALIAS_OVERFLOW - back)
			back -= 1
		_state_aliases[label] = true
		p["generic_name"] = label
		p["name"] = label


## Where state labels start in the three-word overflow, should the pool run out:
## far past anything the AFL cursor reaches.
const STATE_ALIAS_OVERFLOW := 5000000


## True when a name's first word equals its last word ("Reid Reid"). Such a
## label is skipped at the draw, so the cursor and every stored name stay valid.
static func alias_is_double(label: String) -> bool:
	var parts := label.strip_edges().split(" ", false)
	return parts.size() >= 2 and str(parts[0]).to_lower() == str(parts[parts.size() - 1]).to_lower()


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
		p["club"] = club_code(str(cells[idx["club"]]))
		p["num"] = int(str(cells[idx["num"]])) if idx.has("num") else 0
		p["last"] = str(cells[idx["last"]]) if idx.has("last") else ""
		p["first"] = str(cells[idx["first"]]) if idx.has("first") else ""
		p["real_name"] = "%s %s" % [p["first"], p["last"]]
		# real_name is the name shown. "name" still takes a label from the shared
		# pool after the load: it is never shown for him, but drawing it keeps the
		# cursor, and so every generated prospect's name, where saves expect it.
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
		p["src"] = int(str(cells[idx["src"]])) if idx.has("src") else DATA_SEASON
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
		# A past start's honours score (Ratings.rate_on_honours).
		if idx.has("honours") and str(cells[idx["honours"]]) != "":
			p["honours"] = float(str(cells[idx["honours"]]))
		var pick := str(cells[idx["draft_pick"]])
		if pick != "":
			p["drafted_year"] = int(str(cells[idx["draft_year"]]))
			p["drafted_type"] = str(cells[idx["draft_type"]])
			p["drafted_pick"] = int(pick)
			# The club that drafted him is the first club in his AFL career
			# (club:from:to:games:goals stints, oldest first): what home-grown
			# means for a Challenge goal (Challenge.homegrown_flag).
			if idx.has("career"):
				var first := str(cells[idx["career"]]).split(";", false)
				if not first.is_empty():
					var code := str(first[0]).split(":")[0].strip_edges()
					if code != "" and code != "?":
						p["drafted_club"] = code
		if idx.has("peak") and str(cells[idx["peak"]]) != "":
			p["real_peak"] = int(str(cells[idx["peak"]]))
		# A Legacy start's real player: his last real AFL season, when his
		# retirement comes due (Prospects.should_retire, director 2026-11-13).
		if idx.has("last_season") and str(cells[idx["last_season"]]) != "":
			p["real_last"] = int(str(cells[idx["last_season"]]))
		var hist := []
		for chunk in str(cells[idx["seasons"]]).split(";", false):
			var parts := chunk.split(":")
			if parts.size() == 3:
				hist.append([int(parts[0]), int(parts[1]), int(parts[2])])
		if not hist.is_empty():
			p["history"] = hist


## Hand-set OVR (data/ovr_overrides.csv), matched on club + first + last name.
## Every attribute is shifted by the same amount (capped 1-99) until the rating
## in his own position lands on the target, so his profile keeps its gaps. POT
## is the one he had before, raised to the new OVR. An unmatched row is reported.
func _apply_ovr_overrides(list: Array) -> void:
	if skip_ovr_overrides:
		return
	_each_override_row(OVR_CSV, "ovr", list, func(p, cell):
		var text: String = str(cell).strip_edges()
		var before_pot := int(p.get("potential", p["overall"]))
		var mult := 1.0
		var target := 0
		if (text.begins_with("+") or text.begins_with("-")) and text.ends_with("%"):
			# A relative row (+10% or -10%): his computed OVR and the POT he had both scale.
			mult = 1.0 + text.trim_suffix("%").to_float() / 100.0
			target = int(round(float(p["overall"]) * mult))
		else:
			target = int(text)
		if set_player_ovr(p, target):
			if HOLDS_ON_EVERY_LINE.has(_override_key(p)):
				hold_on_every_line(p, target)
			# His POT is the one he had before, raised to his new OVR (a veteran
			# is not a rehab case because his rating moved).
			var pot := int(round(float(before_pot) * mult))
			p["potential"] = clampi(maxi(pot, target), 1, Potential.MAX_POT))


## Walks a hand-set csv (club, first, last + one value column), matching on
## club + real name, and hands each matched player and his cell to `apply`.
func _each_override_row(path: String, column: String, list: Array, apply: Callable) -> void:
	if not FileAccess.file_exists(path):
		return
	var rows := _read_rows(path)
	if rows.size() < 2:
		return
	var header: Array = rows[0]
	var idx := {}
	for j in range(header.size()):
		idx[str(header[j]).strip_edges()] = j
	for key in ["club", "first", "last", column]:
		if not idx.has(key):
			push_warning("GameDB: %s needs a '%s' column" % [path, key])
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
			continue
		override_hits[path + "|" + key] = true
		apply.call(by_key[key], str(cells[idx[column]]))


## Rows in either file that matched no player, warned about and kept in
## override_unmatched for the tests.
func _report_unmatched_overrides() -> Array:
	var out := []
	for path in [OVR_CSV, POTENTIAL_CSV]:
		if not FileAccess.file_exists(path):
			continue
		var rows := _read_rows(path)
		for i in range(1, rows.size()):
			var c: Array = rows[i]
			if c.size() < 3:
				continue
			var key := "%s|%s|%s" % [str(c[0]).strip_edges(),
					str(c[1]).strip_edges().to_lower(), str(c[2]).strip_edges().to_lower()]
			if not override_hits.has(path + "|" + key) and not (skip_ovr_overrides and path == OVR_CSV):
				out.append(path.get_file() + ": " + key)
				push_warning("GameDB: override matches no player: %s %s" % [path.get_file(), key])
	return out


## club|first|last, lower case: who a hand-set rating belongs to.
static func _override_key(p: Dictionary) -> String:
	return "%s|%s|%s" % [p["club"], str(p["first"]).to_lower(), str(p["last"]).to_lower()]


## Hand-set ratings that hold wherever he plays: no line rates him above the
## number. Director, 2026-11-08: Blicavs is a 65, not a 65 ruck who is 81 in the
## midfield and 93 in defence.
const HOLDS_ON_EVERY_LINE := {"GEE|mark|blicavs": true}


## Brings down what his other lines read until none rates him above target,
## the highest attribute first so the profile keeps its order. His own line
## stays on target: when an attribute it shares comes down (a ruck's contested
## work), its heaviest attribute comes up to cover it. Star, durability and
## discipline are who he is and stay.
static func hold_on_every_line(p: Dictionary, target: int) -> void:
	var a: Dictionary = p["attr"]
	var role := str(p.get("role", "MID"))
	var games := Ratings.effective_games(p)
	var own: Dictionary = Ratings.ROLE_WEIGHTS.get(role, Ratings.ROLE_WEIGHTS["MID"])
	var heaviest := ""
	for k in own:
		if heaviest == "" or float(own[k]) > float(own[heaviest]):
			heaviest = k
	for _guard in range(4000):
		var over := ""
		for line in Ratings.ROLE_WEIGHTS:
			if line != role and Ratings.rate_overall(a, line, games) > target:
				over = line
				break
		if over == "":
			return
		var top := ""
		for k in Ratings.ROLE_WEIGHTS[over]:
			if k != heaviest and (top == "" or int(a[k]) > int(a[top])):
				top = k
		a[top] = maxi(1, int(a[top]) - 1)
		while Ratings.rate_overall(a, role, games) < target and int(a[heaviest]) < 99:
			a[heaviest] = int(a[heaviest]) + 1
	push_warning("GameDB: cannot hold %s %s at %d on every line" % [p["first"], p["last"], target])


static func set_player_ovr(p: Dictionary, target: int) -> bool:
	if not p.has("attr"):
		return false
	var role := str(p.get("role", "MID"))
	var games := float(p.get("sample", p.get("gm", 0.0)))
	if games <= 0.0:
		games = 14.0     # a prospect with no senior game is rated on 14
	var base: Dictionary = p["attr"]
	var best: Dictionary = {}
	var best_miss := 1000
	var best_shift := 1000
	# The same shift on every attribute (clamped 1-99): the one that lands
	# nearest the target, the smaller shift on a tie. His profile keeps its gaps.
	for shift in range(-98, 99):
		var a := {}
		for k in base:
			a[k] = clampi(int(base[k]) + shift, 1, 99)
		var miss := absi(Ratings.rate_overall(a, role, games) - target)
		if miss < best_miss or (miss == best_miss and absi(shift) < best_shift):
			best_miss = miss
			best_shift = absi(shift)
			best = a
	# One shift step can move the rating by two (the position scale is steeper
	# than one for a forward); close the last point one attribute at a time.
	var guard := 0
	while best_miss > 0 and guard < 60:
		guard += 1
		var dir := 1 if Ratings.rate_overall(best, role, games) < target else -1
		for k in best:
			var v := int(best[k]) + dir
			if v < 1 or v > 99:
				continue
			best[k] = v
			best_miss = absi(Ratings.rate_overall(best, role, games) - target)
			if best_miss == 0:
				break
		if best_miss == 0:
			break
	if best_miss > 0:
		push_warning("GameDB: ovr override cannot reach %d for %s %s" % [target, p["first"], p["last"]])
		return false
	p["attr"] = best
	p["overall"] = target
	p["value"] = Ratings.salary_value(target)
	return true


## Hand-set potentials, matched on club + first + last name. An unmatched row
## is reported rather than silently ignored, so a typo is easy to spot.
func _apply_potential_overrides(list: Array) -> void:
	_each_override_row(POTENTIAL_CSV, "potential", list, func(p, cell):
		Potential.set_override(p, int(cell)))


func _hex(s) -> Color:
	if s is Color:
		return s
	return Color.html(str(s))


## A league rule as it stood in `year` (data/legacy/era_rules.csv): the
## salary cap, list sizes, interchange and the like. `fallback` when the
## file has no row for that year. See EraRules.
func era_rule(rule: String, year: int, fallback := 0.0) -> float:
	return EraRules.value(rule, year, fallback)
