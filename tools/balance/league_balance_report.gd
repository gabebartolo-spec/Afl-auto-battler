extends SceneTree
## Competitive-balance measurement runner. Instrumentation only: see
## tools/balance/league_balance.gd and docs/LEAGUE_BALANCE.md.
##
## Run a seeded shard (writes raw rows to JSON):
##   godot --headless --path . --script tools/balance/league_balance_report.gd -- \
##       --source drafted --leagues 11,12,13 --seasons 3 --out drafted_a.json
##   --source real        --seasons 12 [--season-base 900000]
##   --source career      --leagues 11,12 (one season each, via GameState)
##   --source sensitivity --leagues 11,12 --ks 0,1,2,3,4,6,8,10 --reps 3
## Drafted/career/sensitivity leagues take --policy board|ai (default board)
## and --top-n N (default 5): how your club drafts (league_balance.gd).
## Merge shards into one report (markdown on stdout, and --md <file>):
##   godot ... --script tools/balance/league_balance_report.gd -- \
##       --report drafted_a.json,real.json,... [--md report.md]
##
## Seeds: a drafted league is the real all-AI career draft with seed L;
## its season s (0-based) uses season seed L * 1000 + s + 1. The real-list
## league's season s uses --season-base + s + 1. Sensitivity match seeds are
## L * 7919 + rep * 100003 + opponent * 211 + venue.

var LB
var _t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _ints(s: String) -> Array:
	var out := []
	for x in s.split(",", false):
		out.append(int(x))
	return out


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	LB = load("res://tools/balance/league_balance.gd").new()
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://balance_probe.save"
	gs.settings_path = "user://balance_probe.cfg"
	gs.set_new_career_difficulty("normal")
	var args := _args()
	if args.has("report"):
		var md := build_report(str(args["report"]).split(",", false))
		print(md)
		if args.has("md"):
			var f := FileAccess.open(str(args["md"]), FileAccess.WRITE)
			f.store_string(md)
			f.close()
		quit(0)
		return
	var source := str(args.get("source", "drafted"))
	var seasons := int(args.get("seasons", "1"))
	var leagues := _ints(str(args.get("leagues", "")))
	var policy := str(args.get("policy", "board"))
	var top_n := int(args.get("top-n", "5"))
	var out := {"source": source, "seasons": [], "sensitivity": [],
			"args": str(OS.get_cmdline_user_args())}
	match source:
		"drafted":
			for L in leagues:
				var dr: Dictionary = LB.drafted_lists(int(L), policy, top_n)
				for s in range(seasons):
					var seed := int(L) * 1000 + s + 1
					out["seasons"].append(LB.play_engine_season(dr["lists"], seed,
							{"source": "drafted", "policy": policy, "top_n": top_n, "league": str(L),
							"season_seed": seed, "sig": dr["sig"], "user_club": dr["user_club"]}))
					print("drafted league %d season %d done (%ds)" % [L, s, _secs()])
		"real":
			var base := int(args.get("season-base", "900000"))
			var lists: Dictionary = LB.real_lists()
			for s in range(seasons):
				var seed := base + s + 1
				out["seasons"].append(LB.play_engine_season(lists, seed,
						{"source": "real", "league": "real", "season_seed": seed}))
				print("real season %d done (%ds)" % [s, _secs()])
		"career":
			for L in leagues:
				var seed := int(L) * 1000 + 1
				out["seasons"].append(LB.play_career_season(int(L), seed, policy, top_n,
						{"source": "career", "policy": policy, "top_n": top_n, "league": str(L),
						"season_seed": seed}))
				print("career league %d done (%ds)" % [L, _secs()])
		"sensitivity":
			var ks := _ints(str(args.get("ks", "0,1,2,3,4,6,8,10")))
			var reps := int(args.get("reps", "3"))
			for L in leagues:
				var lists: Dictionary = LB.drafted_lists(int(L), policy, top_n)["lists"]
				var subject: String = LB.median_club(lists)
				out["sensitivity"].append_array(LB.sensitivity(lists, subject, ks, reps,
						int(L) * 7919, {"league": str(L), "policy": policy}))
				print("sensitivity league %d (%s) done (%ds)" % [L, subject, _secs()])
	out["runtime_s"] = _secs()
	var path := str(args.get("out", "user://league_balance_%s.json" % source))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote %s in %ds" % [path, _secs()])
	quit(0)


