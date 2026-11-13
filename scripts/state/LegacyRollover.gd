class_name LegacyRollover
extends RefCounted
## A Legacy career's rollovers, 1990 to 2026 (TODO row 142, phase L8): each
## year's real draft class in the open draft, each new club's real
## state-league foundation, and the Fitzroy merger. The sim makes the picks, the later careers and the
## retirements: an alternative history from real starting points (director
## 2026-11-10). A career on today's data never reaches any of this.
##
## Data: data/legacy/classes.csv and entry_lists.csv, built by
## tools/legacy_1990s/build_rollovers.py.

const CLASSES_CSV := "res://data/legacy/classes.csv"
const ENTRY_CSV := "res://data/legacy/entry_lists.csv"

## The Fitzroy merger (director 2026-11-11): "it always happens unless you are
## regularly competing in finals, and even then, the story beat still happens
## (with a slim chance of the merge going ahead no matter what) / if youre
## struggling though, no choice, the merge happens whether you want it to or not".
const MERGED := "FIT"
const MERGED_INTO := "BRL"
## Talks open at the start of this season; the merger is settled after it.
const TALKS_YEAR := 1996
## "Regularly competing in finals": finals in this many of the last three seasons.
const FINALS_NEEDED := 2
## The slim chance the merger goes ahead anyway, in percent.
const MERGE_ANYWAY_PCT := 10
## Fitzroy players the Brisbane Lions take (the real merger's eight).
const LIONS_TAKE := 8

static var _classes := {}   # year -> Array of class rows
static var _entries := {}   # "code|year" -> Array of entry rows


## True for a career started on a past season's data.
static func on() -> bool:
	return GameDB.DATA_SEASON < int(Datasets.get_set(Datasets.DEFAULT).get("data_season", 2026))


static func _load() -> void:
	if not _classes.is_empty():
		return
	for r in GameDB._read_dicts(CLASSES_CSV):
		var y := int(r.get("year", "0"))
		if not _classes.has(y):
			_classes[y] = []
		(_classes[y] as Array).append(r)
	for r in GameDB._read_dicts(ENTRY_CSV):
		var key := "%s|%s" % [str(r.get("club", "")), str(r.get("year", ""))]
		if not _entries.has(key):
			_entries[key] = []
		(_entries[key] as Array).append(r)


## The real class drafted at the end of `year`, if this career has one.
static func has_class(year: int) -> bool:
	if not on():
		return false
	_load()
	return _classes.has(year)


## Whether `code`, entering in `year`, has a real state-league foundation.
static func has_foundation(code: String, year: int) -> bool:
	if not on():
		return false
	_load()
	return _entries.has("%s|%d" % [code, year])


# ---------------------------------------------------------------------------
# The draft class
# ---------------------------------------------------------------------------
## The real class drafted at the end of `year` as prospects: rated from his
## draft position like any class, his potential from his best real season
## (the "Informed" ruling, director 2026-11-11). A mature-age pick is in his
## own class however old he is (Prospects.age_pool).
static func real_class(year: int) -> Array:
	_load()
	var out := []
	for r in _classes.get(year, []):
		var rank := int(r.get("rank", "0"))
		var p := {}
		p["first"] = str(r.get("first", ""))
		p["last"] = str(r.get("last", ""))
		p["real_name"] = "%s %s" % [p["first"], p["last"]]
		p["generic_name"] = ""
		p["name"] = ""
		p["id"] = "R%d_%03d" % [year, rank]
		var origin := str(r.get("origin", ""))
		p["club"] = origin
		p["num"] = rank
		p["src"] = "U18"
		for k in GameDB.STAT_KEYS:
			p[k] = 0.0
		p["height_cm"] = float(str(r.get("height_cm", "0")).to_int())
		p["weight_kg"] = 0.0
		var dob := str(r.get("dob", ""))
		p["dob"] = dob if dob.length() >= 10 else "%04d-07-01" % (year - 18)
		# age_pool adds the year a class waits in the pool: he arrives at his
		# age at the next season's start, as the real 2026 class is aged.
		p["age"] = float(Prospects.days_between(str(p["dob"]), "%d-03-01" % (year + 1))) / 365.25 - 1.0
		p["real_class"] = true
		var role := str(r.get("role", ""))
		p["role"] = role if role in ["RUCK", "MID", "DEF", "FWD"] else GameDB.listed_role(p)
		p["role2"] = ""
		p["real_pos"] = Ratings.ROLE_SHORT_TO_POS.get(str(p["role"]), "MID")
		p["debut"] = ""
		p["height_source"] = "draft class"
		p["draft_year"] = year
		p["draft_rank"] = rank
		p["draft_team"] = origin
		p["draft_league"] = ""
		p["draft_state"] = ""
		var tie := str(r.get("tie", ""))
		p["tied_club"] = str(r.get("club", "")) if tie != "" else ""
		p["tied_type"] = tie
		for k in ["u18_gm", "u18_di", "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho"]:
			p[k] = 0.0
		p["note"] = ""
		p["data_src"] = "real class %d" % year
		p["draft_class"] = true
		if str(r.get("peak", "")) != "":
			p["real_peak"] = int(str(r["peak"]))
		# His last real season (build_rollovers): he retires about then, as
		# a start list's real player does (Prospects.should_retire).
		if str(r.get("last_season", "")) != "":
			p["real_last"] = int(str(r["last_season"]))
		Prospects.project(p)
		out.append(p)
	GameDB.assign_aliases(out)
	return out


