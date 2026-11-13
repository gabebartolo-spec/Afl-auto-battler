class_name Season
extends RefCounted
## A 24-round home-and-away season plus a full AFL finals series.
##
## Fixture (build_fixture): 24 rounds and the same number of games for every
## club, 18 to 21 clubs (expansion or a created club). 18 or 20: one bye and
## 23 games each, as in a real season. 19 or 21: two byes and 22 games each.
## Home games within one of half for everyone; byes and repeat opponents fall
## by the season seed.
##
## Finals (10 finalists):
##   Week 1  Wildcard: WC1 7v10, WC2 8v9
##   Week 2  QF1 1v4, QF2 2v3, EF1 5v(W_WC2), EF2 6v(W_WC1) - the wildcard
##           winners are reseeded as the 7th and 8th seeds by their original
##           ladder position
##   Week 3  SF: QF losers v EF winners
##   Week 4  PF: QF winners v SF winners
##   Week 5  GF

## The game's league (2026 on, and any season with no year). A season's own
## shape comes from SeasonRules by its year: read regular_rounds(),
## finalists() and grand_final_venue() from a season, never these.
const REGULAR_ROUNDS := 24
const FINALISTS := 10
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
## The season's year (0: none given, the game's league) and its shape
## (SeasonRules.for_year): rounds, games, finalists, finals format, venue.
var year := 0
var rules := {}


func _init(club_codes: Array, club_lists: Dictionary, p_seed: int = 0, p_year: int = 0) -> void:
	year = p_year
	rules = SeasonRules.for_year(year)
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
	rules["rounds"] = rounds_to_fit(int(rules.get("rounds", REGULAR_ROUNDS)), int(rules.get("games", 0)), clubs.size())
	ladder = {}
	for c in clubs:
		ladder[c] = {"code": c, "p": 0, "w": 0, "l": 0, "d": 0,
				"pf": 0, "pa": 0, "pts": 0, "pct": 0.0}
	fixture = build_fixture()


# ---------------------------------------------------------------------------
# The season's shape
# ---------------------------------------------------------------------------
## Home-and-away rounds this season (24 in the game's league; 22 in 1990).
## Once the fixture is made it is the count: a season saved before its
## year's shape changed (a 2026 season drawn in 24 rounds) keeps its own.
func regular_rounds() -> int:
	if not fixture.is_empty():
		return fixture.size()
	return int(rules.get("rounds", REGULAR_ROUNDS))


## How many clubs make the finals (10; five in 1990, six 1991-93, eight after).
func finalists() -> int:
	return int(rules.get("finalists", FINALISTS))


## The finals format, a SeasonRules.BRACKETS key.
func finals_format() -> String:
	return str(rules.get("finals", SeasonRules.DEFAULT["finals"]))


## How many weeks the finals take (five with the wildcard round, four before).
func finals_weeks() -> int:
	return SeasonRules.finals_weeks(finals_format())


## Every final's tag this season, in the order they are played.
func finals_tags() -> Array:
	return SeasonRules.tags(finals_format())


## Where this season's Grand Final is played, whichever clubs make it.
func grand_final_venue() -> String:
	return str(rules.get("gf_venue", GRAND_FINAL_VENUE))


## The week of the season the current (or last) finals week is: the
## home-and-away rounds, then one a finals week, a replayed final included.
func finals_round() -> int:
	return regular_rounds() + int(finals.get("week", 1)) + int(finals.get("replays", 0))


## Games each club plays: the year's own count, else 23 at an even club
## count and 22 at an odd one (one bye or two in the 24 rounds).
func games_per_club() -> int:
	var g := int(rules.get("games", 0))
	if g > 0:
		return g
	return regular_rounds() - 1 if clubs.size() % 2 == 0 else regular_rounds() - 2


## A year's real games count with more clubs than it really had (a Legacy
## career whose Fitzroy fought off the merger: 17 clubs in 1997) adds rounds
## until every club plays that count (director, 2026-11-13: "Add rounds").
## Every real season already fits its count, so it keeps its rounds.
static func rounds_to_fit(rounds: int, games: int, n: int) -> int:
	if games <= 0 or n < 2:
		return rounds
	while _fit(rounds, n) < games:
		rounds += 1
	return rounds


