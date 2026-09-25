class_name Draft
extends RefCounted
## League-wide list-building phase.
##
## Every club starts empty. The clubs are shuffled into a random draft order,
## then picks snake back and forth (serpentine) until every club has an equal
## list. The human chooses on their club's turns; the rival clubs auto-pick
## between those turns from the same remaining pool and under the same cap.

const CAP_FRACTION := 0.58

## End-of-season intake (rookie) draft: clubs KEEP their existing lists and
## take turns from a small prospect pool only. The salary cap is a formality
## (rookie contracts), the draft order is the reversed ladder supplied by the
## caller, and a club at the list cap skips its turn like the real draft's
## list-management rule.
var intake_mode := false
var existing_sizes := {}              # code -> kept list length (intake only)
var existing_role_counts := {}        # code -> {RUCK..FWD} kept players (intake)
var _fixed_order: Array = []

var pool: Array = []
var budget := 0
var target_size := Ratings.LIST_SIZE

var clubs: Array = []
var user_club := ""
var draft_order: Array = []       # randomised round-one order
var pick_sequence: Array = []     # serpentine club code for every pick
var pick_index := 0               # next pick in pick_sequence
var league_mode := false
var seed := 0

var club_lists := {}              # code -> Array[player dict]
var club_spend := {}              # code -> int
var picked := {}                  # globally drafted player id -> player dict
var order: Array = []             # user's player ids, in pick order
## Successful selections only, in league-wide pick order. Kept in the model so
## resizing or reopening the draft never loses the rival selections.
var pick_history: Array = []
var _pick_by_player := {}         # player id -> history entry


func _init(all_players: Array, p_clubs: Array = [], p_seed: int = 0,
		p_fixed_order: Array = [], p_rounds: int = 0) -> void:
	pool = all_players.duplicate()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	clubs = p_clubs.duplicate()
	seed = p_seed
	_fixed_order = p_fixed_order.duplicate()

	if clubs.is_empty():
		target_size = mini(Ratings.LIST_SIZE, pool.size())
	elif p_rounds > 0:
		# Intake mode: target_size counts rounds of new signings per club, not
		# the final list size (kept players live outside this draft's books).
		target_size = clampi(p_rounds, 1, 4)
	else:
		# The shipped dataset has 669 unique players, which is not enough for
		# 18 x 44. Keep the league fair by giving every club the same-sized list
		# and leaving any remainder undrafted.
		target_size = mini(Ratings.LIST_SIZE, floori(float(pool.size()) / float(clubs.size())))
	budget = compute_budget(pool, target_size)

	if not clubs.is_empty():
		_init_league_draft()


## Build the end-of-season intake draft. p_order is the exact round-one club
## sequence (normally the reversed ladder); rounds are inferred from the pool.
static func build_intake(all_players: Array, p_clubs: Array, p_order: Array,
		p_seed: int, p_existing_sizes: Dictionary, p_existing_counts: Dictionary) -> Draft:
	var rounds := clampi(ceili(float(all_players.size()) / float(maxi(1, p_clubs.size()))), 1, 4)
	var d := new(all_players, p_clubs, p_seed, p_order, rounds)
	d.intake_mode = true
	d.existing_sizes = p_existing_sizes
	d.existing_role_counts = p_existing_counts
	# Rookie deals sit outside the list cap the career draft enforces; money is
	# not the constraint here, list space is.
	d.budget = 999999
	return d


## What the best `list_size` players would cost, scaled down. Deterministic.
static func compute_budget(sorted_pool: Array, list_size: int = Ratings.LIST_SIZE) -> int:
	var n := mini(list_size, sorted_pool.size())
	var total := 0
	for i in range(n):
		total += int(sorted_pool[i]["value"])
	return maxi(n, int(round(total * CAP_FRACTION)))


