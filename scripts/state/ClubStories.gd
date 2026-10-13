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


## This week's cards. In the finals, only while you are still in it: playing,
## or on the week off a qualifying final or a top-six finish earns.
static func pick(gs) -> Array:
	if phase(gs) == "finals" and (gs.season.is_season_over() or not ["alive", "bye"].has(gs.my_finals_status())):
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
	var facts := {"club": GameDB.club_name(gs.my_club), "opp": _opponent_name(gs), "round": week,
			"year": int(gs.season_year), "losing_run": int(gs.losing_streak), "winning_run": _winning_run(gs),
			"ladder": gs.my_position(), "board": gs.board_confidence(), "fit_count": fit,
			"run_games": MatchNotes.count_word(Backing.RUN_GAMES),
			"finals_week": week - Season.REGULAR_ROUNDS if ph == "finals" else 0}
	facts.merge(_leader_facts(gs), true)
	facts.merge(_finals_facts(gs, ph), true)
	return facts


## Where you stand in September (and on the ten before it).
static func _finals_facts(gs, ph: String) -> Dictionary:
	var out := {"finals_math": "", "finals_bye": false, "lost_last_final": false, "gf_run": 0,
			"gf_run_word": "", "gf_again": "", "rival": false}
	if ph == "regular":
		out["finals_math"] = gs.season.finals_math(gs.my_club)
		return out
	out["finals_bye"] = gs.my_finals_status() == "bye"
	var slots: Dictionary = gs.season.finals.get("slots", {})
	out["lost_last_final"] = str(slots.get("L_QF1", "")) == gs.my_club or str(slots.get("L_QF2", "")) == gs.my_club
	if int(gs.season.finals.get("week", 0)) == 5:
		out.merge(_grand_final_story(gs), true)
	return out


## The Grand Final against this opponent: how many in a row (this one included),
## what happened in last year's if it was them too, and whether they are a
## long-standing rival. From the honour roll this save holds, nothing older.
static func _grand_final_story(gs) -> Dictionary:
	var opp := ""
	for m in gs.season.finals_week_matches():
		if str(m["home"]) == gs.my_club:
			opp = str(m["away"])
		elif str(m["away"]) == gs.my_club:
			opp = str(m["home"])
	if opp == "":
		return {}
	var run := 1
	var again := ""
	var year := int(gs.season_year) - 1
	for i in range(gs.honour_roll.size() - 1, -1, -1):
		var h: Dictionary = gs.honour_roll[i]
		if int(h.get("year", 0)) != year:
			break
		var pair := [str(h.get("premier", "")), str(h.get("runner_up", ""))]
		if not (pair.has(gs.my_club) and pair.has(opp)):
			break
		if run == 1:
			again = "won" if pair[0] == gs.my_club else "lost"
		run += 1
		year -= 1
	var words := {2: "second", 3: "third", 4: "fourth", 5: "fifth", 6: "sixth", 7: "seventh", 8: "eighth", 9: "ninth", 10: "tenth"}
	return {"gf_run": run, "gf_run_word": str(words.get(run, "%dth" % run)), "gf_again": again,
			"rival": not Rivalries.established(gs.my_club, opp).is_empty()}


## Your captain, your best-rated vice-captain, and the young player a captain
## would put forward (fewer than ten senior games, not in the side, the most
## potential): names and ids for the captain's cards.
static func _leader_facts(gs) -> Dictionary:
	var rec: Dictionary = gs.captaincy_record(gs.my_club)
	var cap := {}
	var vice := {}
	for p in gs.my_list:
		var role := Captaincy.role_of(rec, str(p["id"]))
		if role == "captain" and cap.is_empty():
			cap = p
		elif role == "vice" and (vice.is_empty() or Leadership.of(p) > Leadership.of(vice)):
			vice = p
	var in_side := {}
	var side: Dictionary = gs.current_side()
	for k in side:
		for id in side[k]:
			in_side[str(id)] = true
	var kid := {}
	for p in gs.my_list:
		if in_side.has(str(p["id"])) or gs.games_played(p) >= 10 or float(p.get("age", 30.0)) > 21.0:
			continue
		if kid.is_empty() or int(p.get("potential", p.get("overall", 0))) > int(kid.get("potential", kid.get("overall", 0))):
			kid = p
	return {"captain_name": GameDB.player_display_name(cap) if not cap.is_empty() else "",
			"vice_name": GameDB.player_display_name(vice) if not vice.is_empty() else "",
			"vice_id": str(vice.get("id", "")), "has_vice": not vice.is_empty(),
			"kid_name": GameDB.player_display_name(kid) if not kid.is_empty() else "",
			"kid_id": str(kid.get("id", "")), "has_kid": not kid.is_empty()}


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
	# By rating on the whole list, the injured included (ties by id, so the same list ranks the same way).
	var everyone: Array = gs.my_list.duplicate()
	everyone.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]) 			or (int(a["overall"]) == int(b["overall"]) and str(a["id"]) < str(b["id"])))
	var all_rank := {}
	for i in range(everyone.size()):
		all_rank[str(everyone[i]["id"])] = i + 1
	var out := []
	for p in gs.my_list:
		var id := str(p["id"])
		out.append(player_fact(gs, p, selected.has(id), info.get(id, {}), int(rank.get(id, 99)), cap_room,
				int(all_rank.get(id, 99))))
	return out


