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

var start := ""


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
		var sim := MatchSim.new(sq_h, sq_a, 500000 + i)
		sim.weather = weather
		for k in sets:
			if not str(k) in sim:
				push_error("balance: MatchSim has no var " + str(k))
				return 1
			sim.set(str(k), float(sets[k]))
		var r: Dictionary = sim.run()
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
		for ev in r["events"]:
			var kind := str((ev as Dictionary).get("kind", ""))
			if kind == "ballup":
				ball_ups += 1
			elif kind == "throwin":
				throw_ins += 1
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
			_shot_counts(t, sim.shot_log, side)
			t["strength"] = snappedf((sq_h if side == 0 else sq_a).strength(), 0.01)
			q_score[side][3] = int(r["score"][side])
			t["q_score"] = q_score[side]
			t["roles"] = role_lines(rosters[side], r["players"])
			t["types"] = type_lines(rosters[side], r["players"])
			t["type_src"] = srcs[side]
			t["carry_zone"] = (sim.carry_log[side] as Dictionary).duplicate()
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
			t["club"] = h if side == 0 else a
			t["ruck1"] = ruck1(r["roster"][side], stats, sq_h if side == 0 else sq_a)
			teams.append(t)
		var line := JSON.stringify({"i": i, "home": h, "away": a, "teams": teams, "duels": duels(sim, r)})
		fh.store_line(line)
		if echo:
			print("BAL " + line)
	fh.close()
	return 0


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


const ROLE_STATS := ["disposals", "kicks", "handballs", "marks", "rebounds", "inside50", "clearances", "goals"]


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
	return out