# ---------------------------------------------------------------------------
# A new club's state-league foundation
# ---------------------------------------------------------------------------
## `code`'s state-league foundation for its first season, `year`: the
## players of its real first list that no draft class brings in. A new club
## builds the rest of its list by the game's expansion rules (ExpansionBuild):
## its concession picks in the open draft and the out-of-contract players it
## signs, from wherever the save has them. Nobody joins it because he really
## did (director, 2026-11-13: "the sim will not replicate historical draftee
## clubs"). Each is rated on his last AFL season before `year`, fitted to his
## rating on that season's own scale, or as a prospect if he has none. At most
## Expansion.foundation_size (a club entering before the expansion
## concessions signs its whole first senior list), the best of them; the rest go into the draft
## before `year` (returned as "pool"); fewer, and the club tops up with
## state-league signings as any new club does.
## Returns {"list": players, "pool": players for the draft}.
static func foundation(gs, code: String, year: int) -> Dictionary:
	_load()
	var list := []
	var established := []
	var n := 0
	for r in _entries.get("%s|%d" % [code, year], []):
		n += 1
		var p := _new_player(code, year, n, r)
		if str(r.get("src", "")) != "":
			established.append([p, r])
		list.append(p)
	if not established.is_empty():
		var rows := []
		for e in established:
			rows.append(e[0])
		Ratings.derive_all(rows, GameDB.players)
		for e in established:
			var p: Dictionary = e[0]
			var r: Dictionary = e[1]
			var role := str(r.get("role", ""))
			if role in ["RUCK", "MID", "DEF", "FWD"] and role != str(p["role"]):
				p["role"] = role
				p["role2"] = Ratings.assign_secondary(p)
			# His rating that season on that season's own scale.
			var ovr := str(r.get("ovr", ""))
			if ovr != "":
				p["attr"] = Prospects.fit_attributes(p["attr"], str(p["role"]), float(ovr.to_int()), float(p["gm"]))
			p["overall"] = Ratings.rate_overall(p["attr"], str(p["role"]), float(p["gm"]))
			p["value"] = Ratings.salary_value(int(p["overall"]))
			p["career"] = Career.from_source("?")
			p["data_club"] = code
			Potential.assign(p)
	GameDB.assign_aliases(list)
	GameDB.register_draftees(list)
	list.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
	var pool := []
	var size := Expansion.foundation_size(code)
	while list.size() > size:
		var p: Dictionary = list.pop_back()
		p["club"] = ""
		p["draft_year"] = year - 1
		pool.append(p)
	if list.size() < size:
		var more: Array = Expansion.foundation_list(code, year - 1, int(gs.career_seed))
		list.append_array(more.slice(0, size - list.size()))
	for p in list:
		p["club"] = code
		if str(p.get("note", "")) == "":
			p["note"] = "State-league signing, %d" % (year - 1)
	return {"list": list, "pool": pool}


## A canon move joins his new club on a fresh deal (ensure_contracts).
static func _join(p: Dictionary, code: String, r: Dictionary) -> void:
	p["club"] = code
	p["num"] = int(str(r.get("num", "0")).to_int())
	for k in ["contract_years", "talks", "rookie_list", "released_by", "comp_eligible", "joined"]:
		p.erase(k)
	p["joined"] = int(GameDB.enter_year(code))


