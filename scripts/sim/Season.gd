class_name Season
extends RefCounted
## A 24-round home-and-away season plus a full AFL finals series.
##
## Fixture (build_fixture): 24 rounds and the same number of games for every
## club. 18 or 20 clubs: one bye and 23 games each, as in a real season. 19
## clubs (Tasmania, 2028-29): two byes and 22 games each. Home games within
## one of half for everyone; byes and repeat opponents fall by the season seed.
##
## Finals (10 finalists):
##   Week 1  Wildcard: WC1 7v10, WC2 8v9
##   Week 2  QF1 1v4, QF2 2v3, EF1 5v(W_WC2), EF2 6v(W_WC1) - the wildcard
##           winners are reseeded as the 7th and 8th seeds by their original
##           ladder position
##   Week 3  SF: QF losers v EF winners
##   Week 4  PF: QF winners v SF winners
##   Week 5  GF

const REGULAR_ROUNDS := 24
const FINALISTS := 10
## The Grand Final is always played here, whichever clubs make it.
const GRAND_FINAL_VENUE := "MCG"

var clubs: Array = []          # club codes
var lists := {}                # code -> Array of player dicts
var fixture: Array = []        # Array of rounds; each round is Array of matches
var results: Array = []        # played rounds, in order
var ladder := {}               # code -> ladder row
var round_index := 0           # next regular round to play
var seed := 0
var finals := {}               # finals series state, empty until started
var selections := {}           # code -> chosen match-day side (empty = auto)
var plans := {}                # code -> standing game plan (absent = balanced)
var matchups := {}             # code -> {their forward id: your defender id} (Matchups)


func _init(club_codes: Array, club_lists: Dictionary, p_seed: int = 0) -> void:
	clubs = club_codes.duplicate()
	# Keep only this season's clubs. Callers build `club_lists` for every
	# club that will ever exist, and the offseason, contracts and free-agent
	# passes iterate `lists` - a phantom entry for a club that has not
	# entered yet would let rivals "sign" free agents into it and silently
	# pre-fill the expansion club's debut list (skipping its generation).
	lists = {}
	for c in clubs:
		lists[c] = club_lists.get(c, [])
	seed = p_seed
	ladder = {}
	for c in clubs:
		ladder[c] = {"code": c, "p": 0, "w": 0, "l": 0, "d": 0,
				"pf": 0, "pa": 0, "pts": 0, "pct": 0.0}
	fixture = build_fixture()


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
## Circle method: hold one club still and rotate the rest, giving a full
## round-robin in n-1 rounds. An odd club count (expansion) adds a virtual
## BYE to the rotation, so every club still meets every other exactly once.
static func round_robin(codes: Array) -> Array:
	var n := codes.size()
	var rot := codes.duplicate()
	if n % 2 == 1:
		rot.append("BYE")
		n += 1
	var rounds := []
	for r in range(n - 1):
		var matches := []
		for i in range(n / 2):
			var a: String = rot[i]
			var b: String = rot[n - 1 - i]
			if a == "BYE" or b == "BYE":
				continue
			# Alternate venue by round and pairing so no club is permanently
			# home or away against a given opponent.
			if (r + i) % 2 == 0:
				matches.append({"home": a, "away": b})
			else:
				matches.append({"home": b, "away": a})
		rounds.append(matches)
		var last = rot.pop_back()
		rot.insert(1, last)
	return rounds


## The most clubs the fair fixture handles (a created club can make 19, 20
## or 21 in any year); more falls back to the old builder.
const FAIR_FIXTURE_MAX := 21