## The most games each of `n` clubs can play in `rounds` rounds, with an even
## total of games (each match is two clubs' games).
static func _fit(rounds: int, n: int) -> int:
	var fit := 2 * rounds * (n / 2) / n
	while fit > 0 and (fit * n) % 2 == 1:
		fit -= 1
	return fit


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
## The bye rounds (0-based, inclusive): mid-season, as in the AFL, so the
## opening rounds and the run home are full at an even count.
const BYE_FIRST := 8
const BYE_LAST := 19
## A pair that meets twice meets at least this many rounds apart, the first
## meeting in the first half of the season and the return in the second, as
## the AFL draws it (director, 2026-11-07: Hawthorn in rounds 1 and 6 was
## wrong). Ten holds at 18 to 21 clubs: the return rounds' first meetings
## go in rounds 1 to 12 and their returns in rounds 13 to 24.
const RETURN_GAP := 10


## Every club plays the same number of games, home and away within one game
## of half, and byes and repeat opponents fall by the season seed - not by a
## club's place in the list, and the same for your club as for any other.
##  - 18 or 20 clubs: 23 games and one bye each, as in a real 24-round
##    season. 19 or 21: 22 games and two byes (n x 23 is odd for an odd
##    count, so 23 each cannot be done).
##  - a round-robin, then a seeded choice of its rounds again (return
##    games). At an odd count the clubs those return rounds rest are paired
##    off with each other (never a pair the return rounds already bring
##    back); at an even count no one needs it.
##  - the return games are spaced (_spaced_order, RETURN_GAP): a return
##    round's first meeting in the first half, its copy at least ten rounds
##    later in the second; the other rounds fill the rest in a seeded order.
##  - then matches move into the thin round until no round is more than one
##    match short (21 clubs: fifteen rounds of ten and nine of nine). The
##    thinned rounds are mid-season (rounds 9 to 20, as the AFL's byes are),
##    a club's two byes apart where the rounds allow it, and a moved match
##    keeps its pair's two meetings spaced.
##  - venues: a pair met twice plays once at each ground; the pairs met once
##    are oriented along an Euler circuit, so every club is home in half of
##    them (within one game).
## A saved season keeps the fixture it was saved with (load_career restores
## it over this one), so only a new season is drawn this way.
##
## A real season (Legacy mode) plays its real fixture instead: real_fixture().
func build_fixture() -> Array:
	var real := real_fixture()
	if not real.is_empty():
		return real
	# 2026's real shape (an Opening Round, 23 games) fits only the real 18
	# clubs; a 2026 season with other clubs (a created club) is drawn in the
	# game's league shape, as before real fixtures.
	if year == SeasonRules.GAME_LEAGUE_YEAR:
		rules = SeasonRules.DEFAULT.duplicate()
		rules["year"] = year
	if clubs.size() > FAIR_FIXTURE_MAX or clubs.size() < 2:
		return _legacy_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["fixture", seed, clubs.size()])
	var order := _shuffled(clubs, rng)
	# Pairings only first: [[a, b], ...] a round.
	var base := []
	for r in round_robin(order):
		base.append(r.map(func(m): return [str(m["home"]), str(m["away"])]))
	var target := games_per_club()
	# Each club meets every other once (n - 1 games), then the return rounds:
	# base rounds picked again. The last round pairs off the clubs those
	# return rounds rest - never a pair they already bring back (a third
	# meeting); if no pairing of them avoids it, another pick of rounds.
	var picked := []
	var spare := []
	for pick_try in range(8):
		var picks := _shuffled(range(base.size()), rng)
		picked = []
		var rested := []
		var twice := {}
		for k in range(target - (clubs.size() - 1)):
			var bi: int = picks[k % picks.size()]
			picked.append(bi)
			var playing := {}
			for m in base[bi]:
				playing[m[0]] = true
				playing[m[1]] = true
				twice[_pair_key(m)] = true
			for c in clubs:
				if not playing.has(c):
					rested.append(str(c))
		var clash := true
		for attempt in range(6):
			spare = []
			clash = false
			var mixed := _shuffled(rested, rng)
			for i in range(0, mixed.size() - 1, 2):
				if mixed[i] != mixed[i + 1]:
					var m := [mixed[i], mixed[i + 1]]
					spare.append(m)
					clash = clash or twice.has(_pair_key(m))
			if not clash:
				break
		if not clash:
			break
	# Of a few seeded orders, levelled, the best by, in turn: no round two or
	# more matches short; no bye outside the mid-season rounds (at an even
	# count); every return game spaced (failing that, the widest closest pair
	# and the fewest close ones); fewest clubs resting in back-to-back rounds
	# (an odd count rests twice). Levelling can dead-end on a spaced order, so
	# if none of those comes out full with its byes mid-season, plain seeded
	# shuffles (the pre-spacing draw) get their turn too.
	var best := []
	var best_score := 1 << 62
	for attempt in range(96):
		var start := []
		if attempt < 80:
			start = _spaced_order(base, picked, spare, rng)
		else:
			for r in base:
				start.append((r as Array).duplicate())
			for bi in picked:
				start.append((base[bi] as Array).duplicate())
			start = _shuffled(start, rng)
			start.insert(rng.randi_range(BYE_FIRST, mini(BYE_LAST, start.size())), spare.duplicate())
		start = _fit_rounds(start)
		var order_r := _level_rounds(start, rng)
		var closest := regular_rounds()
		var close := 0
		var meets := _meet_rounds(order_r)
		for key in meets:
			var at: Array = meets[key]
			for k in range(1, at.size()):
				closest = mini(closest, int(at[k]) - int(at[k - 1]))
				if int(at[k]) - int(at[k - 1]) < RETURN_GAP:
					close += 1
		var score := maxi(0, RETURN_GAP - closest) * 100000000 + close * 100000
		for ri in range(order_r.size()):
			var size := (order_r[ri] as Array).size()
			if size < clubs.size() / 2 - 1:
				score += 1000000000000000
			if clubs.size() % 2 == 0 and (ri < BYE_FIRST or ri > BYE_LAST) and size < clubs.size() / 2:
				score += 10000000000000
		var rests := _rests(order_r)
		for c in rests:
			var rs: Array = rests[c]
			for k in range(1, rs.size()):
				if int(rs[k]) - int(rs[k - 1]) <= 1:
					score += 1
		if score < best_score:
			best = order_r
			best_score = score
		if score == 0:
			break
	return _assign_venues(best, rng)