func _init_league_draft() -> void:
	league_mode = true
	picked = {}
	order = []
	pick_history = []
	_pick_by_player = {}
	club_lists = {}
	club_spend = {}
	for code in clubs:
		club_lists[code] = []
		club_spend[code] = 0

	if _fixed_order.size() == clubs.size():
		draft_order = _fixed_order.duplicate()
	else:
		draft_order = clubs.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system())
		for i in range(draft_order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = draft_order[i]
			draft_order[i] = draft_order[j]
			draft_order[j] = tmp

	pick_sequence = []
	for r in range(target_size):
		var round_order := draft_order.duplicate()
		if r % 2 == 1:
			round_order.reverse()
		for code in round_order:
			pick_sequence.append(code)
	# The draft ends when the pool runs dry - exactly like the national draft's
	# final rounds. Career mode never trips this (666 turns vs 669 players).
	if pick_sequence.size() > pool.size():
		pick_sequence.resize(pool.size())
	pick_index = 0


func start_for_user(code: String) -> void:
	user_club = code
	auto_until_user_turn()


func current_club() -> String:
	if is_finished():
		return ""
	return str(pick_sequence[pick_index])


func current_round() -> int:
	if clubs.is_empty():
		return 1
	return int(pick_index / clubs.size()) + 1


func pick_number_in_round() -> int:
	if clubs.is_empty():
		return 1
	return int(pick_index % clubs.size()) + 1


func is_user_turn() -> bool:
	return league_mode and not is_finished() and current_club() == user_club


func is_finished() -> bool:
	if pick_index >= pick_sequence.size():
		return true
	return intake_mode and remaining_pool() <= 0


func remaining_pool() -> int:
	var n := 0
	for p in pool:
		if not picked.has(str(p["id"])):
			n += 1
	return n


func _list_full(code: String) -> bool:
	if not intake_mode:
		return false
	return int(existing_sizes.get(code, 0)) + count_for(code) >= Ratings.LIST_SIZE


func _skip_current_pick() -> void:
	pick_index += 1


func auto_until_user_turn() -> void:
	if not league_mode:
		return
	while not is_finished():
		var code := current_club()
		if _list_full(code):
			# The club is at the list cap: pass, like a club with no space
			# under the CBA at the real draft.
			_skip_current_pick()
			continue
		if code == user_club:
			return
		if not _ai_pick_current():
			if intake_mode:
				_skip_current_pick()
				continue
			break


func _ai_pick_current() -> bool:
	var code := current_club()
	var p := _best_ai_pick(code)
	if p.is_empty():
		return false
	return _draft_pick(code, p)


func _draft_pick(code: String, p: Dictionary) -> bool:
	var id := str(p["id"])
	if picked.has(id):
		return false
	if count_for(code) >= target_size:
		return false
	if _list_full(code):
		return false
	if not _can_afford_for(code, p):
		return false

	picked[id] = p
	club_lists[code].append(p)
	club_spend[code] = int(club_spend[code]) + int(p["value"])
	if code == user_club:
		order.append(id)
	var entry := {
		"pick": pick_index + 1,
		"round": current_round(),
		"club": code,
		"player_id": id,
		# Kept as a fallback for custom/test pools. The UI resolves the current
		# display label from player_id so changing name mode never leaves stale
		# names in the pick log.
		"player_name": str(p.get("generic_name", p.get("name", "Player"))),
		"role": Ratings.role_tag(p),
		"overall": int(p["overall"]),
		"value": int(p["value"]),
		"source_club": str(p["club"]),
	}
	pick_history.append(entry)
	_pick_by_player[id] = entry
	pick_index += 1
	return true


## The destination club is not p["club"]: that is the player's original club.
func pick_details(player_id: String) -> Dictionary:
	return _pick_by_player.get(player_id, {})


func drafted_by(player_id: String) -> String:
	return str(pick_details(player_id).get("club", ""))


## Actual overall pick numbers, including the current turn, in snake order.
## A limit of 0 returns the entire remaining schedule for the club.
func upcoming_picks(code: String, limit := 3) -> Array:
	var out := []
	for i in range(pick_index, pick_sequence.size()):
		if str(pick_sequence[i]) == code:
			out.append(i + 1)
			if limit > 0 and out.size() >= limit:
				break
	return out


## Coverage guidance, not new drafting restrictions. Match selection needs
## 6 DEF / 6 MID / 1 RUCK / 6 FWD, plus a flexible bench. The existing draft
## validity rule additionally requires a second ruck on the list.
func position_targets() -> Dictionary:
	var out := {}
	if intake_mode:
		# Reserve guidance across the WHOLE list (kept + intake), because the
		# match-day structure scales with list length over a career.
		var full := int(existing_sizes.get(user_club, 0)) + count_for(user_club)
		out["RUCK"] = clampi(int(round(float(full) * 0.09)), 2, 4)
		out["MID"] = int(ceil(float(full) * 0.40))
		out["DEF"] = int(ceil(float(full) * 0.325))
		out["FWD"] = int(ceil(float(full) * 0.325))
		return out
	for slot in Ratings.GROUND_SLOTS:
		out[str(slot[0])] = int(slot[1])
	out["RUCK"] = 2
	return out


func position_needs() -> Dictionary:
	var out := position_targets()
	var counts := role_counts()
	for role in out:
		out[role] = maxi(0, int(out[role]) - int(counts[role]))
	return out


func _can_afford_for(code: String, p: Dictionary) -> bool:
	var slots_after := target_size - count_for(code) - 1
	var remaining_after := budget - int(club_spend[code]) - int(p["value"])
	# Keep enough cap to fill every remaining spot at what those spots will
	# really cost. Reserving 1 a spot (the old rule) painted clubs into a
	# corner: the 2026 pool has no $1 players, so a club with $1 left for its
	# last spot could never finish the draft.
	return float(remaining_after) >= float(slots_after) * _reserve_per_spot()


var _reserve_at := -1
var _reserve_cache := 1.0


## The average price of the cheapest players still available, taking as many
## as the league still has list spots to fill. Rebuilt once per pick.
func _reserve_per_spot() -> float:
	if intake_mode:
		return 1.0
	if _reserve_at == pick_index:
		return _reserve_cache
	_reserve_at = pick_index
	var open := 0
	for code in clubs:
		open += maxi(0, target_size - count_for(code))
	var values: Array = []
	for q in pool:
		if not picked.has(str(q["id"])):
			values.append(int(q["value"]))
	values.sort()
	var n := mini(open, values.size())
	if n <= 0:
		_reserve_cache = 1.0
		return _reserve_cache
	var total := 0
	for i in range(n):
		total += int(values[i])
	_reserve_cache = maxf(1.0, float(total) / float(n))
	return _reserve_cache


func _best_ai_pick(code: String) -> Dictionary:
	var forced_role := _forced_role(code)
	var best := {}
	var best_score := -INF
	for p in pool:
		if picked.has(str(p["id"])):
			continue
		if forced_role != "" and not Ratings.plays_role(p, forced_role):
			continue
		if not _can_afford_for(code, p):
			continue
		var score := _ai_score(code, p)
		if score > best_score:
			best_score = score
			best = p

	# If a forced role cannot be filled, keep the draft moving with the best
	# affordable player. This should be rare, but protects small custom datasets.
	if best.is_empty() and forced_role != "":
		for p in pool:
			if picked.has(str(p["id"])):
				continue
			if not _can_afford_for(code, p):
				continue
			var fallback_score := _ai_score(code, p)
			if fallback_score > best_score:
				best_score = fallback_score
				best = p
	return best


func _forced_role(code: String) -> String:
	if intake_mode:
		# Ruck cover is judged on the whole kept list, not this intake; the
		# club already met the two-ruck rule at the career draft.
		return ""
	var counts := role_counts_for(code)
	var slots_left := target_size - count_for(code)
	var rucks_needed := maxi(0, 2 - int(counts["RUCK"]))
	if rucks_needed > 0 and slots_left <= rucks_needed:
		return "RUCK"
	return ""


# ---------------------------------------------------------------------------
# Rival AI: value over replacement
# ---------------------------------------------------------------------------
## How a rival club values a player:
##
##   worth        his rating blended with his potential. The career draft
##                builds for this season (25% POT); the national draft builds
##                for the years ahead (65% POT).
##   over repl.   worth minus the best player the club can still expect in
##                that position at its next pick. Positions that run dry
##                (good rucks, key forwards) are worth more early; a deep
##                position can wait.
##   need         an open starting slot counts in full, depth up to a
##                balanced list counts 60%, surplus 20%.
##   cap          a player priced above the club's remaining budget per open
##                list spot is marked down.
##
## A player with a second position is valued in both (the second at 85%).
const AI_VORP_WEIGHT := 1.5
## A scarce position is a reason to reach, not to take the 4th-best player
## first: the edge over replacement counts for at most this much.
const AI_VORP_CAP := 10.0
## Average cap left per open list spot below which a pick is marked down.
const AI_CAP_FLOOR := 3.0
const AI_POT_WEIGHT_LEAGUE := 0.25
const AI_POT_WEIGHT_INTAKE := 0.65
## Share of a balanced list by position: 11 mids, 12 defenders, 12 forwards
## of a 37 - list depth for the 6-6-6 match-day shape, the back and forward
## lines running a little deep (rucks: two in the career draft, ~8% of a
## list at the intake).
const AI_LIST_SHARE := {"RUCK": 0.08, "MID": 0.30, "DEF": 0.33, "FWD": 0.33}

var _ai_cache_at := -1
var _ai_avail := {}      # role -> worths of available players, best first
var _ai_share := {}      # role -> share of the league's remaining demand


func _ai_score(code: String, p: Dictionary) -> float:
	_refresh_ai_cache()
	var base := _worth(p)
	var err := _eval_error(code, p)
	var best := -INF
	var roles := [[str(p["role"]), 1.0]]
	var role2 := str(p.get("role2", ""))
	if role2 != "" and role2 != str(p["role"]):
		roles.append([role2, 0.85])
	for entry in roles:
		var role: String = entry[0]
		var need := _need_weight(code, role)
		# A club's own opinion counts in full for a starting spot it is
		# filling; for depth and surplus picks it leans on the consensus.
		var worth := base + err * need
		var over := minf(AI_VORP_CAP, worth - _replacement(code, role))
		var s := (worth + AI_VORP_WEIGHT * over) * need * float(entry[1])
		best = maxf(best, s)
	return best - _cap_penalty(code, p)


# ---------------------------------------------------------------------------
# Rival AI: club-specific player evaluation
# ---------------------------------------------------------------------------
## Recruiting departments disagree. In the career draft every rival club
## sees each player through its own scouting opinion: the worth above plus a
## fixed error that belongs to that club and that player, weighted by how
## much the club needs him (full for an open starting spot, less for depth,
## little for surplus - so late-draft depth picks follow the consensus and
## no club piles up spare rucks). The opinion is
## zero-mean (no club is told to over- or under-rate everyone), and clubs
## differ in how sharp their scouting is: each club's error SD is drawn from
## [AI_EVAL_SD_MIN, AI_EVAL_SD_MAX] rating points. Everything derives from
## the draft seed, so a draft replays identically, the opinion never changes
## mid-draft, and a saved draft needs no extra state.
##
## It only steers rival clubs' choices. Ratings, the board, the cap and your
## club's picks are untouched (your club gets no error), and the intake
## draft keeps its shared valuation. Calibrated with the drafted-league
## harness: docs/DRAFT_EVALUATION.md.
const AI_EVAL_SD_MIN := 1.0
const AI_EVAL_SD_MAX := 5.0
## Errors are capped at this many of the club's SDs, so no club rates a
## fringe player as a star.
const AI_EVAL_CLAMP := 2.5


## How sharp this club's scouting is: its error SD in rating points.
func club_eval_sd(code: String) -> float:
	var span := _eval_sd_range()
	var u := _hash01("%d|eval-sd|%s" % [seed, code])
	return lerpf(float(span[0]), float(span[1]), u)


## This club's opinion of the player, minus the shared worth. 0 for your club
## and outside the career draft.
func _eval_error(code: String, p: Dictionary) -> float:
	if intake_mode or code == user_club or not league_mode:
		return 0.0
	var sd := club_eval_sd(code)
	if sd <= 0.0:
		return 0.0
	var key := "%d|eval|%s|%s" % [seed, code, str(p["id"])]
	# Box-Muller from two independent hashes of the key.
	var u1 := maxf(1e-9, _hash01("a|" + key))
	var u2 := _hash01("b|" + key)
	var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return clampf(z, -AI_EVAL_CLAMP, AI_EVAL_CLAMP) * sd


func _eval_sd_range() -> Array:
	return [AI_EVAL_SD_MIN, AI_EVAL_SD_MAX]


## A uniform [0, 1) from a string: its hash, avalanched (murmur3 finaliser)
## so near-identical keys give unrelated values.
static func _hash01(key: String) -> float:
	var h := key.hash() & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x85ebca6b) & 0xFFFFFFFF
	h ^= h >> 13
	h = (h * 0xc2b2ae35) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFFFF) / float(0x1000000)


