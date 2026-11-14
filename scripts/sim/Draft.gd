class_name Draft
extends RefCounted
## League-wide list-building phase.
##
## Every club starts empty. The clubs are shuffled into a random draft order,
## then picks snake back and forth (serpentine; the National Draft keeps one order) until every club has an equal
## list. The human chooses on their club's turns; the rival clubs auto-pick
## between those turns from the same remaining pool and under the same cap.


## End-of-season intake (rookie) draft: clubs KEEP their existing lists and
## take turns from a small prospect pool only. The salary cap is a formality
## (rookie contracts), the draft order is the reversed ladder supplied by the
## caller, and a club at the list cap skips its turn like the real draft's
## list-management rule.
var intake_mode := false
var existing_sizes := {}              # code -> kept list length (intake only)
## Intake: code -> players on that list retiring at the coming rollover. They
## count toward neither the minimum a club must reach before it may pass nor
## a full list: their places are next season's, so a club drafts their
## replacements first and the list still ends inside the year's maximum
## (2026-11-13: Geelong was capped at 52 with ten retiring, and started 1992
## at 44 against the 48 minimum).
var leaving := {}
## The same retirees as the senior list counts them (RookieList.draft_size)
## and as the 44 does (RookieList.list_size), for the list caps.
var leaving_senior := {}
var leaving_44 := {}
## Where the intake calls a list full: 0 is the whole list (Ratings.LIST_SIZE);
## a career's intake sets the senior list (RookieList), and existing_sizes
## counts senior players only.
var senior_cap := 0
## code -> the list as the 44 counts it when the draft opened (senior and
## Category A; RookieList.list_size). A club at or over Contracts.max_list()
## passes its picks whatever its senior list holds (RookieList.add_block: the
## same rule as every other way onto a list). A club with no entry is bound
## by the senior list alone.
var list_44 := {}
## Youth only (Challenge.gd): your club may not take a player older than this.
## 0 for no limit. Rival clubs are never bound.
var user_max_age := 0
var existing_role_counts := {}        # code -> {RUCK..FWD} kept players (intake)
var existing_roles := {}              # code -> [[role, role2], ...] kept players (intake)
var _fixed_order: Array = []
## Intake only: clubs that have stopped drafting (the coach passed, or a rival
## had nobody it could take). A passed club is skipped for the rest of the
## draft and left out of the extra rounds.
var passed_clubs := {}
## Intake: the coach's picks that passed because his list was full, in order:
## [{"pick": overall pick number, "why": "list_full"}]. Saved with the draft;
## the draft screen and the draft-night news say each one.
var user_passed: Array = []
## Intake: how many slots the planned rounds hold (the extra rounds come after).
var _planned_len := 0

var pool: Array = []
var budget := 0
var target_size := Ratings.LIST_SIZE

var clubs: Array = []
var user_club := ""
var draft_order: Array = []       # randomised round-one order
var pick_sequence: Array = []     # serpentine club code for every pick
var pick_rounds: Array = []       # round of every pick (compensation picks count in their round)
var pick_origin: Array = []       # the club each pick came from (differs from its owner when traded)
## Traded picks: "round:origin club" -> owner. A pick not listed is its own
## club's. See set_pick_owners.
var pick_owners := {}
## An owner no club is: a pick the league took away (YearEvents), which the
## draft skips.
const FORFEIT := "-"
## Pick trades struck on draft night, in order: {"at": the pick about to be
## made when it was struck, "buyer", "seller", "in": [ids the buyer got],
## "out": [ids it gave], "text": the line the board reads}. GameState fills
## it; the screen shows it with the picks.
var night_trades: Array = []
## Draft night: a rival is on the clock (its club code, the pick's index),
## before it picks. GameState listens, and may let it sell the pick.
signal rival_on_clock(code: String, index: int)
## Free-agency compensation picks in this draft: [{"index" (0-based pick),
## "club", "after", "player", "name", "to", ...}]. See add_compensation.
var comp_picks: Array = []
## Clubs with a seat but no regular pick (add_guest).
var guests: Array = []
var pick_index := 0               # next pick in pick_sequence
var league_mode := false
var seed := 0

var club_lists := {}              # code -> Array[player dict]
var club_spend := {}              # code -> int
## National Draft scouting uncertainty by club. Clubs not listed use Standard
## (1.0); the user's multiplier comes from the annual Recruiting allocation.
var scouting_mults := {}
var picked := {}                  # globally drafted player id -> player dict
var order: Array = []             # user's player ids, in pick order
## Successful selections only, in league-wide pick order. Kept in the model so
## resizing or reopening the draft never loses the rival selections.
var pick_history: Array = []
var _pick_by_player := {}         # player id -> history entry
## What the coach opened on the board and why rivals passed on it (P-18):
## session only, never saved (lead 2026-10-18). The career save writes every
## script variable of a draft (CareerSave.object_vars), so these live in a
## static table keyed by this draft, dropped once it is gone.
static var _session := {}


## Prospects your coach opened on the board this draft: {player id: true}.
func wanted() -> Dictionary:
	return _session_of()["wanted"]


## Why a rival passed on, or took, a prospect in `wanted()`, in pick order:
## [{"pick", "club", "player_id", "other_id", "code", "gap"}], the code
## chosen in _best_ai_pick at the branch it took (data/ai_reasons.json).
func wanted_news() -> Array:
	return _session_of()["news"]


func _session_of() -> Dictionary:
	var k := get_instance_id()
	if not _session.has(k):
		for old in _session.keys():
			if not is_instance_id_valid(old):
				_session.erase(old)   # a draft that is gone
		_session[k] = {"wanted": {}, "news": []}
	return _session[k]


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
		p_seed: int, p_existing_sizes: Dictionary, p_existing_counts: Dictionary,
		p_existing_roles: Dictionary = {}) -> Draft:
	var rounds := clampi(ceili(float(all_players.size()) / float(maxi(1, p_clubs.size()))), 1, 4)
	var d := new(all_players, p_clubs, p_seed, p_order, rounds)
	d.intake_mode = true
	d.existing_sizes = p_existing_sizes
	d.existing_role_counts = p_existing_counts
	d.existing_roles = p_existing_roles
	# Rookie deals sit outside the list cap the career draft enforces; money is
	# not the constraint here, list space is.
	d.budget = 999999999
	# The sequence was built before intake_mode was set: rebuild it the intake way.
	d._build_sequence([])
	return d


## The opening league draft uses the same 2027 cap the career will use.
## Keeping one cap across draft -> season means "$18.44m" is real rather
## than a UI label over a separate draft-points economy.
static func compute_budget(_sorted_pool: Array, _list_size: int = Ratings.LIST_SIZE) -> int:
	return Contracts.salary_cap_for_year(GameDB.START_YEAR)


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

	_build_sequence([])
	pick_index = 0