## The drawn rounds made to fill the season's rounds: a season with a round
## for every game (1990, 14 clubs, 22 rounds) drops the empty spare round; a
## longer one (an Opening Round) gets empty rounds mid-season that levelling
## then fills. The game's league already has exactly its rounds: unchanged.
func _fit_rounds(start: Array) -> Array:
	var want := regular_rounds()
	if start.size() == want:
		return start
	var out := start.duplicate()
	if out.size() > want:
		for i in range(out.size() - 1, -1, -1):
			if out.size() > want and (out[i] as Array).is_empty():
				out.remove_at(i)
		return out
	var at := clampi(BYE_FIRST, 0, out.size())
	while out.size() < want:
		out.insert(at, [])
		at = mini(at + 2, out.size())
	return out


func _pair_key(m: Array) -> String:
	return "%s|%s" % ([m[0], m[1]] if str(m[0]) < str(m[1]) else [m[1], m[0]])


## Pair key -> the rounds the pair meets in, in order.
func _meet_rounds(rounds: Array) -> Dictionary:
	var out := {}
	for ri in range(rounds.size()):
		for m in rounds[ri]:
			var key := _pair_key(m)
			if not out.has(key):
				out[key] = []
			(out[key] as Array).append(ri)
	return out


## A seeded order of the season's rounds (the round-robin, the return copies
## of `picked`, the spare round) with the return games spaced: the spare
## round mid-season and the base rounds holding its pairs at least
## RETURN_GAP away across halfway; each picked round in the first half and
## its copy at least RETURN_GAP later in the second; the other rounds fill
## the gaps in a seeded order. Where the rounds can't hold that (a tiny
## league plays one round many times), a plain seeded shuffle.
func _spaced_order(base: Array, picked: Array, spare: Array, rng: RandomNumberGenerator) -> Array:
	var total := base.size() + picked.size() + 1
	var half := total / 2
	var s := rng.randi_range(BYE_FIRST, mini(BYE_LAST, total - 1))
	var slot := {s: spare.duplicate()}    # slot -> round
	var placed := {}                      # base index -> true
	var ok := true
	var once := {}
	for bi in picked:
		ok = ok and not once.has(bi)      # a round played three times can't be spaced
		once[bi] = true
	# The spare pairs' first meetings: far from the spare round, across halfway.
	for m in spare if ok else []:
		var key := _pair_key(m)
		var bi := -1
		for i in range(base.size()):
			for bm in base[i]:
				if _pair_key(bm) == key:
					bi = i
		if bi < 0 or placed.has(bi) or picked.has(bi):
			continue
		var far := []
		var across := []
		for i in range(total):
			if not slot.has(i) and absi(i - s) >= RETURN_GAP:
				far.append(i)
				if (i < half) != (s < half):
					across.append(i)
		var pool: Array = across if not across.is_empty() else far
		if pool.is_empty():
			ok = false
			break
		slot[pool[rng.randi_range(0, pool.size() - 1)]] = (base[bi] as Array).duplicate()
		placed[bi] = true
	# The return rounds: first meeting in the first half, the copy in the
	# second. Latest first meeting first: its choices are a subset of every
	# earlier one's, so taking any of them never blocks the rest.
	var firsts := []
	for i in range(half):
		if not slot.has(i):
			firsts.append(i)
	firsts = _shuffled(firsts, rng)
	ok = ok and firsts.size() >= picked.size()
	if ok:
		firsts = firsts.slice(0, picked.size())
		firsts.sort()
		firsts.reverse()
		var late := picked.duplicate()
		for k in range(late.size()):
			var bi: int = late[k]
			var at: int = firsts[k]
			var pool := []
			for i in range(half, total):
				if not slot.has(i) and i - at >= RETURN_GAP:
					pool.append(i)
			if pool.is_empty() or placed.has(bi):
				ok = false
				break
			slot[at] = (base[bi] as Array).duplicate()
			slot[pool[rng.randi_range(0, pool.size() - 1)]] = (base[bi] as Array).duplicate()
			placed[bi] = true
	var out := []
	if not ok:
		for r in base:
			out.append((r as Array).duplicate())
		for bi in picked:
			out.append((base[bi] as Array).duplicate())
		out = _shuffled(out, rng)
		out.insert(s, spare.duplicate())
		return out
	var rest := []
	for i in range(base.size()):
		if not placed.has(i):
			rest.append((base[i] as Array).duplicate())
	rest = _shuffled(rest, rng)
	for i in range(total):
		out.append(slot[i] if slot.has(i) else rest.pop_back())
	return out


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
## in the round it left: mid-season (BYE_FIRST to BYE_LAST) and apart from a
## club's other rest where any move allows it; further out only when none does.
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
		var meets := _meet_rounds(rounds)
		var best := []
		# Byes in the mid-season window, apart, with the moved pair's
		# meetings still RETURN_GAP apart first; then dropping the apart,
		# then the spacing; then anywhere but round 1 and the last two;
		# anywhere when nothing else moves.
		for pass_i in range(7):
			var apart := pass_i == 0 or pass_i == 2
			var spaced := pass_i == 0 or pass_i == 1 or pass_i == 4
			var span := range(BYE_FIRST, mini(BYE_LAST + 1, last)) if pass_i <= 3 \
					else (range(1, last) if pass_i <= 5 else range(rounds.size()))
			for fi in _shuffled(span, rng):
				if fi == ti or (rounds[fi] as Array).size() < full:
					continue
				for mi in range((rounds[fi] as Array).size()):
					var m: Array = rounds[fi][mi]
					if busy.has(m[0]) or busy.has(m[1]):
						continue
					if spaced:
						var crowded := false
						for r in meets[_pair_key(m)]:
							if int(r) != fi and absi(int(r) - ti) < RETURN_GAP:
								crowded = true
						if crowded:
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


