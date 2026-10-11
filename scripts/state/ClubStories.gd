class_name ClubStories
extends RefCounted
## GameState's side of the week's story cards: the facts a card may read about
## your club and players, and a choice's effects applied through levers the
## game already has (morale, development, the board, trust, selection,
## contracts). The rules of what comes up live in StoryEngine; the cards in
## data/stories. `gs` is GameState.

## Trust lost when a promise made on a card is broken after the match.
const BROKEN_PROMISE_TRUST := -8
const BROKEN_RUN_TRUST := -10


## Your week of the season: the round, then the finals weeks after it.
static func week_in_season(gs) -> int:
	if gs.season == null:
		return 0
	if not gs.season.is_regular_done():
		return gs.season.round_index + 1
	return Season.REGULAR_ROUNDS + (gs.season.finals.get("weeks", []) as Array).size() + 1


static func phase(gs) -> String:
	return "finals" if gs.season != null and gs.season.is_regular_done() else "regular"


## This week's cards. In the finals, only while you are still playing.
static func pick(gs) -> Array:
	if phase(gs) == "finals" and (gs.season.is_season_over() or gs.my_finals_status() != "alive"):
		return []
	return StoryEngine.pick_week(StoryDeck.all(), context(gs), gs.story)


static func context(gs) -> Dictionary:
	var week := week_in_season(gs)
	var ph := phase(gs)
	return {"seed": int(gs.season.seed), "year": int(gs.season_year), "week": week, "phase": ph,
			"big": ph == "finals" or week == 1 or week == Season.REGULAR_ROUNDS,
			"club": club_facts(gs, week, ph), "players": player_facts(gs)}


static func club_facts(gs, week: int, ph: String) -> Dictionary:
	var fit := 0
	for p in gs.my_list:
		if int(p.get("injury_weeks", 0)) <= 0:
			fit += 1
	return {"club": GameDB.club_name(gs.my_club), "opp": _opponent_name(gs), "round": week,
			"year": int(gs.season_year), "losing_run": int(gs.losing_streak), "winning_run": _winning_run(gs),
			"ladder": gs.my_position(), "board": gs.board_confidence(), "fit_count": fit,
			"run_games": MatchNotes.count_word(Backing.RUN_GAMES),
			"finals_week": week - Season.REGULAR_ROUNDS if ph == "finals" else 0}


static func _opponent_name(gs) -> String:
	var opp: Dictionary = gs.my_next_opponent()
	if not opp.is_empty():
		return GameDB.club_name(str(opp["code"]))
	if gs.season.is_regular_done() and not gs.season.is_season_over():
		for m in gs.season.finals_week_matches():
			if str(m["home"]) == gs.my_club:
				return GameDB.club_name(str(m["away"]))
			if str(m["away"]) == gs.my_club:
				return GameDB.club_name(str(m["home"]))
	return "the opposition"


## Your wins in a row this season, from the season's results.
static func _winning_run(gs) -> int:
	var n := 0
	for i in range(gs.season_log.size() - 1, -1, -1):
		var res: Dictionary = gs.season_log[i]
		var side := 0 if str(res.get("home", "")) == gs.my_club else (1 if str(res.get("away", "")) == gs.my_club else -1)
		if side < 0:
			continue
		var score: Array = res.get("score", [0, 0])
		if int(score[side]) <= int(score[1 - side]):
			break
		n += 1
	return n


static func player_facts(gs) -> Array:
	var selected := {}
	var side: Dictionary = gs.current_side()
	for k in side:
		for id in side[k]:
			selected[str(id)] = true
	var info: Dictionary = gs.talk_info(selected)
	var fit := []
	for p in gs.my_list:
		if int(p.get("injury_weeks", 0)) <= 0:
			fit.append(p)
	fit.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var rank := {}
	for i in range(fit.size()):
		rank[str(fit[i]["id"])] = i + 1
	var cap_room: int = gs.salary_cap - gs.my_payroll()
	var out := []
	for p in gs.my_list:
		var id := str(p["id"])
		out.append(player_fact(gs, p, selected.has(id), info.get(id, {}), int(rank.get(id, 99)), cap_room))
	return out