## A player new to the career, as GameDB builds a list addition.
static func _new_player(code: String, year: int, n: int, r: Dictionary) -> Dictionary:
	var p := {}
	p["first"] = str(r.get("first", ""))
	p["last"] = str(r.get("last", ""))
	p["real_name"] = "%s %s" % [p["first"], p["last"]]
	p["generic_name"] = ""
	p["name"] = ""
	# A state-league signing, as ExpansionBuild names one (FND_).
	p["id"] = "FND_%s_L%d_%03d" % [code, year, n]
	p["club"] = code
	p["num"] = int(str(r.get("num", "0")).to_int())
	p["src"] = "LIST"
	for k in GameDB.STAT_KEYS:
		p[k] = 0.0
	p["height_cm"] = float(str(r.get("height_cm", "0")).to_int())
	p["weight_kg"] = 0.0
	var dob := str(r.get("dob", ""))
	p["dob"] = dob
	# Aged at his first season's start, as the league has just been aged.
	p["age"] = float(Prospects.days_between(dob, "%d-03-01" % year)) / 365.25 if dob.length() >= 10 else 22.0
	p["debut"] = ""
	p["height_source"] = "club list"
	var list_type := str(r.get("list", ""))
	p["list_type"] = list_type
	if list_type == "rookie":
		p["rookie_list"] = true
	if str(r.get("peak", "")) != "":
		p["real_peak"] = int(str(r["peak"]))
	var role := str(r.get("role", ""))
	p["role"] = role if role in ["RUCK", "MID", "DEF", "FWD"] else GameDB.listed_role(p)
	p["role2"] = ""
	p["real_pos"] = Ratings.ROLE_SHORT_TO_POS.get(str(p["role"]), "MID")
	p["draft_year"] = year - 1
	p["draft_team"] = ""
	p["draft_league"] = ""
	p["draft_state"] = ""
	p["tied_club"] = ""
	p["tied_type"] = ""
	for k in ["u18_gm", "u18_di", "u18_gl", "u18_mk", "u18_tk", "u18_if50", "u18_ho"]:
		p[k] = 0.0
	p["note"] = ""
	var src := str(r.get("src", ""))
	if src != "":
		for k in GameDB.STAT_KEYS:
			if r.has(k) and str(r[k]) != "":
				p[k] = float(str(r[k]))
		p["stats_year"] = int(src)
		p["draft_rank"] = 0
		p["data_src"] = "listed %d, rated on his %s season" % [year, src]
		return p
	# Rated as the prospect he still is, as GameDB rates a list addition with
	# no senior game: a young one about a mid-first-round pick, older lower.
	var h := absi(hash(str(p["id"])))
	var age := float(p["age"])
	var rank := 22 + h % 20
	if age >= 21.5:
		rank = 45 + h % 15
	elif list_type == "rookie" or age >= 20.5:
		rank = 35 + h % 15
	p["draft_rank"] = rank
	p["data_src"] = "listed %d, no senior game" % year
	Prospects.project(p)
	return p


# ---------------------------------------------------------------------------
# Fitzroy and the Brisbane Bears
# ---------------------------------------------------------------------------
static func _st(gs) -> Dictionary:
	if not (gs.legacy is Dictionary):
		gs.legacy = {}
	if not gs.legacy.has("finals"):
		gs.legacy["finals"] = {}
	return gs.legacy


## Record the clubs that played finals in the season just played.
static func note_finals(gs) -> void:
	if not on() or gs.season == null:
		return
	var rows: Array = gs.season.ladder_sorted()
	var fin := []
	# A season with no games played (a test skips one) has no finalists: a
	# level table would read as the first clubs in alphabetical order.
	if rows.all(func(r): return int(r.get("p", 0)) == 0):
		rows = []
	for i in range(mini(gs.season.finalists(), rows.size())):
		fin.append(str(rows[i]["code"]))
	_st(gs)["finals"][str(gs.season_year)] = fin


## Seasons from `years` in which `code` played finals.
static func finals_in(gs, code: String, years: Array) -> int:
	var fin: Dictionary = _st(gs)["finals"]
	var n := 0
	for y in years:
		if (fin.get(str(y), []) as Array).has(code):
			n += 1
	return n


## Whether this career still has the merger to come.
static func _merger_ahead(gs) -> bool:
	return on() and GameDB.clubs.has(MERGED) and GameDB.clubs.has(MERGED_INTO) \
			and str(_st(gs).get("fitzroy", "")) == ""


## The talks open before TALKS_YEAR: the story, with the odds both ways and
## where Fitzroy stand.
static func talks_line(gs) -> String:
	var y1 := TALKS_YEAR - 2
	var y2 := TALKS_YEAR - 1
	var stay := 100 - MERGE_ANYWAY_PCT
	var had := finals_in(gs, MERGED, [y1, y2])
	var line := "Fitzroy's board has opened merger talks with the Brisbane Bears. The decision comes after the %d season: if Fitzroy have played finals in two of %d, %d and %d, there is a %d%% chance they play on in %d and a %d%% chance the merger goes ahead anyway; if not, they merge (100%%). " % [
			TALKS_YEAR, y1, y2, TALKS_YEAR, stay, TALKS_YEAR + 1, MERGE_ANYWAY_PCT]
	if had >= FINALS_NEEDED:
		line += "With finals in %d and %d, they have done enough: %d%% they play on, %d%% they merge." % [y1, y2, stay, MERGE_ANYWAY_PCT]
	elif had == 0:
		line += "They missed the finals in %d and %d, so there is no way out: Fitzroy merge with the Bears after the %d season (100%%)." % [y1, y2, TALKS_YEAR]
	else:
		var played := y1 if finals_in(gs, MERGED, [y1]) == 1 else y2
		line += "They played finals in %d only: make the finals in %d and it is %d%% they play on; miss them and they merge (100%%)." % [
				played, TALKS_YEAR, stay]
	return line