## The builder before the fair fixture: only the fallback above 21 clubs
## (FAIR_FIXTURE_MAX); the director chose the 21-club shape (2026-10-06).
## The year's real fixture (RealFixture, data/legacy/fixtures.csv), or []
## to draw the season: a year with no real fixture, clubs that differ from the
## clubs that played it (Fitzroy surviving, a created club), or a round count
## that differs from the season's shape.
func real_fixture() -> Array:
	if year <= 0 or not RealFixture.has_year(year):
		return []
	var real := RealFixture.for_season(year, clubs)
	if real.size() != regular_rounds():
		return []
	return real


## Whether this season plays a real fixture: its matches carry their real
## ground. Read from the fixture, so a saved season answers the same.
## The AFL's Opening Round (2024 on): a real season of those years plays it
## first, and the rounds after it count from 1, as the AFL numbers them.
func has_opening_round() -> bool:
	return year >= 2024 and is_real_fixture()


## A home-and-away round's name as the AFL says it: "Opening Round", "Round 7".
## Every screen names a round through this (or round_label), never round_i + 1.
func round_name(round_i: int) -> String:
	if has_opening_round():
		return "Opening Round" if round_i == 0 else "Round %d" % round_i
	return "Round %d" % (round_i + 1)


## The AFL's number of the season's last round ("Round 3 of 24").
func last_round_number() -> int:
	return regular_rounds() - (1 if has_opening_round() else 0)


## Where a round sits in the season: "Opening Round", "Round 3 of 24".
func round_progress(round_i: int) -> String:
	if has_opening_round() and round_i == 0:
		return round_name(0)
	return "%s of %d" % [round_name(round_i), last_round_number()]


## The round a match label names, counted as round_index + 1 counts it
## (the Opening Round is 1), or 0 for a final or no round.
func round_of_label(label: String) -> int:
	var l := label.split(" · ")[0].strip_edges()
	if l == "Opening Round":
		return 1 if has_opening_round() else 0
	if not l.begins_with("Round "):
		return 0
	var n := l.trim_prefix("Round ").to_int()
	return n + 1 if has_opening_round() else n