## Everything a card may say or test about one of your players (the names
## match StoryDeck.PLAYER_FACTS). Money and odds come already in words.
static func player_fact(gs, p: Dictionary, selected: bool, i: Dictionary, fit_rank: int, cap_room: int) -> Dictionary:
	var id := str(p["id"])
	var name := GameDB.player_display_name(p)
	var fit := int(p.get("injury_weeks", 0)) <= 0
	var case := ClubLife.talk_case(p, i) if fit else ""
	var kpi := str(i.get("kpi", ""))
	var need_line := "What a %s has to show: %s." % [str(i.get("job", "player")), str(i.get("need", ""))]
	var sore := p.duplicate()
	sore["sore"] = true
	var early := ClubLife.early_price(p)
	var more := ClubLife.early_years(p) - 1
	var t := Trust.value(gs.relations, Trust.player_key(id))
	var ovr := int(p.get("overall", 0))
	var pot := int(p.get("potential", ovr))
	return {"id": id, "name": name, "first": name.split(" ")[0], "age": float(p.get("age", 25.0)),
			"games": gs.games_played(p), "fit": fit, "selected": selected, "overall": ovr, "potential": pot,
			"pot_gap": pot - ovr, "contract_years": int(p.get("contract_years", 2)), "morale": ClubLife.morale(p),
			"trust": t, "trust_band": Trust.band(t),
			"discipline": int((p.get("attr", {}) as Dictionary).get("discipline", 50)),
			"backed": Backing.is_active(p), "fit_rank": fit_rank, "talk_case": case, "kpi": kpi,
			"kpi_or_need": kpi if kpi != "" else need_line,
			"explain_label": "Talk him through his season" if kpi != "" else "Tell him what he has to show",
			"talk_text": ClubLife.talk_text(case, i), "verdict": str(i.get("verdict", "")),
			"job": str(i.get("job", "")), "need": str(i.get("need", "")),
			"sore_odds": ClubLife.odds(Injuries.chance(sore)),
			"ask": Contracts.money(Contracts.asking_salary(p)), "early_price": Contracts.money(early),
			"more_seasons": "%s more season%s" % [MatchNotes.count_word(more), "" if more == 1 else "s"],
			"extension_ok": ClubLife.extension_wanted(p, {}) and early - int(p.get("salary", 0)) <= cap_room,
			# Shown under his real name: no card invents a private life or
			# misconduct for a real person (story research §4).
			"real_named": bool(gs.show_real_names) and str(p.get("real_name", "")).strip_edges() != ""}


## One card from the deck about `p` (or the club), built for this week whether
## or not it would come up: for tests and captures.
static func card_for(gs, tid: String, p: Dictionary = {}) -> Dictionary:
	var deck := StoryDeck.all()
	var t := StoryDeck.by_id(deck, tid)
	if t.is_empty():
		return {}
	var ctx := context(gs) if gs.season != null else {"club": {}, "players": []}
	var subj := {"kind": "club"}
	if not p.is_empty():
		subj = {}
		for f in ctx["players"]:
			if str(f["id"]) == str(p["id"]):
				subj = f
		if subj.is_empty():
			subj = player_fact(gs, p, false, {}, 99, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tid)
	return StoryEngine.build(deck, t, subj, ctx["club"], rng, gs.story_week())


## Apply a choice. Returns the result line: what happened (an effect that
## has something to report speaks first, else the card's own result), then
## what changed in his trust and the board's mood.
static func apply_choice(gs, card: Dictionary, choice: int) -> String:
	var opt: Dictionary = (card.get("options", []) as Array)[choice]
	var pid := str(card.get("player_id", ""))
	var p: Dictionary = gs.list_player(pid) if pid != "" else {}
	if pid != "" and p.is_empty():
		return "The moment has passed: he is no longer at the club."
	var facts: Dictionary = card.get("facts", {})
	var applied := {}
	var said: PackedStringArray = []
	for e in opt.get("effects", []):
		var line := _apply(gs, e, p, facts, applied)
		if line != "":
			said.append(line)
	var out := " ".join(said) if not said.is_empty() else str(opt.get("result", ""))
	if out == "":
		out = "Business as usual."
	return (out + " " + StoryEngine.aftermath(applied)).strip_edges()