func _worth(p: Dictionary) -> float:
	var ov := float(p["overall"])
	var pot := maxf(ov, float(p.get("potential", ov)))
	var w := AI_POT_WEIGHT_INTAKE if intake_mode else AI_POT_WEIGHT_LEAGUE
	return ov * (1.0 - w) + pot * w


func _ideal_counts(code: String) -> Dictionary:
	var size := target_size
	if intake_mode:
		size = int(existing_sizes.get(code, 0)) + target_size
	var out := {}
	for role in AI_LIST_SHARE:
		out[role] = maxi(1, roundi(float(size) * float(AI_LIST_SHARE[role])))
	# The 2026 pool has 46 rucks for 18 clubs: aim for exactly two in the
	# career draft (a third is surplus), so nobody hoards the ruck stocks.
	out["RUCK"] = maxi(2, int(out["RUCK"])) if intake_mode else 2
	return out


func _need_weight(code: String, role: String) -> float:
	var n := int(role_counts_for(code).get(role, 0))
	if role == "RUCK" and not intake_mode and n == 1:
		return 0.8  # the second ruck is required for a valid list
	if role == "RUCK" and not intake_mode and n >= 3:
		# A fourth ruck is never worth a list spot, and the pool's rucks must
		# stretch to every club's two (clubs' own opinions could otherwise
		# send spare rucks to one list late in the draft).
		return 0.0
	if not intake_mode:
		for slot in Ratings.GROUND_SLOTS:
			if str(slot[0]) == role and n < int(slot[1]):
				return 1.0
	if n < int(_ideal_counts(code).get(role, 0)):
		return 0.6
	return 0.2