## The serpentine order, with compensation picks slotted in: each sits right
## after regular pick `after`, best compensation first when two share a
## spot. The draft ends when the pool runs dry - exactly like the national
## draft's final rounds - so an extra pick never adds players to the league:
## the last regular picks drop off the end instead, and a compensation pick
## a club has earned is never the one lost.
func _build_sequence(comps: Array) -> void:
	var by_after := {}
	for c in comps:
		var k := int(c["after"])
		if not by_after.has(k):
			by_after[k] = []
		(by_after[k] as Array).append(c)
	var slots := []   # [club, round, comp entry or {}]
	var regular := 0
	# An extra pick before the first regular pick (a new club's pick 1).
	for c in by_after.get(0, []):
		slots.append([str(c["club"]), int(c.get("round", 1)), c, str(c.get("origin", c["club"]))])
	for r in range(target_size):
		var round_order := draft_order.duplicate()
		# The League Draft snakes. The National Draft runs the same order every
		# round, worst club first (director, 2026-10-14).
		if r % 2 == 1 and not intake_mode:
			round_order.reverse()
		for code in round_order:
			var owner := str(pick_owners.get("%d:%s" % [r + 1, code], code))
			if owner == FORFEIT:
				continue
			slots.append([owner, r + 1, {}, code])
			regular += 1
			for c in by_after.get(regular, []):
				slots.append([str(c["club"]), int(c.get("round", r + 1)), c, str(c.get("origin", c["club"]))])
	# A pick placed after one the draft never reaches goes at the very end.
	var ks := by_after.keys()
	ks.sort()
	for after in ks:
		if int(after) > regular:
			for c in by_after[after]:
				slots.append([str(c["club"]), target_size, c, str(c["club"])])
	# Too many picks for the pool: drop regular picks from the end.
	var k := slots.size() - 1
	while slots.size() > pool.size() and k >= 0:
		if (slots[k][2] as Dictionary).is_empty():
			slots.remove_at(k)
		k = mini(k - 1, slots.size() - 1)
	if slots.size() > pool.size():
		slots.resize(pool.size())
	pick_sequence = []
	pick_rounds = []
	pick_origin = []
	comp_picks = []
	_planned_len = slots.size()
	for slot in slots:
		if not (slot[2] as Dictionary).is_empty():
			var entry: Dictionary = (slot[2] as Dictionary).duplicate()
			entry["index"] = pick_sequence.size()
			comp_picks.append(entry)
		pick_sequence.append(slot[0])
		pick_rounds.append(slot[1])
		pick_origin.append(slot[3])


## The index of `origin`'s own regular pick in `rnd` if it has not been made
## yet, or -1 (made, passed over, or never in the order). Compensation picks
## are not it.
func pick_slot(rnd: int, origin: String) -> int:
	var comp := {}
	for c in comp_picks:
		comp[int(c["index"])] = true
	for i in range(pick_index, mini(pick_sequence.size(), pick_origin.size())):
		if comp.has(i):
			continue
		if int(pick_rounds[i]) == rnd and str(pick_origin[i]) == origin:
			return i
	return -1


## A pick not yet made changes owner on the night: the club at that spot in
## the order, and the owners table (pick_limit reads it). A pick back with its
## own club needs no entry.
func reassign_pick(index: int, to: String) -> void:
	if index < pick_index or index >= pick_sequence.size():
		return
	pick_sequence[index] = to
	var key := "%d:%s" % [int(pick_rounds[index]), str(pick_origin[index])]
	if to == str(pick_origin[index]):
		pick_owners.erase(key)
	else:
		pick_owners[key] = to


## The rounds the draft was planned with (not the extra rounds added when
## prospects are left over).
func planned_rounds() -> int:
	var n := 0
	for i in range(mini(_planned_len, pick_rounds.size())):
		n = maxi(n, int(pick_rounds[i]))
	return n


## Who owns this year's traded picks: {"round:origin club": owner}. Set
## before the first pick (the order is rebuilt by add_compensation).
func set_pick_owners(owners: Dictionary) -> void:
	if pick_index != 0:
		return
	pick_owners = owners.duplicate()
	_build_sequence(comp_picks.map(func(c): return c))


## Slot this year's compensation picks into the order (before any pick is
## made). `comps` = [{"club", "after", "value", ...}]; a pick after a regular
## pick the draft would not reach lands at the end of the draft. Ties at one spot: higher value
## first, then the club lower on the ladder (earlier in round one).
func add_compensation(comps: Array) -> void:
	if pick_index != 0:
		return
	var sorted := comps.duplicate()
	sorted.sort_custom(func(a, b):
		if int(a["after"]) != int(b["after"]):
			return int(a["after"]) < int(b["after"])
		if float(a.get("value", 0.0)) != float(b.get("value", 0.0)):
			return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
		return draft_order.find(str(a["club"])) < draft_order.find(str(b["club"])))
	_build_sequence(sorted)


## A seat at the intake draft for a club that is not playing yet (a new club
## building its list): it holds no regular pick, only the extra ones slotted
## in with add_compensation. `size`, `counts` and `pairs` describe the list it
## has so far, as existing_sizes and friends do for every other club.
func add_guest(code: String, size: int, counts: Dictionary, pairs: Array) -> void:
	if clubs.has(code) or pick_index != 0:
		return
	guests.append(code)
	clubs.append(code)
	club_lists[code] = []
	club_spend[code] = 0
	existing_sizes[code] = size
	existing_role_counts[code] = counts
	existing_roles[code] = pairs


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
	if pick_index < pick_rounds.size():
		return int(pick_rounds[pick_index])
	if not pick_rounds.is_empty() and pick_index == pick_rounds.size():
		return int(pick_rounds[-1])
	return int(pick_index / clubs.size()) + 1


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
	return open_spots(code) <= 0


## Intake: where a list is full for this draft (the senior list in a career).
func list_cap() -> int:
	return senior_cap if senior_cap > 0 else Ratings.LIST_SIZE


## Intake: the list spots `code` still has open tonight.
func open_spots(code: String) -> int:
	var open := list_cap() - (int(existing_sizes.get(code, 0)) - int(leaving_senior.get(code, 0))) - count_for(code)
	if list_44.has(code):
		open = mini(open, Contracts.max_list() - (list_now(code) - int(leaving_44.get(code, 0))))
	return maxi(0, open)


## `code`'s list as the 44 counts it, tonight's picks included (0 when the
## draft was not told).
func list_now(code: String) -> int:
	return int(list_44[code]) + count_for(code) if list_44.has(code) else 0


## True when it is the 44, not the senior list, that leaves `code` no spot.
func full_at_44(code: String) -> bool:
	return list_44.has(code) and list_now(code) >= Contracts.max_list() \
			and int(existing_sizes.get(code, 0)) + count_for(code) < list_cap()


## Why `code` has no spot, as the coach reads it after "Pick 49 passed: ".
func full_words(code: String) -> String:
	if full_at_44(code):
		var n := list_now(code)
		if n > Contracts.max_list():
			return "your list holds %d and the limit is %d (senior list and Category A rookies together), so nobody joins until it is back under %d." % [
					n, Contracts.max_list(), Contracts.max_list()]
		return "your list is full (%d: senior list and Category A rookies together)." % Contracts.max_list()
	return "your %slist is full (%d)." % ["senior " if senior_cap > 0 else "", list_cap()]


## Intake: `code`'s picks still to come, split by whether a list spot is left
## for each: {"open": spots, "usable": [pick numbers], "passing": [pick
## numbers]}. A club with a full list passes its picks.
func spots_plan(code: String) -> Dictionary:
	var open := open_spots(code)
	var picks := [] if passed_clubs.has(code) else upcoming_picks(code, 0)
	return {"open": open, "usable": picks.slice(0, mini(open, picks.size())),
			"passing": picks.slice(mini(open, picks.size()))}


## Pick numbers in words: "40", "40 and 58", "40, 58 and 76".
static func picks_words(picks: Array) -> String:
	var bits: PackedStringArray = []
	for n in picks:
		bits.append(str(int(n)))
	if bits.size() <= 1:
		return "".join(bits)
	return "%s and %s" % [", ".join(bits.slice(0, bits.size() - 1)), bits[bits.size() - 1]]