func _secs() -> int:
	return int((Time.get_ticks_msec() - _t0) / 1000)


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
func _load(paths: Array) -> Dictionary:
	var seasons := []
	var sens := []
	var runtime := 0.0
	for p in paths:
		var f := FileAccess.open(str(p), FileAccess.READ)
		if f == null:
			push_error("cannot read %s" % p)
			continue
		var d = JSON.parse_string(f.get_as_text())
		f.close()
		if not (d is Dictionary):
			continue
		seasons.append_array(d.get("seasons", []))
		sens.append_array(d.get("sensitivity", []))
		runtime += float(d.get("runtime_s", 0.0))
	return {"seasons": seasons, "sensitivity": sens, "runtime": runtime}


func _signed(x: float) -> String:
	return ("+%.1f" % x) if x >= 0.0 else ("%.1f" % x)


func _pct(x: float) -> String:
	return "%.1f%%" % (100.0 * x)


func _ci(k: float, n: float) -> String:
	var w: Array = LB.wilson(k, n)
	return "%.1f%% (%.1f–%.1f)" % [100.0 * k / maxf(1.0, n), 100.0 * float(w[0]), 100.0 * float(w[1])]


func build_report(paths: Array) -> String:
	var data := _load(paths)
	var md := "# League competitive-balance report\n\n"
	md += "Shards: %s  \nTotal shard runtime: %.0f s (sum over shards)\n\n" % [", ".join(paths), float(data["runtime"])]
	var by_source := {}
	for s in data["seasons"]:
		var src := str(s["source"])
		if src != "real":
			src += "/" + str(s.get("policy", "ai"))
		if not by_source.has(src):
			by_source[src] = []
		(by_source[src] as Array).append(s)
	for src in ["drafted/board", "drafted/ai", "real", "career/board", "career/ai"]:
		if by_source.has(src):
			md += _source_section(src, by_source[src])
	md += _benchmark_section()
	var by_policy := {}
	for r in data["sensitivity"]:
		var pol := str(r.get("policy", "ai"))
		if not by_policy.has(pol):
			by_policy[pol] = []
		(by_policy[pol] as Array).append(r)
	for pol in by_policy:
		md += _sensitivity_section(by_policy[pol], str(pol))
	return md