## The worth of the player this club can expect in `role` at its next pick:
## rivals pick in between, and roughly their share of those picks goes to
## this position.
func _replacement(code: String, role: String) -> float:
	var avail: Array = _ai_avail.get(role, [])
	if avail.is_empty():
		return 0.0
	var gap := 0
	for i in range(pick_index + 1, pick_sequence.size()):
		if str(pick_sequence[i]) == code:
			break
		gap += 1
	var depth := int(ceil(float(gap) * float(_ai_share.get(role, 0.25))))
	return float(avail[mini(depth, avail.size() - 1)])


## Stars are where the cap goes, so price only bites when buying this player
## would leave less than AI_CAP_FLOOR a spot for the rest of the list.
func _cap_penalty(code: String, p: Dictionary) -> float:
	if intake_mode:
		return 0.0
	var value := float(p["value"])
	var spots_after := target_size - count_for(code) - 1
	if spots_after <= 0:
		return value * 0.3
	var left := float(budget - int(club_spend.get(code, 0))) - value
	var per_spot := left / float(spots_after)
	return maxf(0.0, AI_CAP_FLOOR - per_spot) * 12.0 + value * 0.3


## Available worths by position and each position's share of what the
## league still needs. Rebuilt once per pick, not per candidate.
func _refresh_ai_cache() -> void:
	if _ai_cache_at == pick_index:
		return
	_ai_cache_at = pick_index
	_ai_avail = {"RUCK": [], "MID": [], "DEF": [], "FWD": []}
	for p in pool:
		if picked.has(str(p["id"])):
			continue
		var w := _worth(p)
		(_ai_avail[str(p["role"])] as Array).append(w)
		var role2 := str(p.get("role2", ""))
		if role2 != "" and role2 != str(p["role"]) and _ai_avail.has(role2):
			(_ai_avail[role2] as Array).append(w * 0.95)
	for role in _ai_avail:
		(_ai_avail[role] as Array).sort()
		(_ai_avail[role] as Array).reverse()
	var demand := {"RUCK": 0.0, "MID": 0.0, "DEF": 0.0, "FWD": 0.0}
	var total := 0.0
	for code in clubs:
		var ideal := _ideal_counts(code)
		var counts := role_counts_for(code)
		for role in demand:
			var d := maxf(0.0, float(ideal[role]) - float(counts.get(role, 0)))
			demand[role] = float(demand[role]) + d
			total += d
	for role in demand:
		_ai_share[role] = float(demand[role]) / total if total > 0.0 else 0.25


