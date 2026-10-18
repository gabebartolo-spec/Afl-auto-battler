extends RefCounted
## Run through tests/run_international_tests.gd.
## International prospects (switch international_prospects): each generated draft
## class has one or two prospects from Ireland, New Zealand, the USA or an
## African country, with names from their own country's lists and a raw
## ratings profile; one is drafted, kept across a season rollover and a save.
## Switched off, classes are exactly what they were.
## Seeded by design: classes come from their year; the career from replay_seed.

const INTL := preload("res://scripts/sim/InternationalProspects.gd")
const FIRST_YEAR := 2027
const YEARS := 150
const SEED := 2027

var _checks := 0
var failures: Array[String] = []
var _tree: SceneTree


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _digest(p: Dictionary) -> String:
	return "%s|%s|%d|%d|%s|%s" % [p["id"], p["role"], int(p["overall"]),
			int(p.get("potential", 0)), str(p["dob"]), str(p["draft_team"])]


func run() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	var state: Node = _tree.root.get_node("GameState")
	var db: Node = _tree.root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://test_intl.save"
	state.settings_path = "user://test_intl.cfg"
	_check(Features.KNOWN.has("international_prospects"), "The switch is a known feature")
	_check(not Features.on("international_prospects"), "The switch ships off")

	# Switch off: nobody is international, and a class is the same every time.
	var off := {}
	for y in range(FIRST_YEAR, FIRST_YEAR + 40):
		var cls: Array = Prospects.generate_class(y, SEED)
		var digest: Array = []
		var any := false
		for p in cls:
			digest.append(_digest(p))
			any = any or p.has("intl") or p.has("attr_bias")
		off[y] = digest
		_check(not any, "%d switched off: no international in the class" % y)
	var again: Array = Prospects.generate_class(FIRST_YEAR, SEED)
	var same := true
	for i in range(again.size()):
		same = same and _digest(again[i]) == (off[FIRST_YEAR] as Array)[i]
	_check(same, "Switched off, a class is the same on a second build")

	# Switch on.
	Features.set_on("international_prospects", true)
	var counts := {}
	var by_country := {}
	var all_intl: Array = []
	var changed_other := 0
	var two := 0
	var profile_ok := true
	for y in range(FIRST_YEAR, FIRST_YEAR + YEARS):
		var cls: Array = Prospects.generate_class(y, SEED)
		var n := 0
		var ids := {}
		var seen_country := {}
		for i in range(cls.size()):
			var p: Dictionary = cls[i]
			if not p.has("intl"):
				continue
			n += 1
			all_intl.append(p)
			by_country[str(p["intl"])] = int(by_country.get(str(p["intl"]), 0)) + 1
			_check(not seen_country.has(str(p["intl"])), "%d: two prospects from one country" % y)
			seen_country[str(p["intl"])] = true
			ids[i] = true
			_check(int(p["draft_rank"]) >= 11, "%d: an international is not a top-ten pick" % y)
		counts[n] = int(counts.get(n, 0)) + 1
		if n == 2:
			two += 1
		# Everyone else is exactly as before.
		if y < FIRST_YEAR + 40:
			for i in range(cls.size()):
				if not ids.has(i) and _digest(cls[i]) != (off[y] as Array)[i]:
					changed_other += 1
	_check(int(counts.get(0, 0)) == 0, "Every class has an international (zero-class count %d)" % int(counts.get(0, 0)))
	var bad_sizes := 0
	for k in counts:
		if int(k) < 1 or int(k) > 2:
			bad_sizes += int(counts[k])
	_check(bad_sizes == 0, "Never more than two in a class (%s)" % str(counts))
	_check(two >= YEARS / 10 and two <= YEARS / 2, "Two in a class only sometimes (%d of %d)" % [two, YEARS])
	_check(changed_other == 0, "The rest of each class is unchanged by the switch (%d differ)" % changed_other)
	print("INTL counts per class: ", counts, "  by country: ", by_country)

	# Country spread: all seven appear; the three big pathways lead.
	for c in INTL.countries():
		_check(int(by_country.get(str(c["id"]), 0)) > 0, "%s appears over %d classes" % [c["name"], YEARS])
	var african := int(by_country.get("KEN", 0)) + int(by_country.get("NGA", 0)) \
			+ int(by_country.get("RSA", 0)) + int(by_country.get("GHA", 0))
	_check(int(by_country.get("IRL", 0)) > int(by_country.get("KEN", 0)), "Ireland is likelier than any one African country")
	_check(african >= all_intl.size() / 6 and african <= all_intl.size() / 2,
			"Africa is a fair share of them (%d of %d)" % [african, all_intl.size()])

	# Names: from his own country's lists, first and surname from one group.
	var samples := {}
	for p in all_intl:
		var c: Dictionary = INTL.country(str(p["intl"]))
		var found := false
		for g in c["groups"]:
			if (g["first"] as Array).has(str(p["intl_first"])) and (g["last"] as Array).has(str(p["intl_last"])):
				found = true
		_check(found, "%s: %s comes from one name group of %s" % [p["id"], p["name"], c["name"]])
		_check(str(p["name"]) == "%s %s" % [p["intl_first"], p["intl_last"]] and str(p["generic_name"]) == str(p["name"]),
				"%s: shown name is his first name and surname" % p["id"])
		_check(not (str(p["intl_last"]).contains(" ")), "%s: a one-word surname (card shows it whole)" % p["id"])
		var arr: Array = samples.get(str(p["intl"]), [])
		if arr.size() < 10 and not arr.has(str(p["name"])):
			arr.append(str(p["name"]))
			samples[str(p["intl"])] = arr
	for k in samples:
		print("INTL names ", k, ": ", ", ".join(PackedStringArray(samples[k])))
	# No name of one country's lists is used in a way that crosses groups: check the
	# data itself has no first name or surname shared between groups of one country.
	for c in INTL.countries():
		var firsts := {}
		var lasts := {}
		for g in c["groups"]:
			for f in g["first"]:
				_check(not firsts.has(f), "%s: first name %s is in one group only" % [c["name"], f])
				firsts[f] = true
			for l in g["last"]:
				_check(not lasts.has(l), "%s: surname %s is in one group only" % [c["name"], l])
				lasts[l] = true

	# Profile per country: ages, size, pathway, rawness, code-shaped ratings.
	var stat := {}
	var dom_gap := 0.0
	var dom_n := 0
	var dom_rank_gap := 0.0
	var dom_carry := 0.0
	var dom_disp := 0.0
	for y in range(FIRST_YEAR, FIRST_YEAR + 40):
		for p in Prospects.generate_class(y, SEED):
			if not p.has("intl"):
				dom_gap += float(p["potential"]) - float(p["overall"])
				dom_rank_gap += float(p["overall"]) - Prospects.rank_base_overall(int(p["draft_rank"]))
				dom_carry += float(p["attr"]["carry"]) - float(p["overall"])
				dom_disp += float(p["attr"]["disposal"]) - float(p["overall"])
				dom_n += 1
	var raw_gap := 0.0
	var raw_rank_gap := 0.0
	for p in all_intl:
		var id := str(p["intl"])
		var s: Dictionary = stat.get(id, {"n": 0, "disp": 0.0, "acc": 0.0, "cont": 0.0, "mark": 0.0,
				"pres": 0.0, "carry": 0.0, "h": 0.0, "age_lo": 99.0, "age_hi": 0.0, "ruckfwd": 0})
		s["n"] += 1
		var a: Dictionary = p["attr"]
		var ovr := float(p["overall"])
		s["disp"] += float(a["disposal"]) - ovr
		s["acc"] += float(a["accuracy"]) - ovr
		s["cont"] += float(a["contested"]) - ovr
		s["mark"] += float(a["marking"]) - ovr
		s["pres"] += float(a["pressure"]) - ovr
		s["carry"] += float(a["carry"]) - ovr
		s["h"] += float(p["height_cm"])
		s["age_lo"] = minf(float(s["age_lo"]), float(p["age"]))
		s["age_hi"] = maxf(float(s["age_hi"]), float(p["age"]))
		if str(p["role"]) in ["RUCK", "FWD"]:
			s["ruckfwd"] += 1
		stat[id] = s
		raw_gap += float(p["potential"]) - ovr
		raw_rank_gap += ovr - Prospects.rank_base_overall(int(p["draft_rank"]))
		_check(str(p["draft_team"]) != "" and str(p["draft_league"]) != "" and str(p["draft_state"]) == INTL.country_name(p),
				"%s: his pathway and country are filled in" % p["id"])
		_check(float(p["age"]) >= 17.9 and float(p["age"]) <= 21.0, "%s: age %.1f is 18 to 20 when made (19 to 21 at the draft)" % [p["id"], float(p["age"])])
	var n_all := float(all_intl.size())
	_check(raw_rank_gap / n_all < dom_rank_gap / float(dom_n) - 1.0,
			"Raw: rated under his rank's usual (%.1f vs %.1f)" % [raw_rank_gap / n_all, dom_rank_gap / float(dom_n)])
	_check(raw_gap / n_all > dom_gap / float(dom_n),
			"Decent potential: more room to grow than a domestic prospect (%.1f vs %.1f)" % [raw_gap / n_all, dom_gap / float(dom_n)])
	var m := func(id: String, key: String) -> float:
		return float(stat[id][key]) / float(stat[id]["n"])
	print("INTL profile IRL disp %.1f acc %.1f | NZL cont %.1f pres %.1f | USA h %.0f mark %.1f disp %.1f | KEN carry %.1f disp %.1f" % [
			m.call("IRL", "disp"), m.call("IRL", "acc"), m.call("NZL", "cont"), m.call("NZL", "pres"),
			m.call("USA", "h"), m.call("USA", "mark"), m.call("USA", "disp"), m.call("KEN", "carry"), m.call("KEN", "disp")])
	_check(m.call("IRL", "disp") > m.call("USA", "disp") + 3.0, "Irish prospects kick and dispose better than Americans")
	_check(m.call("IRL", "acc") > m.call("NZL", "acc") + 2.0, "Irish prospects are more accurate than New Zealanders")
	_check(m.call("NZL", "cont") > m.call("IRL", "cont") + 3.0, "New Zealanders are stronger in a contest than the Irish")
	_check(m.call("NZL", "pres") > m.call("USA", "pres") + 2.0, "New Zealanders tackle harder than Americans")
	_check(m.call("USA", "h") > m.call("IRL", "h") + 5.0, "Americans are taller than the Irish")
	_check(m.call("USA", "mark") > m.call("NZL", "mark") + 3.0, "Americans mark better than New Zealanders")
	_check(int(stat["USA"]["ruckfwd"]) * 10 >= int(stat["USA"]["n"]) * 6, "Most Americans are ruck or forward")
	_check(m.call("KEN", "carry") > dom_carry / float(dom_n) + 1.0,
			"Kenyans run and carry harder than a home-grown prospect (%.1f vs %.1f)" % [m.call("KEN", "carry"), dom_carry / float(dom_n)])
	_check(m.call("IRL", "disp") > dom_disp / float(dom_n) + 1.0, "Irish prospects dispose better than a home-grown prospect")
	_check(m.call("KEN", "disp") < m.call("IRL", "disp") - 5.0, "Kenyans are rawer with the ball in hand than the Irish")

	# What the draft shows of him.
	var one: Dictionary = all_intl[0]
	var ped := PlayerProfile.pedigree(one)
	_check(ped.contains(INTL.country_name(one)) and ped.contains(str(one["draft_team"])), "His pedigree line names the pathway and country: " + ped)
	_check(INTL.note(one).begins_with("International prospect from"), "His profile explains he is an international prospect")
	_check(not PlayerProfile.production(one)["title"].contains("season"), "No U18 season is claimed for him")
	_check(RecruitMeeting.reason(one).contains("Raw"), "The panel calls him raw: " + RecruitMeeting.reason(one))
	var dom: Dictionary = {}
	for p in Prospects.generate_class(FIRST_YEAR, SEED):
		if not p.has("intl"):
			dom = p
			break
	var view_i := DraftScouting.projection(one, "ADE", SEED)
	var twin := one.duplicate(true)
	twin.erase("intl")
	var view_t := DraftScouting.projection(twin, "ADE", SEED)
	var wi: int = int(view_i["overall"][1]) - int(view_i["overall"][0]) + int(view_i["potential"][1]) - int(view_i["potential"][0])
	var wt: int = int(view_t["overall"][1]) - int(view_t["overall"][0]) + int(view_t["potential"][1]) - int(view_t["potential"][0])
	_check(wi > wt, "Recruiters' range on him is wider than on the same player at home (%d vs %d)" % [wi, wt])

	_career(state, db)
	Features.clear("international_prospects")
	state.delete_saved_career()
	print("International tests: %d checks, %d failures" % [_checks, failures.size()])
	for f in failures:
		print("FAIL: ", f)


