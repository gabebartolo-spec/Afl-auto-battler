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
## Rivals fill their lists from free agency up to this size.
const AI_FILL := 38
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


## How much leverage he has, from 0 (a fringe player glad of a contract) to 1
## (one of the best in the game, or a young gun). Scales smoothly with his
## worth - rating, potential and age - so no single rating changes the rules.
static func leverage(p: Dictionary) -> float:
	return clampf((worth(p) - 55.0) / 30.0, 0.0, 1.0)


## What a coach or manager would say about his position. Read off the same
## numbers as `lowest`, so the words never promise a discount he won't give.
static func stance(p: Dictionary) -> String:
	var want := wants(p)
	if lowest(p, int(want["years"])) >= int(want["salary"]):
		return "He knows his worth and won't take less."
	if leverage(p) < 0.35:
		return "He's fighting for a spot on a list and will take less."
	return "He'd give a little on salary for the security he wants."


## The least he would sign for over `years`. Given the term he wants (or
## longer) he gives up to a fifth of his price, less the more leverage he has;
## a shorter deal costs a point more for anyone.
static func lowest(p: Dictionary, years: int) -> int:
	var want := wants(p)
	var price := int(want["salary"])
	if years < int(want["years"]):
		return price + 1
	return maxi(1, roundi(price * (1.0 - 0.2 * (1.0 - leverage(p)))))


## His answer to `salary` over `years`, given how many offers have already
## failed (and, for a free agent, the `premium` his options add). Returns {"answer": "accept" | "counter" | "walk", "salary": int,
## "insult": bool}. An offer at or above his lowest is accepted; anything else
## gets his lowest for that term as a counter. An offer under two-thirds of
## it is an insult and counts as two failures. Run out of offers and he walks.
static func respond(p: Dictionary, salary: int, years: int, failed := 0, premium := 0) -> Dictionary:
	var floor_price := lowest(p, years) + premium
	if salary >= floor_price:
		return {"answer": "accept", "salary": salary, "insult": false}
	var insult := salary * 3 < floor_price * 2
	var strikes := failed + (2 if insult else 1)
	if strikes >= MAX_OFFERS:
		return {"answer": "walk", "salary": floor_price, "insult": insult}
	return {"answer": "counter", "salary": floor_price, "insult": insult}


## A free agent weighs your club against his options, all from facts you
## can see: `facts` = {"in_best22": would he make your best 22, "rivals":
## other clubs with the room and the need for him, "finish": your ladder
## finish, "clubs": clubs in the league}. Returns {"premium": points on top
## of his lowest, "refuse": bool, "reasons": [what he's weighing, in words]}.
## Rival interest costs a point. Your last finish costs a little more the
## lower you were (`club_premium`). A player who would not make your best 22
## won't come while another club wants him.
static func free_agent_terms(p: Dictionary, facts: Dictionary) -> Dictionary:
	var premium := 0
	var reasons := []
	var rivals := int(facts.get("rivals", 0))
	var finish := int(facts.get("finish", 0))
	var refuse := false
	if not bool(facts.get("in_best22", true)):
		if rivals > 0:
			refuse = true
			reasons.append("He wants senior football: he wouldn't make your best 22, and other clubs want him.")
		else:
			reasons.append("He wouldn't make your best 22, but no other club has room for him.")
	if rivals > 0 and not refuse:
		premium += 1
		reasons.append("Another club has the room and the need for him." if rivals == 1
				else "Other clubs have the room and the need for him.")
	var club := club_premium(p, finish, int(facts.get("clubs", 18)))
	if club > 0 and not refuse:
		premium += club
		reasons.append("Your side finished %s: he'd want a little more to come." % _ordinal(finish))
	return {"premium": premium, "refuse": refuse, "reasons": reasons}


## How much your last finish adds to his price: nothing for the premiers,
## rising evenly to a tenth of his asking price for the wooden spoon,
## rounded to a whole point. No single ladder position changes the rule; the
## rounding only decides where, for this player, the one point lands.
static func club_premium(p: Dictionary, finish: int, clubs: int) -> int:
	if finish <= 1 or clubs <= 1:
		return 0
	var t := clampf(float(finish - 1) / float(clubs - 1), 0.0, 1.0)
	return roundi(asking_salary(p) * 0.1 * t)


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