## The line that says your picks passed for a full list ("" when none did):
## "Pick 49 passed: your senior list is full (38)."
func user_passed_line() -> String:
	if user_passed.is_empty():
		return ""
	var nums := user_passed.map(func(e): return int(e["pick"]))
	return "%s %s passed: %s" % ["Pick" if nums.size() == 1 else "Picks", picks_words(nums), full_words(user_club)]


func _note_user_pass(code: String) -> void:
	if intake_mode and code == user_club and _list_full(code):
		user_passed.append({"pick": pick_index + 1, "why": "list_full"})


func _skip_current_pick() -> void:
	if intake_mode and pick_index < pick_sequence.size():
		# A club that passes (or has no pick it can take) is out of the rest of
		# the draft, so the extra rounds always end.
		passed_clubs[str(pick_sequence[pick_index])] = true
	pick_index += 1
	_extend_if_needed()


## The National Draft runs until every list is full or the class is gone
## (director, 2026-10-14): when the planned rounds end with prospects left,
## another round in the same order is added for the clubs that still have room
## and have not passed. A prospect is never wasted while a club has a place for him.
func _extend_if_needed() -> void:
	if not intake_mode or pick_index < pick_sequence.size():
		return
	var left := remaining_pool()
	if left <= 0:
		return
	var rnd := (int(pick_rounds[-1]) if not pick_rounds.is_empty() else 0) + 1
	var added := 0
	for code in draft_order:
		if added >= left:
			break
		if passed_clubs.has(code) or _list_full(code):
			continue
		pick_sequence.append(code)
		pick_rounds.append(rnd)
		pick_origin.append(code)
		added += 1


## Why the coach cannot pass this pick, in words ("" when he can). Intake only.
func pass_block_reason() -> String:
	if not intake_mode or not is_user_turn():
		return "You can only pass on your own pick."
	var gone := int(leaving.get(user_club, 0))
	var have := int(existing_sizes.get(user_club, 0)) + count_for(user_club) - gone
	if have < Contracts.min_list():
		if gone > 0:
			return "With %d retiring, your list has %d players for next season and needs at least %d, so you cannot pass yet." % [gone, have, Contracts.min_list()]
		return "Your list has %d players and needs at least %d, so you cannot pass yet." % [have, Contracts.min_list()]
	return ""


## The coach passes: this pick and every later one are skipped.
func user_pass() -> bool:
	if pass_block_reason() != "":
		return false
	passed_clubs[user_club] = true
	_skip_current_pick()
	auto_until_user_turn()
	return true


## "Pick for me": the assistant's best available player for this one pick.
func pick_for_me() -> bool:
	if not is_user_turn():
		return false
	var p := _best_ai_pick(user_club)
	if p.is_empty():
		return false
	return pick(p)


func auto_until_user_turn() -> void:
	if not league_mode:
		return
	while not is_finished():
		var code := current_club()
		if passed_clubs.has(code):
			_note_user_pass(code)
			_skip_current_pick()
			continue
		if _list_full(code):
			# The club is at the list cap: pass, like a club with no space
			# under the CBA at the real draft. Your own pass is recorded,
			# so the draft screen can say it.
			_note_user_pass(code)
			_skip_current_pick()
			continue
		if code == user_club:
			return
		if intake_mode:
			rival_on_clock.emit(code, pick_index)
			if str(current_club()) != code:
				continue   # the pick changed hands: whoever holds it now is on the clock
		if not _ai_pick_current():
			# A rival with no legal pick passes rather than freezing the whole
			# draft (the cap guard makes this rare; an older save can hold it).
			_skip_current_pick()
			continue


func _ai_pick_current() -> bool:
	var code := current_club()
	var why := {}
	var p := _best_ai_pick(code, why)
	if p.is_empty():
		return false
	var at := pick_index + 1
	if not _draft_pick(code, p):
		return false
	_note_wanted(code, p, why, at)
	return true


## Remember why `code` passed on each prospect you opened that was still on
## the board, and why it took one you opened (`why`: id -> reason code, from
## _best_ai_pick). `at`: the pick it made.
func _note_wanted(code: String, p: Dictionary, why: Dictionary, at: int) -> void:
	if why.is_empty():
		return
	var gap := ""
	var next := upcoming_picks(user_club, 1)
	if not next.is_empty():
		gap = gap_words(int(next[0]) - at)
	var ids := why.keys()
	ids.sort()
	for id in ids:
		wanted_news().append({"pick": at, "club": code, "player_id": str(id), "other_id": str(p["id"]),
				"code": str(why[id]), "gap": gap})


## "one pick before yours", "two picks before yours", "12 picks before yours".
static func gap_words(n: int) -> String:
	if n <= 0:
		return "before your pick"
	var words := ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
	var num: String = words[n - 1] if n <= words.size() else str(n)
	return "%s pick%s before yours" % [num, "" if n == 1 else "s"]


## The sentence for one wanted_news entry (AiReasons), with names from
## `name_of` (a Callable: player dictionary -> display name).
func wanted_line(e: Dictionary, name_of: Callable) -> String:
	var who := _pool_player(str(e["player_id"]))
	var other := _pool_player(str(e["other_id"]))
	var code := str(e["code"])
	var role := str(who.get("role", ""))
	var pos := role_noun(role, 1) if code == "draft_took_need" else role_noun(role, 2)
	return AiReasons.line(code, {"club": GameDB.club_name(str(e["club"])), "player": name_of.call(who),
			"other": name_of.call(other), "pos": pos, "gap": str(e.get("gap", "")),
			"age": int(who.get("age", 0))})


func _pool_player(id: String) -> Dictionary:
	if picked.has(id):
		return picked[id]
	for q in pool:
		if str(q["id"]) == id:
			return q
	return {}


func _draft_pick(code: String, p: Dictionary) -> bool:
	var id := str(p["id"])
	if picked.has(id):
		return false
	if count_for(code) >= pick_limit(code):
		return false
	if _list_full(code):
		return false
	if not _can_afford_for(code, p):
		return false

	var paid := price_for(code, p)
	picked[id] = p
	club_lists[code].append(p)
	club_spend[code] = int(club_spend[code]) + paid
	if code == user_club:
		order.append(id)
	var entry := {
		"pick": pick_index + 1,
		"round": current_round(),
		"club": code,
		"player_id": id,
		# Kept as a fallback for custom/test pools. The UI resolves the current
		# display label from player_id, so the pick log never shows a real
		# player's hidden label.
		"player_name": str(p.get("generic_name", p.get("name", "Player"))),
		"role": Ratings.role_tag(p),
		"overall": int(p["overall"]),
		"value": paid,
		"source_club": str(p["club"]),
	}
	pick_history.append(entry)
	_pick_by_player[id] = entry
	pick_index += 1
	_extend_if_needed()
	return true


## The destination club is not p["club"]: that is the player's original club.
func pick_details(player_id: String) -> Dictionary:
	return _pick_by_player.get(player_id, {})


func drafted_by(player_id: String) -> String:
	return str(pick_details(player_id).get("club", ""))


## Actual overall pick numbers, including the current turn, in draft order.
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


## What is still short of each target, by who can actually play there
## (Ratings.plays_role: primary or secondary position, the same rule team
## selection uses). Each player fills one spot only, so a MID/FWD covers the
## forwards when the midfield is already covered, never both at once.
func position_needs() -> Dictionary:
	return slot_shortfall(role_pairs_for(user_club), position_targets())


