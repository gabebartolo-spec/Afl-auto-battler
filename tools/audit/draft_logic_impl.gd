extends RefCounted
## Draft logic audit (overnight, director-requested). Measurement only: no game
## behaviour is changed. Parts (args after the impl name: part [n]):
##   league    n seeds of the League Draft (all clubs AI), rules + AI sense
##   national  n seeds of synthetic National Drafts (generated classes), AI sense,
##             rules, hit and bust by pick band
##   career    real-lists career (seed n, user MEL): the 2026 draft and later
##             drafts with real order, trades and compensation, rules checks
##   edge      names, a club with no picks, a user with no picks, save and load
## godot --headless --path . --script tools/audit/run_audit.gd -- draft_logic_impl league 20
## Output lines are plain text; the summary lines start with "SUM".

const BASE_YEAR := 2028
var _acc := {}   # running sums for the SUM lines
var _pfx := ""   # prefix for the SUM keys of the current group of drafts


func _add(key: String, v: float) -> void:
	key = _pfx + key
	_acc[key] = float(_acc.get(key, 0.0)) + v


static func _key_def(p: Dictionary) -> bool:
	return str(p.get("role", "")) == "DEF" and float(p.get("height_cm", 0.0)) >= 190.0


static func _worth(p: Dictionary) -> float:
	var ov := float(p.get("overall", 0))
	return ov * 0.35 + maxf(ov, float(p.get("potential", ov))) * 0.65


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / xs.size()