## Every club plays the same number of games, home and away within one game
## of half, and byes and repeat opponents fall by the season seed - not by a
## club's place in the list, and the same for your club as for any other.
##  - 18 or 20 clubs: 23 games and one bye each, as in a real 24-round
##    season. 19 or 21: 22 games and two byes (n x 23 is odd for an odd
##    count, so 23 each cannot be done).
##  - a round-robin, then a seeded choice of its rounds again (return
##    games). At an odd count the clubs those return rounds rest are paired
##    off with each other; at an even count no one needs it.
##  - the rounds go in a seeded order, then matches move into the thin
##    round until no round is more than one match short (21 clubs: fifteen
##    rounds of ten and nine of nine). No round thinned in round 1 or the
##    last two, and a club's two byes apart where the rounds allow it.
##  - venues: a pair met twice plays once at each ground; the pairs met once
##    are oriented along an Euler circuit, so every club is home in half of
##    them (within one game).
func build_fixture() -> Array:
	if clubs.size() > FAIR_FIXTURE_MAX or clubs.size() < 2:
		return _legacy_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fixture", seed, clubs.size()])
	var order := _shuffled(clubs, rng)
	# Pairings only first: [[a, b], ...] a round.
	var base := []
	for r in round_robin(order):
		base.append(r.map(func(m): return [str(m["home"]), str(m["away"])]))
	var target := REGULAR_ROUNDS - 1 if clubs.size() % 2 == 0 else REGULAR_ROUNDS - 2
	var picks := _shuffled(range(base.size()), rng)
	var rounds := []
	for r in base:
		rounds.append((r as Array).duplicate())
	var rested := []
	# Each club meets every other once (n - 1 games), then the return rounds.
	for k in range(target - (clubs.size() - 1)):
		var again: Array = (base[picks[k % picks.size()]] as Array).duplicate()
		rounds.append(again)
		var playing := {}
		for m in again:
			playing[m[0]] = true
			playing[m[1]] = true
		for c in clubs:
			if not playing.has(c):
				rested.append(str(c))
	# The last round: the rested clubs of the return rounds, paired off.
	var spare := []
	rested = _shuffled(rested, rng)
	for i in range(0, rested.size() - 1, 2):
		if rested[i] != rested[i + 1]:
			spare.append([rested[i], rested[i + 1]])
	# A seeded order of rounds; of a few, the one with fewest clubs resting
	# in back-to-back rounds (an odd count rests twice).
	var best := []
	var best_near := 1 << 30
	for attempt in range(12):
		var order_r := _shuffled(rounds, rng)
		if not spare.is_empty() or order_r.size() < REGULAR_ROUNDS:
			order_r.insert(rng.randi_range(1, maxi(1, order_r.size() - 2)), spare.duplicate())
		var near := 0
		var rests := _rests(order_r)
		for c in rests:
			var rs: Array = rests[c]
			for i in range(1, rs.size()):
				if int(rs[i]) - int(rs[i - 1]) <= 1:
					near += 1
		if near < best_near:
			best = order_r
			best_near = near
		if near == 0:
			break
	rounds = best
	return _assign_venues(_level_rounds(rounds, rng), rng)


func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## No round more than one match short of full: a match moves from a full
## round into a thinner one where both clubs are free. Its clubs then rest
## in the round it left: never round 1 or the last two, and apart from a
## club's other rest where any move allows it.
func _level_rounds(rounds: Array, rng: RandomNumberGenerator) -> Array:
	var full := clubs.size() / 2
	var last := rounds.size() - 2
	while true:
		var ti := -1
		for i in range(rounds.size()):
			if (rounds[i] as Array).size() < full - 1:
				ti = i
				break
		if ti < 0:
			break
		var busy := {}
		for m in rounds[ti]:
			busy[m[0]] = true
			busy[m[1]] = true
		var rests := _rests(rounds)
		var best := []
		# Byes apart and away from round 1 and the last two first; anywhere
		# when nothing else moves.
		for pass_i in range(3):
			var apart := pass_i == 0
			var span := range(rounds.size()) if pass_i == 2 else range(1, last)
			for fi in _shuffled(span, rng):
				if fi == ti or (rounds[fi] as Array).size() < full:
					continue
				for mi in range((rounds[fi] as Array).size()):
					var m: Array = rounds[fi][mi]
					if busy.has(m[0]) or busy.has(m[1]):
						continue
					var near := false
					if apart:
						for c in m:
							for r in rests.get(c, []):
								if absi(int(r) - fi) <= 1:
									near = true
					if not near:
						best = [fi, mi]
						break
				if not best.is_empty():
					break
			if not best.is_empty():
				break
		if best.is_empty():
			break
		(rounds[ti] as Array).append(rounds[best[0]][best[1]])
		(rounds[best[0]] as Array).remove_at(best[1])
	return rounds


