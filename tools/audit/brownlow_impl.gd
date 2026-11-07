extends RefCounted
## Brownlow realism: who wins and who polls, over seeded home-and-away seasons
## through Season.play_round -> MatchSim, votes from Awards.tally_match (the game's
## own 3-2-1 rule). Set ratings (data/ovr_overrides.csv) are ON, as in a career:
## never run it with AFL_SKIP_OVR_ROWS=1.
##
## Args: mode first last.
##   real     the real 2026 lists, seasons first..last (season seed s * 7919 + 13)
##   drafted  a career draft per season (league_balance.drafted_lists(40 + s))
##   ratings  no matches: each set rating against his best line, unset players whose
##            best other line beats their overall by 5+, and generated rucks grown
##            five seasons (Prospects.age_player re-fits them each year)
##
##   godot --headless --path . --script tools/audit/run_audit.gd -- brownlow_impl real 1 20
##   python tools/audit/brownlow_report.py <log> [<log B>]
##
## Lines (| separated):
##   ROW  mode season id name club role role2 real_pos overall games votes polled
##        coaches influence_pg tackles pressure_acts hitouts stats alt
##        (every man who played; stats are k=v season totals of the influence terms;
##        alt is k=v votes he would have had under each ALT measure, same matches)
##   WIN  mode season id votes
##   WSH  mode season votes_to_winning_side all_votes   (drawn matches left out)
##   WSA  mode season alt_key votes_to_winning_side all_votes   (the same, per ALT)
##   VRD  mode season measure n sum_delta sum_delta_sq bins  (the coach's full-time
##        read of each man, influence less expected_influence at four quarters:
##        "old" is the pre-fit weights and expectation, "s<k>" the game's own
##        measure times k; bins split at the verdict edges 8 4 1 -1 -3 -6)
##   SET / UNSET / GEN / RSUM  (ratings mode)

## influence's weights before the umpires' fit; the season totals in ROW are these stats.
const COMP := {"disposals": 1.0, "goals": 5.0, "marks": 0.8, "inside50": 2.0, "tackles": 0.5,
		"pressure_acts": 0.3, "hitouts": 0.7, "clearances": 1.2, "one_percenters": 0.6, "clangers": -2.0}
