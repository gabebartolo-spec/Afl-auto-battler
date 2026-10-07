extends SceneTree
## godot --headless --path . --script tests/run_stats_tests.gd
## Season stats (the Stats patch, ROADMAP §1.11): the hub's Season stats
## button, every section, and the numbers behind them.
const Tap := preload("res://tests/tap.gd")
const SUITE_SEED := 2031

var _state: Node
## Loaded at run time: in --script mode a class that reads an autoload
## (GameDB) cannot compile into this script.
var _aw
var _cs
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_aw = load("res://scripts/sim/Awards.gd")
	_cs = load("res://scripts/state/CareerSave.gd")
	_state.autosave_enabled = false
	_state.save_path = "user://test_stats.save"
	_state.settings_path = "user://test_stats_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = SUITE_SEED
	var db = root.get_node("GameDB")
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	# Before any round: no press conference sits over the hub.
	await _hub_button()
	await _awards_early()
	for i in range(4):
		_state.advance()
	await _sections()
	await _awards_races()
	await _awards_ties()
	_rising_star_rules()
	await _rising_star_saves()
	await _awards_awarded()
	print("Stats tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The hub's Season stats button takes a tap and opens the hub.
func _hub_button() -> void:
	root.size = Vector2i(1280, 720)
	_state.set_setting("seen_weekly_loop_intro", true)
	var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
	root.add_child(hub)
	await _settle()
	var b: Button = hub.find_child("SeasonStats", true, false)
	_check(b != null and hub.find_child("FullLadder", true, false) == null,
			"The hub offers Season stats in place of Full ladder")
	if b != null:
		var got := await Tap.tap(b)
		_check(got == "", "Season stats takes a tap (%s)" % got)
	hub.queue_free()
	await _settle()


## Every section opens, at a phone's width and a PC's.
func _sections() -> void:
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		root.size = sz
		var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
		root.add_child(s)
		await _settle()
		for key in ["ladder", "players", "awards", "fixture", "trophies"]:
			var t: Button = s.find_child("Section_" + key, true, false)
			_check(t != null, "Season stats has a %s section (%dx%d)" % [key, sz.x, sz.y])
			if t == null:
				continue
			_check((await Tap.tap(t)) == "", "The %s tab takes a tap (%dx%d)" % [key, sz.x, sz.y])
			await _settle()
			var body: Node = s.find_child("SectionBody", true, false)
			_check(body != null and body.get_child_count() == 1, "The %s section builds (%dx%d)" % [key, sz.x, sz.y])
		s.queue_free()
		await _settle()


# ---------------------------------------------------------------------------
# Awards
# ---------------------------------------------------------------------------
func _open_awards(sz: Vector2i) -> Control:
	root.size = sz
	load("res://scripts/ui/StatsHubScene.gd").current = "awards"
	var s: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(s)
	await _settle()
	return s


func _close(s: Control) -> void:
	s.queue_free()
	await _settle()


## Before a ball is bounced: every race says so, nothing is projected.
func _awards_early() -> void:
	var s := await _open_awards(Vector2i(390, 844))
	_check(s.find_child("AwardsProvisional", true, false) != null, "Awards before Round 1 are labelled provisional")
	var none: Label = s.find_child("ColemanEmpty", true, false)
	_check(none != null and none.text == "No goals kicked yet.", "The Coleman race before a goal says so")
	_check(s.find_child("Coleman_1", true, false) == null, "No Coleman leader before a goal")
	_check(s.find_child("CoachesAwardEmpty", true, false) != null, "The Coaches Award before a vote says so")
	_check(s.find_child("AATeam", true, false) == null, "No projected All-Australian team before Round 1")
	_check(s.find_child("BrownlowSealed", true, false) != null, "The Brownlow is sealed before Round 1")
	await _close(s)


## Four rounds in, at a phone's size and a PC's: the races, the sealed
## Brownlow, the projected team, and real taps on a player and the team.
func _awards_races() -> void:
	var min_games: int = _aw.aa_min_games(4)
	_check(min_games == 2, "The All-Australian minimum after 4 of 24 rounds is 2 games (%d)" % min_games)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var s := await _open_awards(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		var prov: Label = s.find_child("AwardsProvisional", true, false)
		_check(prov != null and prov.text.contains("After Round 4") and prov.text.contains("Nothing here is awarded"),
				"The races are labelled provisional (%s)" % tag)
		_check(s.find_child("AwardsHonours", true, false) == null, "No honours before they are awarded (%s)" % tag)
		var sealed: Node = s.find_child("BrownlowSealed", true, false)
		_check(sealed != null and sealed.find_children("*", "Button", true, false).is_empty(),
				"The Brownlow stays sealed: no names, no counts (%s)" % tag)
		var proj: Label = s.find_child("AAProjected", true, false)
		_check(proj != null and proj.text.begins_with("Projected") and proj.text.contains("2 or more games"),
				"The All-Australian team is labelled projected, with its games line (%s)" % tag)
		_check(s.find_child("AANamed", true, false) == null, "The projected team is never called named (%s)" % tag)
		# A finger on the Coleman leader opens his profile; Back shuts it first.
		var lead: Button = s.find_child("Coleman_1", true, false)
		_check(lead != null, "The Coleman race has a leader (%s)" % tag)
		if lead != null:
			_check((await Tap.tap(lead)) == "", "The Coleman leader takes a tap (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens his profile (%s)" % tag)
			_check(s.call("handle_back"), "Back closes the profile first (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) == null and not s.call("handle_back"),
					"The profile is gone, and the next Back leaves (%s)" % tag)
		# The projected team on the oval: 18 spots and five on the bench, filled.
		var team: Node = s.find_child("AATeam", true, false)
		var spots := []
		if team != null:
			for c in team.find_children("*Spot_*", "Button", true, false):
				if str(c.get_meta("id", "")) != "":
					spots.append(c)
		_check(spots.size() == 23, "The projected team fills 23 spots on the oval (%s: %d)" % [tag, spots.size()])
		_check(team != null and team.find_child("BuilderSearch", true, false) == null
				and team.find_child("NotSelected", true, false) == null, "The team shows just the oval (%s)" % tag)
		var ruck: Button = team.find_child("Spot_RUCK", true, false) if team != null else null
		_check(ruck != null, "The projected team has a ruckman (%s)" % tag)
		if ruck != null:
			_check((await Tap.tap(ruck)) == "", "The All-Australian ruckman takes a tap (%s)" % tag)
			await _settle()
			_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens the ruckman's profile (%s)" % tag)
			s.call("handle_back")
			await _settle()
		await _close(s)
	# The projected team by position, from the tally so far.
	var players := _players()
	var team: Array = _aw.projected_all_australian(_state.season_tally, players, min_games)
	var slots := {}
	var ok := true
	var ids := {}
	for r in team:
		slots[str(r["slot"])] = int(slots.get(str(r["slot"]), 0)) + 1
		ids[str(r["id"])] = true
		if int(r["games"]) < min_games:
			ok = false
		if str(r["slot"]) != "BENCH" and str(players[str(r["id"])]["role"]) != str(r["slot"]):
			ok = false
	_check(team.size() == 23 and ids.size() == 23, "The projected All-Australian team is 23 different players (%d)" % team.size())
	_check(slots == {"RUCK": 1, "MID": 5, "DEF": 6, "FWD": 6, "BENCH": 5} and ok,
			"Every projected All-Australian plays his position and has the games (%s)" % str(slots))


## Level counts share a rank; a tie across the cut is summed up, never split.
func _awards_ties() -> void:
	var keep: Dictionary = _state.season_tally
	var ids := []
	for p in _state.season.lists["COL"]:
		ids.append(str(p["id"]))
	var tally := {}
	var goals := [9, 5, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
	for i in range(goals.size()):
		tally[ids[i]] = _row(goals[i])
	_state.season_tally = tally
	var s := await _open_awards(Vector2i(390, 844))
	var ranks := []
	for i in range(1, 6):
		var b: Node = s.find_child("Coleman_%d" % i, true, false)
		ranks.append(_rank(b) if b != null else "-")
	_check(ranks == ["1", "2", "2", "2", "-"], "Level goals share a rank and a tie across the cut isn't split (%s)" % str(ranks))
	var more: Label = s.find_child("ColemanMore", true, false)
	_check(more != null and more.text == "10 more on 2 goals.", "The tie at the cut is summed up (%s)" % (more.text if more else "none"))
	await _close(s)
	# Twelve level on one goal: the leaders are shown, the rest counted.
	tally = {}
	for i in range(12):
		tally[ids[i]] = _row(1)
	_state.season_tally = tally
	s = await _open_awards(Vector2i(390, 844))
	var b10: Node = s.find_child("Coleman_10", true, false)
	more = s.find_child("ColemanMore", true, false)
	_check(b10 != null and _rank(b10) == "1" and more != null and more.text == "2 more on 1 goal.",
			"Twelve level leaders: ten shown at rank 1, two counted (%s)" % (more.text if more else "none"))
	await _close(s)
	_state.season_tally = keep


## One nominee a round: the most influential eligible player, once a season.
func _rising_star_rules() -> void:
	var res := {"home": "COL", "away": "CAR",
		"roster": [[{"id": "old"}, {"id": "kid"}], [{"id": "kid2"}]],
		"players": {"old": {"disposals": 40}, "kid": {"disposals": 20}, "kid2": {"disposals": 10}}}
	var ages := {"old": 22.0, "kid": 20.0, "kid2": 19.0}
	_check(str(_aw.rising_star_nominee([res], ages, {}).get("id", "")) == "kid",
			"The Rising Star nominee is the best player 21 and under, not the best overall")
	_check(str(_aw.rising_star_nominee([res], ages, {"kid": true}).get("id", "")) == "kid2",
			"A player is nominated once a season")
	var fin := res.duplicate()
	fin["tag"] = "GF"
	_check(_aw.rising_star_nominee([fin], ages, {}).is_empty(), "Finals bring no nomination")
	# The four rounds so far: one nominee each, all eligible, all different.
	var noms: Array = _state.rising_star_noms["rounds"]
	var players := _players()
	var rounds := []
	var seen := {}
	var young := true
	for n in noms:
		rounds.append(int(n["round"]))
		seen[str(n["id"])] = true
		if float(players[str(n["id"])]["age"]) > _aw.RISING_STAR_AGE:
			young = false
	_check(rounds == [1, 2, 3, 4] and seen.size() == 4 and young,
			"Four rounds, four different nominees, all 21 or under (%s)" % str(rounds))
	var before := {}
	for n in noms.slice(0, 3):
		before[str(n["id"])] = true
	var ages_now := {}
	for id in players:
		ages_now[id] = float(players[id]["age"])
	var pick: Dictionary = _aw.rising_star_nominee(_state.last_results, ages_now, before)
	_check(noms.size() == 4 and str(pick.get("id", "")) == str(noms[3]["id"]),
			"Round 4's nominee was that round's best eligible player")
	# The winner comes from the nominees, as in the AFL; a season without a
	# full record (an older save) keeps the old rule.
	var tally := {"a": _row(0, 10, 10), "b": _row(0, 5, 3)}
	var who := {"a": {"role": "MID", "age": 20.0}, "b": {"role": "MID", "age": 19.0}}
	var full: Dictionary = _aw.season_awards(tally, who, 2026, {"from": 1, "rounds": [{"round": 1, "id": "b", "club": "COL"}]})
	_check(str(full["rising_star"][0]["id"]) == "b", "With every round recorded, the Rising Star comes from the nominees")
	var old: Dictionary = _aw.season_awards(tally, who, 2026, {"from": 5, "rounds": [{"round": 5, "id": "b", "club": "COL"}]})
	_check(old["rising_star"].size() == 1 and str(old["rising_star"][0]["id"]) == "a",
			"Without a full record (an older save), the old Rising Star rule stands")


## Nominations survive a save and load; an older save says which rounds it
## never recorded, and records from the next round on.
func _rising_star_saves() -> void:
	var before := JSON.stringify(_state.rising_star_noms)
	_check(_state.save_career() and _state.load_career(), "The career saves and loads")
	_check(JSON.stringify(_state.rising_star_noms) == before, "The Rising Star nominations survive a save and load")
	var s := await _open_awards(Vector2i(390, 844))
	_check(s.find_child("RisingStar_4", true, false) != null and s.find_child("RisingStarUnrecorded", true, false) == null,
			"The nominations show by round, with no unrecorded rounds")
	await _close(s)
	var state: Dictionary = _cs.read(_state.save_path)
	var meta: Dictionary = _cs.read_meta(_state.save_path)
	state.erase("rising_star_noms")
	_cs.write(state, meta, _state.save_path)
	_check(_state.load_career(), "An older save, without nominations, loads")
	_check(int(_state.rising_star_noms["from"]) == 5 and (_state.rising_star_noms["rounds"] as Array).is_empty(),
			"An older save invents no nominations for the rounds played")
	s = await _open_awards(Vector2i(390, 844))
	var gap: Label = s.find_child("RisingStarUnrecorded", true, false)
	_check(gap != null and gap.text == "Nominations from Rounds 1 to 4 weren't recorded in this save."
			and s.find_child("RisingStar_1", true, false) == null, "An older save says plainly which rounds weren't recorded")
	await _close(s)
	_state.advance()
	var noms: Array = _state.rising_star_noms["rounds"]
	_check(noms.size() == 1 and int(noms[0]["round"]) == 5, "Recording starts with the next round")


## Once the season's awards are presented they lead, labelled awarded, and
## nothing is called projected.
func _awards_awarded() -> void:
	_state.season_awards = _aw.season_awards(_state.season_tally, _players(), _state.season_year,
			_state.rising_star_noms)
	for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
		var s := await _open_awards(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		var awarded: Label = s.find_child("AwardsAwarded", true, false)
		_check(s.find_child("AwardsHonours", true, false) != null and awarded != null and awarded.text.begins_with("Awarded"),
				"Presented awards are labelled awarded (%s)" % tag)
		_check(s.find_child("AwardsProvisional", true, false) == null and s.find_child("AAProjected", true, false) == null,
				"Nothing presented is called provisional or projected (%s)" % tag)
		_check(s.find_child("AANamed", true, false) != null, "The All-Australian team is the one named (%s)" % tag)
		var medal: Button = s.find_child("Honour_BrownlowMedal", true, false)
		var fig: Label = medal.find_child("Figure", true, false) if medal != null else null
		_check(fig != null and (fig.text.ends_with(" votes") or fig.text.ends_with(" vote")),
				"The medallist's count carries its unit (%s: %s)" % [tag, fig.text if fig else "none"])
		var name_l: Label = medal.find_child("Name", true, false) if medal != null else null
		var club_l: Label = medal.find_child("Club", true, false) if medal != null else null
		_check(name_l != null and club_l != null and _fits(name_l),
				"The medallist's name fits in full, beside the count (%s, club %s)"
				% [tag, "under the name" if club_l != null and name_l != null and name_l.get_parent() == club_l.get_parent() else "beside it"])
		_check(medal != null and (await Tap.tap(medal)) == "", "The Brownlow medallist takes a tap (%s)" % tag)
		await _settle()
		_check(s.find_child("PlayerProfile", true, false) != null, "The tap opens the medallist's profile (%s)" % tag)
		await _close(s)
	_state.season_awards = {}


func _players() -> Dictionary:
	var out := {}
	for code in _state.season.lists:
		for p in _state.season.lists[code]:
			out[str(p["id"])] = p
	return out


func _row(goals: int, votes := 0, games := 4) -> Dictionary:
	return {"club": "COL", "games": games, "goals": goals, "goals_ha": goals, "disposals": 0,
			"distance_run": 0.0, "influence": 10.0 * games, "votes": votes, "bf": 0, "polled": 0, "coaches": 0}


## Whether a label shows its whole text, without an ellipsis.
func _fits(l: Label) -> bool:
	var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			l.get_theme_font_size("font_size")).x
	return w <= l.size.x + 1.0


func _rank(row: Node) -> String:
	return str((row.get_child(0).get_child(0) as Label).text)


func _settle() -> void:
	for i in range(4):
		await process_frame


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
		push_error(what)
