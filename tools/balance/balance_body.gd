extends RefCounted
## Body of tools/balance/balance_worker.gd (loaded after autoloads are ready).
## Seed i: two real 2026 club lists picked from i, home side alternating, match
## seed 500000 + i. One JSON line per match: score, margin and every team stat,
## plus each side's list strength (Squad.strength), score at each quarter's end (q_score)
## and the shot counts (_shot_counts).
## `sets` puts values on each MatchSim's own vars (--set name=value,...) to
## screen a tuning knob without editing the sim; a name the sim lacks fails.
## `echo` also prints each line as "BAL <json>" (tools/audit/balance_match_impl.gd).
## `start` "real" (--start real, row 65 follow-up): the lists are the 2027 round-1 lists of a
## real-lists career instead (GameState.begin_real_lists, the 2026 National Draft run with
## every club picking as the AI does, career and replay seed 2026), so the real 2026 class
## plays where it is picked; each team line then also carries "draftees", the 2026
## draftees in its 23.
## `--plan-know F` (row 126): both sides know every plan but Balanced at fluency F
## (PreSeason: 0 low, 1 medium, 2 high, 1.5 half way from medium to high), as a career's
## record would give them. Without it a squad knows every plan fully.
## `setup` (--setup, fatigue parity): "" plays both sides as before (no coaching table);
## "league" plays both as a career's background match does (Season.match_sim: rival coaches
## pick their plans, every club rotates on a Steady season plan); "coached" makes one side
## your club as a coached match you skip through (side i % 2, so home and away each get it
## half the time): its assistant takes the calls, moments take their default answer, and
## both sides' rotations are set before every quarter as MatchScene sets them.
## Every team line carries its legs: "legs_q" mean energy of the 18 on the ground and
## "tank_q" how many of them are under TANK, at the end of each quarter, "interchanges",
## "exertion" (MatchSim.exertion summed over the side), and "coached".
## `tag` (--tag, row 120): side i % 2 tags the rival's biggest midfielder from the first bounce
## with the man `tag` names on tag_order: "first" (the tightest hold), "median", "last" (the
## loosest), "tagger" (first on the list, only if he is a Tagger) or "none" (no tag, the paired
## baseline: same man followed). The match line then carries "tag" (_tag_record).

var start := ""
var setup := ""
var tag := ""
## Energy under which a player on the ground is running on empty (fit 0.90 or less).
const TANK := 40.0
## --arrivals league: how many new-club men and draftees a selected side carries in
## Rounds 1-6, as weights for 0, 1, 2 .. men, measured over seeded careers by
## tools/audit/familiarity_impl.gd (TeamFamiliarity, row 125).
## Computer clubs, seeds 301-303 over four counted seasons; draftees leave out an
## expansion club's foundation year (14 or more).
const LEAGUE_NEW_CLUB := [378.0, 373.0, 262.0, 125.0, 59.0, 39.0, 42.0, 5.0, 3.0, 9.0, 1.0]
const LEAGUE_DRAFTEES := [279.0, 595.0, 318.0, 76.0, 7.0, 3.0]