static func _pearson(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 3:
		return 0.0
	var mx := _mean(xs)
	var my := _mean(ys)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(n):
		sxy += (float(xs[i]) - mx) * (float(ys[i]) - my)
		sxx += (float(xs[i]) - mx) * (float(xs[i]) - mx)
		syy += (float(ys[i]) - my) * (float(ys[i]) - my)
	return sxy / maxf(0.0001, sqrt(sxx * syy))


func _ranks(pool: Array, f: Callable) -> Dictionary:
	var arr := pool.duplicate()
	arr.sort_custom(func(a, b):
		var fa: float = f.call(a)
		var fb: float = f.call(b)
		if not is_equal_approx(fa, fb):
			return fa > fb
		return str(a["id"]) < str(b["id"]))
	var out := {}
	for i in range(arr.size()):
		out[str(arr[i]["id"])] = i + 1
	return out


# ---------------------------------------------------------------------------
# Shared checks on a finished draft
# ---------------------------------------------------------------------------
## Rules and AI sense for any finished Draft. `label` prefixes the lines.
## kept: code -> [[role, role2, is_key_defender]...] kept players (intake).
func analyse(d: Draft, label: String, kept: Dictionary = {}) -> void:
	_add("drafts", 1)
	var pool: Array = d.pool
	if not d.is_finished():
		print("BUG|%s|draft did not finish at pick_index %d of %d" % [label, d.pick_index, d.pick_sequence.size()])
		_add("unfinished", 1)
	var by_id := {}
	for p in pool:
		by_id[str(p["id"])] = p
	var worth_rank := _ranks(pool, func(p): return _worth(p))
	var ovr_rank := _ranks(pool, func(p): return float(p["overall"]))
	var cons_rank := _ranks(pool, func(p): return -float(p.get("draft_rank", 999)))
	var hist: Array = d.pick_history

	# --- order and rules ---
	var seq_owner_counts := {}
	for c in d.pick_sequence:
		seq_owner_counts[str(c)] = int(seq_owner_counts.get(str(c), 0)) + 1
	var made := {}
	var dupes := 0
	var seen := {}
	for e in hist:
		made[str(e["club"])] = int(made.get(str(e["club"]), 0)) + 1
		if seen.has(str(e["player_id"])):
			dupes += 1
		seen[str(e["player_id"])] = true
	if dupes > 0:
		print("BUG|%s|%d players drafted twice" % [label, dupes])
		_add("dupes", dupes)
	var order_bad := 0
	for e in hist:
		var i: int = int(e["pick"]) - 1
		if i < 0 or i >= d.pick_sequence.size() or str(e["club"]) != str(d.pick_sequence[i]):
			order_bad += 1
	if order_bad > 0:
		print("BUG|%s|%d picks made by a club other than the sequence's" % [label, order_bad])
		_add("order_bad", order_bad)
	var skipped := {}
	for c in seq_owner_counts:
		var miss: int = int(seq_owner_counts[c]) - int(made.get(c, 0))
		if miss > 0:
			skipped[c] = miss
	var skip_total := 0
	for c in skipped:
		skip_total += int(skipped[c])
	_add("skipped_slots", skip_total)
	var over := []
	for code in d.clubs:
		var base := int(d.existing_sizes.get(code, 0)) if d.intake_mode else 0
		var n := base + (d.club_lists.get(code, []) as Array).size()
		if d.intake_mode and n > Ratings.LIST_SIZE and base <= Ratings.LIST_SIZE:
			over.append("%s %d" % [code, n])
		if not d.intake_mode and n != d.target_size:
			over.append("%s %d of %d" % [code, n, d.target_size])
		if (d.club_lists.get(code, []) as Array).size() > d.pick_limit(code):
			over.append("%s above pick_limit" % code)
	if not over.is_empty():
		print("BUG|%s|list limits broken: %s" % [label, ", ".join(over)])
		_add("limit_bad", over.size())

	# --- AI sense: where the best prospects went ---
	var pick_of := {}
	for e in hist:
		pick_of[str(e["player_id"])] = int(e["pick"])
	var n_pool := pool.size()
	var top_n := 5
	var top_slid := 0
	var top_undrafted := 0
	var slid_list := []
	var ovr_slid := 0
	var cons_slid := 0
	for pid in by_id:
		if int(worth_rank[pid]) <= top_n:
			if not pick_of.has(pid):
				top_undrafted += 1
			elif int(pick_of[pid]) > 20:
				top_slid += 1
				slid_list.append("%s worth#%d -> pick %d" % [pid, int(worth_rank[pid]), int(pick_of[pid])])
		if int(ovr_rank[pid]) <= top_n and (not pick_of.has(pid) or int(pick_of[pid]) > 20):
			ovr_slid += 1
		if int(cons_rank[pid]) <= top_n and (not pick_of.has(pid) or int(pick_of[pid]) > 20):
			cons_slid += 1
	_add("top5_worth_slid_past20", top_slid)
	_add("top5_worth_undrafted", top_undrafted)
	_add("top5_ovr_slid_past20", ovr_slid)
	_add("top5_consensus_slid_past20", cons_slid)
	_add("top5_slots", top_n)
	var reach10 := 0
	var reach20 := 0
	var reach30 := 0
	var top10_worth_ranks := []
	var low_ovr_top10 := 0
	for e in hist:
		if int(e["pick"]) > 10:
			break
		var pid2 := str(e["player_id"])
		var wr: int = int(worth_rank[pid2])
		top10_worth_ranks.append(wr)
		if wr > 10:
			reach10 += 1
		if wr > 20:
			reach20 += 1
		if wr > 30:
			reach30 += 1
		if int(ovr_rank[pid2]) > maxi(30, n_pool / 3):
			low_ovr_top10 += 1
	_add("top10_picks", top10_worth_ranks.size())
	_add("top10_worth_rank_sum", _mean(top10_worth_ranks) * top10_worth_ranks.size())
	_add("top10_not_in_top10", reach10)
	_add("top10_not_in_top20", reach20)
	_add("top10_not_in_top30", reach30)
	_add("top10_ovr_rank_in_lower_two_thirds", low_ovr_top10)
	var xs := []
	var ys := []
	for e in hist:
		xs.append(float(e["pick"]))
		ys.append(float(worth_rank[str(e["player_id"])]))
	var corr := _pearson(xs, ys)
	_add("corr_pick_vs_worth_rank_sum", corr)

	# --- rucks and key defenders on the final list ---
	var ruck3_nokey := 0
	var ruck3 := 0
	var ruck4 := 0
	var nokey := 0
	var ruck_over_picks := 0
	var max_rucks := 0
	for code in d.clubs:
		var rucks := 0
		var keys := 0
		for pair in (kept.get(code, []) as Array):
			if str(pair[0]) == "RUCK":
				rucks += 1
			if bool(pair[2]):
				keys += 1
		for e in hist:
			if str(e["club"]) != code:
				continue
			var p: Dictionary = by_id[str(e["player_id"])]
			if str(p["role"]) == "RUCK":
				if rucks >= 2 and d.intake_mode:
					ruck_over_picks += 1
				if rucks >= 3 and d.intake_mode:
					_add("picks_ruck_when_3_rucks_held", 1)
				rucks += 1
			if _key_def(p):
				keys += 1
		max_rucks = maxi(max_rucks, rucks)
		if rucks >= 4:
			ruck4 += 1
		if rucks >= 3:
			ruck3 += 1
			if keys == 0:
				ruck3_nokey += 1
		if keys == 0:
			nokey += 1
	_add("clubs_total", d.clubs.size())
	_add("clubs_3plus_rucks", ruck3)
	_add("clubs_4plus_rucks", ruck4)
	_add("clubs_3plus_rucks_no_key_def", ruck3_nokey)
	_add("clubs_no_key_def", nokey)
	_add("picks_ruck_when_2_rucks_held", ruck_over_picks)
	if ruck3_nokey > 0:
		print("DET|%s|clubs with 3+ rucks and no key defender: %d (max rucks on a list %d)" % [label, ruck3_nokey, max_rucks])
	print("AI|%s|picks %d of pool %d, skipped slots %d, top5 (by worth) slid past 20: %d (by OVR %d, by consensus rank %d), top10 picks outside worth top10/20/30: %d/%d/%d, mean worth rank in top10 %.1f, corr %.2f, rucks drafted by a club holding 2+ %d%s" % [
			label, hist.size(), n_pool, skip_total, top_slid, ovr_slid, cons_slid, reach10, reach20, reach30,
			_mean(top10_worth_ranks), corr, ruck_over_picks, ("; " + "; ".join(slid_list)) if not slid_list.is_empty() else ""])
	if skip_total > 0:
		var parts := []
		for c in skipped:
			parts.append("%s %d" % [c, int(skipped[c])])
		print("DET|%s|skipped slots by club: %s" % [label, ", ".join(parts)])


# ---------------------------------------------------------------------------
# League Draft
# ---------------------------------------------------------------------------
func league(n: int) -> void:
	for s in range(1, n + 1):
		var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
		pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
		var clubs: Array = GameDB.active_clubs(GameDB.START_YEAR).duplicate()
		var d := Draft.new(pool, clubs, s)
		d.start_for_user("")
		var label := "league s%d" % s
		analyse(d, label, {})
		var bad_ruck := 0
		var over_cap := 0
		var no_ruck_cover := []
		for code in d.clubs:
			var cover := 0
			for p in d.club_lists[code]:
				if Ratings.plays_role(p, "RUCK"):
					cover += 1
			if cover < 2:
				bad_ruck += 1
				no_ruck_cover.append(code)
			if int(d.club_spend.get(code, 0)) > d.budget:
				over_cap += 1
		_add("league_ruck_short_clubs", bad_ruck)
		_add("league_over_cap_clubs", over_cap)
		if bad_ruck > 0:
			print("BUG|%s|clubs under two rucks: %s" % [label, ",".join(no_ruck_cover)])
		if over_cap > 0:
			print("BUG|%s|%d clubs over the cap" % [label, over_cap])
		var r3 := 0
		var r3nk := 0
		var nk := 0
		var maxr := 0
		for code in d.clubs:
			var rucks := 0
			var keys := 0
			for p in d.club_lists[code]:
				if str(p["role"]) == "RUCK":
					rucks += 1
				if _key_def(p):
					keys += 1
			maxr = maxi(maxr, rucks)
			if rucks >= 3:
				r3 += 1
				if keys == 0:
					r3nk += 1
			if keys == 0:
				nk += 1
		_add("L_clubs_3plus_rucks", r3)
		_add("L_clubs_3plus_rucks_no_key_def", r3nk)
		_add("L_clubs_no_key_def", nk)
		_add("L_max_rucks", maxr)
		_add("L_runs", 1)
		var ovr_rank := _ranks(pool, func(p): return float(p["overall"]))
		var pick_of := {}
		for e in d.pick_history:
			pick_of[str(e["player_id"])] = int(e["pick"])
		var top_picks := []
		for p in pool.slice(0, 10):
			top_picks.append(int(pick_of.get(str(p["id"]), 0)))
		var first10 := []
		for e in d.pick_history:
			if int(e["pick"]) > 10:
				break
			first10.append(int(ovr_rank[str(e["player_id"])]))
		var first10_bad := 0
		for r in first10:
			if int(r) > 60:
				first10_bad += 1
		_add("L_first10_ovr_rank_over60", first10_bad)
		_add("L_first10_ovr_rank_sum", _mean(first10) * first10.size())
		print("LG|%s|pool %d target %d budget %d; ten best by OVR taken at picks %s; first ten picks' OVR ranks %s; clubs with 3+ rucks %d (no key def %d), clubs with no key def %d, max rucks %d" % [
				label, pool.size(), d.target_size, d.budget, str(top_picks), str(first10), r3, r3nk, nk, maxr])


# ---------------------------------------------------------------------------
# Synthetic National Drafts
# ---------------------------------------------------------------------------
## The 18 founding clubs' real lists as the kept lists, with an optional squeeze.
func _kept_from_real(clubs: Array, squeeze: bool, rng: RandomNumberGenerator) -> Array:
	var sizes := {}
	var counts := {}
	var pairs := {}
	var kept := {}
	for code in clubs:
		var arr: Array = GameState.league_lists.get(code, [])
		sizes[code] = arr.size()
		var c := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		var pr: Array = []
		var kp: Array = []
		for p in arr:
			var r := str(p["role"])
			c[r] = int(c.get(r, 0)) + 1
			pr.append([r, str(p.get("role2", ""))])
			kp.append([r, str(p.get("role2", "")), _key_def(p)])
		counts[code] = c
		pairs[code] = pr
		kept[code] = kp
	if squeeze:
		var picks := clubs.duplicate()
		for i in range(picks.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = picks[i]
			picks[i] = picks[j]
			picks[j] = t
		for i in range(5):
			sizes[picks[i]] = Ratings.LIST_SIZE - (i % 3)
	return [sizes, counts, pairs, kept]


func national(n: int, squeeze: bool) -> void:
	if GameState.league_lists.is_empty():
		GameState.begin_real_lists()
	var clubs: Array = GameDB.active_clubs(GameDB.START_YEAR).duplicate()
	for s in range(1, n + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919
		var year := BASE_YEAR + (s % 9)
		var cls: Array = Prospects.generate_class(year, s)
		var order := clubs.duplicate()
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]
			order[i] = order[j]
			order[j] = t
		var base: Array = _kept_from_real(clubs, squeeze, rng)
		var d := Draft.build_intake(cls, clubs.duplicate(), order, s, base[0], base[1], base[2])
		d.start_for_user("")
		var label := "national%s s%d y%d (class %d, rounds %d)" % ["-tight" if squeeze else "", s, year, cls.size(), d.target_size]
		analyse(d, label, base[3])
		if not squeeze:
			_bust_band(d, year)
			_starvation(d, order)


## Picks per club by position in the order (0 = first pick of round one).
func _starvation(d: Draft, order: Array) -> void:
	var cnt := {}
	for e in d.pick_history:
		cnt[str(e["club"])] = int(cnt.get(str(e["club"]), 0)) + 1
	for i in range(order.size()):
		_add("starve_pos_%02d" % i, float(cnt.get(str(order[i]), 0)))
	_add("starve_runs", 1)


## Follow each pick five seasons with the game's own ageing (Prospects.age_player),
## no training and no league re-anchoring: an approximation of what he becomes.
func _bust_band(d: Draft, year: int) -> void:
	var by_id := {}
	for p in d.pool:
		by_id[str(p["id"])] = p
	var rows := []   # [pick, ovr0, pot0, ovr3, ovr5, scouted_ovr, scouted_pot, draft_rank]
	for e in d.pick_history:
		var p: Dictionary = (by_id[str(e["player_id"])] as Dictionary).duplicate(true)
		var proj := DraftScouting.projection(p, "AUD", d.seed, 1.0)
		var o0 := int(p["overall"])
		var pot0 := maxi(o0, int(p.get("potential", o0)))
		var o3 := o0
		var o5 := o0
		for i in range(1, 6):
			Prospects.age_player(p, year + i)
			if i == 3:
				o3 = int(p["overall"])
			if i == 5:
				o5 = int(p["overall"])
		rows.append([int(e["pick"]), o0, pot0, o3, o5, int(proj["overall_mid"]), int(proj["potential_mid"]), int(p.get("draft_rank", 0))])
	for r in rows:
		var band := "1-10" if int(r[0]) <= 10 else ("11-30" if int(r[0]) <= 30 else "31+")
		_add("hb_n_" + band, 1)
		_add("hb_o0_" + band, float(r[1]))
		_add("hb_pot_" + band, float(r[2]))
		_add("hb_o3_" + band, float(r[3]))
		_add("hb_o5_" + band, float(r[4]))
		if int(r[4]) >= 75:
			_add("hb_star75_" + band, 1)
		if int(r[4]) >= 68:
			_add("hb_good68_" + band, 1)
		if int(r[4]) < 58:
			_add("hb_bust_under58_" + band, 1)
		if int(r[4]) < int(r[1]) + 3:
			_add("hb_flat_gain_under3_" + band, 1)
		if int(r[2]) - int(r[4]) >= 10:
			_add("hb_still_10_short_of_pot_" + band, 1)
		_add("hb_gap_to_pot_sum_" + band, float(r[4]) - float(r[2]))
		_add("hb_gap_to_pot_sq_" + band, (float(r[4]) - float(r[2])) * (float(r[4]) - float(r[2])))
		if int(r[4]) < int(r[2]) - 5:
			_add("hb_5_short_of_pot_" + band, 1)
		_add("hb_scout_ovr_err_abs_" + band, absf(float(r[5]) - float(r[1])))
		_add("hb_scout_pot_err_abs_" + band, absf(float(r[6]) - float(r[2])))
	var picks := []
	var o5s := []
	var sc_pot := []
	var sc_ovr := []
	var ranks := []
	for r in rows:
		picks.append(-float(r[0]))
		o5s.append(float(r[4]))
		sc_pot.append(float(r[6]))
		sc_ovr.append(float(r[5]))
		ranks.append(-float(r[7]))
	_add("hb_corr_pick_vs_o5", _pearson(picks, o5s))
	_add("hb_corr_scoutpot_vs_o5", _pearson(sc_pot, o5s))
	_add("hb_corr_scoutovr_vs_o5", _pearson(sc_ovr, o5s))
	_add("hb_corr_draftrank_vs_o5", _pearson(ranks, o5s))
	_add("hb_runs", 1)


# ---------------------------------------------------------------------------
# Career (real lists): real order, trades, compensation
# ---------------------------------------------------------------------------
func _user_picks_best(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 400:
		guard += 1
		if d.is_user_turn():
			var choice := {}
			for cand in d.board("", "", "", "overall", true):
				if d.can_pick_player(cand):
					choice = cand
					break
			if choice.is_empty() or not d.pick(choice):
				d._skip_current_pick()
				d.auto_until_user_turn()
		else:
			d.auto_until_user_turn()


func _kept_now() -> Dictionary:
	var kept := {}
	for code in GameState.league_lists:
		var arr: Array = []
		for p in GameState.league_lists[code]:
			arr.append([str(p["role"]), str(p.get("role2", "")), _key_def(p)])
		kept[code] = arr
	return kept


func career(seed_n: int, seasons: int) -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = seed_n
	GameState.replay_seed = seed_n
	GameState.begin_real_lists()
	var kept := _kept_now()
	GameState.choose_real_club("MEL")
	var d: Draft = GameState.draft
	print("CAREER|seed %d|opening draft: pool %d, rounds %d, order %s" % [seed_n, d.pool.size(), d.target_size, str(d.draft_order)])
	_user_picks_best(d)
	analyse(d, "career s%d 2026 (real class)" % seed_n, kept)
	GameState.finish_intake_draft()
	for s in range(seasons):
		var year := GameState.season_year
		while not GameState.season.is_season_over():
			GameState.advance()
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			var dd: Draft = GameState.draft
			var kept2 := _kept_now()
			var sizes := []
			for code in dd.clubs:
				sizes.append(int(dd.existing_sizes.get(code, 0)))
			sizes.sort()
			print("CAREER|seed %d|year %d draft: pool %d, rounds %d, comps %d, traded picks %d, list sizes at the draft min %d median %d max %d" % [
					seed_n, year, dd.pool.size(), dd.target_size, dd.comp_picks.size(), dd.pick_owners.size(),
					int(sizes[0]), int(sizes[sizes.size() / 2]), int(sizes[-1])])
			_user_picks_best(dd)
			analyse(dd, "career s%d %d" % [seed_n, year], kept2)
			var made_by_club := {}
			for e in dd.pick_history:
				made_by_club[str(e["club"])] = int(made_by_club.get(str(e["club"]), 0)) + 1
			var vals := []
			for code in dd.clubs:
				vals.append(int(made_by_club.get(code, 0)))
			vals.sort()
			print("DET|career s%d %d|picks per club min %d median %d max %d" % [seed_n, year, int(vals[0]), int(vals[vals.size() / 2]), int(vals[-1])])
			GameState.finish_intake_draft()
			var after := []
			for code in GameState.season.lists:
				after.append((GameState.season.lists[code] as Array).size())
			after.sort()
			print("DET|career s%d %d|list sizes at next season's start min %d median %d max %d" % [seed_n, year, int(after[0]), int(after[after.size() / 2]), int(after[-1])])
		else:
			GameState.start_next_season()


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------
func edge() -> void:
	GameState.begin_real_lists()
	var clubs: Array = GameDB.active_clubs(GameDB.START_YEAR).duplicate()
	var names := {}
	var dup := 0
	var empty_name := 0
	var empty_last := 0
	var empty_last_card := 0
	var total := 0
	var all: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	for year in range(2027, 2047):
		all.append_array(Prospects.generate_class(year, 5))
	for p in all:
		total += 1
		var nm := GameDB.player_display_name(p)
		if nm == "" or nm == "Player":
			empty_name += 1
		if str(p.get("last", "")).strip_edges() == "":
			empty_last += 1
			if GameDB.card_surname(p).strip_edges() == "":
				empty_last_card += 1
		var k := nm.to_lower()
		if names.has(k):
			dup += 1
			if dup <= 5:
				print("EDGE|duplicate display name \"%s\": %s and %s" % [nm, str(names[k]), str(p["id"])])
		else:
			names[k] = str(p["id"])
	print("EDGE|names: %d players and prospects (league + 20 generated classes), empty display name %d, empty surname field %d (card surname still empty: %d), duplicate display names %d" % [
			total, empty_name, empty_last, empty_last_card, dup])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var cls: Array = Prospects.generate_class(2029, 3)
	var base: Array = _kept_from_real(clubs, false, rng)
	var order := clubs.duplicate()
	var d := Draft.build_intake(cls, clubs.duplicate(), order, 3, base[0], base[1], base[2])
	var owners := {}
	var dead: String = str(order[3])
	var heir: String = str(order[10])
	for r in range(1, d.target_size + 1):
		owners["%d:%s" % [r, dead]] = heir
	d.set_pick_owners(owners)
	d.start_for_user(dead)
	print("EDGE|user club %s traded away every pick: is_finished at once %s, slots owned %d, pick_limit %d, user_turn %s, is_valid %s" % [
			dead, str(d.is_finished()), (d.pick_sequence.filter(func(c): return c == dead)).size(), d.pick_limit(dead), str(d.is_user_turn()), str(d.is_valid())])
	print("EDGE|  heir %s picks %d (limit %d); %d picks made in all of %d slots; invalid_reason '%s' / short '%s'" % [
			heir, (d.pick_history.filter(func(e): return e["club"] == heir)).size(), d.pick_limit(heir), d.pick_history.size(), d.pick_sequence.size(), d.invalid_reason(), d.short_positions()])
	var small: Array = cls.slice(0, 40)
	var d2 := Draft.build_intake(small, clubs.duplicate(), order, 3, base[0], base[1], base[2])
	var comps := [{"club": str(order[17]), "after": 3, "value": 5.0, "name": "A", "player": "x"},
			{"club": str(order[16]), "after": 3, "value": 2.0, "name": "B", "player": "y"},
			{"club": str(order[0]), "after": 39, "value": 1.0, "name": "C", "player": "z"}]
	d2.add_compensation(comps)
	d2.start_for_user("")
	var comp_made := 0
	for e in d2.comp_picks:
		var idx: int = int(e["index"])
		if idx < d2.pick_history.size() and str(d2.pick_history[idx]["club"]) == str(e["club"]):
			comp_made += 1
	var limit_sum := 0
	for code in clubs:
		limit_sum += d2.pick_limit(code)
	print("EDGE|pool 40, rounds %d, 3 compensation picks: slots %d, picks made %d, compensation picks made %d of 3, sum of pick_limit %d" % [
			d2.target_size, d2.pick_sequence.size(), d2.pick_history.size(), comp_made, limit_sum])
	var full_sizes := {}
	for code in clubs:
		full_sizes[code] = Ratings.LIST_SIZE
	var d3 := Draft.build_intake(cls, clubs.duplicate(), order, 3, full_sizes, base[1], base[2])
	d3.start_for_user("")
	print("EDGE|every club at 44: finished %s, picks made %d (should be 0), pool left %d" % [str(d3.is_finished()), d3.pick_history.size(), d3.remaining_pool()])
	var d4 := Draft.build_intake([], clubs.duplicate(), order, 3, base[0], base[1], base[2])
	d4.start_for_user("MEL")
	print("EDGE|empty pool: finished %s, rounds %d, sequence %d" % [str(d4.is_finished()), d4.target_size, d4.pick_sequence.size()])
	_save_load("real")
	_save_load("league")


func dbg() -> void:
	GameState.begin_real_lists()
	var clubs: Array = GameDB.active_clubs(GameDB.START_YEAR).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var cls: Array = Prospects.generate_class(2029, 3)
	var base: Array = _kept_from_real(clubs, false, rng)
	var d := Draft.build_intake(cls, clubs.duplicate(), clubs.duplicate(), 3, base[0], base[1], base[2])
	print("DBG|pool %d seq %d target %d budget %d sizes %s" % [d.pool.size(), d.pick_sequence.size(), d.target_size, d.budget, str(base[0])])
	for i in range(8):
		var code := d.current_club()
		var p := d._best_ai_pick(code)
		print("DBG|slot %d club %s full %s limit %d count %d best %s afford %s" % [d.pick_index, code, str(d._list_full(code)), d.pick_limit(code), d.count_for(code), str(p.get("id", "NONE")), str(d._can_afford_for(code, p)) if not p.is_empty() else "-"])
		if p.is_empty():
			print("DBG|usable cap %d reserve %d value0 %d" % [d.usable_cap_for(code), d.reserve_for(code), int(cls[0]["value"])])
			d._skip_current_pick()
		else:
			print("DBG|drafted %s" % str(d._draft_pick(code, p)))


func _sig(d: Draft) -> String:
	var parts := []
	for e in d.pick_history:
		parts.append("%d:%s:%s" % [int(e["pick"]), str(e["club"]), str(e["player_id"])])
	return ",".join(parts)


func _save_load(kind: String) -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	GameState.career_seed = 4
	GameState.replay_seed = 4
	if kind == "real":
		GameState.begin_real_lists()
		GameState.choose_real_club("MEL")
	else:
		GameState.begin_draft()
		GameState.draft.start_for_user("MEL")
	var d: Draft = GameState.draft
	var n := 0
	while n < 4 and not d.is_finished():
		if d.is_user_turn():
			for cand in d.board("", "", "", "overall", true):
				if d.can_pick_player(cand):
					d.pick(cand)
					n += 1
					break
		else:
			d.auto_until_user_turn()
	var at := d.pick_index
	var saved := GameState.save_career()
	_user_picks_best(d)
	var sig_live := _sig(d)
	var loaded := GameState.load_career()
	var d2: Draft = GameState.draft
	var ok_state := d2 != null and d2.pick_index == at and d2.user_club == "MEL"
	if d2 != null:
		_user_picks_best(d2)
	var sig_loaded := _sig(d2) if d2 != null else ""
	print("EDGE|save/load mid-draft (%s): saved %s loaded %s state restored %s (pick %d); same result after reload: %s (live %d picks, reloaded %d picks)" % [
			kind, str(saved), str(loaded), str(ok_state), at, str(sig_live == sig_loaded),
			d.pick_history.size(), d2.pick_history.size() if d2 != null else 0])


# ---------------------------------------------------------------------------
func summary() -> void:
	var keys := _acc.keys()
	keys.sort()
	for k in keys:
		print("SUM|%s|%.3f" % [k, float(_acc[k])])


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var part := str(args[1]) if args.size() > 1 else "league"
	var n := int(args[2]) if args.size() > 2 else 20
	GameState.reset()
	GameState.autosave_enabled = false
	match part:
		"league":
			league(n)
		"national":
			national(n, false)
			_pfx = "tight_"
			national(maxi(5, n / 3), true)
		"career":
			career(n, int(args[3]) if args.size() > 3 else 2)
		"edge":
			edge()
		"dbg":
			dbg()
	summary()