func _rests(rounds: Array) -> Dictionary:
	var out := {}
	for ri in range(rounds.size()):
		var playing := {}
		for m in rounds[ri]:
			playing[m[0]] = true
			playing[m[1]] = true
		for c in clubs:
			if not playing.has(c):
				if not out.has(c):
					out[c] = []
				(out[c] as Array).append(ri)
	return out


## Home and away: a pair met twice is home once each (the first meeting's
## host by the seed); the pairs met once follow an Euler circuit of their
## graph (odd-degree clubs joined through a dummy), so each club hosts half
## of them, within one.
func _assign_venues(rounds: Array, rng: RandomNumberGenerator) -> Array:
	var meetings := {}   # "a|b" (sorted) -> [[round, index], ...]
	for ri in range(rounds.size()):
		for mi in range((rounds[ri] as Array).size()):
			var m: Array = rounds[ri][mi]
			var key := "%s|%s" % ([m[0], m[1]] if str(m[0]) < str(m[1]) else [m[1], m[0]])
			if not meetings.has(key):
				meetings[key] = []
			(meetings[key] as Array).append([ri, mi])
	var host := {}       # "round:index" -> home club
	var adj := {}        # club -> [edge id]
	var edges := []      # [a, b, slot]
	for key in meetings:
		var ab: PackedStringArray = str(key).split("|")
		var slots: Array = meetings[key]
		if slots.size() >= 2:
			var first := ab[0] if rng.randf() < 0.5 else ab[1]
			var second := ab[1] if first == ab[0] else ab[0]
			for si in range(slots.size()):
				host["%d:%d" % [slots[si][0], slots[si][1]]] = first if si % 2 == 0 else second
		else:
			edges.append([ab[0], ab[1], "%d:%d" % [slots[0][0], slots[0][1]]])
	# Join odd-degree clubs to a dummy so every degree is even.
	var deg := {}
	for e in edges:
		deg[e[0]] = int(deg.get(e[0], 0)) + 1
		deg[e[1]] = int(deg.get(e[1], 0)) + 1
	for c in deg:
		if int(deg[c]) % 2 == 1:
			edges.append([c, "~", ""])
	for i in range(edges.size()):
		for c in [edges[i][0], edges[i][1]]:
			if not adj.has(c):
				adj[c] = []
			(adj[c] as Array).append(i)
	var used := {}
	var starts := adj.keys()
	starts.sort()
	for start in starts:
		# Hierholzer: walk unused edges, orienting each from where we stand.
		var stack := [start]
		while not stack.is_empty():
			var v = stack[stack.size() - 1]
			var next_e := -1
			for ei in adj[v]:
				if not used.has(ei):
					next_e = int(ei)
					break
			if next_e < 0:
				stack.pop_back()
				continue
			used[next_e] = true
			var e: Array = edges[next_e]
			var w = e[1] if e[0] == v else e[0]
			if str(e[2]) != "":
				host[str(e[2])] = str(v)
			stack.append(w)
	var out := []
	for ri in range(rounds.size()):
		var r := []
		for mi in range((rounds[ri] as Array).size()):
			var m: Array = rounds[ri][mi]
			var h := str(host.get("%d:%d" % [ri, mi], m[0]))
			r.append({"home": h, "away": m[1] if h == m[0] else m[0]})
		out.append(r)
	return out


## The builder before the fair fixture: kept for a 21st club until the
## director chooses its season shape.
func _legacy_fixture() -> Array:
	var first_half := round_robin(clubs)
	var out := []
	for r in first_half:
		out.append(r)
	# Return fixture: same pairings, venues flipped.
	for r in first_half:
		if out.size() >= REGULAR_ROUNDS:
			break
		var flipped := []
		for m in r:
			flipped.append({"home": m["away"], "away": m["home"]})
		out.append(flipped)
	return out.slice(0, REGULAR_ROUNDS)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------