func play(from: int, count: int, out: String, weather: String,
		sets: Dictionary = {}, echo := false) -> int:
	GameDB.skip_ovr_overrides = true
	GameDB.reload()
	# --tune KEY=V,KEY=V: MatchSim tunables (MatchSim.tune, read through _tv) for
	# sizing a constant before it is written into the code.
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if str(args[i]) == "--tune":
			for kv in str(args[i + 1]).split(",", false):
				var pair := kv.split("=")
				if pair.size() == 2:
					MatchSim.tune[pair[0].strip_edges()] = float(pair[1])
	# --arrivals: put team familiarity in the match (see _arrivals). Off, the lists
	# are as they start a career: nobody is an arrival.
	var arrivals := ""
	for i in range(args.size() - 1):
		if str(args[i]) == "--arrivals":
			arrivals = str(args[i + 1])
	# --together BAND: one side a match (in turn: side i % 2) plays with that
	# Togetherness band's stoppage edge (row 84), the other at mid.
	var together := ""
	for i in range(args.size() - 1):
		if str(args[i]) == "--together":
			together = str(args[i + 1])
	var plan_know := -1.0
	for i in range(args.size() - 1):
		if str(args[i]) == "--plan-know":
			plan_know = float(args[i + 1])
	# --year Y (legacy, row 142 L5): every match is played in season Y, so it
	# plays that era's football (EraFootball). The lists stay the real 2026 ones:
	# each season's players are rated against their own season, so the era's
	# level of the game is the era row's alone.
	var year := 0
	for i in range(args.size() - 1):
		if str(args[i]) == "--year":
			year = int(args[i + 1])
	var lists := {}
	var class_ids := {}
	if start == "real":
		lists = real_start_lists()
		for q in GameDB.draftees:
			class_ids[str(q["id"])] = true
	var codes: Array = GameDB.active_clubs(2026).duplicate()
	# --lists generated: every club's list is generated players instead (row 104).
	for i in range(args.size() - 1):
		if str(args[i]) == "--lists" and str(args[i + 1]) == "generated":
			lists = generated_lists(codes)
	var pairs := []
	for a in range(codes.size()):
		for b in range(a + 1, codes.size()):
			pairs.append([codes[a], codes[b]])
	var fh := FileAccess.open(out, FileAccess.WRITE)
	if fh == null:
		push_error("balance: cannot write " + out)
		return 1
	for i in range(from, from + count):
		var p: Array = pairs[i % pairs.size()]
		var flip := (i / pairs.size()) % 2 == 1
		var h := str(p[1] if flip else p[0])
		var a := str(p[0] if flip else p[1])
		# Every match is staged as a Gather Round match (at the host ground, a
		# club's home edge only at its own ground), the per-match effect of the
		# one round a season it applies to.
		var ground: Callable = func(c): return str(GameDB.club(str(c)).get("ground", ""))
		var v := str(GatherRound.venues_for([{"home": h, "away": a}], 500000 + i, ground)[0])
		var at_home := [ground.call(h) == v, ground.call(a) == v]
		var sq_h := Squad.new(h, lists.get(h, GameDB.club_list(h)), bool(at_home[0]), h)
		var sq_a := Squad.new(a, lists.get(a, GameDB.club_list(a)), bool(at_home[1]), a)
		if plan_know >= 0.0:
			for sq in [sq_h, sq_a]:
				for plan in PreSeason.DRILL_PLANS:
					(sq as Squad).plan_know[str(plan)] = PreSeason.familiar_mult(plan_know)
		var coached := i % 2 if setup == "coached" else -1
		if setup == "league" or setup == "coached":
			for side in range(2):
				var sq: Squad = sq_h if side == 0 else sq_a
				sq.ai_plans = side != coached
				sq.assistant = side == coached
		var fam := _arrivals(arrivals, i, sq_h, sq_a)
		if together != "":
			(sq_h if i % 2 == 0 else sq_a).together = Culture.effect_of("match_contest", "together", together)
		# --coach S,P (row 119): side i%2 is coached by archetypes S and P
		# (Archetypes ids, "-" for none); --side-plan X makes it play plan X;
		# --custom-plan S,C makes it play its own plan of strength S and cost C
		# (CustomPlan ids).
		var cside: Squad = sq_h if i % 2 == 0 else sq_a
		var side_plan := ""
		for ci in range(args.size() - 1):
			if str(args[ci]) == "--coach":
				var ids := str(args[ci + 1]).split(",")
				cside.arch = Archetypes.levers(ids[0], ids[1] if ids.size() > 1 else "")
				cside.tactics_exec *= float(cside.arch.get("exec", 1.0))
			elif str(args[ci]) == "--side-plan":
				side_plan = str(args[ci + 1])
			elif str(args[ci]) == "--custom-plan":
				var sc := str(args[ci + 1]).split(",")
				var plan := {"name": "", "s": sc[0], "c": sc[1] if sc.size() > 1 else ""}
				if not CustomPlan.ready(plan):
					push_error("balance: --custom-plan S,C: a strength (%s) and a cost (%s) on different levers"
							% [", ".join(CustomPlan.STRENGTH_IDS), ", ".join(CustomPlan.COST_IDS)])
					return 2
				cside.custom_plan = CustomPlan.clean(plan)
				side_plan = CustomPlan.KEY
		if side_plan != "":
			cside.ai_plans = false
		var sim := MatchSim.new(sq_h, sq_a, 500000 + i)
		# --weather league (row 160): each match's weather as a season gives it,
		# from the ground it is staged at and a regular-season month (i % 6), with
		# the day's turn at a break; --no-turn keeps the start all match, for
		# pairing the turn's own effect. Any other --weather holds all match.
		if weather == "league":
			var wkey := hash([500000 + i, "weather"])
			var wstart := Weather.condition(v, i % 6, wkey, str(GameDB.club(h).get("state", "")))
			sim.set_day({"weather": wstart, "chance": Weather.turn_chance(wstart, v),
					"turn": {} if args.has("--no-turn") else Weather.turn(wstart, v, wkey)})
		else:
			sim.weather = weather
		sim.season_year = year
		if side_plan != "":
			(sim.tactics[i % 2] as Dictionary)["gameplan"] = side_plan
		if setup == "league":
			sim.season_plans = ["steady", "steady"]
		elif setup == "coached":
			sim.moment_side = coached
		var tag_rec := _set_tag(sim, i % 2) if tag != "" else {}
		var through_rec := {}
		for ci in range(args.size() - 1):
			if str(args[ci]) == "--through":
				through_rec = _set_through(sim, i % 2, str(args[ci + 1]))
		for k in sets:
			if not str(k) in sim:
				push_error("balance: MatchSim has no var " + str(k))
				return 1
			sim.set(str(k), float(sets[k]))
		# MatchSim.run(), a quarter at a time, reading each side's legs at the siren.
		var legs := [[], []]
		var tank := [[], []]
		while sim.current_quarter <= 4:
			if coached >= 0:
				# MatchScene._apply_quarter_tactics: the assistant sets your rotations,
				# the rival coach its plan and rotations.
				sim.set_rotation_policy(coached, sim.auto_rotation(coached, "steady"))
				sim.set_tactics(1 - coached, sim.ai_tactics(1 - coached))
				sim.set_rotation_policy(1 - coached, sim.auto_rotation(1 - coached, "steady"))
			sim.run_quarter()
			for side in range(2):
				var e := _legs(sim, side)
				legs[side].append(e[0])
				tank[side].append(e[1])
		if sim.needs_extra_time():
			sim.run_extra_time()
		var r: Dictionary = sim.result()
		# Each side's score at the end of each quarter (for comebacks), from the
		# running score every event carries.
		var q_score := [[0, 0, 0, 0], [0, 0, 0, 0]]
		for ev in r["events"]:
			var sc = (ev as Dictionary).get("score", null)
			var q := int((ev as Dictionary).get("q", 0))
			if sc is Array and (sc as Array).size() == 2 and q >= 1:
				for k in range(clampi(q, 1, 4) - 1, 4):
					q_score[0][k] = int(sc[0])
					q_score[1][k] = int(sc[1])
		# Stoppages in play (row 120), counted from the event log, match totals on
		# both team lines (not StatBook keys, which are saved and append-only):
		# ball-ups where play locked up and boundary throw-ins. Centre bounces are
		# the team key "centre_bounces".
		var ball_ups := 0
		var throw_ins := 0
		# Marks inside 50 (row 61), each side's, from the event log too: a mark
		# (or a lead mark played on to) taken inside that side's forward 50, and
		# a forward's mark in the goal-square pack.
		var mi50 := [0, 0]
		var f50 := float(Ratings.T["forward50_line"])
		for ev in r["events"]:
			var kind := str((ev as Dictionary).get("kind", ""))
			if kind == "ballup":
				ball_ups += 1
			elif kind == "throwin":
				throw_ins += 1
			elif kind == "mark" or kind == "receive" or (kind == "pack" and str(ev.get("outcome", "")) == "marked"):
				var s := int(ev.get("side", 0))
				if float(ev.get("fp", 0.0)) * (1.0 if s == 0 else -1.0) >= f50:
					mi50[s] += 1
		var teams := []
		var rosters: Array = sim.rosters()
		var stats: Dictionary = r["players"]
		var srcs := type_sources(sim, r)
		for side in range(2):
			var t: Dictionary = (r["team"][side] as Dictionary).duplicate()
			t["score"] = int(r["score"][side])
			t["ball_ups"] = ball_ups
			t["throw_ins"] = throw_ins
			t["stoppages"] = ball_ups + throw_ins
			t["marks_inside_50"] = mi50[side]
			_shot_counts(t, sim.shot_log, side)
			t["strength"] = snappedf((sq_h if side == 0 else sq_a).strength(), 0.01)
			q_score[side][3] = int(r["score"][side])
			t["q_score"] = q_score[side]
			t["roles"] = role_lines(rosters[side], r["players"])
			t["types"] = type_lines(rosters[side], r["players"])
			t["type_src"] = srcs[side]
			t["carry_zone"] = (sim.carry_log[side] as Dictionary).duplicate()
			if "rebound_log" in sim:
				t["reb_route"] = (sim.rebound_log[side] as Dictionary).duplicate()
			t["legs_q"] = legs[side]
			t["tank_q"] = tank[side]
			t["interchanges"] = int(sim.interchanges[side])
			t["coached"] = side == coached
			var ex := 0.0
			for pl in (r["roster"][side] as Array):
				ex += float((r["exertion"] as Dictionary).get(str(pl["id"]), 0.0))
			t["exertion"] = snappedf(ex, 0.1)
			t["spoil_zone"] = (sim.spoil_log[side] as Dictionary).duplicate()
			if not class_ids.is_empty():
				var sq: Squad = sq_h if side == 0 else sq_a
				var n_new := 0
				for pl in sq.ground + sq.bench:
					n_new += 1 if class_ids.has(str(pl["id"])) else 0
				t["draftees"] = n_new
			# Intercepts by each man's listed position (DEF, MID, FWD, RUCK), as
			# tools/audit/intercept_impl.gd counts them: "ic_MID" intercepts and
			# "pg_MID" player-games (every man who played and has a stat line).
			for pl in (r["roster"][side] as Array):
				var st: Dictionary = stats.get(str(pl["id"]), {})
				if st.is_empty():
					continue
				var role := str(pl.get("list_role", pl.get("role", "")))
				t["ic_" + role] = float(t.get("ic_" + role, 0.0)) + float(st.get("intercepts", 0.0))
				t["pg_" + role] = int(t.get("pg_" + role, 0)) + 1
				t["sp_" + role] = float(t.get("sp_" + role, 0.0)) + float(st.get("spoils", 0.0))
				# Each man's tackles and pressure acts, for the per-player spread
				# (balance_report.py tackle_section): [tackles, pressure acts, list_role].
				var tp: Dictionary = t.get("tp", {})
				tp[str(pl["id"])] = [int(st.get("tackles", 0)), int(st.get("pressure_acts", 0)), role]
				t["tp"] = tp
			t["club"] = h if side == 0 else a
			if together != "":
				t["together"] = float((sq_h if side == 0 else sq_a).together)
				t["together_pts"] = snappedf(float((sim.impact[side] as Dictionary).get("together", 0.0)), 0.01)
			if arrivals != "":
				t["arrivals"] = TeamFamiliarity.new_club_men((sq_h if side == 0 else sq_a).ground + (sq_h if side == 0 else sq_a).bench).size()
				t["fam_round"] = int(fam["round"])
				t["fam_carry"] = int(fam["carry"]) == side
				t["team_cut"] = snappedf(float(sim.team_fam_cut[side]), 0.0001)
			t["ruck1"] = ruck1(r["roster"][side], stats, sq_h if side == 0 else sq_a)
			teams.append(t)
		for pl in fam["men"]:
			TeamFamiliarity.clear(pl)   # GameDB's lists are shared by every match
		var row := {"i": i, "home": h, "away": a, "teams": teams, "duels": duels(sim, r)}
		if weather == "league":
			row["wx"] = {"start": sim.weather_start if sim.weather_turned_after > 0 else sim.weather,
					"end": sim.weather, "after": sim.weather_turned_after, "chance": sim.weather_odds}
		if tag != "":
			row["tag"] = _tag_record(tag_rec, r)
		if not through_rec.is_empty():
			for slot in through_rec:
				var st: Dictionary = (r["players"] as Dictionary).get(str(through_rec[slot]), {})
				through_rec[slot] = {"id": through_rec[slot], "disposals": int(st.get("disposals", 0)),
						"goals": int(st.get("goals", 0))}
			row["through"] = through_rec
		var line := JSON.stringify(row)
		fh.store_line(line)
		if echo:
			print("BAL " + line)
	fh.close()
	return 0