func is_real_fixture() -> bool:
	for r in fixture:
		for m in r:
			return str((m as Dictionary).get("ground", "")) != ""
	return false


## The real ground a home-and-away match was fixtured at, or "" (a drawn
## season, or no such match that round).
func _real_ground(round_i: int, home_code: String, away_code: String) -> String:
	if round_i < 0 or round_i >= fixture.size():
		return ""
	for m in fixture[round_i]:
		if str(m["home"]) == home_code and str(m["away"]) == away_code:
			return str((m as Dictionary).get("ground", ""))
	return ""


func _legacy_fixture() -> Array:
	var first_half := round_robin(clubs)
	var out := []
	for r in first_half:
		out.append(r)
	# Return fixture: same pairings, venues flipped.
	for r in first_half:
		if out.size() >= regular_rounds():
			break
		var flipped := []
		for m in r:
			flipped.append({"home": m["away"], "away": m["home"]})
		out.append(flipped)
	return out.slice(0, regular_rounds())


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
## plans.
func match_sim(home_code: String, away_code: String, match_seed: int,
		at_home := [true, false], is_final := false, weather := "perfect") -> MatchSim:
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
	sim.weather = weather
	# The season's own football (legacy, row 142 L5); today's from 2026 on.
	sim.season_year = year
	for side in range(2):
		# Every club rotates as a competent coach would, on its own plan.
		sim.season_plans[side] = str(fitness_plans.get([home_code, away_code][side], "steady"))
		var plan := str(plans.get([home_code, away_code][side], ""))
		if plan != "":
			sim.set_tactics(side, {"gameplan": plan})
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
	if not threads_available():
		# A browser build without threads: nothing runs yet. pump() plays one
		# match per call (GameState does that between frames while you coach
		# yours); finish_all() plays whatever is left.
		var todo := []
		for i in range(sims.size()):
			todo.append([sims[i], out[i]])
		return {"threads": [], "out": out, "todo": todo}
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


## Threads everywhere but a browser build exported without them (that one
## needs no special server headers; the threaded one does).
static func threads_available() -> bool:
	return not OS.has_feature("web") or OS.has_feature("threads")


## Play the next waiting match of a no-thread job; true while more remain.
static func pump(job: Dictionary) -> bool:
	var todo: Array = job.get("todo", [])
	if todo.is_empty():
		return false
	_run_share([todo.pop_front()])
	return not todo.is_empty()


## When set, called over and over during long blocking work (the main thread
## waiting on match threads, the steps of the rollover): the loading cover keeps
## its ball moving (ScreenTransition.keep_moving). It touches nothing in the sim
## and draws no random numbers, so the results do not depend on it.
static var wait_hook := Callable()


## Long blocking work calls this between its steps.
static func beat() -> void:
	if wait_hook.is_valid():
		wait_hook.call()


## Wait for matches started by start_all; their results, in order.
static func finish_all(job: Dictionary) -> Array:
	while pump(job):
		pass
	for th in job.get("threads", []):
		if wait_hook.is_valid():
			while (th as Thread).is_alive():
				wait_hook.call()
				OS.delay_usec(2000)
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


## The weather at a match (ARD-M4-016): from the ground and the month, the
## same whenever it's asked, so the forecast in the week is what's played.
## `finals_m`: a final's bracket entry (its venue is the host's, or the MCG).
func weather_for(home_code: String, away_code: String, round_i: int, finals_m: Dictionary = {}) -> String:
	var is_final := not finals_m.is_empty()
	var ground := finals_venue(finals_m) if is_final else home_ground(home_code)
	if not is_final and _real_ground(round_i, home_code, away_code) != "":
		ground = _real_ground(round_i, home_code, away_code)
	var state := str(GameDB_ref().club(home_code).get("state", ""))
	if not is_final and round_i == gather_round():
		ground = round_venue(round_i, home_code, away_code)
		state = GatherRound.HOST_STATE
	return Weather.condition(ground, Weather.month_of_round(round_i, is_final),
			hash([seed, round_i, home_code, away_code, "weather"]), state)



## Each club's season fitness plan this week (GameState stamps it before a
## round); a club missing here runs the default "steady". Not saved.
var fitness_plans := {}


func next_seed(extra: int = 0) -> int:
	return seed * 1000003 + round_index * 9176 + extra * 7919 + 13


## The current round's matches, built and not yet run.
func _round_sims() -> Array:
	var round_matches: Array = fixture[round_index]
	var sims := []
	for i in range(round_matches.size()):
		var m: Dictionary = round_matches[i]
		sims.append(match_sim(m["home"], m["away"], next_seed(i),
				round_at_home(round_index, m["home"], m["away"]), false,
				weather_for(m["home"], m["away"], round_index)))
	return sims