## Other ways to give the 3-2-1, counted on the same matches for comparison only
## (the game's votes are Awards.tally_match's, on CoachReport.influence):
##   old     the weights influence had before the umpires' fit (COMP)
##   fitwin  the umpires' 2023-25 fit with the result in it
##           (tools/balance/afl_brownlow.json matches.vote_fit.with_result): a
##           player on the winning side gets won_in_disposals more
##   umpire  the fit without the result, drawn the way the fit says umpires vote
##           (Plackett-Luce, per_disposal_logit 0.1921 a unit) instead of always the
##           top three: the umpires' own unpredictability, seeded per season
const ALT := {
	"old": COMP,
	"fitwin": {"disposals": 1.0, "goals": 4.966, "marks": 0.272, "inside50": 0.294, "tackles": 0.275,
			"hitouts": 0.087, "clearances": 0.808, "one_percenters": 0.582, "clangers": 0.188, "won": 7.45},
	"umpire": {"disposals": 1.0, "goals": 5.412, "marks": 0.378, "inside50": 0.401, "tackles": 0.306,
			"hitouts": 0.079, "clearances": 0.864, "one_percenters": 0.631, "clangers": 0.104, "noise": 0.1921},
}
const VRD_EDGES := [8.0, 4.0, 1.0, -1.0, -3.0, -6.0]
const VRD_SCALES := [1.0, 1.2, 1.4, 1.6]
const LINES := ["MID", "DEF", "FWD", "RUCK"]
const GAP := 5


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[1]) if args.size() > 1 else "real"
	var first := int(args[2]) if args.size() > 2 else 1
	var last := int(args[3]) if args.size() > 3 else 20
	if GameDB.skip_ovr_overrides:
		push_error("brownlow_impl: AFL_SKIP_OVR_ROWS is set; set ratings must be on")
		return
	if mode == "ratings":
		_ratings()
		return
	var lb = load("res://tools/balance/league_balance.gd").new()
	var t0 := Time.get_ticks_msec()
	for s in range(first, last + 1):
		var lists: Dictionary = lb.real_lists() if mode == "real" else lb.drafted_lists(40 + s)["lists"]
		var codes: Array = lb.clubs()
		var players := {}
		for c in codes:
			for p in lists[c]:
				players[str(p["id"])] = p
		var season := Season.new(codes, lists, s * 7919 + 13)
		var tally := {}
		var alt := {}  # id -> {ALT key: votes}
		var comp := {}  # id -> {stat: season total}
		var win_votes := 0
		var all_votes := 0
		var vrd := {}
		var wsa := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 104729 + 7
		while not season.is_regular_done():
			for res in season.play_round():
				Awards.tally_match(tally, res, true)
				var st_all: Dictionary = res.get("players", {})
				for id in st_all:
					var c: Dictionary = comp.get(str(id), {})
					for k in COMP:
						c[k] = float(c.get(k, 0.0)) + float((st_all[id] as Dictionary).get(k, 0.0))
					comp[str(id)] = c
				for key in ALT:
					var wv := _alt_votes(alt, key, res, rng)
					if wv >= 0:
						var a: Array = wsa.get(key, [0, 0])
						wsa[key] = [int(a[0]) + wv, int(a[1]) + 6]
				_verdicts(vrd, res, players)
				var w := _vote_sides(res)
				if w[0] >= 0:
					win_votes += w[1]
					all_votes += 6
		var aw := Awards.season_awards(tally, players, 2027)
		for id in tally:
			var t: Dictionary = tally[id]
			var p: Dictionary = players.get(str(id), {})
			var c: Dictionary = comp.get(str(id), {})
			var parts := []
			for k in COMP:
				parts.append("%s=%.0f" % [k, float(c.get(k, 0.0))])
			var alts := []
			for key in ALT:
				alts.append("%s=%d" % [key, int((alt.get(str(id), {}) as Dictionary).get(key, 0))])
			print("ROW|%s|%d|%s|%s %s|%s|%s|%s|%s|%d|%d|%d|%d|%d|%.2f|%d|%d|%d|%s|%s" % [mode, s, str(id),
					str(p.get("first", "")), str(p.get("last", "")), str(t["club"]),
					str(p.get("role", "")), str(p.get("role2", "")), str(p.get("real_pos", "")),
					int(p.get("overall", 0)), int(t["games"]), int(t["votes"]), int(t["polled"]),
					int(t.get("coaches", 0)), float(t["influence"]) / float(maxi(1, int(t["games"]))),
					int(c.get("tackles", 0.0)), int(c.get("pressure_acts", 0.0)), int(c.get("hitouts", 0.0)),
					",".join(parts), ",".join(alts)])
		var wn: Dictionary = aw.get("brownlow_winner", {})
		print("WIN|%s|%d|%s|%d" % [mode, s, str(wn.get("id", "")), int(wn.get("votes", 0))])
		print("WSH|%s|%d|%d|%d" % [mode, s, win_votes, all_votes])
		for key in wsa:
			print("WSA|%s|%d|%s|%d|%d" % [mode, s, key, int(wsa[key][0]), int(wsa[key][1])])
		for key in vrd:
			var v: Dictionary = vrd[key]
			print("VRD|%s|%d|%s|%d|%.1f|%.1f|%s" % [mode, s, key, int(v["n"]), float(v["sum"]),
					float(v["sq"]), ",".join((v["bins"] as Array).map(func(x): return str(x)))])
		print("season %s %d done (%d s)" % [mode, s, (Time.get_ticks_msec() - t0) / 1000])