## At the rollover into `next_year`. Into TALKS_YEAR: the talks open (news).
## Into the year after: the merger is settled before the coach moves (a
## Fitzroy coach goes to the Brisbane Lions), and the lists after the season
## is closed (merge_lists).
static func before_moves(gs, next_year: int) -> void:
	if not _merger_ahead(gs):
		return
	if next_year == TALKS_YEAR:
		gs.add_news("legacy", talks_line(gs))
		return
	if next_year != TALKS_YEAR + 1:
		return
	_decide(gs)


## When the TALKS_YEAR off-season opens, before any club re-signs: the merger
## is settled and, as in 1996, Fitzroy's best go to the Brisbane Lions and the
## rest into that year's National Draft. A coach at Fitzroy keeps the old
## order (decided at the rollover, the rest to free agency), since his club
## has a list to run until he moves.
static func settle_merger(gs) -> void:
	if not _merger_ahead(gs) or int(gs.season_year) != TALKS_YEAR or str(gs.my_club) == MERGED:
		return
	note_finals(gs)
	_decide(gs)
	if str(_st(gs).get("fitzroy", "")) == "merged":
		_merge(gs, true)


## True once `code` has merged away (Fitzroy, its list gone): from the 1996
## off-season on it has no seat at a draft and holds no pick.
static func merged_away(gs, code: String) -> bool:
	return code == MERGED and bool(_st(gs).get("merge_done", false))


## Merge or play on: finals in two of the last three seasons give a
## MERGE_ANYWAY_PCT chance of merging; fewer, and they merge.
static func _decide(gs) -> void:
	var st := _st(gs)
	var regular := finals_in(gs, MERGED, [TALKS_YEAR - 2, TALKS_YEAR - 1, TALKS_YEAR]) >= FINALS_NEEDED
	var merge := true
	if regular:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("fitzroy-merger|%d" % int(gs.career_seed))
		merge = rng.randi_range(1, 100) <= MERGE_ANYWAY_PCT
	st["fitzroy"] = "merged" if merge else "stays"
	st["fitzroy_regular"] = regular
	if not merge:
		keep_fitzroy()
		gs.add_news("legacy", stays_line())
		return
	if str(gs.my_club) == MERGED and ClubArcs.on(gs):
		var arcs: Dictionary = ClubArcs._st(gs)
		if str((arcs.get("move", {}) as Dictionary).get("to", "")) == "":
			arcs["move"] = {"to": MERGED_INTO, "why": "merger"}


## After the season is closed: Fitzroy's best go to the Brisbane Lions, the
## rest to free agency, and no coach is left at a club that is gone.
static func merge_lists(gs) -> void:
	if not on():
		return
	canon_moves(gs, int(gs.season_year) + 1)
	_sweep_leftovers(gs)
	if str(_st(gs).get("fitzroy", "")) != "merged" or bool(_st(gs).get("merge_done", false)):
		return
	_merge(gs, false)


## Fitzroy's best LIONS_TAKE go to the Brisbane Lions. The rest go into this
## year's National Draft (`to_draft`, the 1996 order) or to free agency.
## Anyone retiring at the rollover ends his career here, as his list closes.
static func _merge(gs, to_draft: bool) -> void:
	var st := _st(gs)
	st["merge_done"] = true
	var fit: Array = gs.league_lists.get(MERGED, [])
	var ranked := fit.filter(func(q): return not gs.retiring_now(q))
	if to_draft:
		for p in fit:
			if gs.retiring_now(p):
				gs._career_over(p, "retired")
	else:
		ranked = fit.duplicate()
	ranked.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
	var lions: Array = gs.league_lists.get(MERGED_INTO, [])
	var taken := []
	for i in range(ranked.size()):
		var p: Dictionary = ranked[i]
		if i < LIONS_TAKE:
			p["club"] = MERGED_INTO
			p["joined"] = TALKS_YEAR + 1
			lions.append(p)
			taken.append(GameDB.player_display_name(p))
		elif to_draft:
			p["club"] = ""
			p["draft_year"] = int(gs.season_year)
			p["fitzroy_left"] = true
			p["contract_years"] = 0
			p.erase("rookie_list")
			# A leftover drafted in an earlier season (R1990_245) is in
			# drafted_draftees from that draft: cleared, he can be drafted
			# again, and age_pool keeps him instead of dropping him as taken.
			gs.drafted_draftees.erase(str(p["id"]))
			gs.draftee_pool.append(p)
		else:
			p["released_by"] = MERGED
			p["contract_years"] = 0
			p.erase("rookie_list")
			gs.free_agents.append(p)
	fit.clear()
	# Off the league's lists altogether, or free agency would sign players to
	# a club that no longer exists; mid off-season, off the season's lists
	# too, which the league's are rebuilt from.
	gs.league_lists.erase(MERGED)
	if to_draft and gs.season != null:
		gs.season.lists.erase(MERGED)
	gs.unique_jumpers(lions)
	for cid in gs.coaches:
		var c: Dictionary = gs.coaches[cid]
		if str(c.get("status", "")) == "club" and str(c.get("club", "")) == MERGED:
			CoachMarket._leave_job(c, int(gs.season_year))
	var head := "Fitzroy and the Brisbane Bears have merged."
	if bool(st.get("fitzroy_regular", false)):
		head = "Fitzroy played finals often enough to stand alone, but the board took the merger anyway (the %d%% chance)." % MERGE_ANYWAY_PCT
	gs.add_news("legacy", "%s The Brisbane Lions play from %d and take Fitzroy's best %d players: %s. The rest of Fitzroy's list %s." % [
			head, TALKS_YEAR + 1, taken.size(), _and(taken),
			("go into the %d National Draft" % int(gs.season_year)) if to_draft else "are free agents"])


