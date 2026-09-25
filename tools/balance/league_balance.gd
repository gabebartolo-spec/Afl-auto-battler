extends RefCounted
## Competitive-balance measurement for the league a career actually plays.
##
## Instrumentation only: every match, draft and season below runs through the
## shipped game code (Draft, Squad, Season -> MatchSim, and GameState for the
## full career path). Nothing here simulates football itself, and nothing here
## changes a rating, a rule or a constant. Every seed is explicit.
##
## Three league sources:
##   drafted  the 18 founding clubs re-draft the 2026 pool with the real
##            career draft (Draft), then play a season through Season (no
##            between-round systems). The rival clubs always pick with the
##            game's own AI. Your club's picks follow a drafting policy:
##              "ai"    you pick exactly like the AI. The whole draft is then
##                      deterministic up to the random pick order - every
##                      seed yields the same 18 lists under different club
##                      names - so this is one league, relabelled.
##              "board" a simple human model: at each of your turns, pick at
##                      random (seeded) from the top TOP_N players on the
##                      draft board sorted by overall, among those the board
##                      lets you pick (Draft.can_pick_player). Your choices
##                      change every later AI pick, so seeds give genuinely
##                      different leagues.
##   real     the real 2026 club lists (the path most other suites use)
##   career   a drafted league played through GameState.advance(): injuries,
##            in-season training for every club, your club's default plans,
##            morale, weekly events - exactly a normal career's first season
## plus a controlled sensitivity experiment: one club's whole list shifted by
## +k overall with Prospects._shift_player (the refit the game's own
## renormalisation uses), against the same opponents with the same seeds.
##
## Loaded with load() by tools/balance/league_balance_report.gd and the CI
## smoke suite (tests/test_league_balance.gd).

const FOUNDING_YEAR := 2026
const FINALISTS := Season.FINALISTS
const GAP_BUCKETS := [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 1000.0]
const OVR_GAP_BUCKETS := [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 1000.0]


# ---------------------------------------------------------------------------
# Leagues
# ---------------------------------------------------------------------------
func clubs() -> Array:
	return GameDB.active_clubs(FOUNDING_YEAR).duplicate()


## The career draft for `seed` (see the class doc for `policy`). Returns
## the lists, the pick order, your club ("" for policy "ai") and a signature
## of the league that ignores club names (to count distinct leagues).
## Deterministic for a given (seed, policy, top_n).
func drafted_lists(seed: int, policy := "board", top_n := 5, model := {}) -> Dictionary:
	var d := make_draft(seed, policy, top_n, model)
	return {"lists": d.all_lists(), "order": d.draft_order.duplicate(),
			"user_club": d.user_club, "sig": league_signature(d.all_lists())}


## A non-empty `model` drafts with an experimental draft model
## (tools/balance/draft_variant.gd) instead of the shipped one.
func make_draft(seed: int, policy := "board", top_n := 5, model := {}) -> Draft:
	var d: Draft
	if model.is_empty():
		d = Draft.new(GameDB.all_players_sorted(), clubs(), seed)
	else:
		d = load("res://tools/balance/draft_variant.gd").new(GameDB.all_players_sorted(), clubs(), seed)
		d.configure(model)
	if policy == "ai":
		d.start_for_user("")
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 31 + 7
		var user := str(d.draft_order[rng.randi_range(0, d.draft_order.size() - 1)])
		d.start_for_user(user)
		while not d.is_finished():
			var options := []
			for p in d.board("", "", "", "overall", true):
				if d.can_pick_player(p):
					options.append(p)
					if options.size() >= top_n:
						break
			if options.is_empty() or not d.pick(options[rng.randi_range(0, options.size() - 1)]):
				d._skip_current_pick()
				d.auto_until_user_turn()
	if not d.is_finished():
		push_error("league_balance: draft %d did not finish" % seed)
	return d


## The league's lists with club names removed: equal for two drafts that
## produced the same 18 lists in a different order.
static func league_signature(lists: Dictionary) -> String:
	var parts := []
	for c in lists:
		var ids := []
		for p in lists[c]:
			ids.append(str(p["id"]))
		ids.sort()
		parts.append(",".join(ids))
	parts.sort()
	return "|".join(parts).md5_text()


func real_lists() -> Dictionary:
	var lists := {}
	for c in clubs():
		lists[c] = GameDB.club_list(c)
	return lists


## Preseason strength of every club, from the auto-selected side the engine
## would field: Squad.strength() (the figure the board ranks clubs by) and
## the mean overall of the selected 22.
func club_ratings(lists: Dictionary, codes: Array) -> Dictionary:
	var out := {}
	for c in codes:
		var sq := Squad.new(str(c), lists[c], true, str(c))
		var total := 0.0
		var n := 0
		for p in sq.ground + sq.bench:
			total += float(p["overall"])
			n += 1
		out[c] = {"strength": sq.strength(), "ovr22": total / float(maxi(1, n)),
				"contest": sq.contest, "attack": sq.attack, "defence": sq.defence}
	return out