func _career(state: Node, db: Node) -> void:
	# Old save: a career begun and saved with the switch off loads with it on.
	Features.set_on("international_prospects", false)
	state.replay_seed = SEED
	state.reset()
	state.start_season("ADE", db.club_list("ADE"))
	_check(state.save_career(), "A career saves with the switch off")
	Features.set_on("international_prospects", true)
	_check(state.load_career(), "...and loads with the switch on")
	var any_old := false
	for p in state.draftee_pool:
		any_old = any_old or p.has("intl")
	_check(not any_old, "...its draft class has no international (it was made without them)")

	# A new career with the switch on: draft an international, keep him through
	# a rollover, a save and a reload.
	state.replay_seed = SEED
	state.reset()
	state.start_season("ADE", db.club_list("ADE"))
	var mine := ""
	for p in state.draftee_pool:
		if p.has("intl"):
			mine = str(p["id"])
	_check(mine != "", "The first class has an international prospect")
	state.season.round_index = state.season.fixture.size()
	_check(state.begin_intake_draft(), "The intake opens")
	var draft: Draft = state.draft
	var guard := 0
	while not draft.is_finished() and guard < 2000:
		guard += 1
		var code: String = draft.current_club()
		var pick := {}
		if code == "ADE" and mine != "" and not draft.picked.has(mine):
			for q in draft.pool:
				if str(q["id"]) == mine:
					pick = q
		if pick.is_empty():
			pick = draft._best_ai_pick(code)
		if pick.is_empty() or not draft._draft_pick(code, pick):
			draft._skip_current_pick()
	_check(draft.picked.has(mine), "Adelaide drafted the international prospect")
	var year := int(state.season_year)
	_check(state.finish_intake_draft(), "The draft commits and the career rolls on")
	var found := _find(state, mine)
	_check(not found.is_empty(), "He is on a list next season")
	var name_before := str(found.get("generic_name", ""))
	_check(str(found.get("intl", "")) != "" and str(found.get("drafted_type", "")) == "national",
			"He is an ordinary draftee with his origin kept")
	var club := str(found.get("club", ""))
	_check(club == "ADE", "He is at Adelaide")
	_check(state.save_career() and state.load_career(), "Save and reload")
	found = _find(state, mine)
	_check(str(found.get("generic_name", "")) == name_before and str(found.get("intl", "")) != "",
			"He reloads with his name and origin")
	var guard2 := 0
	while not state.season.is_season_over() and guard2 < 40:
		guard2 += 1
		state.advance()
	_check(state.start_next_season(), "The season rolls over")
	found = _find(state, mine)
	_check(not found.is_empty() and str(found.get("intl", "")) != "" and str(found.get("generic_name", "")) == name_before,
			"He keeps his identity across a season rollover (year %d to %d)" % [year, int(state.season_year)])


func _find(state: Node, id: String) -> Dictionary:
	for code in state.league_lists:
		for p in state.league_lists[code]:
			if str(p["id"]) == id:
				return p
	return {}