## Fitzroy's leftovers nobody drafted: one young enough stays in the pool for
## next year's draft; one who would age out of it (22) ends his career here,
## on the record, never silently.
static func _sweep_leftovers(gs) -> void:
	var keep := []
	for p in gs.draftee_pool:
		if bool(p.get("fitzroy_left", false)) and not gs.drafted_draftees.has(str(p["id"])) \
				and float(p.get("age", 30.0)) + 1.0 >= 22.0:
			gs._career_over(p, "delisted")
			continue
		keep.append(p)
	gs.draftee_pool = keep


## Fitzroy fought the merger off: they play on, and the Bears stay the Bears.
static func keep_fitzroy(lions := false) -> void:
	GameDB.keep_club(MERGED)
	if lions:
		GameDB.unpin_era(MERGED_INTO)
	else:
		GameDB.pin_era(MERGED_INTO, TALKS_YEAR)
	separate_colours()


## The news when Fitzroy play on (after the coach moves; nothing moves).
static func stays_line() -> String:
	return "Fitzroy have fought off the merger and play on in %d, beside the Brisbane Bears." % (TALKS_YEAR + 1)


## A loaded career puts back what its rollovers changed in GameDB.
static func restore(gs) -> void:
	if on() and str(_st(gs).get("fitzroy", "")) == "stays":
		keep_fitzroy(str(_st(gs).get("brand", "")) == "lions")


# ---------------------------------------------------------------------------
# Fitzroy play on: the Bears' coach picks the name (director, 2026-11-13)
# ---------------------------------------------------------------------------
const BRAND_TID := "legacy_brand"


## "bears coaches should be given the choice to rebrand to lions or stay as
## bears" (director, 2026-11-13): in the first week after Fitzroy fight the
## merger off, a coach at the Bears gets one card. It is asked once; left
## unanswered, the club stays the Bears. A Bears side the sim runs stays the
## Bears. The name and look only: play never changes.
static func week(gs) -> void:
	canon_week(gs)
	if not on() or str(gs.my_club) != MERGED_INTO or gs.season == null:
		return
	var st := _st(gs)
	if str(st.get("fitzroy", "")) != "stays" or bool(st.get("brand_asked", false)):
		return
	st["brand_asked"] = true
	gs.week_events.append(brand_card())


## The card itself (also for tests and captures).
static func brand_card() -> Dictionary:
	return {"tid": BRAND_TID, "title": "Bears or Lions?",
		"text": "Fitzroy have fought off the merger, so the Bears stand alone in %d. The board leaves the club's name to you: become the Brisbane Lions, in maroon, blue and gold, or stay the Brisbane Bears, in maroon and gold. It changes the name, the guernsey and the colours, never how the side plays. You make this call once." % (TALKS_YEAR + 1),
		"options": [
			{"label": "Become the Lions", "effects": [], "result": "From %d the club is the Brisbane Lions." % (TALKS_YEAR + 1)},
			{"label": "Stay the Bears", "effects": [], "result": "The Bears it is: maroon and gold, as ever."}],
		"unanswered": {"hint": "Leave it and the club stays the Bears."},
		"facts": {}}


## The coach's answer to the card (GameState.resolve_card).
static func answered(gs, card: Dictionary, choice: int) -> void:
	canon_answered(gs, card, choice)
	if str(card.get("tid", "")) != BRAND_TID:
		return
	var lions := choice == 0
	_st(gs)["brand"] = "lions" if lions else "bears"
	keep_fitzroy(lions)
	if lions:
		gs.add_news("legacy", "The Brisbane Bears are now the Brisbane Lions, in maroon, blue and gold.")