## [winning side (0/1, -1 for a draw), votes that side got], with the same top
## three Awards.tally_match picks (most influence on the ground).
static func _vote_sides(res: Dictionary) -> Array:
	var sc: Array = res.get("score", [0, 0])
	if int(sc[0]) == int(sc[1]):
		return [-1, 0]
	var won := 0 if int(sc[0]) > int(sc[1]) else 1
	var st_all: Dictionary = res.get("players", {})
	var roster: Array = res.get("roster", [])
	var everyone := []
	for side in range(mini(2, roster.size())):
		for r in roster[side]:
			everyone.append([side, CoachReport.influence(st_all.get(str(r["id"]), {}))])
	everyone.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var v := 0
	for i in range(mini(3, everyone.size())):
		if int(everyone[i][0]) == won:
			v += 3 - i
	return [won, v]


## The 3-2-1 of one match under ALT[key], added to alt[id][key]. Returns the
## votes the winning side got, or -1 for a draw.
static func _alt_votes(alt: Dictionary, key: String, res: Dictionary, rng: RandomNumberGenerator) -> int:
	var wt: Dictionary = ALT[key]
	var sc: Array = res.get("score", [0, 0])
	var st_all: Dictionary = res.get("players", {})
	var roster: Array = res.get("roster", [])
	var everyone := []
	for side in range(mini(2, roster.size())):
		var won := int(sc[side]) > int(sc[1 - side])
		for r in roster[side]:
			var st: Dictionary = st_all.get(str(r["id"]), {})
			var v := float(wt.get("won", 0.0)) if won else 0.0
			for k in wt:
				if k != "won" and k != "noise":
					v += float(wt[k]) * float(st.get(k, 0.0))
			everyone.append([str(r["id"]), v, won])
	everyone.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	if wt.has("noise"):
		everyone = _draw_three(everyone, float(wt["noise"]), rng)
	var to_winner := 0
	for i in range(mini(3, everyone.size())):
		var d: Dictionary = alt.get(everyone[i][0], {})
		d[key] = int(d.get(key, 0)) + (3 - i)
		alt[everyone[i][0]] = d
		if everyone[i][2]:
			to_winner += 3 - i
	return -1 if int(sc[0]) == int(sc[1]) else to_winner


## Three draws without replacement, each man's chance exp(noise x measure) of
## those left (Plackett-Luce): the 3, then the 2, then the 1.
static func _draw_three(everyone: Array, noise: float, rng: RandomNumberGenerator) -> Array:
	var left := everyone.duplicate()
	var out := []
	for _i in range(mini(3, left.size())):
		var top := float(left[0][1])
		var tot := 0.0
		for e in left:
			tot += exp(noise * (float(e[1]) - top))
		var x := rng.randf() * tot
		var pick := left.size() - 1
		for j in range(left.size()):
			x -= exp(noise * (float(left[j][1]) - top))
			if x <= 0.0:
				pick = j
				break
		out.append(left[pick])
		left.remove_at(pick)
	return out


## The coach's full-time read of every man in one match, added to vrd[measure].
static func _verdicts(vrd: Dictionary, res: Dictionary, players: Dictionary) -> void:
	var st_all: Dictionary = res.get("players", {})
	var roster: Array = res.get("roster", [])
	for side in range(mini(2, roster.size())):
		for r in roster[side]:
			var id := str(r["id"])
			var st: Dictionary = st_all.get(id, {})
			var ov := int((players.get(id, r) as Dictionary).get("overall", 50))
			var old := 0.0
			for k in COMP:
				old += float(COMP[k]) * float(st.get(k, 0.0))
			_vrd_add(vrd, "old", old - maxf(1.5, 4.5 + (float(ov) - 50.0) * 0.16) * 4.0)
			var d := (CoachReport.influence(st) - CoachReport.expected_influence(ov, 4)) / CoachReport.INFLUENCE_SCALE
			for k in VRD_SCALES:
				_vrd_add(vrd, "s%.1f" % k, d * float(k))