## The match-day shape a list must be able to field: the ground positions,
## and two rucks (the second covers the first).
static func match_day_targets() -> Dictionary:
	var out := {}
	for slot in Ratings.GROUND_SLOTS:
		out[str(slot[0])] = int(slot[1])
	out["RUCK"] = 2
	return out


## One answer per position for your list, every player counted in one spot
## only (slot_shortfall): {role: {"count": primary players, "short": spots of
## the match-day shape still unfilled, "light": spots short of a full list's
## depth beyond that (national draft guidance)}}.
func position_status() -> Dictionary:
	var pairs := role_pairs_for(user_club)
	var must := slot_shortfall(pairs, match_day_targets())
	var depth := slot_shortfall(pairs, position_targets())
	var counts := role_counts()
	var out := {}
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		var short := maxi(0, int(must.get(role, 0)))
		out[role] = {"count": int(counts.get(role, 0)), "short": short,
				"light": 0 if short > 0 else maxi(0, int(depth.get(role, 0)))}
	return out


## A position's state in a word or two: "short 2" (the match-day side cannot
## be fielded), "need 1" for rucks, "light 3" (below a full list's depth),
## or "covered".
static func need_word(st: Dictionary, role: String) -> String:
	var short := int(st.get("short", 0))
	if short > 0:
		return ("need %d" if role == "RUCK" else "short %d") % short
	var light := int(st.get("light", 0))
	if light > 0:
		return "light %d" % light
	return "covered"


## A position's players in football words, for a count of n.
static func role_noun(role: String, n: int) -> String:
	var one := {"RUCK": "ruck", "MID": "midfielder", "DEF": "defender", "FWD": "forward"}
	var word: String = one.get(role, role.to_lower())
	return word if n == 1 else word + "s"


## Where the finished list still cannot field the match-day side, in words:
## "6 defenders" or "6 defenders, 2 forwards" ("" when no position is short).
func short_positions() -> String:
	var status := position_status()
	var parts: Array[String] = []
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		var short := int((status[role] as Dictionary)["short"])
		if short > 0:
			parts.append("%d %s" % [short, role_noun(role, short)])
	return ", ".join(parts)


## Why a finished list cannot start the season, in one sentence ("" when it
## can): the same three tests as is_valid(), said in the order a manager
## would count them.
func invalid_reason() -> String:
	if intake_mode or is_valid():
		return ""
	if count() != target_size:
		return "You have %d of %d players." % [count(), target_size]
	if spent() > budget:
		return "You are %s over the salary cap." % Contracts.money(spent() - budget)
	return "You have %d ruck%s. Every list needs two." % [count_covering("RUCK"),
			"" if count_covering("RUCK") == 1 else "s"]


## [[role, role2], ...] for everyone on `code`'s list (kept players too).
func role_pairs_for(code: String) -> Array:
	var out: Array = []
	if intake_mode:
		out.append_array(existing_roles.get(code, []))
	var arr: Array = list()
	if league_mode:
		arr = club_lists.get(code, []) as Array
	for p in arr:
		out.append([str(p["role"]), str(p.get("role2", ""))])
	return out


## Players who can play each role, primary or secondary. A dual-position
## player counts in both, so these do not add up to the list size (the
## primary counts, role_counts(), do).
func role_coverage() -> Dictionary:
	var out := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	for pair in role_pairs_for(user_club):
		for role in out:
			if str(pair[0]) == role or str(pair[1]) == role:
				out[role] = int(out[role]) + 1
	return out


## Shortfall per role when `pairs` ([[role, role2], ...]) fill `targets`
## ({role: spots}), one spot per player, as many spots as possible (a small
## bipartite matching). Deterministic.
static func slot_shortfall(pairs: Array, targets: Dictionary) -> Dictionary:
	var slots: Array = []
	for role in ["RUCK", "MID", "DEF", "FWD"]:
		for i in range(int(targets.get(role, 0))):
			slots.append(role)
	var holder: Array = []
	holder.resize(slots.size())
	holder.fill(-1)
	for pi in range(pairs.size()):
		_match_player(pi, pairs, slots, holder, {})
	var out := {}
	for role in targets:
		out[role] = int(targets[role])
	for si in range(slots.size()):
		if int(holder[si]) >= 0:
			out[slots[si]] = int(out[slots[si]]) - 1
	return out


static func _match_player(pi: int, pairs: Array, slots: Array, holder: Array, seen: Dictionary) -> bool:
	var pair: Array = pairs[pi]
	for si in range(slots.size()):
		if seen.has(si) or (str(pair[0]) != str(slots[si]) and str(pair[1]) != str(slots[si])):
			continue
		seen[si] = true
		if int(holder[si]) < 0 or _match_player(int(holder[si]), pairs, slots, holder, seen):
			holder[si] = pi
			return true
	return false


func _can_afford_for(code: String, p: Dictionary) -> bool:
	return price_for(code, p) <= usable_cap_for(code)


## What a club can spend on its next pick: the cap it has left, less enough to
## fill every other place it still has to fill at what those places will
## really cost. Reserving 1 a spot (the old rule) painted clubs into a
## corner: the 2026 pool has no $1 players, so a club with $1 left for its
## last spot could never finish the draft.
func usable_cap_for(code: String) -> int:
	return budget - spent_for(code) - reserve_for(code)


## The cap a club must keep for the places after its next pick.
func reserve_for(code: String) -> int:
	var slots_after := maxi(0, target_size - count_for(code) - 1)
	return int(ceil(float(slots_after) * _reserve_per_spot()))


var _reserve_at := -1
var _reserve_cache := float(Contracts.senior_min(GameDB.START_YEAR))


## The average price of the cheapest players still available, taking as many
## as the league still has list spots to fill. Rebuilt once per pick.
func _reserve_per_spot() -> float:
	if intake_mode:
		return float(Contracts.senior_min(GameDB.START_YEAR))
	if _reserve_at == pick_index:
		return _reserve_cache
	_reserve_at = pick_index
	var open := 0
	for code in clubs:
		open += maxi(0, target_size - count_for(code))
	var values: Array = []
	for q in pool:
		if not picked.has(str(q["id"])):
			values.append(cost_of(q))
	values.sort()
	var n := mini(open, values.size())
	if n <= 0:
		_reserve_cache = float(Contracts.senior_min(GameDB.START_YEAR))
		return _reserve_cache
	var total := 0
	for i in range(n):
		total += int(values[i])
	_reserve_cache = maxf(float(Contracts.senior_min(GameDB.START_YEAR)), float(total) / float(n))
	return _reserve_cache