func spent() -> int:
	return spent_for(user_club)


func spent_for(code: String) -> int:
	if league_mode:
		return int(club_spend.get(code, 0))
	var total := 0
	for id in order:
		total += int(picked[id]["value"])
	return total


func remaining() -> int:
	return budget - spent()


func count() -> int:
	return count_for(user_club)


func count_for(code: String) -> int:
	if league_mode:
		return (club_lists.get(code, []) as Array).size()
	return order.size()


func has(id: String) -> bool:
	return picked.has(id)


func can_pick_player(p: Dictionary) -> bool:
	if league_mode:
		if not is_user_turn() or picked.has(str(p["id"])) or not _can_afford_for(user_club, p):
			return false
		var forced_role := _forced_role(user_club)
		return forced_role == "" or Ratings.plays_role(p, forced_role)
	return not picked.has(str(p["id"])) and count() < target_size and remaining() >= int(p["value"])


func pick(p: Dictionary) -> bool:
	if league_mode:
		if not is_user_turn():
			return false
		if not can_pick_player(p):
			return false
		if not _draft_pick(user_club, p):
			return false
		auto_until_user_turn()
		return true

	if picked.has(p["id"]):
		return false
	if count() >= target_size:
		return false
	if remaining() < int(p["value"]):
		return false
	picked[p["id"]] = p
	order.append(p["id"])
	return true