## Would a rival club want this free agent? It has a spot to fill, the cap room for
## his asking price and he would be at least an average player on its list
## - the same test rivals use to keep their own.
static func ai_wants(p: Dictionary, list: Array, cap: int) -> bool:
	if list.size() >= AI_FILL or asking_salary(p) > cap - payroll(list):
		return false
	var worths := []
	for q in list:
		worths.append(worth(q))
	worths.sort()
	var median := float(worths[worths.size() / 2]) if not worths.is_empty() else 0.0
	return worth(p) >= median - 2.0


# ---------------------------------------------------------------------------
# Free-agency compensation. A club that loses an out-of-contract player it
# wanted to keep - he walked, or it could not fit him under the cap - gets a
# national draft pick when he signs elsewhere. A delisted player earns
# nothing, and nor does one who had been at the club under two seasons.
# ---------------------------------------------------------------------------
## Seasons a player must have been at a club before losing him earns a pick.
const COMP_TENURE := 2


## Why a rival lets an expiring player go: "" (it keeps him), "delist" (not
## wanted: past it, or below the list's median worth) or "cap" (wanted, but
## no room for his price - he walks to free agency and can earn a pick).
static func ai_release_reason(p: Dictionary, list: Array, cap: int) -> String:
	if float(p.get("age", 25.0)) >= 33.0 and int(p.get("overall", 50)) < 70:
		return "delist"
	var worths := []
	for q in list:
		worths.append(worth(q))
	worths.sort()
	var median := float(worths[worths.size() / 2]) if not worths.is_empty() else 0.0
	if worth(p) < median - 2.0:
		return "delist"
	if asking_salary(p) > cap - payroll(list) + int(p.get("salary", 0)):
		return "cap"
	return ""


## The term a rival club offers: longer for the young.
static func ai_years(p: Dictionary) -> int:
	var age := float(p.get("age", 25.0))
	return 3 if age <= 25.0 else (2 if age <= 30.0 else 1)


## What losing him is worth, from what the market paid for him and who he
## is - nothing hidden: his new salary and its length, his rating and his
## age. Two parts in five are the salary he signed for, three his rating on
## the same scale (so a rating point moves it smoothly, where salaries step); a
## longer deal and a younger player each count for more. Roughly 1 to 14.
static func compensation_value(p: Dictionary, salary: int, years: int) -> float:
	var rating := clampf((float(p.get("overall", 50)) - 35.0) / 5.5, 1.0, 10.0)
	var base := 0.4 * float(salary) + 0.6 * rating
	var term := 0.85 + 0.1 * float(clampi(years, 1, MAX_YEARS))
	var youth := clampf(1.0 + (27.0 - float(p.get("age", 27.0))) * 0.03, 0.85, 1.15)
	return base * term * youth


## Where the pick goes: right after regular pick `after` in the national
## draft (0 = no pick). It slides evenly with the value - the best
## departures land mid first round, an ordinary starter around the end of
## the first, a role player in the second - and a value too small to reach
## the end of the second round earns nothing.
static func compensation_after(value: float, clubs: int) -> int:
	var after := roundi(float(clubs) * (0.5 + (12.0 - value) / 4.0))
	after = maxi(after, roundi(clubs * 0.5))
	return after if after <= clubs * 2 else 0


## "after pick 18, at the end of the first round".
static func pick_words(after: int, clubs: int) -> String:
	var rnd := (after - 1) / maxi(1, clubs) + 1
	var nth: String = ["first", "second", "third", "fourth"][clampi(rnd - 1, 0, 3)]
	var at := after - (rnd - 1) * clubs
	var where := "at the end of the %s round" % nth if at == clubs else \
			("early in the %s round" % nth if at <= clubs / 3 else "in the %s round" % nth)
	return "after pick %d, %s" % [after, where]


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
	return ai_release_reason(p, list, cap) == ""


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