# ---------------------------------------------------------------------------
# Fitzroy beside Brisbane: guernseys apart (director, 2026-11-13)
# ---------------------------------------------------------------------------
## The most a colour is reshaded, in value (0-1) each way.
const SHADE_MAX := 0.2
const SHADE_STEP := 0.02


## "if the lions/bears and fitzroy guernseys clash you can slightly change the
## colours of each (still same look, just slightly reshaded to emphasise
## differences)" (director, 2026-11-13). When both play and their guernseys
## clash by the match's own check (PitchView.DISC_CLASH on the two home
## kits), Fitzroy's colours go a shade darker and Brisbane's a shade brighter,
## step by step until they no longer clash, at most SHADE_MAX. Hue, design and
## which colour goes where never change.
static func separate_colours() -> void:
	GameDB.shade_colours(MERGED, {})
	GameDB.shade_colours(MERGED_INTO, {})
	if not GameDB.clubs.has(MERGED) or not GameDB.clubs.has(MERGED_INTO):
		return
	if kit_gap() >= PitchView.DISC_CLASH:
		return
	var fit := GameDB.club_colours(MERGED)
	var bri := GameDB.club_colours(MERGED_INTO)
	var step := SHADE_STEP
	while step <= SHADE_MAX + 0.0001:
		GameDB.shade_colours(MERGED, _shaded(fit, -step))
		GameDB.shade_colours(MERGED_INTO, _shaded(bri, step))
		if kit_gap() >= PitchView.DISC_CLASH:
			return
		step += SHADE_STEP


## How far apart the two home guernseys look on the ground.
static func kit_gap() -> float:
	return PitchView.disc_distance(PitchView.with_trim(MERGED, GameDB.club_guernsey(MERGED)),
			PitchView.with_trim(MERGED_INTO, GameDB.club_guernsey(MERGED_INTO)))


static func _shaded(cols: Array, by: float) -> Dictionary:
	var out := {}
	var keys := ["primary", "secondary", "accent"]
	for i in range(mini(cols.size(), keys.size())):
		var c: Color = cols[i]
		out[keys[i]] = Color.from_hsv(c.h, c.s, clampf(c.v + by, 0.0, 1.0), c.a)
	return out


