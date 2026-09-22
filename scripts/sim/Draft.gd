class_name Draft
extends RefCounted
## League-wide list-building phase.
##
## Every club starts empty. The clubs are shuffled into a random draft order,
## then picks snake back and forth (serpentine) until every club has an equal
## list. The human chooses on their club's turns; the 17 AI clubs auto-pick
## between those turns from the same remaining pool and under the same cap.

const CAP_FRACTION := 0.58

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


func _init(all_players: Array, p_clubs: Array = [], p_seed: int = 0) -> void:
	pool = all_players.duplicate()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	clubs = p_clubs.duplicate()
	seed = p_seed

	if clubs.is_empty():
		target_size = mini(Ratings.LIST_SIZE, pool.size())
	else:
		# The shipped dataset has 669 unique players, which is not enough for
		# 18 x 44. Keep the league fair by giving every club the same-sized list
		# and leaving any remainder undrafted.
		target_size = mini(Ratings.LIST_SIZE, floori(float(pool.size()) / float(clubs.size())))
	budget = compute_budget(pool, target_size)

	if not clubs.is_empty():
		_init_league_draft()


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
	return pick_index >= pick_sequence.size()


func auto_until_user_turn() -> void:
	if not league_mode:
		return
	while not is_finished() and current_club() != user_club:
		if not _ai_pick_current():
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
## 5 DEF / 7 MID / 1 RUCK / 5 FWD, plus a flexible bench. The existing draft
## validity rule additionally requires a second ruck on the list.
func position_targets() -> Dictionary:
	var out := {}
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
	# Reserve one cap point per remaining slot, because the minimum value is 1.
	return remaining_after >= slots_after


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
	var counts := role_counts_for(code)
	var slots_left := target_size - count_for(code)
	var rucks_needed := maxi(0, 2 - int(counts["RUCK"]))
	if rucks_needed > 0 and slots_left <= rucks_needed:
		return "RUCK"
	return ""


func _ai_score(code: String, p: Dictionary) -> float:
	var role := str(p["role"])
	var counts := role_counts_for(code)
	var desired := _desired_role_counts()
	var need := maxf(0.0, float(desired.get(role, 0)) - float(counts.get(role, 0)))
	var score := float(p["overall"]) * 10.0
	score += need * 18.0
	var role2 := str(p.get("role2", ""))
	if role2 != "" and role2 != role:
		var need2 := maxf(0.0, float(desired.get(role2, 0)) - float(counts.get(role2, 0)))
		score += need2 * 7.0
	score -= float(p["value"]) * 1.8
	return score


func _desired_role_counts() -> Dictionary:
	return {
		"RUCK": 2,
		"MID": maxi(8, roundi(float(target_size) * 0.38)),
		"DEF": maxi(6, roundi(float(target_size) * 0.25)),
		"FWD": maxi(6, roundi(float(target_size) * 0.25)),
	}


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