## `at_home`: whether each club plays at its own home ground (the engine's
## home-ground edge). Normally the home club hosts; see finals_at_home() for
## the Grand Final.
func simulate(home_code: String, away_code: String, match_seed: int,
		at_home := [true, false], is_final := false) -> Dictionary:
	return match_sim(home_code, away_code, match_seed, at_home, is_final).run()


## The match, set up and ready to run: both sides, their form, coaching,
## plans and match-ups.
func match_sim(home_code: String, away_code: String, match_seed: int,
		at_home := [true, false], is_final := false) -> MatchSim:
	var home := Squad.new(GameDB_ref().club_name(home_code),
			lists[home_code], bool(at_home[0]), home_code, selections.get(home_code, {}))
	var away := Squad.new(GameDB_ref().club_name(away_code),
			lists[away_code], bool(at_home[1]), away_code, selections.get(away_code, {}))
	home.form = club_form(home_code)
	away.form = club_form(away_code)
	CoachEffects.apply(home)
	CoachEffects.apply(away)
	var sim := MatchSim.new(home, away, match_seed)
	sim.finals_mode = is_final
	for side in range(2):
		var plan := str(plans.get([home_code, away_code][side], ""))
		if plan != "":
			sim.set_tactics(side, {"gameplan": plan})
		var mu: Dictionary = matchups.get([home_code, away_code][side], {})
		if not mu.is_empty():
			sim.set_matchups(side, mu)
	return sim


## Run matches side by side on background threads and wait for them all.
## Results in the order given. A week's matches don't depend on one another
## (recording one only moves the ladder and bracket), so this gives exactly
## what running them in turn would, several times faster on a phone.
static func run_all(sims: Array) -> Array:
	return finish_all(start_all(sims, OS.get_processor_count()))


## Start matches running in the background: {"threads", "out"}. By default
## one core is left for the screen and the rest share the matches.
static func start_all(sims: Array, cores := OS.get_processor_count() - 1) -> Dictionary:
	PlayerProfile.warm()     # its lazy cache must not be filled from threads
	var out := []
	for i in range(sims.size()):
		out.append({})       # one holder per match: no shared writes
	var n := clampi(cores, 1, maxi(1, sims.size()))
	var threads := []
	for k in range(n):
		var mine := []
		for i in range(k, sims.size(), n):
			mine.append([sims[i], out[i]])
		if mine.is_empty():
			continue
		var th := Thread.new()
		th.start(Season._run_share.bind(mine))
		threads.append(th)
	return {"threads": threads, "out": out}


static func _run_share(share: Array) -> void:
	for pair in share:
		(pair[1] as Dictionary)["res"] = (pair[0] as MatchSim).run()


## Wait for matches started by start_all; their results, in order.
static func finish_all(job: Dictionary) -> Array:
	for th in job.get("threads", []):
		(th as Thread).wait_to_finish()
	job["threads"] = []
	var res := []
	for h in job.get("out", []):
		res.append((h as Dictionary)["res"])
	return res


## A club's results this season, oldest first: "W", "L" or "D" for every
## home-and-away match and final it has played. Finals decided on ladder
## position after a level score count as a draw.
func club_results(code: String) -> Array:
	var out := []
	var rounds: Array = results.duplicate()
	rounds.append_array(finals.get("weeks", []))
	for rnd in rounds:
		for res in rnd:
			var side := -1
			if str(res.get("home", "")) == code:
				side = 0
			elif str(res.get("away", "")) == code:
				side = 1
			if side < 0:
				continue
			var s: Array = res["score"]
			if int(s[side]) > int(s[1 - side]):
				out.append("W")
			elif int(s[side]) < int(s[1 - side]):
				out.append("L")
			else:
				out.append("D")
	return out


## Team form, -1..1, going into the club's next match (ClubLife.team_form).
func club_form(code: String) -> float:
	return ClubLife.team_form(club_results(code))


## GameDB is an autoload; reaching it from a RefCounted needs the scene tree.
func GameDB_ref() -> Node:
	return Engine.get_main_loop().root.get_node("GameDB")