func unpick(id: String) -> bool:
	# Once a league draft has advanced through AI picks, rewinding one player
	# would invalidate the global pick sequence. Start a new draft to reset.
	if league_mode:
		return false
	if not picked.has(id):
		return false
	picked.erase(id)
	order.erase(id)
	return true


func list() -> Array:
	if league_mode:
		return (club_lists.get(user_club, []) as Array).duplicate()
	var out := []
	for id in order:
		out.append(picked[id])
	return out


func all_lists() -> Dictionary:
	var out := {}
	if league_mode:
		for code in club_lists:
			out[code] = (club_lists[code] as Array).duplicate()
	else:
		out[user_club] = list()
	return out


## A list is signable at the target size within the cap. Also require at least
## two ruckmen - a list with none cannot contest a centre bounce, and the engine
## would quietly field a midfield ruck instead.
func is_valid() -> bool:
	if intake_mode:
		# The intake is valid the moment the whole league has taken its turns
		# (or the pool ran dry). Kept lists were validated at the career draft.
		return is_finished()
	if count() != target_size:
		return false
	if spent() > budget:
		return false
	return count_covering("RUCK") >= 2


func is_complete_size() -> bool:
	return count() >= target_size


func count_by_role(role: String) -> int:
	return int(role_counts().get(role, 0))


## Primary or secondary. A MID/RUCK covers the two-ruck rule; position totals
## themselves stay primary-only so they still sum to the list size.
func count_covering(role: String) -> int:
	var n := 0
	for p in list():
		if Ratings.plays_role(p, role):
			n += 1
	return n


func role_counts() -> Dictionary:
	return role_counts_for(user_club)


func role_counts_for(code: String) -> Dictionary:
	var out := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	if intake_mode:
		var ex: Dictionary = existing_role_counts.get(code, {})
		for r in out:
			out[r] = int(ex.get(r, 0))
	var arr: Array
	if league_mode:
		arr = club_lists.get(code, []) as Array
	else:
		arr = list()
	for p in arr:
		var r := str(p["role"])
		if out.has(r):
			out[r] = int(out[r]) + 1
	return out


## Filter + sort the pool for the draft board UI.
func board(role := "", club := "", search := "", sort := "overall",
		hide_picked := false) -> Array:
	var out := []
	var q := search.to_lower()
	for p in pool:
		if hide_picked and picked.has(str(p["id"])):
			continue
		if role != "" and not Ratings.plays_role(p, role):
			continue
		if club != "" and p["club"] != club:
			continue
		if q != "" and not GameDB.player_search_text(p).to_lower().contains(q):
			continue
		out.append(p)
	match sort:
		"overall":
			out.sort_custom(func(a, b): return a["overall"] > b["overall"])
		"value":
			out.sort_custom(func(a, b):
				if a["value"] != b["value"]:
					return int(a["value"]) < int(b["value"])
				return a["overall"] > b["overall"])
		"name":
			out.sort_custom(func(a, b): return GameDB.player_sort_name(a) < GameDB.player_sort_name(b))
		"potential":
			out.sort_custom(func(a, b):
				if int(a.get("potential", 0)) != int(b.get("potential", 0)):
					return int(a.get("potential", 0)) > int(b.get("potential", 0))
				return a["overall"] > b["overall"])
		"goals":
			out.sort_custom(func(a, b): return a["gl"] > b["gl"])
		"disposals":
			out.sort_custom(func(a, b): return a["di"] > b["di"])
	return out


## Retained for scripts/tests that need the old AI-list helper.
static func ai_lists(by_club: Dictionary, exclude_club: String) -> Dictionary:
	var out := {}
	for code in by_club:
		if code == exclude_club:
			continue
		out[code] = (by_club[code] as Array).duplicate()
	return out