## Set team familiarity on the two sides before kick-off, seeded by the match so
## both arms of a paired run mark the same men. The spec is "" (nobody), "N" (one
## side, in turn, carries N new-club men, at each of Rounds 1-6 in turn: the
## isolated measure), "N@R" (the same, always at round R) or "league" (both sides
## carry what careers measure). Returns {round, carry (side, -1 none), men}.
func _arrivals(spec: String, i: int, sq_h: Squad, sq_a: Squad) -> Dictionary:
	var out := {"round": 0, "carry": -1, "men": []}
	if spec == "":
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + i
	out["round"] = (i / 2) % 6 + 1
	var plan := [[0, 0], [0, 0]]
	if spec == "league":
		for side in range(2):
			plan[side] = [_weighted(rng, LEAGUE_NEW_CLUB), _weighted(rng, LEAGUE_DRAFTEES)]
	else:
		var parts := spec.split("@")
		if parts.size() > 1:
			out["round"] = int(parts[1])
		out["carry"] = i % 2
		plan[i % 2] = [int(parts[0]), 0]
	var fam := TeamFamiliarity.ROUND_ONE + TeamFamiliarity.SENIOR_GAME * (int(out["round"]) - 1)
	for side in range(2):
		var sq: Squad = sq_h if side == 0 else sq_a
		var men: Array = sq.ground + sq.bench
		for k in range(men.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var swap: Variant = men[k]
			men[k] = men[j]
			men[j] = swap
		var at := 0
		for n in range(mini(int(plan[side][0]), men.size())):
			TeamFamiliarity.arrive_club(men[at])
			men[at]["team_fam"] = fam
			out["men"].append(men[at])
			at += 1
		for n in range(mini(int(plan[side][1]), men.size() - at)):
			TeamFamiliarity.arrive_draftee(men[at])
			men[at]["team_fam"] = fam
			out["men"].append(men[at])
			at += 1
	return out


func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := rng.randf() * total
	for k in range(weights.size()):
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return weights.size() - 1


## Puts this arm's tag on, before the first bounce, for side `side`: {side, target, tagger,
## specialist, has_tagger, set, keep, keeps (what his man keeps on each midfielder's fresh legs,
## tag_order's order)}. The target is the rival's biggest midfielder by what he adds to the midfield
## (MatchSim.tag_give_up), the same man in every arm. "set" is false when this arm plays no tag
## (none, or tagger with no Tagger on the ground).
## --through mid|fwd|def|all (director bug 2026-11-12, play-through on the
## ground): side i % 2 plays through its highest-rated man in that call's line
## (focus_mid, focus_fwd, focus_def; "all" makes all three calls) from the first
## bounce, its plan unchanged. Returns {slot: id}; the match line carries each
## man's disposals and goals under "through".
func _set_through(sim: MatchSim, side: int, which: String) -> Dictionary:
	var slots := MatchSim.FOCUS_SLOTS if which == "all" else ["focus_" + which]
	var t: Dictionary = (sim.tactics[side] as Dictionary).duplicate()
	var out := {}
	for slot in slots:
		if not MatchSim.FOCUS_SLOT_ROLES.has(slot):
			push_error("balance: --through is mid, fwd, def or all")
			return {}
		var best := {}
		for p in (sim.squads[side] as Squad).ground:
			if (MatchSim.FOCUS_SLOT_ROLES[slot] as Array).has(str(p["role"])) and not out.values().has(str(p["id"])) 					and (best.is_empty() or int(p["overall"]) > int(best["overall"])):
				best = p
		if not best.is_empty():
			t[slot] = str(best["id"])
			out[slot] = str(best["id"])
	sim.set_tactics(side, t)
	return out


func _set_tag(sim: MatchSim, side: int) -> Dictionary:
	var theirs: Array = (sim.squads[1 - side] as Squad).ground
	var target := {}
	var most := -1.0
	for p in theirs:
		if MatchSim.taggable(p) and MatchSim.tag_give_up(p, theirs) > most:
			most = MatchSim.tag_give_up(p, theirs)
			target = p
	var order := MatchSim.tag_order((sim.squads[side] as Squad).ground)
	var keeps := []
	var has_tagger := false
	for p in order:
		keeps.append(snappedf(Roles.tag_keep(p, 100.0), 0.001))
		has_tagger = has_tagger or Roles.is_tagger(p)
	var who := {}
	if not order.is_empty():
		match tag:
			"first": who = order[0]
			"median": who = order[order.size() / 2]
			"last": who = order[order.size() - 1]
			"tagger": who = order[0] if Roles.is_tagger(order[0]) else {}
	var rec := {"side": side, "target": str(target.get("id", "")), "tagger": str(who.get("id", "")),
			"specialist": Roles.is_tagger(who) if not who.is_empty() else false,
			"has_tagger": has_tagger, "set": false, "keeps": keeps}
	if not target.is_empty() and not who.is_empty():
		sim.set_tactics(side, {"gameplan": "balanced", "tag_id": rec["target"], "tagger_id": rec["tagger"], "tag_set": true})
		rec["set"] = true
		rec["keep"] = snappedf(sim._tag_share(side), 0.001)
	return rec


## The tag's outcome: the tagged man's and the tagger's lines and the tagging side's margin.
func _tag_record(rec: Dictionary, r: Dictionary) -> Dictionary:
	var out := rec.duplicate()
	var stats: Dictionary = r["players"]
	var line := func(id: String) -> Dictionary:
		var st: Dictionary = stats.get(id, {})
		return {"di": int(st.get("disposals", 0)), "g": int(st.get("goals", 0)),
				"cl": int(st.get("clearances", 0)), "cp": int(st.get("contested_possessions", st.get("contested", 0)))}
	out["target_line"] = line.call(str(rec.get("target", "")))
	out["tagger_line"] = line.call(str(rec.get("tagger", "")))
	var side := int(rec["side"])
	out["margin"] = int(r["score"][side]) - int(r["score"][1 - side])
	return out


## [mean energy of the side's players on the ground, how many of them are under TANK].
func _legs(sim: MatchSim, side: int) -> Array:
	var ground: Array = (sim.squads[side] as Squad).ground
	var total := 0.0
	var low := 0
	for p in ground:
		var e := float(sim.energy.get(str(p["id"]), 100.0))
		total += e
		low += 1 if e < TANK else 0
	return [snappedf(total / maxf(1.0, float(ground.size())), 0.01), low]


## The 2027 round-1 lists of a real-lists career: the real end-of-2026 lists, the 2026
## list decisions, trades and free agency, then the 2026 National Draft with every club
## (MEL included) picking as the AI does. Same seeds every run, so two checkouts pair.
func real_start_lists() -> Dictionary:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = 2026
	GameState.replay_seed = 2026
	GameState.begin_real_lists()
	GameState.choose_real_club("MEL")
	var d: Draft = GameState.draft
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()
	GameState.finish_intake_draft()
	return GameState.season.lists


## Set-shot bands by metres out, as docs/research/SET_SHOT_EVIDENCE.md gives them.
## The pocket (MatchSim SET_BANDS "pocket", 15 m on a tight angle) is its own
## band, "pocket", so it is checked against the wide-angle cells, not straight in front.
const SHOT_BANDS := [[10.0, "0-10"], [20.0, "10-20"], [30.0, "20-30"], [40.0, "30-40"], [50.0, "40-50"], [999.0, "50+"]]


## Shots off MatchSim.shot_log into the team row: set shots and general-play
## shots with their goals and behinds, and set shots by distance band
## ("sshot_<band>_n" shots, "_g" goals, "_b" behinds).
func _shot_counts(t: Dictionary, shots: Array, side: int) -> void:
	for k in ["sshot_n", "sshot_g", "sshot_b", "gshot_n", "gshot_g", "gshot_b"]:
		t[k] = 0
	for band in SHOT_BANDS + [[0.0, "pocket"]]:
		for x in ["_n", "_g", "_b"]:
			t["sshot_" + str(band[1]) + x] = 0
	for s in shots:
		if int(s[0]) != side:
			continue
		var pre := "sshot" if int(s[1]) == 1 else "gshot"
		var res := str(s[3])
		var keys := [pre]
		if pre == "sshot" and s.size() > 4 and str(s[4]) == "pocket":
			keys.append("sshot_pocket")
		elif pre == "sshot":
			for band in SHOT_BANDS:
				if float(s[2]) <= float(band[0]):
					keys.append("sshot_" + str(band[1]))
					break
		for k in keys:
			t[k + "_n"] += 1
			if res == "goal":
				t[k + "_g"] += 1
			elif res == "behind":
				t[k + "_b"] += 1


## Key forward v key defender (row 94): one row per key forward who had a
## direct opponent, contests from the engine's duel log (what the full-time
## line reads). [contests, marks, most contests against one defender,
## MatchNotes.duel_verdict over the match]. A key forward with none is a 0 row.
func duels(sim: MatchSim, r: Dictionary) -> Array:
	var log: Dictionary = r.get("duels", {})
	var ids := {}
	for side in range(2):
		for fid in (sim.duels[side] as Dictionary):
			ids[str(fid)] = true
	for fid in log:
		ids[str(fid)] = true
	var out := []
	for fid in ids:
		var n := 0
		var won := 0
		var per := {}
		for c in (log.get(fid, {}) as Dictionary).get("contests", []):
			n += 1
			won += 1 if bool(c[2]) else 0
			per[str(c[1])] = int(per.get(str(c[1]), 0)) + 1
		var top := 0
		for d in per:
			top = maxi(top, int(per[d]))
		out.append([n, won, top, MatchNotes.duel_verdict(won, n)])
	return out


## The side's number-one ruck in this match (T2.31): the man with the most hit-outs
## (ties to the first in the roster), as [hit-outs, hit-outs to advantage, ruck
## contests, his ruck rating]. [0, 0, 0, 0] when nobody on the side had a hit-out.
static func ruck1(roster: Array, stats: Dictionary, sq: Squad) -> Array:
	var rating := {}
	for pl in sq.ground + sq.bench:
		rating[str(pl["id"])] = int((pl.get("attr", {}) as Dictionary).get("ruck", 0))
	var best := [0, 0, 0, 0]
	for pl in roster:
		var st: Dictionary = stats.get(str(pl["id"]), {})
		var ho := int(st.get("hitouts", 0))
		if ho > int(best[0]):
			best = [ho, int(st.get("hitouts_adv", 0)), int(st.get("ruck_contests", 0)),
				int(rating.get(str(pl["id"]), 0))]
	return best


## "a=1,b=0.5" -> {"a": 1.0, "b": 0.5}
## --lists generated (row 104): a league of generated players, to screen a change to
## generation in matches (main against the branch). Classes 2027 on (career seed 4242 +
## year) are generated on the game's data (the hand-set OVR rows on) and grown
## GEN_GROW seasons by the development rules; each real 2026 list player's place is
## taken by the next unused generated player of his position, re-rated to his OVR on
## the harness's own data
## (GameDB.set_player_ovr, one shift on every rated attribute; discipline kept, as the
## career's refit keeps it), as the in-career league is
## re-anchored to the 2026 spread every rollover. Every worker builds the same league,
## so two checkouts differ only in what generation does with the same draws.
const GEN_CLASSES := 40
const GEN_GROW := 5
func generated_lists(codes: Array) -> Dictionary:
	var skipped: bool = GameDB.skip_ovr_overrides
	GameDB.skip_ovr_overrides = false
	GameDB.reload()
	Prospects.forget_cache()
	var pool := {}
	for y in range(2027, 2027 + GEN_CLASSES):
		for q in Prospects.generate_class(y, 4242 + y):
			for k in range(1, GEN_GROW + 1):
				Prospects.age_player(q, y + k)
			var r := str(q.get("role", "MID"))
			if not pool.has(r):
				pool[r] = []
			(pool[r] as Array).append(q)
	GameDB.skip_ovr_overrides = skipped
	GameDB.reload()
	Prospects.forget_cache()
	var targets := {}
	for code in codes:
		targets[code] = []
		for p in GameDB.club_list(code):
			(targets[code] as Array).append([str(p.get("role", "MID")), int(p.get("overall", 50))])
	var used := {}
	var out := {}
	for code in codes:
		out[code] = []
		for t in targets[code]:
			var from: Array = pool.get(t[0], pool["MID"])
			var at := int(used.get(t[0], 0)) % from.size()
			used[t[0]] = at + 1
			var q: Dictionary = (from[at] as Dictionary).duplicate(true)
			q["club"] = code
			# The career's re-anchor (Prospects.fit_attributes) leaves the attributes outside
			# the rating alone; set_player_ovr shifts them too, so put them back: the league
			# keeps the temperaments generation rolled (the hothead share the audit measures).
			var keep := {}
			for k in Prospects.UNRATED_KEYS:
				keep[k] = (q["attr"] as Dictionary).get(k)
			GameDB.set_player_ovr(q, int(t[1]))
			for k in keep:
				if keep[k] != null:
					q["attr"][k] = keep[k]
			(out[code] as Array).append(q)
	return out


static func parse_sets(text: String) -> Dictionary:
	var d := {}
	for kv in text.split(",", false):
		var parts := kv.split("=")
		if parts.size() == 2:
			d[parts[0].strip_edges()] = float(parts[1])
	return d


## One side's box score by line, grouped by each player's own position
## (list_role, as afl_role_rates.json groups real players): player-games and
## the stats the role reference has, so the report can set them against real.
static func role_lines(roster: Array, players: Dictionary) -> Dictionary:
	var out := {}
	for p in roster:
		var role := str(p.get("list_role", p.get("role", "")))
		if not out.has(role):
			out[role] = {"pg": 0}
		var row: Dictionary = out[role]
		row["pg"] = int(row["pg"]) + 1
		var st: Dictionary = players.get(str(p["id"]), {})
		for k in ROLE_STATS:
			row[k] = float(row.get(k, 0.0)) + float(st.get(k, 0.0))
	return out


const ROLE_STATS := ["disposals", "kicks", "handballs", "marks", "rebounds", "inside50", "clearances", "goals",
		"tackles", "pressure_acts"]


## The same box score by each man's type as the game names it (Roles.label on his
## list record: "Key defender", "Defender", "Small defender", "Inside midfielder",
## "Wing", "Key forward", ...), as afl_role_rates.json "types" groups real players,
## plus one row per man ("pl": [id, type, disposals, kicks, handballs, marks,
## rebounds, kick_ins]) for the report's top-by-type list.
static var _type_of := {}
static func type_lines(roster: Array, players: Dictionary) -> Dictionary:
	var out := {}
	var pl := []
	for p in roster:
		var id := str(p["id"])
		if not _type_of.has(id):
			var rec = GameDB.player_by_id(id)
			_type_of[id] = Roles.label(rec) if rec is Dictionary else "?"
		var ty := str(_type_of[id])
		if not out.has(ty):
			out[ty] = {"pg": 0}
		var row: Dictionary = out[ty]
		row["pg"] = int(row["pg"]) + 1
		var st: Dictionary = players.get(id, {})
		for k in ROLE_STATS + ["kick_ins"]:
			row[k] = float(row.get(k, 0.0)) + float(st.get(k, 0.0))
		pl.append([id, ty, int(st.get("disposals", 0.0)), int(st.get("kicks", 0.0)),
				int(st.get("handballs", 0.0)), int(st.get("marks", 0.0)),
				int(st.get("rebounds", 0.0)), int(st.get("kick_ins", 0.0))])
	out["pl"] = pl
	return out


## Where each type's disposals happen, read off the event log (no dice): every
## kick, mark-and-kick or handball event by zone from his side's view (back
## under -10 m, middle to +5, attack to the forward 50, inside), and how many
## were his first touch straight after his own rebound out of defence ("reb").
## Kick-ins kicked straight in are not disposals and are left out.
static func type_sources(sim: MatchSim, r: Dictionary) -> Array:
	var out := [{}, {}]
	var f50 := float(Ratings.T["forward50_line"])
	var prev := {}
	for ev in r["events"]:
		var e: Dictionary = ev
		var kind := str(e.get("kind", ""))
		var side := int(e.get("side", -1))
		var id := str(e.get("player_id", ""))
		if side >= 0 and id != "" and ["kick", "mark", "handball"].has(kind) \
				and not (bool(e.get("kick_in", false)) and not bool(e.get("play_on", false))):
			if not _type_of.has(id):
				var rec = GameDB.player_by_id(id)
				_type_of[id] = Roles.label(rec) if rec is Dictionary else "?"
			var ty := str(_type_of[id])
			var fp := float(e.get("fp", 0.0))
			var atk := fp if side == 0 else -fp
			var zone := "back" if atk < -10.0 else ("middle" if atk <= 5.0 else ("attack" if atk <= f50 else "inside"))
			var d: Dictionary = out[side].get(ty, {})
			d[zone] = int(d.get(zone, 0)) + 1
			d["ev"] = int(d.get("ev", 0)) + 1
			if str(prev.get("kind", "")) == "rebound" and str(prev.get("player_id", "")) == id:
				d["reb"] = int(d.get("reb", 0)) + 1
			out[side][ty] = d
		if kind != "":
			prev = e
	# Who takes the ball straight after a rebound 50 (MatchSim.exit_rx_log),
	# "rx" in all and "rx_<zone>" by where he took it.
	# Every touch later in a chain that had a rebound 50 (post_exit_log): "px"
	# and "px_<zone>".
	for lg in [["exit_rx_log", "rx"], ["post_exit_log", "px"]]:
		if not (str(lg[0]) in sim):
			continue
		for side in 2:
			var log: Dictionary = sim.get(str(lg[0]))[side]
			for k in log:
				var parts := str(k).split("|")
				var id := parts[1]
				if not _type_of.has(id):
					var rec = GameDB.player_by_id(id)
					_type_of[id] = Roles.label(rec) if rec is Dictionary else "?"
				var ty := str(_type_of[id])
				var n := int(log[k])
				var d: Dictionary = out[side].get(ty, {})
				d[lg[1]] = int(d.get(lg[1], 0)) + n
				d[str(lg[1]) + "_" + parts[0]] = int(d.get(str(lg[1]) + "_" + parts[0], 0)) + n
				out[side][ty] = d
	return out