func _source_section(src: String, seasons: Array) -> String:
	var titles := {"drafted/board": "Drafted league: career draft, your picks by the board policy (Season/MatchSim)",
			"drafted/ai": "Drafted league: all-AI career draft (Season/MatchSim)",
			"real": "Real 2026 club lists (Season/MatchSim)",
			"career/board": "Career first season: board-policy draft through GameState.advance",
			"career/ai": "Career first season: all-AI draft through GameState.advance"}
	var md := "## %s\n\n" % titles.get(src, src)
	var leagues := {}
	var sigs := {}
	for s in seasons:
		leagues[str(s["league"])] = true
		if s.has("sig"):
			sigs[str(s["sig"])] = true
	md += "Draft seeds: %d; seasons: %d (%s)\n\n" % [leagues.size(), seasons.size(),
			", ".join(leagues.keys()) if src != "real" else "one list set"]
	if not sigs.is_empty():
		md += "Distinct leagues (same 18 lists regardless of club names count once): %d\n\n" % sigs.size()

	# --- preseason strength distribution (per league, first season) -------
	var spread := []; var sdv := []; var ospread := []; var osd := []
	var seen := {}
	for s in seasons:
		var lg := str(s["league"])
		if seen.has(lg):
			continue
		seen[lg] = true
		var st := []; var ov := []
		for c in s["clubs"]:
			st.append(float(c["strength"])); ov.append(float(c["ovr22"]))
		st.sort(); ov.sort()
		spread.append(st[st.size() - 1] - st[0]); sdv.append(LB.sd(st))
		ospread.append(ov[ov.size() - 1] - ov[0]); osd.append(LB.sd(ov))
	md += "### Preseason strength distribution (per league)\n\n"
	md += "| Measure | Mean | Min | Max |\n|---|---|---|---|\n"
	for row in [["Squad.strength spread (strongest − weakest)", spread],
			["Squad.strength SD across clubs", sdv],
			["Selected-22 mean OVR spread", ospread],
			["Selected-22 mean OVR SD across clubs", osd]]:
		var xs: Array = row[1]
		md += "| %s | %.2f | %.2f | %.2f |\n" % [row[0], LB.mean(xs), xs.min(), xs.max()]
	md += "\n"

	# --- match level (home and away only) ----------------------------------
	var n := 0; var draws := 0; var home_w := 0; var decided := 0
	var fav_w := 0; var fav_n := 0; var ofav_w := 0; var ofav_n := 0
	var margins := []
	var gb := {}; var ogb := {}
	for s in seasons:
		for m in s["matches"]:
			if str(m["final"]) != "":
				continue
			n += 1
			var mg := int(m["hs"]) - int(m["as"])
			margins.append(absi(mg))
			if mg == 0:
				draws += 1
				continue
			decided += 1
			if mg > 0:
				home_w += 1
			var gap := absf(float(m["sh"]) - float(m["sa"]))
			if gap > 0.0:
				var fav_home := float(m["sh"]) > float(m["sa"])
				var won := (mg > 0) == fav_home
				fav_n += 1
				fav_w += 1 if won else 0
				_bucket(gb, LB.GAP_BUCKETS, gap, won)
			var ogap := absf(float(m["oh"]) - float(m["oa"]))
			if ogap > 0.0:
				var ofav_home := float(m["oh"]) > float(m["oa"])
				var owon := (mg > 0) == ofav_home
				ofav_n += 1
				ofav_w += 1 if owon else 0
				_bucket(ogb, LB.OVR_GAP_BUCKETS, ogap, owon)
	md += "### Match outcomes (home and away, n = %d)\n\n" % n
	md += "| Measure | Value (95% CI) |\n|---|---|\n"
	md += "| Home win (decided games) | %s |\n" % _ci(home_w, decided)
	md += "| Draw rate | %s |\n" % _ci(draws, n)
	md += "| Stronger side wins (Squad.strength, decided) | %s |\n" % _ci(fav_w, fav_n)
	md += "| Stronger side wins (selected-22 OVR, decided) | %s |\n\n" % _ci(ofav_w, ofav_n)
	md += "Favourite win rate by preseason gap:\n\n| Squad.strength gap | Fav wins | n | | Selected-22 OVR gap | Fav wins | n |\n|---|---|---|---|---|---|---|\n"
	for i in range(LB.GAP_BUCKETS.size() - 1):
		var b: Array = gb.get(i, [0, 0])
		var ob: Array = ogb.get(i, [0, 0])
		md += "| %s | %s | %d | | %s | %s | %d |\n" % [_range_label(LB.GAP_BUCKETS, i), _ci(b[0], b[1]) if b[1] > 0 else "-", b[1],
				_range_label(LB.OVR_GAP_BUCKETS, i), _ci(ob[0], ob[1]) if ob[1] > 0 else "-", ob[1]]
	md += "\n" + _margin_table(margins) + "\n"

	# --- season outcomes -----------------------------------------------------
	var r_w := []; var r_pct := []; var rho := []
	var cx := []; var cy := []
	var rank_prem := {}; var rank_fin := {}; var rank_spoon := {}
	for s in seasons:
		var st := []; var w := []; var pc := []; var lad := []
		for c in s["clubs"]:
			st.append(float(c["strength"])); w.append(float(c["w"]) + 0.5 * float(c["d"]))
			pc.append(float(c["pct"])); lad.append(-float(c["ladder"]))
			var rk := int(c["strength_rank"])
			rank_prem[rk] = int(rank_prem.get(rk, 0)) + (1 if bool(c["premier"]) else 0)
			rank_fin[rk] = int(rank_fin.get(rk, 0)) + (1 if bool(c["finals"]) else 0)
			rank_spoon[rk] = int(rank_spoon.get(rk, 0)) + (1 if bool(c["spoon"]) else 0)
		r_w.append(LB.pearson(st, w)); r_pct.append(LB.pearson(st, pc)); rho.append(LB.spearman(st, lad))
		var ms: float = LB.mean(st)
		for i in range(st.size()):
			cx.append(float(st[i]) - ms); cy.append(w[i])
	var r2: float = pow(LB.pearson(cx, cy), 2.0)
	md += "### Preseason strength → season outcome\n\n"
	md += "| Measure (per season, mean ± SD across seasons) | Value |\n|---|---|\n"
	md += "| Pearson r: Squad.strength vs wins | %.2f ± %.2f |\n" % [LB.mean(r_w), LB.sd(r_w)]
	md += "| Pearson r: Squad.strength vs percentage | %.2f ± %.2f |\n" % [LB.mean(r_pct), LB.sd(r_pct)]
	md += "| Spearman ρ: strength rank vs ladder position | %.2f ± %.2f |\n" % [LB.mean(rho), LB.sd(rho)]
	md += "| Pooled R² of wins on league-centred strength | %.2f |\n\n" % r2
	md += _decomposition(seasons)
	if src == "drafted/board":
		md += _without_user(seasons)
	md += "Outcome frequency by preseason strength rank (1 = strongest):\n\n| Rank | Premiership | Finals (top %d) | Wooden spoon |\n|---|---|---|---|\n" % int(LB.FINALISTS)
	var ns := float(seasons.size())
	var max_rank := 0
	for k in rank_prem:
		max_rank = maxi(max_rank, int(k))
	for rk in range(1, max_rank + 1):
		md += "| %d | %s | %s | %s |\n" % [rk, _pct(float(rank_prem.get(rk, 0)) / ns),
				_pct(float(rank_fin.get(rk, 0)) / ns), _pct(float(rank_spoon.get(rk, 0)) / ns)]
	md += "\n(Each rank has %d club-seasons: one per season.)\n\n" % seasons.size()
	if src.begins_with("career") or src == "drafted/board":
		md += _user_club_lines(seasons)
	return md