## The rival's pick. `why` is filled with a reason code for each prospect in
## `wanted` it passed on, or took (P-18): the branch below that ruled him
## out, or what his score lost on against the pick (_why_scored).
func _best_ai_pick(code: String, why := {}) -> Dictionary:
	var forced_role := _forced_role(code)
	var best := {}
	var best_score := -INF
	var watch := AiReasons.enabled and not wanted().is_empty()
	var scored := {}   # wanted id -> [score, detail]
	var mine := code == user_club and user_max_age > 0
	for p in pool:
		var id := str(p["id"])
		if picked.has(id):
			continue
		if mine and too_old_for_user(p):
			continue
		if forced_role != "" and not Ratings.plays_role(p, forced_role):
			if watch and wanted().has(id):
				why[id] = "draft_must_ruck"
			continue
		if not _can_afford_for(code, p):
			if watch and wanted().has(id):
				why[id] = "draft_cap"
			continue
		if intake_mode and str(p["role"]) == "RUCK" and _intake_ruck_need(code, p) <= 0.0:
			if watch and wanted().has(id):
				why[id] = "draft_ruck_full"
			continue   # a fourth ruck: no use to this club
		var detail := {}
		var score := _ai_score(code, p, detail)
		if watch and wanted().has(id):
			scored[id] = [score, detail]
		if score > best_score:
			best_score = score
			best = p

	# If a forced role cannot be filled, keep the draft moving with the best
	# affordable player. This should be rare, but protects small custom datasets.
	if best.is_empty() and forced_role != "":
		for p in pool:
			var id := str(p["id"])
			if picked.has(id):
				continue
			if mine and too_old_for_user(p):
				continue
			if not _can_afford_for(code, p):
				continue
			var detail := {}
			var fallback_score := _ai_score(code, p, detail)
			if watch and wanted().has(id):
				why.erase(id)  # the forced role no longer ruled him out
				scored[id] = [fallback_score, detail]
			if fallback_score > best_score:
				best_score = fallback_score
				best = p
	if watch and not best.is_empty():
		_why_scored(code, best, best_score, scored, why)
	return best


## Reason codes for the wanted prospects that were scored: the pick itself
## ("draft_took_need" when it filled an open starting spot, else
## "draft_took_best"), and for the rest the part of the score they lost on.
func _why_scored(code: String, best: Dictionary, best_score: float, scored: Dictionary, why: Dictionary) -> void:
	var bid := str(best["id"])
	var bd := {}
	if scored.has(bid):
		bd = scored[bid][1]
	else:
		_ai_score(code, best, bd)
	for id in scored:
		var d: Dictionary = scored[id][1]
		if id == bid:
			why[id] = "draft_took_need" if float(d.get("need", 0.0)) >= 1.0 else "draft_took_best"
		elif bool(d.get("second_star", false)):
			# The rule turns on his rating and their ruck's: say so only when
			# the board shows the coach both; otherwise only what is plain.
			why[id] = "draft_first_ruck" if _first_ruck_public(code, scored_player(id)) else "draft_preferred"
		elif float(d.get("need", 0.0)) <= 0.0 and str(d.get("role", "")) == "RUCK":
			why[id] = "draft_ruck_full"
		elif float(d.get("need_list", 0.0)) < float(bd.get("need_list", 0.0)):
			why[id] = "draft_stocked"
		elif float(scored[id][0]) + float(d.get("penalty", 0.0)) - float(bd.get("penalty", 0.0)) > best_score:
			why[id] = "draft_price"
		else:
			why[id] = "draft_preferred"


## The prospect `id` from the pool (for a reason's check), or {}.
func scored_player(id: String) -> Dictionary:
	return _pool_player(id)


## True when the board shows the coach exact ratings for `p` and for every
## first-choice ruck on `code`'s list: only then may a reason rest on them.
func _first_ruck_public(code: String, p: Dictionary) -> bool:
	if p.is_empty() or bool(user_view(p)["scouted"]):
		return false
	for q in club_lists.get(code, []):
		if str(q["role"]) == "RUCK" and int(q["overall"]) >= RUCK_FIRST_CHOICE and bool(user_view(q)["scouted"]):
			return false
	return true


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
## Average cap left per open list spot below which a pick is marked down,
## expressed on Contracts.salary_score's old 1-10-equivalent scale.
const AI_CAP_FLOOR := 3.0
const AI_POT_WEIGHT_LEAGUE := 0.25
const AI_POT_WEIGHT_INTAKE := 0.65
## Share of a balanced list by position: 11 mids, 12 defenders, 12 forwards
## of a 37 - list depth for the 6-6-6 match-day shape, the back and forward
## lines running a little deep (rucks: two in the career draft, ~8% of a
## list at the intake).
const AI_LIST_SHARE := {"RUCK": 0.08, "MID": 0.30, "DEF": 0.33, "FWD": 0.33}

## Scarcity is a reason to reach late, not at the top: the edge over
## replacement counts in full from the third round and not at all at the
## first pick, in both drafts (row 37, director 2026-11-03), so a club takes
## the best player early and reaches for a thin position late.
const AI_VORP_FULL_ROUNDS := 2


func _vorp_weight(_code := "") -> float:
	if clubs.is_empty():
		return AI_VORP_WEIGHT
	var ramp := float(pick_index) / float(clubs.size() * AI_VORP_FULL_ROUNDS)
	return AI_VORP_WEIGHT * clampf(ramp, 0.0, 1.0)


## National Draft (row 37): the edge over replacement counts for at most this
## much, and a covered position keeps this share of a prospect's worth (need
## only tips near-equals). Every club drafts this way, the user's "Pick for
## me" and sim-through picks included (director, 2026-11-03).
const AI_INTAKE_VORP_CAP := 5.0
const AI_INTAKE_COVERED := 0.97


func _vorp_cap(_code := "") -> float:
	return AI_INTAKE_VORP_CAP if intake_mode else AI_VORP_CAP


func _intake_covered(_code: String) -> float:
	return AI_INTAKE_COVERED


var _ai_cache_at := -1
var _ai_avail := {}      # role -> worths of available players, best first
var _ai_share := {}      # role -> share of the league's remaining demand


func scouting_mult_for(code: String) -> float:
	return maxf(0.25, float(scouting_mults.get(code, 1.0)))


## `detail`, when given, is filled with the parts of the winning position's
## score: {"role", "need", "second_star", "penalty"} (P-18 reasons).
func _ai_score(code: String, p: Dictionary, detail = null) -> float:
	_refresh_ai_cache()
	var base := DraftScouting.scouted_worth(p, code, seed, AI_POT_WEIGHT_INTAKE,
			scouting_mult_for(code)) if intake_mode else _club_worth(code, p)
	var err := _eval_error(code, p)
	var best := -INF
	var roles := [[str(p["role"]), 1.0]]
	var role2 := str(p.get("role2", ""))
	if role2 != "" and role2 != str(p["role"]):
		roles.append([role2, 0.85])
	for entry in roles:
		var role: String = entry[0]
		var need := _need_weight(code, role)
		if role == "RUCK" and intake_mode:
			need = _intake_ruck_need(code, p)
		var second_star := false
		if role == "RUCK" and _has_first_ruck(code) and int(p["overall"]) >= RUCK_FIRST_CHOICE:
			# One ruck plays at a time: a club with its first-choice ruck
			# looks for a second, not another star to sit behind him.
			need *= SECOND_STAR_RUCK
			second_star = true
		# A club's own opinion counts in full for a starting spot it is
		# filling; for depth and surplus picks it leans on the consensus.
		var worth := base + err * need
		var over := minf(_vorp_cap(code), worth - _replacement(code, role))
		var s := (worth + _vorp_weight(code) * over) * need * float(entry[1])
		if s > best and detail is Dictionary:
			detail["role"] = role
			detail["need"] = need
			detail["need_list"] = _need_by_count(code, role)
			detail["second_star"] = second_star
		best = maxf(best, s)
	var penalty := _cap_penalty(code, p)
	if detail is Dictionary:
		detail["penalty"] = penalty
	return best - penalty