## A week's matches started ahead by start_week, waiting for play_round or
## play_finals_week to take their results. Never saved.
var _early := {}


## Start this week's matches on threads without waiting (GameState.advance_async
## keeps drawing frames until running() is false). The same matches, seeds and
## order as play_round / play_finals_week build, so the results are identical.
func start_week() -> Dictionary:
	_early = {}
	if not is_regular_done():
		if round_index < fixture.size():
			_early = start_all(_round_sims(), web_cores())
			_early["week"] = "r%d" % round_index
	elif not finals.is_empty() and not bool(finals["done"]):
		_early = start_all(_finals_sims(_finals_ready()), web_cores())
		_early["week"] = "f%d" % int(finals["week"])
	return _early


## Threads for a week's matches. A browser keeps a small fixed pool of workers
## and Godot uses some of them itself, so a web build takes two.
static func web_cores() -> int:
	if OS.has_feature("web"):
		return 2
	return OS.get_processor_count()


## True while a started week still has matches running. Without threads it
## plays one more match per call, so a caller drawing a frame each time still
## draws between matches.
static func running(job: Dictionary) -> bool:
	if job.is_empty():
		return false
	if job.has("todo"):
		return pump(job)
	for th in job.get("threads", []):
		if (th as Thread).is_alive():
			return true
	return false


## The results of the week started by start_week, if it is this week; else [].
func _take_early(week: String) -> Array:
	if _early.is_empty() or str(_early.get("week", "")) != week:
		_early = {}
		return []
	var job := _early
	_early = {}
	return finish_all(job)


func play_round() -> Array:
	if round_index >= fixture.size():
		return []
	var played := _take_early("r%d" % round_index)
	if played.is_empty():
		played = run_all(_round_sims())
	var gather := round_index == gather_round()
	for res in played:
		res["round"] = round_index + 1
		res["label"] = round_label(round_index)
		if gather:
			res["venue"] = round_venue(round_index, str(res["home"]), str(res["away"]))
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


## Where `code` stands on the finals ten, by the points alone (the table cannot
## say more than it knows): "in" when no result left can drop it out of the ten,
## "out" when no result left can lift it into the ten, else "live". Level points
## always count against the club, since percentage is decided on the day, so a
## "in" or "out" is never wrong: it can only come a round or two late.
func finals_math(code: String) -> String:
	if not ladder.has(code) or is_regular_done():
		return "live"
	var left := {}
	for c in ladder:
		left[c] = 0
	for r in range(round_index, fixture.size()):
		for m in fixture[r]:
			left[str(m["home"])] = int(left.get(str(m["home"]), 0)) + 1
			left[str(m["away"])] = int(left.get(str(m["away"]), 0)) + 1
	var least := int(ladder[code]["pts"])
	var most := least + 4 * int(left.get(code, 0))
	var could_pass := 0
	var certain_ahead := 0
	for c in ladder:
		if c == code:
			continue
		var pts := int(ladder[c]["pts"])
		if pts + 4 * int(left.get(c, 0)) >= least:
			could_pass += 1
		if pts > most:
			certain_ahead += 1
	if could_pass <= finalists() - 1:
		return "in"
	if certain_ahead >= finalists():
		return "out"
	return "live"


func is_regular_done() -> bool:
	return round_index >= fixture.size()


# ---------------------------------------------------------------------------
# Finals
# ---------------------------------------------------------------------------
## The finals series of the season's format (SeasonRules.BRACKETS): the
## wildcard bracket of the class doc in the game's league, the McIntyre final
## five, the final six or a final eight in a past year. A club the league has
## thrown out of the finals (`barred`, YearEvents) is passed over, and the
## next club on the ladder takes its place.
func start_finals(barred: Array = []) -> void:
	var top := []
	for row in ladder_sorted():
		if top.size() >= finalists():
			break
		if barred.has(str(row["code"])):
			continue
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


## This finals week's matches, {"tag", "label", "home", "away"}; a side not
## known yet is "". A week replaying a drawn final holds only the replay.
func finals_week_matches() -> Array:
	if finals.is_empty():
		return []
	var week := int(finals["week"])
	var spec := SeasonRules.bracket(finals_format())
	if week < 1 or week > spec.size():
		return []
	var again: Array = finals.get("replay", [])
	var out := []
	for e in spec[week - 1]:
		if not again.is_empty() and not again.has(e[0]):
			continue
		var home := finals_slot(str(e[2]))
		var away := finals_slot(str(e[3]))
		if bool(e[4]) and home != "" and away != "" and _seed_of(away) < _seed_of(home):
			var t := home
			home = away
			away = t
		var label := str(e[1]) + (" Replay" if not again.is_empty() else "")
		out.append({"tag": e[0], "label": label, "home": home, "away": away})
	return out