## Skill share of season wins: the same lists replayed with different
## season seeds. Within-club variance is luck; the variance of club means
## beyond what that luck predicts is skill.
func _decomposition(seasons: Array) -> String:
	var by_league := {}
	for s in seasons:
		var lg := str(s["league"])
		if not by_league.has(lg):
			by_league[lg] = []
		(by_league[lg] as Array).append(s)
	var within_all := []; var skill_all := []; var shares := []
	for lg in by_league:
		var ss: Array = by_league[lg]
		if ss.size() < 2:
			continue
		var per_club := {}
		for s in ss:
			for c in s["clubs"]:
				var code := str(c["club"])
				if not per_club.has(code):
					per_club[code] = []
				(per_club[code] as Array).append(float(c["w"]) + 0.5 * float(c["d"]))
		var within := 0.0
		var means := []
		for code in per_club:
			var ws: Array = per_club[code]
			within += pow(LB.sd(ws), 2.0)
			means.append(LB.mean(ws))
		within /= float(per_club.size())
		var between: float = pow(LB.sd(means), 2.0)
		var skill := maxf(0.0, between - within / float(ss.size()))
		within_all.append(within); skill_all.append(skill)
		shares.append(skill / maxf(0.0001, skill + within))
	if shares.is_empty():
		return "Skill/luck decomposition needs 2+ seasons per league (not in this sample).\n\n"
	var md := "Skill vs luck (same lists replayed with new season seeds; %d leagues with 2+ seasons):\n\n" % shares.size()
	md += "| Measure | Value |\n|---|---|\n"
	md += "| Luck SD of a club's season wins (within-club) | %.2f wins |\n" % sqrt(LB.mean(within_all))
	md += "| Skill SD (between-club, net of luck) | %.2f wins |\n" % sqrt(LB.mean(skill_all))
	md += "| Share of season-win variance that is skill | %s (per league: %.0f–%.0f%%) |\n\n" % [
			_pct(LB.mean(skill_all) / maxf(0.0001, LB.mean(skill_all) + LB.mean(within_all))),
			100.0 * shares.min(), 100.0 * shares.max()]
	return md