func next_seed(extra: int = 0) -> int:
	return seed * 1000003 + round_index * 9176 + extra * 7919 + 13


func play_round() -> Array:
	if round_index >= fixture.size():
		return []
	var round_matches: Array = fixture[round_index]
	var sims := []
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		sims.append(match_sim(m["home"], m["away"], next_seed(i)))
	var played := run_all(sims)
	for res in played:
		res["round"] = round_index + 1
		res["label"] = "Round %d" % (round_index + 1)
		record_regular(res)
	results.append(played)
	round_index += 1
	recalc_ladder()
	return played


func record_regular(res: Dictionary) -> void:
	var h: String = res["home"]
	var a: String = res["away"]
	var s: Array = res["score"]
	ladder[h]["pf"] = int(ladder[h]["pf"]) + s[0]
	ladder[h]["pa"] = int(ladder[h]["pa"]) + s[1]
	ladder[a]["pf"] = int(ladder[a]["pf"]) + s[1]
	ladder[a]["pa"] = int(ladder[a]["pa"]) + s[0]
	ladder[h]["p"] = int(ladder[h]["p"]) + 1
	ladder[a]["p"] = int(ladder[a]["p"]) + 1
	if s[0] > s[1]:
		ladder[h]["w"] = int(ladder[h]["w"]) + 1
		ladder[a]["l"] = int(ladder[a]["l"]) + 1
	elif s[1] > s[0]:
		ladder[a]["w"] = int(ladder[a]["w"]) + 1
		ladder[h]["l"] = int(ladder[h]["l"]) + 1
	else:
		ladder[h]["d"] = int(ladder[h]["d"]) + 1
		ladder[a]["d"] = int(ladder[a]["d"]) + 1


func recalc_ladder() -> void:
	for c in ladder:
		var row: Dictionary = ladder[c]
		row["pts"] = int(row["w"]) * 4 + int(row["d"]) * 2
		var pa := int(row["pa"])
		row["pct"] = (100.0 * int(row["pf"]) / pa) if pa > 0 else 0.0


## Points first, then percentage - the actual AFL tiebreak order.
func ladder_sorted() -> Array:
	var out := []
	for c in ladder:
		out.append(ladder[c])
	out.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return int(a["pts"]) > int(b["pts"])
		if not is_equal_approx(a["pct"], b["pct"]):
			return a["pct"] > b["pct"]
		return int(a["pf"]) > int(b["pf"]))
	return out


func is_regular_done() -> bool:
	return round_index >= fixture.size()


# ---------------------------------------------------------------------------
# Finals
# ---------------------------------------------------------------------------
## The wildcard bracket (see the class doc): ten finalists, five weeks.
func start_finals() -> void:
	var top := []
	for row in ladder_sorted():
		if top.size() >= FINALISTS:
			break
		top.append(row["code"])
	finals = {
		"week": 1,
		"top": top,
		"slots": {},          # "W_WC1" etc -> club code
		"weeks": [],          # played weeks: Array of Array of results
		"premier": "",
		"runner_up": "",
		"done": false,
	}


func finals_week_matches() -> Array:
	if finals.is_empty():
		return []
	var t: Array = finals["top"]
	var s: Dictionary = finals["slots"]
	match int(finals["week"]):
		1:
			return [
				{"tag": "WC1", "label": "Wildcard Final 1", "home": t[6], "away": t[9]},
				{"tag": "WC2", "label": "Wildcard Final 2", "home": t[7], "away": t[8]},
			]
		2:
			return [
				{"tag": "QF1", "label": "Qualifying Final 1", "home": t[0], "away": t[3]},
				{"tag": "QF2", "label": "Qualifying Final 2", "home": t[1], "away": t[2]},
				# Wildcard winners reseed by original ladder position: the
				# winner of 7v10 takes the 7th seed, the winner of 8v9 the 8th.
				{"tag": "EF1", "label": "Elimination Final 1",
						"home": t[4], "away": s.get("W_WC2", "")},
				{"tag": "EF2", "label": "Elimination Final 2",
						"home": t[5], "away": s.get("W_WC1", "")},
			]
		3:
			return [
				{"tag": "SF1", "label": "Semi Final 1",
						"home": s.get("L_QF1", ""), "away": s.get("W_EF1", "")},
				{"tag": "SF2", "label": "Semi Final 2",
						"home": s.get("L_QF2", ""), "away": s.get("W_EF2", "")},
			]
		4:
			return [
				{"tag": "PF1", "label": "Preliminary Final 1",
						"home": s.get("W_QF1", ""), "away": s.get("W_SF1", "")},
				{"tag": "PF2", "label": "Preliminary Final 2",
						"home": s.get("W_QF2", ""), "away": s.get("W_SF2", "")},
			]
		5:
			return [{"tag": "GF", "label": "Grand Final",
						"home": s.get("W_PF1", ""), "away": s.get("W_PF2", "")}]
	return []