## The club in a bracket slot (SeasonRules.BRACKETS), or "" while unknown.
func finals_slot(slot: String) -> String:
	var t: Array = finals.get("top", [])
	var s: Dictionary = finals.get("slots", {})
	if slot.begins_with("S") and slot.substr(1).is_valid_int():
		var i := int(slot.substr(1)) - 1
		return str(t[i]) if i >= 0 and i < t.size() else ""
	if slot == "HI_EF" or slot == "LO_EF":
		var a := str(s.get("W_EF1", ""))
		var b := str(s.get("W_EF2", ""))
		if a == "" or b == "":
			return ""
		var hi := a if _seed_of(a) < _seed_of(b) else b
		return hi if slot == "HI_EF" else (b if hi == a else a)
	if slot.begins_with("RW") or slot.begins_with("RL"):
		# Week one's winners (or losers), best-placed first.
		var side := "W_" if slot.begins_with("RW") else "L_"
		var ranked := []
		for e in SeasonRules.bracket(finals_format())[0]:
			var c := str(s.get(side + str(e[0]), ""))
			if c == "":
				return ""
			ranked.append(c)
		ranked.sort_custom(func(x, y): return _seed_of(x) < _seed_of(y))
		var k := int(slot.substr(2)) - 1
		return str(ranked[k]) if k >= 0 and k < ranked.size() else ""
	return str(s.get(slot, ""))


## Whether the loser of final `tag` plays on: the bracket has a later final
## for that loser (a qualifying final's second chance), or, in the McIntyre
## final eight, `code` is one of the two best-placed losers of week one.
func loser_goes_on(tag: String, code: String) -> bool:
	var spec := SeasonRules.bracket(finals_format())
	var at := -1
	for w in range(spec.size()):
		for e in spec[w]:
			if str(e[0]) == tag:
				at = w
	for w in range(at + 1, spec.size()):
		for e in spec[w]:
			for side in [str(e[2]), str(e[3])]:
				if side == "L_" + tag:
					return true
				if at == 0 and side.begins_with("RL") and finals_slot(side) == code:
					return true
	return false


## True once `code` has lost a final it does not come back from.
func finals_eliminated(code: String) -> bool:
	var s: Dictionary = finals.get("slots", {})
	for tag in finals_tags():
		if str(s.get("L_" + str(tag), "")) == code and not loser_goes_on(str(tag), code):
			return true
	return false


## A finalist's ladder place, 0-based (a club not in the finals sorts last).
func _seed_of(code: String) -> int:
	var i := (finals.get("top", []) as Array).find(code)
	return i if i >= 0 else 1 << 20


## This finals week's matches with both clubs known: [index in the week (its
## seed), match] pairs.
func _finals_ready() -> Array:
	var matches := finals_week_matches()
	var ready := []
	for i in range(matches.size()):
		var m: Dictionary = matches[i]
		if m["home"] == "" or m["away"] == "":
			continue
		ready.append([i, m])
	return ready


func _finals_sims(ready: Array) -> Array:
	var sims := []
	for pair in ready:
		var m: Dictionary = pair[1]
		var sim := match_sim(m["home"], m["away"], finals_seed(int(pair[0])), finals_at_home(m), true,
				weather_for(m["home"], m["away"], finals_round(), m))
		sim.extra_time_allowed = finals_extra_time(m)
		sims.append(sim)
	return sims


## Whether a final level at the end of normal time goes to extra time: always
## in the game's league; a year that replayed drawn finals plays it again.
func finals_extra_time(m: Dictionary) -> bool:
	return not SeasonRules.replays_draw(str(rules.get("drawn_finals", "extra_time")), str(m.get("tag", "")))


func play_finals_week() -> Array:
	if finals.is_empty() or bool(finals["done"]):
		return []
	var ready := _finals_ready()
	var played := _take_early("f%d" % int(finals["week"]))
	if played.is_empty():
		played = run_all(_finals_sims(ready))
	for i in range(played.size()):
		record_final(ready[i][1], played[i])
	complete_finals_week(played)
	return played


## Seed for match `i` of the current finals week. Shared by the simulated
## week and the interactive finals match so both roll the same game.
func finals_seed(i: int) -> int:
	return seed * 7717 + int(finals["week"]) * 131 + i + int(finals.get("replays", 0)) * 100003


## Where a final is played. The club listed first hosts every final at its
## home ground, except the Grand Final, which is at the season's Grand Final
## ground (the MCG; Waverley Park in 1991) whoever makes it.
func finals_venue(m: Dictionary) -> String:
	if str(m.get("tag", "")) == "GF":
		return grand_final_venue()
	return home_ground(str(m.get("home", "")))


