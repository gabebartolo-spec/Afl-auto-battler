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
## Trades & Contracts, where you negotiate salary and term with each player
## (see `wants`, `lowest` and `respond`). Players you leave undecided are
## re-signed for 2 years at their asking price if the cap allows; a player
## whose talks broke down goes to free agency. Contracts tick down at the
## rollover.

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


# ---------------------------------------------------------------------------
# Negotiation. No dice: the same offer always gets the same answer, and what
# a player wants is shown in full - only how far he would bend is left to the
# words in `stance`.
# ---------------------------------------------------------------------------
## Failed offers before a player gives up on talks and tests free agency.
const MAX_OFFERS := 3


## His opening position: his asking price over the term he would like.
## Players up to 29 want three years of security; older players two.
static func wants(p: Dictionary) -> Dictionary:
	return {"salary": asking_salary(p), "years": 3 if float(p.get("age", 25.0)) < 30.0 else 2}


## How much leverage he has: "star" (among the best, or a young gun), "fringe"
## (fighting for his spot), else "regular".
static func standing(p: Dictionary) -> String:
	var ovr := int(p.get("overall", 50))
	var age := float(p.get("age", 25.0))
	if ovr >= 79 or (age <= 23.0 and int(p.get("potential", ovr)) >= 82):
		return "star"
	if asking_salary(p) <= 4:
		return "fringe"
	return "regular"


## What a coach or manager would say about his position.
static func stance(p: Dictionary) -> String:
	match standing(p):
		"star":
			return "He knows his worth and won't take less."
		"fringe":
			return "He's fighting for his spot and will take less to stay."
	return "He'd give a little on salary for the security he wants."


## The least he would sign for over `years`. A regular or fringe player gives
## a point for the term he wants (or longer); a shorter deal costs a point
## more for anyone.
static func lowest(p: Dictionary, years: int) -> int:
	var want := wants(p)
	var price := int(want["salary"])
	if years < int(want["years"]):
		return price + 1
	if standing(p) != "star":
		price -= 1
	return maxi(1, price)


## His answer to `salary` over `years`, given how many offers have already
## failed. Returns {"answer": "accept" | "counter" | "walk", "salary": int,
## "insult": bool}. An offer at or above his lowest is accepted; anything else
## gets his lowest for that term as a counter. An offer under two-thirds of
## it is an insult and counts as two failures. Run out of offers and he walks.
static func respond(p: Dictionary, salary: int, years: int, failed := 0) -> Dictionary:
	var floor_price := lowest(p, years)
	if salary >= floor_price:
		return {"answer": "accept", "salary": salary, "insult": false}
	var insult := salary * 3 < floor_price * 2
	var strikes := failed + (2 if insult else 1)
	if strikes >= MAX_OFFERS:
		return {"answer": "walk", "salary": floor_price, "insult": insult}
	return {"answer": "counter", "salary": floor_price, "insult": insult}


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
		var short := "a little short" if in_value >= 0.9 * out_value else "well short"
		return {"ok": false, "reason": "They want more for that: your offer is %s of what they give up." % short}
	return {"ok": true, "reason": "They accept."}


## A club values a player more in a position it is short of.
static func _need_bonus(list: Array, leaving: Array, role: String) -> float:
	var have := 0
	for p in list:
		if str(p.get("role", "")) == role and not leaving.has(p):
			have += 1
	var ideal := {"RUCK": 3, "MID": 13, "DEF": 10, "FWD": 10}
	return 1.15 if have < int(ideal.get(role, 10)) else 1.0