## The board-policy drafter is one deliberately simple human; the same
## measures over the 17 AI-drafted clubs only (matches involving your club
## and your club's rows removed).
func _without_user(seasons: Array) -> String:
	var trimmed := []
	var fav_w := 0
	var fav_n := 0
	for s in seasons:
		var user := str(s.get("user_club", ""))
		var t: Dictionary = s.duplicate()
		var rows := []
		for c in s["clubs"]:
			if str(c["club"]) != user:
				rows.append(c)
		t["clubs"] = rows
		trimmed.append(t)
		for m in s["matches"]:
			if str(m["final"]) != "" or str(m["h"]) == user or str(m["a"]) == user:
				continue
			var mg := int(m["hs"]) - int(m["as"])
			if mg == 0 or is_equal_approx(float(m["sh"]), float(m["sa"])):
				continue
			fav_n += 1
			fav_w += 1 if (mg > 0) == (float(m["sh"]) > float(m["sa"])) else 0
	var st_sd := []
	var r_w := []
	for t in trimmed:
		var st := []
		var w := []
		for c in t["clubs"]:
			st.append(float(c["strength"]))
			w.append(float(c["w"]) + 0.5 * float(c["d"]))
		st_sd.append(LB.sd(st))
		r_w.append(LB.pearson(st, w))
	var md := "Excluding your (board-policy) club - the 17 AI-drafted clubs only:\n\n| Measure | Value |\n|---|---|\n"
	md += "| Squad.strength SD across clubs (mean) | %.2f |\n" % LB.mean(st_sd)
	md += "| Stronger side wins (Squad.strength, decided, AI v AI) | %s |\n" % _ci(fav_w, fav_n)
	md += "| Pearson r: Squad.strength vs wins | %.2f ± %.2f |\n\n" % [LB.mean(r_w), LB.sd(r_w)]
	md += _decomposition(trimmed).replace("Skill vs luck", "Skill vs luck, AI-drafted clubs only")
	return md


func _user_club_lines(seasons: Array) -> String:
	var md := "Your club (the board-policy drafter; with policy ai, the first pick of the order):\n\n| Draft seed | Season seed | Club | Strength rank | Ladder | Wins |\n|---|---|---|---|---|---|\n"
	for s in seasons:
		for c in s["clubs"]:
			if str(c["club"]) == str(s.get("user_club", "")):
				md += "| %s | %d | %s | %d | %d | %d |\n" % [s["league"], int(s["season_seed"]), c["club"], int(c["strength_rank"]), int(c["ladder"]), int(c["w"])]
	return md + "\n"


func _bucket(b: Dictionary, edges: Array, gap: float, won: bool) -> void:
	for i in range(edges.size() - 1):
		if gap >= float(edges[i]) and gap < float(edges[i + 1]):
			var e: Array = b.get(i, [0, 0])
			e[0] += 1 if won else 0
			e[1] += 1
			b[i] = e
			return


func _range_label(edges: Array, i: int) -> String:
	if float(edges[i + 1]) >= 999.0:
		return "%s+" % str(edges[i])
	return "%s–%s" % [str(edges[i]), str(edges[i + 1])]


func _margin_table(margins: Array) -> String:
	var n := float(margins.size())
	var c := {40: 0, 60: 0, 80: 0, 100: 0}
	for m in margins:
		for t in c:
			if int(m) >= int(t):
				c[t] = int(c[t]) + 1
	var md := "| Margin measure | Value |\n|---|---|\n"
	md += "| Mean / median / 90th percentile | %.1f / %.0f / %.0f |\n" % [LB.mean(margins), LB.percentile(margins, 0.5), LB.percentile(margins, 0.9)]
	for t in [40, 60, 80, 100]:
		md += "| %d+ points | %s |\n" % [t, _ci(c[t], n)]
	return md