## Which of a final's clubs plays at its own home ground (the engine's
## home-ground edge). The host of every other final has it, exactly as in a
## home-and-away match. At the Grand Final a club has it only if the MCG is
## its home ground, whichever slot it is listed in: two MCG clubs, or none,
## and neither side has an edge.
func finals_at_home(m: Dictionary) -> Array:
	if str(m.get("tag", "")) != "GF":
		return [true, false]
	return [home_ground(str(m.get("home", ""))) == grand_final_venue(),
			home_ground(str(m.get("away", ""))) == grand_final_venue()]


func home_ground(code: String) -> String:
	return str(GameDB_ref().club(code).get("ground", ""))


## This season's Gather Round (GatherRound), 0-based, or -1 (none, or a year
## before the AFL held one).
func gather_round() -> int:
	if not bool(rules.get("gather_round", true)):
		return -1
	if is_real_fixture():
		return _real_gather_round()
	return GatherRound.round_of(fixture, clubs, seed)


## A real season's Gather Round: the round every match of which is at the
## host's grounds (2023 on), or -1.
func _real_gather_round() -> int:
	var hosts := {}
	for v in GatherRound.VENUES:
		hosts[str(v["ground"])] = true
	for ri in range(fixture.size()):
		var ms: Array = fixture[ri]
		if ms.size() < GatherRound.VENUES.size():
			continue
		var all_hosted := true
		for m in ms:
			if not hosts.has(str((m as Dictionary).get("ground", ""))):
				all_hosted = false
				break
		if all_hosted:
			return ri
	return -1


## Where a home-and-away match is played: the home club's ground, or in Gather
## Round the host ground the match is staged at. A real season's match is at
## the ground it was really played at.
func round_venue(round_i: int, home_code: String, away_code: String) -> String:
	var real := _real_ground(round_i, home_code, away_code)
	if real != "":
		return real
	if round_i >= 0 and round_i < fixture.size() and round_i == gather_round():
		var ms: Array = fixture[round_i]
		var vs := GatherRound.venues_for(ms, seed, home_ground)
		for i in range(ms.size()):
			if str(ms[i]["home"]) == home_code and str(ms[i]["away"]) == away_code:
				return str(vs[i])
	return home_ground(home_code)


## Which of a home-and-away match's clubs has its home-ground edge: the home
## club, except in Gather Round, where a club has it only at its own ground
## (rule 2.38: a relocated club gets none).
func round_at_home(round_i: int, home_code: String, away_code: String) -> Array:
	if round_i != gather_round():
		return [true, false]
	var v := round_venue(round_i, home_code, away_code)
	return [home_ground(home_code) == v, home_ground(away_code) == v]


## A home-and-away round's name: "Round 5", or "Round 5 · Gather Round".
func round_label(round_i: int) -> String:
	var label := round_name(round_i)
	if round_i >= 0 and round_i == gather_round():
		label += " · " + GatherRound.NAME
	return label


## Stamp a finals result and advance the bracket slots. Extra time settles
## almost every level final; if even the golden-point period runs dry, the
## higher-ranked side advances. In a year that replayed drawn finals a level
## final fills no slot: it is played again the next week.
func record_final(m: Dictionary, res: Dictionary) -> void:
	var s: Dictionary = finals["slots"]
	res["round"] = finals_round()
	res["label"] = m["label"]
	res["tag"] = m["tag"]
	res["venue"] = finals_venue(m)
	var sc: Array = res["score"]
	var winner: String
	var loser: String
	if sc[0] == sc[1] and not finals_extra_time(m):
		res["replay_due"] = true
		return
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
## A drawn final due a replay holds the bracket a week: the next week plays
## only the replay (1990: Collingwood and West Coast's qualifying final).
func complete_finals_week(played: Array) -> void:
	var s: Dictionary = finals["slots"]
	finals["weeks"].append(played)
	var again := []
	for res in played:
		if bool((res as Dictionary).get("replay_due", false)):
			again.append(str(res.get("tag", "")))
	if not again.is_empty():
		finals["replay"] = again
		finals["replays"] = int(finals.get("replays", 0)) + 1
		return
	finals.erase("replay")
	if int(finals["week"]) == finals_weeks() and not played.is_empty():
		finals["premier"] = s.get("W_GF", "")
		finals["runner_up"] = s.get("L_GF", "")
		finals["done"] = true
	else:
		finals["week"] = int(finals["week"]) + 1


func is_season_over() -> bool:
	return not finals.is_empty() and bool(finals["done"])