func play_finals_week() -> Array:
	if finals.is_empty() or bool(finals["done"]):
		return []
	var matches := finals_week_matches()
	var ready := []
	var sims := []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if m["home"] == "" or m["away"] == "":
			continue
		ready.append(m)
		sims.append(match_sim(m["home"], m["away"], finals_seed(i), finals_at_home(m), true))
	var played := run_all(sims)
	for i in range(played.size()):
		record_final(ready[i], played[i])
	complete_finals_week(played)
	return played


## Seed for match `i` of the current finals week. Shared by the simulated
## week and the interactive finals match so both roll the same game.
func finals_seed(i: int) -> int:
	return seed * 7717 + int(finals["week"]) * 131 + i


## Where a final is played. The higher-ranked club hosts every final at its
## home ground, except the Grand Final, which is always at the MCG whoever
## makes it. The bracket always lists the higher seed first.
func finals_venue(m: Dictionary) -> String:
	if str(m.get("tag", "")) == "GF":
		return GRAND_FINAL_VENUE
	return home_ground(str(m.get("home", "")))


## Which of a final's clubs plays at its own home ground (the engine's
## home-ground edge). The host of every other final has it, exactly as in a
## home-and-away match. At the Grand Final a club has it only if the MCG is
## its home ground, whichever slot it is listed in: two MCG clubs, or none,
## and neither side has an edge.
func finals_at_home(m: Dictionary) -> Array:
	if str(m.get("tag", "")) != "GF":
		return [true, false]
	return [home_ground(str(m.get("home", ""))) == GRAND_FINAL_VENUE,
			home_ground(str(m.get("away", ""))) == GRAND_FINAL_VENUE]


func home_ground(code: String) -> String:
	return str(GameDB_ref().club(code).get("ground", ""))


## Stamp a finals result and advance the bracket slots. Extra time settles
## almost every level final; if even the golden-point period runs dry, the
## higher-ranked side advances.
func record_final(m: Dictionary, res: Dictionary) -> void:
	var s: Dictionary = finals["slots"]
	res["round"] = REGULAR_ROUNDS + int(finals["week"])
	res["label"] = m["label"]
	res["tag"] = m["tag"]
	res["venue"] = finals_venue(m)
	var sc: Array = res["score"]
	var winner: String
	var loser: String
	if sc[0] == sc[1]:
		var top: Array = finals["top"]
		winner = m["home"] if top.find(m["home"]) < top.find(m["away"]) else m["away"]
		loser = m["away"] if winner == m["home"] else m["home"]
		res["decided_on_ladder"] = true
	else:
		winner = m["home"] if sc[0] > sc[1] else m["away"]
		loser = m["away"] if winner == m["home"] else m["home"]
	s["W_" + m["tag"]] = winner
	s["L_" + m["tag"]] = loser


## Close the current finals week once every match in it has been recorded.
func complete_finals_week(played: Array) -> void:
	var s: Dictionary = finals["slots"]
	finals["weeks"].append(played)
	if int(finals["week"]) == 5 and not played.is_empty():
		finals["premier"] = s.get("W_GF", "")
		finals["runner_up"] = s.get("L_GF", "")
		finals["done"] = true
	else:
		finals["week"] = int(finals["week"]) + 1


func is_season_over() -> bool:
	return not finals.is_empty() and bool(finals["done"])