## Everything a card may say or test about one of your players (the names
## match StoryDeck.PLAYER_FACTS). Money and odds come already in words.
static func player_fact(gs, p: Dictionary, selected: bool, i: Dictionary, fit_rank: int, cap_room: int, all_rank := 99) -> Dictionary:
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
	var lead := Leadership.of(p)
	var band := Trust.band(t)
	var holds: bool = lead >= StoryDeck.HOLDS_AT or (lead >= StoryDeck.HOLDS_WITH_TRUST and (band == "trusts" or band == "close"))
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
			"real_named": bool(gs.show_real_names) and str(p.get("real_name", "")).strip_edges() != "",
			# A dispute left to the captain: held when his Leadership is high enough, or
			# fairly high and he trusts you (the rule is printed on the choice).
			"leadership": lead, "captain": Captaincy.role_of(gs.captaincy_record(gs.my_club), id) == "captain",
			"delegate_holds": holds, "holds_at": StoryDeck.HOLDS_AT, "holds_trust_at": StoryDeck.HOLDS_WITH_TRUST,
			"last_season": _last_season(gs, p), "finals_games": int(p.get("finals_games", 0)),
			"save_debut": gs.save_saw_every_game(p), "debut_year": _debut_year(gs, p),
			"milestone_next": _milestone_next(gs, p), "injured_weeks": int(p.get("injury_weeks", 0)),
			"rushable": int(p.get("injury_weeks", 0)) > 0 and str(p.get("injury_kind", "")) != "concussion",
			"overall_rank": all_rank, "told_players": gs.story_flag_set(id, "farewell_told")}


## The ageing rule retires him at this rollover (Retirement.intends, read-only: the
## coach can still talk him round at the rollover, so a card only says "could be").
static func _last_season(gs, p: Dictionary) -> bool:
	if int(p.get("play_on", 0)) == int(gs.season_year) + 1:
		return false
	return Retirement.intends(p, int(gs.season_year) + 1)


## His first season of senior football: no game before this year, one or more in it,
## and a career this save has seen in full.
static func _debut_year(gs, p: Dictionary) -> bool:
	var this_year: int = gs.season_games(str(p["id"]))
	return Career.complete(p) and this_year >= 1 and gs.games_played(p) - this_year == 0


## The milestone his next game is, from the banner rule (GameState.milestone_notes);
## 0 when it is not a game worth a banner.
static func _milestone_next(gs, p: Dictionary) -> int:
	if not Career.complete(p):
		return 0
	var next: int = gs.games_played(p) + 1
	return next if [100, 150, 200, 250, 300, 350].has(next) else 0


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
	var facts: Dictionary = (card.get("facts", {}) as Dictionary).duplicate()
	facts["_tid"] = str(card.get("tid", ""))
	var applied := {}
	var said: PackedStringArray = []
	for e in opt.get("effects", []):
		var line := _apply(gs, e, p, facts, applied)
		if line != "":
			said.append(line)
	var out := " ".join(said) if not said.is_empty() else str(opt.get("result", ""))
	out = StoryEngine.fill_ranked(out, running_fitness(gs))
	if out == "":
		out = "Business as usual."
	return (out + " " + StoryEngine.aftermath(applied)).strip_edges()