## The line aggregates behind Squad.strength() (the engine's inputs) and the
## shape of the list, for the draft-model experiment.
func club_units(lists: Dictionary, codes: Array) -> Dictionary:
	var out := {}
	for c in codes:
		var list: Array = lists[c]
		var sq := Squad.new(str(c), list, true, str(c))
		var roles := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		var ovrs := []
		var value := 0
		for p in list:
			roles[str(p["role"])] = int(roles[str(p["role"])]) + 1
			ovrs.append(float(p["overall"]))
			value += int(p["value"])
		ovrs.sort()
		ovrs.reverse()
		var sel := 0.0
		for p in sq.ground + sq.bench:
			sel += float(p["overall"])
		out[c] = {
			"strength": sq.strength(), "ovr22": sel / float(maxi(1, sq.ground.size() + sq.bench.size())),
			"contest": sq.contest, "attack": sq.attack, "defence": sq.defence,
			"ruck": sq.ruck, "mid_contest": sq.mid_contest, "mid_disposal": sq.mid_disposal,
			"mid_carry": sq.mid_carry, "def_pressure": sq.def_pressure,
			"def_intercept": sq.def_intercept, "fwd_goal": sq.fwd_goal,
			"fwd_mark": sq.fwd_mark, "fwd_create": sq.fwd_create,
			"team_star": sq.team_star, "team_discipline": sq.team_discipline,
			"list_ovr": mean(ovrs), "top5_ovr": mean(ovrs.slice(0, 5)),
			"size": list.size(), "value": value, "roles": roles,
			"ids": list.map(func(p): return str(p["id"])),
		}
	return out


# ---------------------------------------------------------------------------
# Seasons
# ---------------------------------------------------------------------------
## A full season (24 rounds and the finals) through Season.play_round /
## play_finals_week, i.e. Season.simulate -> Squad -> MatchSim.
func play_engine_season(lists: Dictionary, season_seed: int, meta: Dictionary) -> Dictionary:
	var codes := clubs()
	var ratings := club_ratings(lists, codes)
	var season := Season.new(codes, lists, season_seed)
	while not season.is_regular_done():
		season.play_round()
	season.start_finals()
	while not season.is_season_over():
		season.play_finals_week()
	return season_record(season, ratings, meta)


## A normal career's first season through GameState: the career draft
## (seeded, with your picks from `policy`), start_season, then
## GameState.advance() for every round and final. Your club follows the
## default training plans and default weekly decisions, as an untouched
## career would. GameState seeds the season from
## the clock; the season seed is overwritten before round 1 (the fixture does
## not depend on it) and round 1's event card is re-drawn from it, so the run
## is fully determined by (draft_seed, season_seed).
func play_career_season(draft_seed: int, season_seed: int, policy: String, top_n: int, meta: Dictionary) -> Dictionary:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	var d := make_draft(draft_seed, policy, top_n)
	# Policy "ai" has no human club: the first pick of the order stands in.
	var user_club := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user_club, [])
	gs.season.seed = season_seed
	gs._next_week_event()
	var ratings := club_ratings(gs.season.lists, clubs())
	while not gs.season.is_season_over():
		gs.advance()
	meta["user_club"] = user_club
	return season_record(gs.season, ratings, meta)


## What the report needs from a finished season: one row per club, one per
## match. Plain data, so shards can be written to JSON and merged.
func season_record(season: Season, ratings: Dictionary, meta: Dictionary) -> Dictionary:
	var rows: Array = season.ladder_sorted()
	var top: Array = season.finals.get("top", [])
	var codes := []
	for c in ratings:
		codes.append(c)
	codes.sort_custom(func(a, b):
		var sa := float(ratings[a]["strength"])
		var sb := float(ratings[b]["strength"])
		if not is_equal_approx(sa, sb):
			return sa > sb
		return float(ratings[a]["ovr22"]) > float(ratings[b]["ovr22"]))
	var club_rows := []
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var c := str(r["code"])
		club_rows.append({
			"club": c, "strength": float(ratings[c]["strength"]),
			"ovr22": float(ratings[c]["ovr22"]),
			"strength_rank": codes.find(c) + 1, "ladder": i + 1,
			"w": int(r["w"]), "l": int(r["l"]), "d": int(r["d"]),
			"pct": float(r["pct"]), "finals": top.has(c),
			"premier": str(season.finals.get("premier", "")) == c,
			"spoon": i == rows.size() - 1,
		})
	var matches := []
	for rnd in season.results:
		for res in rnd:
			matches.append(_match_row(res, ratings, ""))
	for wk in season.finals.get("weeks", []):
		for res in wk:
			matches.append(_match_row(res, ratings, str(res.get("tag", "F"))))
	var out := meta.duplicate()
	out["clubs"] = club_rows
	out["matches"] = matches
	return out


