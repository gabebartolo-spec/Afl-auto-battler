class_name Draft
extends RefCounted
## The list-building phase: sign a full 44-player list out of the whole player
## pool under a salary cap.
##
## The cap is derived from the data rather than hard-coded, so it stays
## meaningful if the dataset changes. It is set at a fraction of what the 44
## best players in the competition would cost, which forces real trade-offs:
## you can have a handful of stars, or genuine depth, but not both.

const CAP_FRACTION := 0.58

var pool: Array = []
var budget := 0
var order: Array = []          # player ids, in pick order
var picked := {}               # id -> player dict


func _init(all_players: Array) -> void:
	pool = all_players.duplicate()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	budget = compute_budget(pool)


## What the 44 best players would cost, scaled down. Deterministic.
static func compute_budget(sorted_pool: Array) -> int:
	var n := mini(Ratings.LIST_SIZE, sorted_pool.size())
	var total := 0
	for i in n:
		total += int(sorted_pool[i]["value"])
	return maxi(n, int(round(total * CAP_FRACTION)))


func spent() -> int:
	var total := 0
	for id in order:
		total += int(picked[id]["value"])
	return total


func remaining() -> int:
	return budget - spent()


func count() -> int:
	return order.size()


func has(id: String) -> bool:
	return picked.has(id)


func pick(p: Dictionary) -> bool:
	if picked.has(p["id"]):
		return false
	if count() >= Ratings.LIST_SIZE:
		return false
	if remaining() < int(p["value"]):
		return false
	picked[p["id"]] = p
	order.append(p["id"])
	return true


func unpick(id: String) -> bool:
	if not picked.has(id):
		return false
	picked.erase(id)
	order.erase(id)
	return true


func list() -> Array:
	var out := []
	for id in order:
		out.append(picked[id])
	return out


## A list is signable at 44 players within the cap. Also require at least two
## ruckmen - a list with none cannot contest a centre bounce, and the engine
## would quietly field a midfield ruck instead.
func is_valid() -> bool:
	if count() != Ratings.LIST_SIZE:
		return false
	if spent() > budget:
		return false
	return count_by_role("RUCK") >= 2


func is_complete_size() -> bool:
	return count() >= Ratings.LIST_SIZE


func count_by_role(role: String) -> int:
	var n := 0
	for id in order:
		if str(picked[id]["role"]) == role:
			n += 1
	return n


func role_counts() -> Dictionary:
	var out := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
	for id in order:
		var r: String = picked[id]["role"]
		if out.has(r):
			out[r] = int(out[r]) + 1
	return out


## Filter + sort the pool for the draft board UI.
func board(role := "", club := "", search := "", sort := "overall",
		hide_picked := false) -> Array:
	var out := []
	var q := search.to_lower()
	for p in pool:
		if hide_picked and picked.has(p["id"]):
			continue
		if role != "" and p["role"] != role:
			continue
		if club != "" and p["club"] != club:
			continue
		if q != "" and not str(p["name"]).to_lower().contains(q):
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
			out.sort_custom(func(a, b): return str(a["last"]) < str(b["last"]))
		"goals":
			out.sort_custom(func(a, b): return a["gl"] > b["gl"])
		"disposals":
			out.sort_custom(func(a, b): return a["di"] > b["di"])
	return out


## The 17 AI lists: each club simply keeps the players it actually fielded in
## 2026. Real lists are already salary-balanced by definition, so this gives a
## fair ladder without needing to simulate a 17-way draft.
static func ai_lists(by_club: Dictionary, exclude_club: String) -> Dictionary:
	var out := {}
	for code in by_club:
		if code == exclude_club:
			continue
		out[code] = (by_club[code] as Array).duplicate()
	return out