# ---------------------------------------------------------------------------
# Real AFL benchmark (data/raw/*_2026.json)
# ---------------------------------------------------------------------------
func _benchmark_section() -> String:
	var md := "## Real AFL 2026 benchmark (data/raw)\n\n"
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/fixtures_2026.json"))
	var games: Array = fx.get("games", []) if fx is Dictionary else (fx if fx is Array else [])
	var margins := []; var draws := 0; var home_w := 0; var decided := 0
	for g in games:
		if int(g.get("complete", 0)) != 100 or bool(g.get("is_final", 0)):
			continue
		var m := int(g["hscore"]) - int(g["ascore"])
		margins.append(absi(m))
		if m == 0:
			draws += 1
		else:
			decided += 1
			home_w += 1 if m > 0 else 0
	md += "Home and away games: %d\n\n| Measure | Value |\n|---|---|\n" % margins.size()
	md += "| Home win (decided) | %s |\n| Draw rate | %s |\n" % [_ci(home_w, decided), _ci(draws, margins.size())]
	md += _margin_table(margins).replace("| Margin measure | Value |\n|---|---|\n", "")
	var st = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/standings_2026.json"))
	var rows: Array = st if st is Array else st.get("standings", [])
	var wins := []
	var games_played := 0
	for r in rows:
		wins.append(float(r["wins"]) + 0.5 * float(r.get("draws", 0)))
		games_played = int(r["played"])
	var luck := sqrt(float(games_played) * 0.25)
	var total: float = LB.sd(wins)
	var skill := sqrt(maxf(0.0, total * total - luck * luck))
	md += "\nSeason wins (%d games): SD across clubs %.2f; coin-flip luck alone would give %.2f, so skill SD ≈ %.2f and the skill share ≈ %s (one season: a rough estimate).\n\n" % [
			games_played, total, luck, skill, _pct(skill * skill / maxf(0.0001, total * total))]
	# How well does the engine's strength metric rank the real clubs?
	var real_ratings: Dictionary = LB.club_ratings(LB.real_lists(), LB.clubs())
	var names := {}
	var db = root.get_node("GameDB")
	for c in LB.clubs():
		names[db.club_name(c)] = c
		names["%s %s" % [db.club_name(c), db.club_short(c)]] = c
	var xs := []; var ys := []
	for r in rows:
		var code := str(names.get(str(r["name"]), ""))
		if code != "":
			xs.append(float(real_ratings[code]["strength"])); ys.append(float(r["wins"]))
	md += "Squad.strength of the real 2026 lists vs the real 2026 wins (%d clubs): Pearson r = %.2f.\n\n" % [xs.size(), LB.pearson(xs, ys)]
	return md


# ---------------------------------------------------------------------------
# Sensitivity
# ---------------------------------------------------------------------------
func _sensitivity_section(rows: Array, policy: String) -> String:
	var ks := {}
	var leagues := {}
	for r in rows:
		ks[int(r["k"])] = true
		leagues["%s/%s" % [r["league"], r["subject"]]] = true
	var kl := ks.keys()
	kl.sort()
	var base := {}
	for r in rows:
		if int(r["k"]) == 0:
			base["%s|%s|%s|%s" % [r["league"], r["opp"], str(r["home"]), r["rep"]]] = int(r["margin"])
	var md := "## Controlled sensitivity (%s-policy drafted leagues): one club's whole list shifted by +k OVR\n\n" % policy
	md += "Subjects (median-strength club of each drafted league): %s. Every k plays the same opponents at the same venues with the same seeds.\n\n" % ", ".join(leagues.keys())
	md += "| +k OVR | Sel-22 OVR | Strength | Win % (95% CI) | Home win % | Away win % | Mean margin ± SE | Δ margin vs k=0 ± SE (paired) | n |\n|---|---|---|---|---|---|---|---|---|\n"
	for k in kl:
		var w := 0.0; var n := 0.0; var hw := 0.0; var hn := 0.0; var aw := 0.0; var an := 0.0
		var ms := []; var deltas := []; var ovr := []; var stg := []
		for r in rows:
			if int(r["k"]) != int(k):
				continue
			var m := int(r["margin"])
			var pts := 1.0 if m > 0 else (0.5 if m == 0 else 0.0)
			w += pts; n += 1.0
			if bool(r["home"]):
				hw += pts; hn += 1.0
			else:
				aw += pts; an += 1.0
			ms.append(m)
			ovr.append(float(r["ovr22"])); stg.append(float(r["strength"]))
			var key := "%s|%s|%s|%s" % [r["league"], r["opp"], str(r["home"]), r["rep"]]
			if base.has(key):
				deltas.append(m - int(base[key]))
		md += "| +%d | %.1f | %.1f | %s | %s | %s | %s ± %.1f | %s ± %.1f | %d |\n" % [
				int(k), LB.mean(ovr), LB.mean(stg), _ci(w, n), _pct(hw / maxf(1.0, hn)), _pct(aw / maxf(1.0, an)),
				_signed(LB.mean(ms)), LB.sd(ms) / sqrt(maxf(1.0, float(ms.size()))),
				_signed(LB.mean(deltas)), LB.sd(deltas) / sqrt(maxf(1.0, float(deltas.size()))), int(n)]
	md += "\n(Draws count as half a win.)\n\n"
	return md