static func _and(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


# ---------------------------------------------------------------------------
# Canon stories (director, 2026-11-13)
# ---------------------------------------------------------------------------
## "historical trades arent in the sim. make the gold coast and lance franklin
## trades canon events that CAN be stopped"; who stops it: "His coach, with
## odds"; then "make Scully another", Dangerfield, Brodie Grundy, Zach Merrett,
## Chris Judd, Lachie Neale and Joe Daniher; and "storylines around Liam Jurrah
## and Cyril Rioli where they will either make an early retirement or be
## convinced to play on"; "just have a story no matter where he is".
##
## Each fires from wherever the sim has him, in round `round` of the season
## before `year`. Kind "move": he leaves for `to` at the rollover into `year`
## (`to` "" is the ladder's leader that week, his own club aside: Merrett, whose
## real destination we have no record of). Kind "retire": he retires at that
## rollover. If you coach his club, a card: fight for him (KEEP_PCT he stays)
## or let him go. At a rival club it happens as it really did. Retired, or
## already at the club, nothing happens.
const CANON := [
	{"id": "ablett_gcs", "kind": "move", "first": "Gary", "last": "Ablett", "dob": "1984-05-14", "to": "GCS", "year": 2011,
		"pitch": "a long deal to be the face of their first season"},
	{"id": "scully_gws", "kind": "move", "first": "Tom", "last": "Scully", "dob": "1991-05-15", "to": "GWS", "year": 2012,
		"pitch": "a long deal to join them for their first season"},
	{"id": "judd_car", "kind": "move", "first": "Chris", "last": "Judd", "dob": "1983-09-08", "to": "CAR", "year": 2008,
		"pitch": "a big deal to come home to Victoria"},
	{"id": "franklin_syd", "kind": "move", "first": "Lance", "last": "Franklin", "dob": "1987-01-30", "to": "SYD", "year": 2014,
		"pitch": "nine years as a free agent"},
	{"id": "dangerfield_gee", "kind": "move", "first": "Patrick", "last": "Dangerfield", "dob": "1990-04-05", "to": "GEE", "year": 2016,
		"pitch": "the chance to come home to Geelong"},
	{"id": "neale_brl", "kind": "move", "first": "Lachie", "last": "Neale", "dob": "1993-05-24", "to": "BRL", "year": 2019,
		"pitch": "a long deal"},
	{"id": "daniher_brl", "kind": "move", "first": "Joe", "last": "Daniher", "dob": "1994-03-04", "to": "BRL", "year": 2021,
		"pitch": "a fresh start as a free agent"},
	{"id": "grundy_mel", "kind": "move", "first": "Brodie", "last": "Grundy", "dob": "1994-04-15", "to": "MEL", "year": 2023,
		"pitch": "a fresh start in their ruck"},
	{"id": "grundy_syd", "kind": "move", "first": "Brodie", "last": "Grundy", "dob": "1994-04-15", "to": "SYD", "year": 2024,
		"pitch": "a fresh start in their ruck"},
	{"id": "merrett_flag", "kind": "move", "first": "Zach", "last": "Merrett", "dob": "1995-10-03", "to": "", "year": 2026,
		"pitch": "a place in a side chasing the flag"},
	{"id": "jurrah_home", "kind": "retire", "first": "Liam", "last": "Jurrah", "dob": "1988-09-22", "year": 2014,
		"pitch": "walking away from the game to go home to the Territory"},
	{"id": "rioli_home", "kind": "retire", "first": "Cyril", "last": "Rioli", "dob": "1989-07-14", "year": 2019,
		"pitch": "retiring early to go home to Darwin with his family"},
]
const CANON_ROUND := 18
const CANON_TID := "legacy_canon"
## Fight for him: the chance he stays, and what a move's keeping deal costs.
const KEEP_PCT := 50
const KEEP_RAISE_PCT := 50
const KEEP_YEARS := 4


static func canon(id: String) -> Dictionary:
	for m in CANON:
		if str(m["id"]) == id:
			return m
	return {}


static func _canon_st(gs) -> Dictionary:
	var st := _st(gs)
	if not st.has("canon"):
		st["canon"] = {}
	return st["canon"]


## Where the sim has him now: {"p", "club"}, or {} when he is on no list.
static func canon_find(gs, m: Dictionary) -> Dictionary:
	var name := "%s %s" % [str(m["first"]), str(m["last"])]
	for c in gs.league_lists:
		for p in gs.league_lists[c]:
			if str(p.get("real_name", "")) != name:
				continue
			if str(p.get("dob", "")) != "" and str(p.get("dob", "")) != str(m["dob"]):
				continue
			return {"p": p, "club": str(c)}
	return {}


## The bigger deal that keeps a player another club wants: his asking price
## plus KEEP_RAISE_PCT, a season.
static func keep_salary(p: Dictionary) -> int:
	return ceili(Contracts.asking_salary(p) * (100 + KEEP_RAISE_PCT) / 100.0)


## Where a move goes: its club, or the ladder's leader other than `from`.
static func _canon_to(gs, m: Dictionary, from: String) -> String:
	if str(m.get("to", "")) != "":
		return str(m["to"])
	if gs.season != null:
		for row in gs.season.ladder_sorted():
			if str(row["code"]) != from:
				return str(row["code"])
	return ""


## This week: each story that is due fires once. A retirement is set now (the
## season's close retires him); you get the card if you coach his club.
static func canon_week(gs) -> void:
	if not on() or gs.season == null:
		return
	var cst := _canon_st(gs)
	for m in CANON:
		if int(gs.season_year) != int(m["year"]) - 1 or int(gs.season.round_index) < CANON_ROUND:
			continue
		if cst.has(m["id"]):
			continue
		var e := {"asked": true}
		cst[m["id"]] = e
		var at := canon_find(gs, m)
		if at.is_empty():
			continue
		var p: Dictionary = at["p"]
		var from := str(at["club"])
		if str(m["kind"]) == "retire":
			p["retiring"] = int(m["year"])
			p["retire_talk"] = {"year": int(m["year"]), "stays": false, "reason": "He wants to go home."}
		else:
			e["to"] = _canon_to(gs, m, from)
			if str(e["to"]) == "" or str(e["to"]) == from:
				continue
		if from == str(gs.my_club) and not gs.is_sacked():
			e["card"] = true
			gs.week_events.append(canon_card(gs, m, p, str(e.get("to", ""))))


## The card (also for tests and captures).
static func canon_card(_gs, m: Dictionary, p: Dictionary, to_code: String) -> Dictionary:
	var who := GameDB.player_display_name(p)
	var y := int(m["year"])
	if str(m["kind"]) == "retire":
		return {"tid": CANON_TID, "canon": str(m["id"]), "title": "%s thinks of going home" % who,
			"text": "%s is thinking about %s at the end of the season. The club can try to talk him into playing on in %d." % [who, str(m["pitch"]), y],
			"options": [
				{"label": "Talk him into playing on", "effects": [],
					"rule": "%d%% he plays on in %d. %d%% he retires anyway." % [KEEP_PCT, y, 100 - KEEP_PCT],
					"result": "The club has made its case. He gives his answer at season's end."},
				{"label": "Let him go home", "effects": [],
					"rule": "He retires at season's end.",
					"result": "The club backs his call. He retires at season's end."}],
			"unanswered": {"hint": "Leave it and he retires."},
			"facts": {}}
	var to := GameDB.club_name(to_code)
	var asks := Contracts.asking_salary(p)
	return {"tid": CANON_TID, "canon": str(m["id"]), "title": "%s want %s" % [to, who],
		"text": "%s have offered %s %s, from %d. He is leaning their way, and he goes at season's end unless the club fights to keep him." % [
			to, who, str(m["pitch"]), y],
		"options": [
			{"label": "Fight to keep him", "effects": [],
				"rule": "%d%% he stays, on %d more seasons at %s a season (he asks %s). %d%% he goes anyway." % [
					KEEP_PCT, KEEP_YEARS, Contracts.money(keep_salary(p)), Contracts.money(asks), 100 - KEEP_PCT],
				"result": "The club has made its offer. He gives his answer at season's end."},
			{"label": "Let him go", "effects": [],
				"rule": "He joins %s for %d, and his pay comes off your cap." % [to, y],
				"result": "The club wishes him well. He plays for %s from %d." % [to, y]}],
		"unanswered": {"hint": "Leave it and he goes."},
		"facts": {}}


## Your answer to the card (GameState.resolve_card, through answered()). The
## roll is seeded by the career, so a reload cannot change it.
static func canon_answered(gs, card: Dictionary, choice: int) -> void:
	if str(card.get("tid", "")) != CANON_TID:
		return
	var id := str(card.get("canon", ""))
	var m := canon(id)
	var cst := _canon_st(gs)
	var e: Dictionary = cst.get(id, {"asked": true})
	cst[id] = e
	e["fight"] = choice == 0
	if choice != 0 or m.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("canon|%s|%d" % [id, int(gs.career_seed)])
	e["roll"] = rng.randi_range(1, 100)
	e["kept"] = int(e["roll"]) <= KEEP_PCT
	if not bool(e["kept"]):
		return
	var at := canon_find(gs, m)
	if at.is_empty():
		return
	var p: Dictionary = at["p"]
	if str(m["kind"]) == "retire":
		p["play_on"] = int(m["year"])
		p["retire_talk"] = {"year": int(m["year"]), "stays": true, "reason": "The club talked him into another season."}
	else:
		p["salary"] = keep_salary(p)
		p["contract_years"] = KEEP_YEARS


## At the rollover into `year`: the news of each story, and each move made. A
## move to a club yet to play joins the list it is building.
static func canon_moves(gs, year: int) -> void:
	var cst := _canon_st(gs)
	for m in CANON:
		if int(m["year"]) != year:
			continue
		var e: Dictionary = cst.get(m["id"], {})
		if e.has("done"):
			continue
		e["done"] = true
		cst[m["id"]] = e
		var who := "%s %s" % [str(m["first"]), str(m["last"])]
		if str(m["kind"]) == "retire":
			if e.has("asked") and not bool(e.get("kept", false)):
				gs.add_news("legacy", "%s has retired, %s." % [who, str(m["pitch"]).replace("retiring early", "early").replace("walking away from the game", "walking away")])
			elif bool(e.get("kept", false)):
				gs.add_news("legacy", "%s has been talked into playing on in %d." % [who, year])
			continue
		var at := canon_find(gs, m)
		if at.is_empty():
			continue
		var p: Dictionary = at["p"]
		var from := str(at["club"])
		var to := str(e.get("to", _canon_to(gs, m, from)))
		if to == "" or to == from:
			continue
		who = GameDB.player_display_name(p)
		if from == str(gs.my_club) and bool(e.get("kept", false)):
			gs.add_news("legacy", "%s turns down %s and stays at %s, on %d more seasons at %s a season." % [
					who, GameDB.club_name(to), GameDB.club_name(from), KEEP_YEARS, Contracts.money(int(p["salary"]))])
			continue
		e["from"] = from
		e["to"] = to
		(gs.league_lists[from] as Array).erase(p)
		_join(p, to, {"num": str(p.get("num", 0))})
		p["joined"] = year
		# A club yet to play takes him onto the list it is building.
		var dest: Array = gs.league_lists.get(to, []) if gs.league_lists.has(to) 				else ExpansionBuild.list_of(gs, to)
		dest.append(p)
		if gs.league_lists.has(to) or not ExpansionBuild.has_package(gs, to):
			gs.league_lists[to] = dest
		else:
			# Its draft is done: the list it enters with still fits its spots.
			ExpansionBuild.fit_spots(gs, to)
		gs.unique_jumpers(dest)
		gs.add_news("legacy", "%s leaves %s for %s." % [who, GameDB.club_name(from), GameDB.club_name(to)])