## Your players who could run a time trial, fittest first. The rating is the
## one the match uses for running fitness: durability sets how fast a player
## tires on the ground and how he recovers between games. An injured player
## sits it out; ties go to the name, so the same list gives the same answer.
static func running_fitness(gs) -> Array:
	var rows := []
	for p in gs.my_list:
		if int(p.get("injury_weeks", 0)) > 0:
			continue
		rows.append({"id": str(p["id"]), "name": GameDB.player_display_name(p),
				"v": int((p.get("attr", {}) as Dictionary).get("durability", 0))})
	rows.sort_custom(func(a, b): return int(a["v"]) > int(b["v"]) or (int(a["v"]) == int(b["v"]) and str(a["id"]) < str(b["id"])))
	return rows


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
		"slow_start":
			# A small chance, rolled once for the whole group (or the one player), from the
			# save's seed: the same save answers the same way. Never announced; it shows on the day.
			var hit := StoryEngine.risk_hit(int(gs.season.seed), int(facts.get("year", 0)), int(facts.get("round", 0)),
					"%s|slow|%s|%s" % [facts.get("_tid", ""), e.get("who", "subject"), name], int(e.get("chance", 0)))
			if hit:
				for q in _targets(gs, e, p):
					q["slow_start"] = true
		"loss_sting":
			# Waits for the result (GameState._settle_loss_sting).
			for q in _targets(gs, e, p):
				q["loss_sting"] = [int(e.get("chance", 0)), int(e.get("d", 0))]
		"news":
			gs.add_news("retirement", StoryEngine.fill(str(e.get("text", "")), facts))
		"rush_back":
			if str(p.get("injury_kind", "")) == "concussion":
				return "%s stays out: a concussion keeps him out under the protocols." % name
			p["injury_weeks"] = 0
			p.erase("injury_kind")
			p["sore"] = true
			return "%s is cleared to play. Name him in the side." % name
		"sore":
			if int(p.get("injury_weeks", 0)) > 0:
				return "%s has since been ruled out anyway." % name
			p["sore"] = true
		"fresh", "heavy_legs":
			for q in _targets(gs, e, p):
				q[str(e["op"])] = true
		"expects_game":
			p["expects_game"] = int(e.get("sting", 12))
			return ("%s feels heard. He's in the side this week." if gs.my_selection().is_empty()
					else "%s feels heard, and expects a game this week.") % name
		"start_backing":
			# His chance: a run of senior games (Backing). Leaving him out
			# while fit breaks the promise, and that stings.
			gs._start_backing(p)
			var run := MatchNotes.count_word(Backing.RUN_GAMES)
			return ("%s is told he has a run of %s games. He's in the side this week." if gs.my_selection().is_empty()
					else "%s is told he has a run of %s games. Pick him this week.") % [name, run]
		"extend_early":
			return _extend(gs, p, name)
		"promise_win":
			gs.board["promise"] = true
		"explain":
			return gs._explain_outcome(name, facts)
		"talk_note":
			gs._note_talk(p, str(e.get("said", "")), str(facts.get("talk_case", "")))
		"delegate":
			# Left to the captain: his Leadership and his trust in you decide, by the
			# rule the choice printed. No dice.
			var held := bool(facts.get("delegate_holds", false))
			var parts: PackedStringArray = []
			for ne in (e.get("held" if held else "failed", []) as Array):
				var said_line := _apply(gs, ne, p, facts, applied)
				if said_line != "":
					parts.append(said_line)
			var res := StoryEngine.fill(str(e.get("held_result" if held else "failed_result", "")), facts)
			return (res + " " + " ".join(parts)).strip_edges()
		"back_kid":
			var kid: Dictionary = gs.list_player(str(facts.get("kid_id", "")))
			if kid.is_empty():
				return "%s is no longer at the club." % str(facts.get("kid_name", "He"))
			gs._start_backing(kid)
			return "%s is told he has a run of %s games. Pick him this week." % [str(facts.get("kid_name", "")),
					MatchNotes.count_word(Backing.RUN_GAMES)]
		"captaincy_swap":
			var vice: Dictionary = gs.list_player(str(facts.get("vice_id", "")))
			if vice.is_empty() or p.is_empty():
				return "The captaincy stays as it is."
			# The card may be older than the captaincy: if you have changed it since, do nothing.
			var now: Dictionary = gs.captaincy_record(gs.my_club)
			if Captaincy.role_of(now, str(p["id"])) != "captain" or Captaincy.role_of(now, str(vice["id"])) != "vice":
				return "The captaincy has changed since this came up, so nothing changes."
			var slots := [{"id": str(vice["id"]), "role": "captain"}, {"id": str(p["id"]), "role": "vice"}]
			for s in Captaincy.slots(gs.captaincy_record(gs.my_club)):
				var sid := str((s as Dictionary)["id"])
				if sid != str(vice["id"]) and sid != str(p["id"]) and slots.size() < Captaincy.MAX_LEADERS:
					slots.append(s)
			var pv: Dictionary = gs.set_captaincy(slots)
			if not bool(pv.get("ok", false)):
				return str(pv.get("why_not", "The captaincy can't change this week."))
			return "%s takes the armband. %s hands it over and stays in the leadership group." % [str(facts.get("vice_name", "")), name]
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