# ---------------------------------------------------------------------------
# Rival AI: club-specific player evaluation
# ---------------------------------------------------------------------------
## Recruiting departments disagree. In the career draft every rival club
## sees each player through its own scouting opinion: the worth above plus a
## fixed error that belongs to that club and that player, weighted by how
## much the club needs him (full for an open starting spot, less for depth,
## little for surplus - late-draft depth picks follow the consensus). The
## opinion is zero-mean (no club is told to over- or under-rate everyone), and clubs
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
	if intake_mode or not league_mode:
		return 0.0
	# Your club's opinion is your recruiters' read (row T1.R26 L1, director
	# 2026-11-10: "everything follows the read"), so Pick for me and your price
	# see what you see.
	if code == user_club:
		return float(int(user_view(p)["overall_mid"]) - int(p.get("overall", 50)))
	var sd := club_eval_sd(code)
	if sd <= 0.0:
		return 0.0
	var key := "%d|eval|%s|%s" % [seed, code, str(p["id"])]
	# Box-Muller from two independent hashes of the key.
	var u1 := maxf(1e-9, _hash01("a|" + key))
	var u2 := _hash01("b|" + key)
	var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return clampf(z, -AI_EVAL_CLAMP, AI_EVAL_CLAMP) * sd * _eval_certainty(p)


## Clubs agree more about the league's proven best: at the consensus top the
## opinion counts AI_EVAL_TOP_SHARE of itself, rising to full by
## AI_EVAL_FULL_RANK. Below that - where most of a list is built and where
## sharper scouting separates clubs - nothing changes.
const AI_EVAL_TOP_SHARE := 0.30
const AI_EVAL_FULL_RANK := 90
var _consensus_rank := {}


func _eval_certainty(p: Dictionary) -> float:
	if _consensus_rank.is_empty():
		# Clubs agree on what a player has shown, not on what he is worth to
		# them: with horizons, a 35-year-old star is still read exactly.
		var shown := func(p: Dictionary) -> float:
			return float(p["overall"]) if league_mode and not intake_mode and horizon_value else _worth(p)
		var by_worth := pool.duplicate()
		by_worth.sort_custom(func(a, b):
			if not is_equal_approx(shown.call(a), shown.call(b)):
				return shown.call(a) > shown.call(b)
			return str(a["id"]) < str(b["id"]))
		for i in range(by_worth.size()):
			_consensus_rank[str(by_worth[i]["id"])] = i + 1
	var rank := int(_consensus_rank.get(str(p["id"]), AI_EVAL_FULL_RANK))
	return lerpf(AI_EVAL_TOP_SHARE, 1.0, clampf(float(rank - 1) / float(AI_EVAL_FULL_RANK - 1), 0.0, 1.0))


func _eval_sd_range() -> Array:
	return [AI_EVAL_SD_MIN, AI_EVAL_SD_MAX]


# ---------------------------------------------------------------------------
# What your club sees
# ---------------------------------------------------------------------------
## Your recruiters are an average club's: the middle of the rival range,
## sharper or blunter with the recruiting budget.
const USER_EVAL_SD := 3.0


## A player as your club sees him: {"scouted", "overall", "potential" (each
## [low, high]), "overall_mid", "potential_mid"}. A National Draft prospect
## is a scouting projection; in the League Draft a player you have not
## drafted is your recruiters' read, as every rival club has its own; your
## own picks are known exactly. The player underneath never changes.
func user_view(p: Dictionary) -> Dictionary:
	var ov := int(p.get("overall", 50))
	var pot := maxi(ov, int(p.get("potential", ov)))
	if intake_mode and bool(p.get("projected", false)):
		var proj := DraftScouting.projection(p, user_club, seed, scouting_mult_for(user_club))
		proj["scouted"] = true
		return proj
	if not league_mode or intake_mode or drafted_by(str(p["id"])) == user_club:
		return {"scouted": false, "overall": [ov, ov], "potential": [pot, pot],
				"overall_mid": ov, "potential_mid": pot}
	var sd := USER_EVAL_SD * scouting_mult_for(user_club) * _eval_certainty(p)
	var ov_mid := clampi(int(round(float(ov) + _user_error(p, "ovr") * sd)), 1, 99)
	# POT reads tightened (director, 2026-10-07): wide reads made elite talent
	# look common. The read's miss is no bigger than OVR's, and the window is
	# a point either side wider than OVR's.
	var pot_mid := clampi(int(round(float(pot) + _user_error(p, "pot") * sd)), ov_mid, 99)
	var half := maxi(1, int(round(sd * 0.7)))
	return {"scouted": true, "overall": [maxi(1, ov_mid - half), mini(99, ov_mid + half)],
			"potential": [maxi(ov_mid, pot_mid - half - 1), mini(99, pot_mid + half + 1)],
			"overall_mid": ov_mid, "potential_mid": pot_mid}


## What `code` pays for him: his true salary, the same for every club at
## every scouting level. In Redraft mode's initial redraft every salary is
## clear, never blurred by scout prowess (director 2026-11-10: "in redraft mode
## the salaries shouldnt be obscured by scout prowess ... all salaries must be
## clear"). Row T1.R26 L1 (everything follows the read) still moves what you
## see of his ratings, traits and Pick for me; never his salary.
func price_for(_code: String, p: Dictionary) -> int:
	return cost_of(p)


## His salary in the opening season's dollars (the budget's year,
## compute_budget): Legacy mode prices a 1990 draft in 1990 dollars.
static func cost_of(p: Dictionary) -> int:
	return Contracts.dollars(int(p["value"]), GameDB.START_YEAR)


## Your price for him (price_for your club).
func price(p: Dictionary) -> int:
	return price_for(user_club, p)


## A player as your scouts see him (row T1.R26 L1, "everything follows the
## read"): every rating moved by the read's miss on his OVR, so his strengths,
## traits and full ratings miss exactly as often as the OVR range does. Only
## what you see uses it; the player underneath never changes. `p` itself when
## your read of him is exact.
func scouted_copy(p: Dictionary) -> Dictionary:
	var view := user_view(p)
	if not bool(view["scouted"]) or not p.has("attr"):
		return p
	var shift := float(int(view["overall_mid"]) - int(p.get("overall", 50)))
	var c := p.duplicate(true)
	var attr: Dictionary = c["attr"]
	for k in attr.keys():
		var moved := clampf(float(attr[k]) + shift, 1.0, 99.0)
		attr[k] = roundi(moved) if typeof(attr[k]) == TYPE_INT else moved
	c["overall"] = int(view["overall_mid"])
	c["potential"] = int(view["potential_mid"])
	return c


## user_view for a whole board at once, by id, so a sort reads each once.
func _views(players: Array) -> Dictionary:
	var out := {}
	for p in players:
		out[p["id"]] = user_view(p)
	return out


## A standard-normal draw fixed per draft, player and stat: your read of him
## does not change while you look at him.
func _user_error(p: Dictionary, what: String) -> float:
	var key := "%d|user|%s|%s" % [seed, str(p["id"]), what]
	var u1 := maxf(1e-9, _hash01("a|" + key))
	var u2 := _hash01("b|" + key)
	return clampf(sqrt(-2.0 * log(u1)) * cos(TAU * u2), -AI_EVAL_CLAMP, AI_EVAL_CLAMP)


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
	if league_mode and not intake_mode and horizon_value:
		return horizon_worth(p, "build")
	var ov := float(p["overall"])
	var pot := maxf(ov, float(p.get("potential", ov)))
	var w := AI_POT_WEIGHT_INTAKE if intake_mode else AI_POT_WEIGHT_LEAGUE
	return ov * (1.0 - w) + pot * w


## A club's own view of a player's worth: its horizon in the League Draft.
func _club_worth(code: String, p: Dictionary) -> float:
	if league_mode and not intake_mode and horizon_value:
		return horizon_worth(p, club_horizon(code))
	return _worth(p)