static func _vrd_add(vrd: Dictionary, key: String, d: float) -> void:
	var v: Dictionary = vrd.get(key, {"n": 0, "sum": 0.0, "sq": 0.0, "bins": [0, 0, 0, 0, 0, 0, 0]})
	v["n"] = int(v["n"]) + 1
	v["sum"] = float(v["sum"]) + d
	v["sq"] = float(v["sq"]) + d * d
	var b := 0
	while b < VRD_EDGES.size() and (d < float(VRD_EDGES[b]) if b < 3 else d <= float(VRD_EDGES[b])):
		b += 1
	(v["bins"] as Array)[b] = int((v["bins"] as Array)[b]) + 1
	vrd[key] = v


## His rating in each line: his own overall in his own line, else what his
## attributes make him there (Ratings.line_rating).
static func _lines(p: Dictionary) -> Dictionary:
	var out := {}
	for line in LINES:
		out[line] = int(round(Ratings.line_rating(p, line)))
	return out


static func _best_other(p: Dictionary, lines: Dictionary) -> Array:
	var best := ""
	var best_v := -1
	for line in LINES:
		if line != str(p.get("role", "")) and int(lines[line]) > best_v:
			best = line
			best_v = int(lines[line])
	return [best, best_v]


static func _set_rows() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://data/ovr_overrides.csv", FileAccess.READ)
	if f == null:
		return out
	f.get_line()
	while not f.eof_reached():
		var cells := f.get_line().split(",")
		if cells.size() >= 4:
			out["%s|%s|%s" % [cells[0].strip_edges(), cells[1].strip_edges(), cells[2].strip_edges()]] = cells[3].strip_edges()
	return out


func _ratings() -> void:
	var sets := _set_rows()
	var unset_n := {}
	var unset_gap := {}
	var unset_rows := []
	var seen := 0
	for code in GameDB.active_clubs(2027):
		for p in GameDB.club_list(code):
			var lines := _lines(p)
			var bo := _best_other(p, lines)
			var gap := int(bo[1]) - int(p.get("overall", 0))
			var key := "%s|%s|%s" % [code, str(p.get("first", "")), str(p.get("last", ""))]
			var role := str(p.get("role", ""))
			seen += 1
			if sets.has(key):
				print("SET|%s|%s %s|%s|%s|%d|%d|%d|%d|%d|%s|%d" % [code, str(p["first"]), str(p["last"]),
						role, str(sets[key]), int(p["overall"]), int(lines["MID"]), int(lines["DEF"]),
						int(lines["FWD"]), int(lines["RUCK"]), str(bo[0]), gap])
				continue
			unset_n[role] = int(unset_n.get(role, 0)) + 1
			if gap >= GAP:
				unset_gap[role] = int(unset_gap.get(role, 0)) + 1
				unset_rows.append([gap, "UNSET|%s|%s %s|%s|%d|%s|%d|%d" % [code, str(p["first"]), str(p["last"]),
						role, int(p["overall"]), str(bo[0]), int(bo[1]), gap]])
	unset_rows.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for r in unset_rows:
		print(r[1])
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		print("RSUM|unset|%s|%d|%d" % [role, int(unset_n.get(role, 0)), int(unset_gap.get(role, 0))])
	# Generated rucks, grown five seasons: each year's development re-fits every
	# attribute to his ruck rating (Prospects.age_player -> fit_attributes).
	Prospects.forget_cache()
	var n := 0
	var g := 0
	var gaps := []
	for y in range(2027, 2030):
		for q in Prospects.generate_class(y, 4242 + y):
			if str(q.get("role", "")) != "RUCK":
				continue
			for k in range(1, 6):
				Prospects.age_player(q, y + k)
			var lines := _lines(q)
			var bo := _best_other(q, lines)
			var gap := int(bo[1]) - int(q.get("overall", 0))
			n += 1
			gaps.append(gap)
			if gap >= GAP:
				g += 1
				print("GEN|%d|%s|%d|%s|%d|%d" % [y, str(q.get("id", "")),
						int(q["overall"]), str(bo[0]), int(bo[1]), gap])
	gaps.sort()
	print("RSUM|generated_ruck_5y|RUCK|%d|%d|median_gap=%d" % [n, g, int(gaps[gaps.size() / 2]) if gaps.size() > 0 else 0])
	print("ratings done: %d listed players" % seen)