static func _targets(gs, e: Dictionary, p: Dictionary) -> Array:
	match str(e.get("who", "subject")):
		"subject":
			return [p] if not p.is_empty() else []
		"others":
			return gs.my_list.filter(func(q): return q != p)
		"side":
			var ids := {}
			var side: Dictionary = gs.current_side()
			for k in side:
				for id in side[k]:
					ids[str(id)] = true
			return gs.my_list.filter(func(q): return ids.has(str(q["id"])))
	return gs.my_list


static func _apply(gs, e: Dictionary, p: Dictionary, facts: Dictionary, applied: Dictionary) -> String:
	var d := StoryEngine.effect_d(e, facts)
	var name := str(facts.get("name", ""))
	match str(e.get("op", "")):
		"morale":
			for q in _targets(gs, e, p):
				ClubLife.add_morale(q, d)
			applied["morale"] = int(applied.get("morale", 0)) + d
		"xp":
			for q in _targets(gs, e, p):
				q["xp"] = int(q.get("xp", 0)) + d
			if str(e.get("who", "subject")) == "subject":
				gs.apply_plan_to(p)
			else:
				gs.apply_train_plans()
		"board":
			if not gs.board.is_empty():
				gs.board["confidence"] = clampi(gs.board_confidence() + d, 0, 100)
			applied["board"] = int(applied.get("board", 0)) + d
		"trust":
			var when := "Round %d" % int(facts.get("round", 0)) if int(facts.get("finals_week", 0)) == 0 else "Finals"
			applied["trust"] = int(applied.get("trust", 0)) + Trust.change(gs.relations, Trust.player_key(str(p["id"])),
					d, StoryEngine.fill(str(e.get("why", "")), facts), int(gs.season_year), when)
		"rest":
			p["rested"] = true
		"sore":
			if int(p.get("injury_weeks", 0)) > 0:
				return "%s has since been ruled out anyway." % name
			p["sore"] = true
		"fresh", "heavy_legs":
			for q in _targets(gs, e, p):
				q[str(e["op"])] = true
		"expects_game":
			p["expects_game"] = int(e.get("sting", 12))
			return ("%s feels heard. Auto-pick names him this week." if gs.my_selection().is_empty()
					else "%s feels heard, and expects a game this week.") % name
		"start_backing":
			# His chance: a run of senior games (Backing). Leaving him out
			# while fit breaks the promise, and that stings.
			gs._start_backing(p)
			var run := MatchNotes.count_word(Backing.RUN_GAMES)
			return ("%s is told he has a run of %s games. Auto-pick names him this week." if gs.my_selection().is_empty()
					else "%s is told he has a run of %s games. Pick him this week.") % [name, run]
		"extend_early":
			return _extend(gs, p, name)
		"promise_win":
			gs.board["promise"] = true
		"explain":
			return gs._explain_outcome(name, facts)
		"talk_note":
			gs._note_talk(p, str(e.get("said", "")), str(facts.get("talk_case", "")))
	return ""


static func _extend(gs, p: Dictionary, name: String) -> String:
	var cost := ClubLife.early_price(p)
	var years := ClubLife.early_years(p)
	if int(p.get("contract_years", 1)) > 1:
		return "%s is already signed beyond this season." % name
	if gs.my_payroll() - int(p.get("salary", 0)) + cost > gs.salary_cap:
		# The cap moved since the card was drawn: nobody's fault.
		return "The cap no longer has room to extend %s now; it waits for the off-season." % name
	p["salary"] = cost
	p["contract_years"] = years
	ClubLife.add_morale(p, 8)
	return "%s signs on for %d more season%s at %s a season." % [name, years - 1,
			"" if years == 2 else "s", Contracts.money(cost)]