# ---------------------------------------------------------------------------
# League Draft: a club's horizon (director's PC playtest, 2026-10-07)
# ---------------------------------------------------------------------------
## A player is worth the seasons he will give, not his rating today alone:
## his expected rating each coming season (Potential.outlook), above what a
## club could find anywhere (HORIZON_REPLACEMENT), counted only while he is
## still playing, and weighted by the club's horizon. A club chasing the flag
## now counts next season and the one after; a club building counts the long
## run, so a 35-year-old is a fine pick for the first and a poor one for the
## second, and a 19-year-old with a big ceiling the other way round. In
## rating points, so the rest of the AI (need, scarcity, cap, its own
## opinion) works as before. horizon_value off: the old blend of today's
## rating and POT (for paired audits).
static var horizon_value := true
## Building clubs look eight seasons ahead (director, 2026-10-07: "look
## further ahead"), so the best kids are contested early.
const HORIZON_YEARS := 8
const HORIZON_WEIGHTS := {
	"now": [1.0, 0.7, 0.25, 0.1, 0.0, 0.0, 0.0, 0.0],
	"build": [1.0, 1.0, 1.0, 1.0, 0.95, 0.9, 0.85, 0.8],
}
## Share of rival clubs going for the flag now; the rest build.
const HORIZON_NOW_SHARE := 0.25
const HORIZON_REPLACEMENT := 58.0
## Share of a season after he retires that still dilutes a building club's
## view of a veteran (1.0 = full, the old rule).
static var BUILD_RETIRED_SHARE := 0.35
var _horizon_cache := {}


## "now" or "build", fixed for a club in a draft by its seed.
func club_horizon(code: String) -> String:
	return "now" if _hash01("%d|horizon|%s" % [seed, code]) < HORIZON_NOW_SHARE else "build"


func horizon_worth(p: Dictionary, horizon: String) -> float:
	var key := "%s|%s" % [str(p["id"]), horizon]
	if _horizon_cache.has(key):
		return float(_horizon_cache[key])
	var weights: Array = HORIZON_WEIGHTS[horizon]
	var total := 0.0
	var above := 0.0
	var seasons := Potential.outlook(p, HORIZON_YEARS)
	for t in range(HORIZON_YEARS):
		var w := float(weights[t])
		# A club going for the flag now values an older star for the seasons he
		# will actually play: seasons after he retires do not dilute his rating
		# (director, 2026-10-14). Building clubs count every season as before.
		var alive := float(seasons[t][1])
		total += w * (alive if horizon == "now" else alive + BUILD_RETIRED_SHARE * (1.0 - alive))
		above += w * float(seasons[t][1]) * (float(seasons[t][0]) - HORIZON_REPLACEMENT)
	var v := HORIZON_REPLACEMENT + above / maxf(0.001, total)
	_horizon_cache[key] = v
	return v


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


## A national-draft prospect at a position the club already has covered is
## worth this share: a few rating points, enough to separate near-equals.
const INTAKE_COVERED := 0.92
## A third ruck is worth this share early in a National Draft; full (covered)
## from this round on, or when he has this much growth in him.
const INTAKE_RUCK_THIRD := 0.5
const INTAKE_RUCK_LATE_ROUND := 3
const INTAKE_RUCK_PROJECT_GAP := 12


## A first-choice ruck (League Draft): rated this or better and young enough
## to be one for the seasons ahead.
const RUCK_FIRST_CHOICE := 65
const SECOND_STAR_RUCK := 0.6


func _has_first_ruck(code: String) -> bool:
	if intake_mode:
		return false
	for p in club_lists.get(code, []):
		if str(p["role"]) == "RUCK" and int(p["overall"]) >= RUCK_FIRST_CHOICE and float(p.get("age", 30.0)) < 33.0:
			return true
	return false


## AI clubs stop at two rucks (director, 2026-10-14): a third only late in the
## draft or as a clear project (a long way to grow), never a fourth.
func _intake_ruck_need(code: String, p: Dictionary) -> float:
	var n := int(role_counts_for(code).get("RUCK", 0))
	if n < 2:
		return 1.0
	if n >= 3:
		return 0.0
	var project := int(p.get("potential", 0)) - int(p.get("overall", 0)) >= INTAKE_RUCK_PROJECT_GAP
	return INTAKE_COVERED if (current_round() >= INTAKE_RUCK_LATE_ROUND or project) else INTAKE_RUCK_THIRD


## The need a reason may name: from the list's counts and the round alone,
## never a rating (the intake ruck rule's "project" turns on POT; the first-
## choice ruck rule on OVR). P-18 reasons only; picks use _need_weight.
func _need_by_count(code: String, role: String) -> float:
	if role == "RUCK" and intake_mode:
		var n := int(role_counts_for(code).get("RUCK", 0))
		if n < 2:
			return 1.0
		if n >= 3:
			return 0.0
		return INTAKE_COVERED if current_round() >= INTAKE_RUCK_LATE_ROUND else INTAKE_RUCK_THIRD
	return _need_weight(code, role)


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
	if intake_mode:
		# The national draft builds for years ahead: need tips close calls,
		# it never makes a club pass a much better prospect.
		return 1.0 if n < int(_ideal_counts(code).get(role, 0)) else _intake_covered(code)
	if n < int(_ideal_counts(code).get(role, 0)):
		return 0.6
	return 0.2


## The worth of the player this club can expect in `role` at its next pick:
## rivals pick in between, and roughly their share of those picks goes to
## this position.
func _replacement(code: String, role: String) -> float:
	var avail: Array = []
	if intake_mode:
		# A National Draft club judges the depth behind a prospect through the
		# same imperfect scouting view as the prospect itself.
		for p in pool:
			if picked.has(str(p["id"])) or not Ratings.plays_role(p, role):
				continue
			avail.append(DraftScouting.scouted_worth(p, code, seed,
					AI_POT_WEIGHT_INTAKE, scouting_mult_for(code)))
		avail.sort()
		avail.reverse()
	else:
		avail = _ai_avail.get(role, [])
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
	var salary := price_for(code, p)
	var value := Contracts.salary_score(salary)
	var spots_after := target_size - count_for(code) - 1
	if spots_after <= 0:
		return value * 0.3
	var left := float(budget - int(club_spend.get(code, 0)) - salary)
	var per_spot := int(left / float(spots_after))
	var per_spot_score := Contracts.salary_score(per_spot)
	return maxf(0.0, AI_CAP_FLOOR - per_spot_score) * 12.0 + value * 0.3


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


## Picks a club may make: one a round, plus any compensation picks and picks
## it traded for, less those it traded away.
func pick_limit(code: String) -> int:
	var n := 0 if guests.has(code) else target_size
	for c in comp_picks:
		if str(c["club"]) == code:
			n += 1
	for key in pick_owners:
		var parts := str(key).split(":")
		if int(parts[0]) > target_size:
			continue
		if str(pick_owners[key]) == code:
			n += 1
		if str(parts[1]) == code:
			n -= 1
	if intake_mode and _planned_len > 0:
		# The rounds run until lists are full: the extra rounds' places count too.
		for i in range(_planned_len, pick_sequence.size()):
			if str(pick_sequence[i]) == code:
				n += 1
	return n


## The compensation pick at `index`, or {}.
func comp_at(index: int) -> Dictionary:
	for c in comp_picks:
		if int(c["index"]) == index:
			return c
	return {}