func _match_row(res: Dictionary, ratings: Dictionary, tag: String) -> Dictionary:
	var h := str(res["home"])
	var a := str(res["away"])
	return {"h": h, "a": a, "hs": int(res["score"][0]), "as": int(res["score"][1]),
			"sh": float(ratings[h]["strength"]), "sa": float(ratings[a]["strength"]),
			"oh": float(ratings[h]["ovr22"]), "oa": float(ratings[a]["ovr22"]),
			"final": tag, "neutral": bool(res.get("neutral", false))}


# ---------------------------------------------------------------------------
# Controlled sensitivity experiment
# ---------------------------------------------------------------------------
## Copies of `list` with every player shifted by `k` overall through the
## game's own refit (Prospects._shift_player: uniform attribute shift, then
## re-rated). k = 0 returns plain copies.
func shifted_list(list: Array, k: int) -> Array:
	var out := []
	for p in list:
		var q: Dictionary = p.duplicate(true)
		if k != 0:
			Prospects._shift_player(q, float(int(q["overall"]) + k))
		out.append(q)
	return out


## `subject` plays every other club home and away, `reps` times, once per k.
## The match seed depends only on (seed_base, rep, opponent, venue), so every
## k faces identical opponents with identical seeds (paired design).
func sensitivity(lists: Dictionary, subject: String, ks: Array, reps: int, seed_base: int, meta: Dictionary) -> Array:
	var rows := []
	var codes := clubs()
	for k in ks:
		var mine := shifted_list(lists[subject], int(k))
		var base_sq := Squad.new(subject, mine, true, subject)
		var ovr := 0.0
		for p in base_sq.ground + base_sq.bench:
			ovr += float(p["overall"])
		ovr /= float(base_sq.ground.size() + base_sq.bench.size())
		for r in range(reps):
			for opp in codes:
				if opp == subject:
					continue
				for home in [true, false]:
					var me := Squad.new(subject, mine, home, subject)
					var them := Squad.new(str(opp), lists[opp], not home, str(opp))
					var seed := seed_base + r * 100003 + codes.find(opp) * 211 + (1 if home else 0)
					var sim := MatchSim.new(me if home else them, them if home else me, seed)
					var res := sim.run()
					var s: Array = res["score"]
					var m := (int(s[0]) - int(s[1])) * (1 if home else -1)
					var row := meta.duplicate()
					row.merge({"k": int(k), "subject": subject, "opp": str(opp), "home": home,
							"rep": r, "margin": m, "strength": base_sq.strength(), "ovr22": ovr})
					rows.append(row)
	return rows


## The median club by Squad.strength (the subject of the experiment).
func median_club(lists: Dictionary) -> String:
	var ratings := club_ratings(lists, clubs())
	var codes := clubs()
	codes.sort_custom(func(a, b): return float(ratings[a]["strength"]) > float(ratings[b]["strength"]))
	return str(codes[codes.size() / 2])


# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------
static func mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / float(xs.size())


static func sd(xs: Array) -> float:
	if xs.size() < 2:
		return 0.0
	var m := mean(xs)
	var t := 0.0
	for x in xs:
		t += (float(x) - m) * (float(x) - m)
	return sqrt(t / float(xs.size() - 1))


static func percentile(xs: Array, q: float) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	var i := q * float(s.size() - 1)
	var lo := int(floor(i))
	var hi := mini(s.size() - 1, lo + 1)
	return float(s[lo]) + (float(s[hi]) - float(s[lo])) * (i - float(lo))


static func pearson(xs: Array, ys: Array) -> float:
	var mx := mean(xs)
	var my := mean(ys)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(xs.size()):
		var dx := float(xs[i]) - mx
		var dy := float(ys[i]) - my
		sxy += dx * dy
		sxx += dx * dx
		syy += dy * dy
	if sxx <= 0.0 or syy <= 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)


static func ranks(xs: Array) -> Array:
	var idx := range(xs.size())
	idx.sort_custom(func(a, b): return float(xs[a]) < float(xs[b]))
	var out := []
	out.resize(xs.size())
	var i := 0
	while i < idx.size():
		var j := i
		while j + 1 < idx.size() and is_equal_approx(float(xs[idx[j + 1]]), float(xs[idx[i]])):
			j += 1
		var r := (float(i) + float(j)) / 2.0 + 1.0
		for t in range(i, j + 1):
			out[idx[t]] = r
		i = j + 1
	return out


static func spearman(xs: Array, ys: Array) -> float:
	return pearson(ranks(xs), ranks(ys))


## Wilson score interval for k successes in n trials: [low, high].
static func wilson(k: float, n: float, z := 1.96) -> Array:
	if n <= 0.0:
		return [0.0, 0.0]
	var p := k / n
	var den := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / den
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / den
	return [centre - half, centre + half]
