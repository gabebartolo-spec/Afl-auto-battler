class_name Contracts
extends RefCounted
## Contracts, the salary cap, free agency and trade valuation.
##
## A contract is `contract_years` (seasons left, counting the current one)
## and `salary` (cap points, fixed when signed - a player's draft price,
## Ratings.salary_value). Every club's payroll counts against the same cap
## the career draft used, carried across seasons.
##
## Off-season (season over, before the national draft opens): contracts in
## their final year are up. Rivals decide straight away - keep a player who
## is worth his new price, let the rest go to free agency - and you decide in
## Trades & Contracts. Anything you leave undecided is re-signed for 2 years
## if the cap allows. Contracts tick down at the rollover.

const MIN_LIST := 32
const MAX_LIST := 44
const MAX_YEARS := 4
const ROOKIE_YEARS := 2
## A trade has to leave the AI club at least this much better off.
const TRADE_MARGIN := 0.04


## First contracts for a list: younger players on longer deals. Seeded by
## id, so the same career always gets the same contracts.
static func assign_initial(list: Array) -> void:
	for p in list:
		if p.has("contract_years"):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("contract|" + str(p["id"]))
		var age := float(p.get("age", 25.0))
		var years := 1
		if age <= 22.0:
			years = rng.randi_range(2, 3)
		elif age <= 29.0:
			years = rng.randi_range(1, 4)
		else:
			years = rng.randi_range(1, 2)
		p["contract_years"] = years
		p["salary"] = int(p.get("value", 3))


## A drafted rookie: two seasons on a rookie wage.
static func rookie_deal(p: Dictionary) -> void:
	p["contract_years"] = ROOKIE_YEARS
	var pick := int(p.get("draft_pick", 99))
	p["salary"] = 2 if pick > 0 and pick <= 10 else 1


## What re-signing (or signing) this player costs now.
static func asking_salary(p: Dictionary) -> int:
	var price := Ratings.salary_value(int(p.get("overall", 50)))
	# An unhappy player wants paying to stay.
	if int(p.get("morale", 70)) < 40:
		price = ceili(price * 1.25)
	return price


static func payroll(list: Array) -> int:
	var total := 0
	for p in list:
		total += int(p.get("salary", p.get("value", 1)))
	return total


static func expiring(list: Array) -> Array:
	var out := []
	for p in list:
		if int(p.get("contract_years", 1)) <= 1:
			out.append(p)
	return out


## Worth to a club, for re-signing and trades: rating blended with potential,
## discounted for age past 29.
static func worth(p: Dictionary) -> float:
	var ov := float(p.get("overall", 50))
	var pot := maxf(ov, float(p.get("potential", ov)))
	var w := ov * 0.65 + pot * 0.35
	w -= 1.5 * maxf(0.0, float(p.get("age", 25.0)) - 29.0)
	return w


## Stars are worth far more than two middling players: value grows steeply
## with worth, so two 65s never buy an 85.
static func trade_value(p: Dictionary) -> float:
	return pow(maxf(1.0, worth(p)) / 70.0, 4.0)


## Would a rival keep this expiring player at his asking price? Keep good
## players the cap can carry; let the rest go.
static func ai_keeps(p: Dictionary, list: Array, cap: int) -> bool:
	if float(p.get("age", 25.0)) >= 33.0 and int(p.get("overall", 50)) < 70:
		return false
	var room := cap - payroll(list) + int(p.get("salary", 0))
	if asking_salary(p) > room:
		return false
	# Keep anyone at or above the list's median worth.
	var worths := []
	for q in list:
		worths.append(worth(q))
	worths.sort()
	var median := float(worths[worths.size() / 2]) if not worths.is_empty() else 0.0
	return worth(p) >= median - 2.0


## Does the AI club accept `give` (its players, to you) for `take` (yours, to
## it)? Returns {"ok": bool, "reason": String}.
static func evaluate_trade(ai_list: Array, give: Array, take: Array, cap: int,
		my_list: Array, my_cap: int, margin := TRADE_MARGIN) -> Dictionary:
	if give.is_empty() or take.is_empty():
		return {"ok": false, "reason": "Pick a player from each side."}
	var in_value := 0.0
	var out_value := 0.0
	for p in take:
		in_value += trade_value(p) * _need_bonus(ai_list, give, str(p["role"]))
	for p in give:
		out_value += trade_value(p)
	var ai_after := ai_list.size() - give.size() + take.size()
	var my_after := my_list.size() - take.size() + give.size()
	if ai_after > MAX_LIST or my_after > MAX_LIST:
		return {"ok": false, "reason": "That would take a list past %d players." % MAX_LIST}
	if ai_after < MIN_LIST or my_after < MIN_LIST:
		return {"ok": false, "reason": "That would take a list below %d players." % MIN_LIST}
	var ai_pay := payroll(ai_list) - payroll(give) + payroll(take)
	if ai_pay > cap:
		return {"ok": false, "reason": "They cannot fit the salary under their cap."}
	var my_pay := payroll(my_list) - payroll(take) + payroll(give)
	if my_pay > my_cap:
		return {"ok": false, "reason": "You cannot fit the salary under your cap."}
	if in_value < out_value * (1.0 + margin):
		return {"ok": false, "reason": "They want more for that. (You offer %.0f%% of what they give up.)" % [
				100.0 * in_value / maxf(0.001, out_value)]}
	return {"ok": true, "reason": "They accept."}


## A club values a player more in a position it is short of.
static func _need_bonus(list: Array, leaving: Array, role: String) -> float:
	var have := 0
	for p in list:
		if str(p.get("role", "")) == role and not leaving.has(p):
			have += 1
	var ideal := {"RUCK": 3, "MID": 13, "DEF": 10, "FWD": 10}
	return 1.15 if have < int(ideal.get(role, 10)) else 1.0