func count_for(code: String) -> int:
	if league_mode:
		return (club_lists.get(code, []) as Array).size()
	return order.size()


func has(id: String) -> bool:
	return picked.has(id)


## Over your Youth only age line (user_max_age)?
func too_old_for_user(p: Dictionary) -> bool:
	return user_max_age > 0 and int(floor(float(p.get("age", 0)))) > user_max_age


func can_pick_player(p: Dictionary) -> bool:
	if too_old_for_user(p):
		return false
	if league_mode:
		if not is_user_turn() or picked.has(str(p["id"])) or not _can_afford_for(user_club, p):
			return false
		var forced_role := _forced_role(user_club)
		return forced_role == "" or Ratings.plays_role(p, forced_role)
	return not picked.has(str(p["id"])) and count() < target_size and remaining() >= cost_of(p)


## Your turn, and no player left fits both your cap and your list's needs.
## Only an older save (from before the cap guard) can reach this.
func user_stuck() -> bool:
	if not league_mode or intake_mode or not is_user_turn():
		return false
	for p in pool:
		if can_pick_player(p):
			return false
	return true


## A finished list the rules refuse (over the cap, or short of two rucks) with
## every place filled. Play cannot reach it - every pick is checked against
## the cap and the two-ruck rule - but an older save can. Releasing a pick
## reopens the draft with one extra pick at the end, so the coach can fix it
## without starting again. Never true for a list that is valid.
func finished_list_refused() -> bool:
	return league_mode and not intake_mode and is_finished() 			and not is_valid() and count() >= target_size


## Releasing a pick is offered when you are stuck or the finished list is refused.
func can_release() -> bool:
	return user_stuck() or finished_list_refused()


## The way out of a stuck draft without ever breaching the cap: release one
## of your picks. He goes back into the pool, his salary comes off your books
## and you get an extra pick at the end of the draft to fill his place.
func release_for_room(id: String) -> bool:
	if not can_release() or not picked.has(id) or drafted_by(id) != user_club:
		return false
	var p: Dictionary = picked[id]
	(club_lists[user_club] as Array).erase(p)
	picked.erase(id)
	order.erase(id)
	club_spend[user_club] = int(club_spend[user_club]) - price_for(user_club, p)
	var entry: Dictionary = _pick_by_player.get(id, {})
	entry["released"] = true
	_pick_by_player.erase(id)
	pick_sequence.append(user_club)
	# The parallel arrays stay in step: the extra pick is in the last round.
	pick_rounds.append(int(pick_rounds[-1]) if not pick_rounds.is_empty() else 1)
	pick_origin.append(user_club)
	_reserve_at = -1
	return true


## Why you cannot take this player right now, in words ("" when you can).
## The same checks as can_pick_player, in the order a manager would ask
## them. Read-only.
func pick_block_reason(p: Dictionary) -> String:
	var id := str(p["id"])
	if picked.has(id):
		var entry := pick_details(id)
		var club := drafted_by(id)
		if club == "" or not league_mode:
			return "Already on your list."
		return "Drafted #%d by %s." % [int(entry.get("pick", 0)),
				Engine.get_main_loop().root.get_node("GameDB").club_name(club)]
	if too_old_for_user(p):
		return "Youth only: %s is %d, and you cannot draft a player over %d." % [
				Challenge.surname(p), int(floor(float(p.get("age", 0)))), user_max_age]
	if league_mode:
		if is_finished():
			return "The draft is complete."
		if not is_user_turn():
			return "Not your pick yet - rival clubs are still choosing."
		if count() >= pick_limit(user_club):
			return "Your list is full."
		if not _can_afford_for(user_club, p):
			var slots_after := target_size - count() - 1
			if slots_after <= 0:
				return "Not enough salary cap: he costs %s and you have %s left." % [Contracts.money(price(p)), Contracts.money(remaining())]
			return "This selection would leave too little salary cap to complete your list. He costs %s; you have %s left, and after keeping about %s for your other %d places, %s is free for this pick." % [
					Contracts.money(price(p)), Contracts.money(remaining()), Contracts.money(reserve_for(user_club)), slots_after, Contracts.money(maxi(0, usable_cap_for(user_club)))]
		var forced := _forced_role(user_club)
		if forced != "" and not Ratings.plays_role(p, forced):
			return "Your remaining places must go to rucks: every list needs two."
		return ""
	if count() >= target_size:
		return "Your list is full."
	if remaining() < cost_of(p):
		return "Not enough salary cap: he costs %s and you have %s left." % [Contracts.money(cost_of(p)), Contracts.money(remaining())]
	return ""


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

	if picked.has(p["id"]) or too_old_for_user(p):
		return false
	if count() >= target_size:
		return false
	if remaining() < cost_of(p):
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
			if intake_mode:
				out.sort_custom(func(a, b):
					return DraftScouting.estimated_overall(a, user_club, seed,
							scouting_mult_for(user_club)) > DraftScouting.estimated_overall(
							b, user_club, seed, scouting_mult_for(user_club)))
			elif league_mode:
				var seen := _views(out)
				out.sort_custom(func(a, b):
					return int(seen[a["id"]]["overall_mid"]) > int(seen[b["id"]]["overall_mid"]))
			else:
				out.sort_custom(func(a, b): return a["overall"] > b["overall"])
		"value":
			# Lowest cost at your price, then your read (L1: never the truth).
			var cost := {}
			for pl in out:
				cost[pl["id"]] = price(pl)
			var read := _views(out) if league_mode and not intake_mode else {}
			out.sort_custom(func(a, b):
				if cost[a["id"]] != cost[b["id"]]:
					return int(cost[a["id"]]) < int(cost[b["id"]])
				if not read.is_empty():
					return int(read[a["id"]]["overall_mid"]) > int(read[b["id"]]["overall_mid"])
				return a["overall"] > b["overall"])
		"name":
			out.sort_custom(func(a, b): return GameDB.player_sort_name(a) < GameDB.player_sort_name(b))
		"potential":
			if intake_mode:
				out.sort_custom(func(a, b):
					var ap := DraftScouting.estimated_potential(a, user_club, seed,
							scouting_mult_for(user_club))
					var bp := DraftScouting.estimated_potential(b, user_club, seed,
							scouting_mult_for(user_club))
					if ap != bp:
						return ap > bp
					return DraftScouting.estimated_overall(a, user_club, seed,
							scouting_mult_for(user_club)) > DraftScouting.estimated_overall(
							b, user_club, seed, scouting_mult_for(user_club)))
			elif league_mode:
				var seen := _views(out)
				out.sort_custom(func(a, b):
					var va: Dictionary = seen[a["id"]]
					var vb: Dictionary = seen[b["id"]]
					if int(va["potential_mid"]) != int(vb["potential_mid"]):
						return int(va["potential_mid"]) > int(vb["potential_mid"])
					return int(va["overall_mid"]) > int(vb["overall_mid"]))
			else:
				out.sort_custom(func(a, b):
					if int(a.get("potential", 0)) != int(b.get("potential", 0)):
						return int(a.get("potential", 0)) > int(b.get("potential", 0))
					return a["overall"] > b["overall"])
		"goals":
			out.sort_custom(func(a, b):
				if intake_mode:
					return float(a.get("u18_gl", 0.0)) > float(b.get("u18_gl", 0.0))
				return a["gl"] > b["gl"])
		"disposals":
			out.sort_custom(func(a, b):
				if intake_mode:
					return float(a.get("u18_di", 0.0)) > float(b.get("u18_di", 0.0))
				return a["di"] > b["di"])
	return out

