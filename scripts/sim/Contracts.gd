class_name Contracts
extends RefCounted
## Contracts, the salary cap, free agency and trade valuation.
##
## A contract is `contract_years` (seasons left, counting the current one)
## and `salary` (annual Australian dollars for list-management purposes,
## fixed when signed). Match payments/ASAs are deliberately outside this
## lightweight model. Every club's payroll counts against the same cap.
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

## 2027 is the first playable season. These are the real CBA anchors the
## simplified economy starts from; unknown future years grow by a modest
## game-world index rather than pretending future AFL agreements are known.
const CAP_2027 := 18440415
const SENIOR_MIN_2027 := 155000
const ROOKIE_MIN_2027 := 105000
const SALARY_STEP := 25000
const FUTURE_GROWTH := 1.03


static func salary_cap_for_year(year: int) -> int:
	var cap := float(CAP_2027)
	for y in range(2028, year + 1):
		cap *= FUTURE_GROWTH
	return int(round(cap / 1000.0)) * 1000


static func indexed_money_2027(amount: int, year: int) -> int:
	var value := float(amount)
	for y in range(2028, year + 1):
		value *= FUTURE_GROWTH
	return int(round(value / 1000.0)) * 1000


## Compact football money for phone UI.
static func money(amount: int) -> String:
	var n := maxi(0, amount)
	if n >= 1000000:
		var m := float(n) / 1000000.0
		return "$%.2fm" % m if n % 100000 != 0 else ("$%.1fm" % m)
	return "$%dk" % int(round(float(n) / 1000.0))


## Convert one old 1-10 cap-point salary into the equivalent rung of the new
## dollar curve. Used only for save migration.
static func old_points_to_salary(points: int) -> int:
	var map := {
		1: 155000, 2: 225000, 3: 325000, 4: 425000, 5: 525000,
		6: 650000, 7: 775000, 8: 900000, 9: 1050000, 10: 1250000,
	}
	if points <= 10:
		return int(map.get(maxi(1, points), SENIOR_MIN_2027))
	# Old negotiations could push a star beyond the 10-point base tier.
	return 1250000 + (points - 10) * 100000


## Salary represented on the old roughly 1-10 market scale. Free-agent
## preference and compensation use this normalised value so moving to dollars
## does not make money overwhelm role, security, rating or age.
static func salary_score(salary: int) -> float:
	return clampf(1.0 + 9.0 * (float(salary) - 155000.0) / (1250000.0 - 155000.0), 1.0, 12.0)


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


## A first-year National Draft deal. The 2027 CBA base bands are used as
## the starting point and indexed in later game-world seasons.
static func rookie_deal(p: Dictionary, year := 2027) -> void:
	p["contract_years"] = ROOKIE_YEARS
	var pick := int(p.get("draft_pick", 0))
	var base := 125000
	if pick > 0 and pick <= 10:
		base = 150000
	elif pick <= 20 and pick > 0:
		base = 140000
	elif pick <= 50 and pick > 0:
		base = 130000
	elif pick <= 0:
		base = ROOKIE_MIN_2027
	p["salary"] = indexed_money_2027(base, year)


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
## a shorter deal costs one normal negotiation step more for anyone.
static func lowest(p: Dictionary, years: int) -> int:
	var want := wants(p)
	var price := int(want["salary"])
	if years < int(want["years"]):
		return price + SALARY_STEP
	return maxi(SENIOR_MIN_2027, int(round(float(price) * (1.0 - 0.2 * (1.0 - leverage(p))) / 5000.0)) * 5000)


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


## Would this free agent turn you down flat? A player who would not make
## your best 22 won't come while a club that would play him has an offer on
## the table. `facts` = {"in_best22": bool, "rivals": offers from clubs that
## would play him}. Returns {"refuse": bool, "reasons": [words]}. His price
## is settled by the offers themselves (see the market below).
static func free_agent_terms(_p: Dictionary, facts: Dictionary) -> Dictionary:
	var reasons := []
	var refuse := false
	if not bool(facts.get("in_best22", true)):
		if int(facts.get("rivals", 0)) > 0:
			refuse = true
			reasons.append("He wants senior football: he wouldn't make your best 22, and a club that would play him has made an offer.")
		else:
			reasons.append("He wouldn't make your best 22, but no club that would play him has made an offer.")
	return {"premium": 0, "refuse": refuse, "reasons": reasons}


# ---------------------------------------------------------------------------
# The free-agent market. Clubs that want a free agent put real offers on the
# table (salary and years, visible to everyone); he weighs them on money,
# security, his role at the club and how the club went last year. No dice:
# the same offers always produce the same choice.
# ---------------------------------------------------------------------------
## Offers you can make that rivals answer: the second is your final offer.
const FA_ROUNDS := 2
const ROLE_WEIGHT := {"ground": 1.5, "bench": 0.75, "depth": 0.0}
const ROLE_RANK := {"ground": 2, "bench": 1, "depth": 0}


## How he rates an offer: salary normalised back to the old market scale,
## plus security (0.4 a year, up to the term he wants), role and club context.
## This keeps the pre-conversion bargaining balance intact.
## that finished high last year (`finish_t`: 0 premiers, 1 wooden spoon).
## Never shown as a number; `offer_view` puts it in words.
static func offer_score(p: Dictionary, o: Dictionary) -> float:
	var wanted := int(wants(p)["years"])
	return salary_score(int(o["salary"])) + 0.4 * float(mini(int(o["years"]), wanted)) \
			+ float(ROLE_WEIGHT.get(str(o.get("role", "depth")), 0.0)) \
			+ 0.8 * (1.0 - clampf(float(o.get("finish_t", 0.5)), 0.0, 1.0))


## Does he prefer offer `a` to `b`? Ties go to more money, then the longer
## deal, then the bigger role, then the club that finished higher - never
## to a club's place in any list.
static func prefers(p: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var sa := snappedf(offer_score(p, a), 0.001)
	var sb := snappedf(offer_score(p, b), 0.001)
	if sa != sb:
		return sa > sb
	if int(a["salary"]) != int(b["salary"]):
		return int(a["salary"]) > int(b["salary"])
	if int(a["years"]) != int(b["years"]):
		return int(a["years"]) > int(b["years"])
	var ra := int(ROLE_RANK.get(str(a.get("role", "depth")), 0))
	var rb := int(ROLE_RANK.get(str(b.get("role", "depth")), 0))
	if ra != rb:
		return ra > rb
	return float(a.get("finish_t", 1.0)) < float(b.get("finish_t", 1.0))


## The offer he prefers among `offers` (standing ones only), or {}.
static func best_offer(p: Dictionary, offers: Array) -> Dictionary:
	var best := {}
	for o in offers:
		if bool(o.get("withdrawn", false)):
			continue
		if best.is_empty() or prefers(p, o, best):
			best = o
	return best


## The most a club will pay him a season, from his role there and his
## asking price - never his potential: a starter up to two $25k steps over
## his ask, a bench player one, a depth signing only his lowest.
static func club_max(p: Dictionary, role: String, cap_room: int) -> int:
	var ask := asking_salary(p)
	var most := ask + 2 * SALARY_STEP if role == "ground" else (ask + SALARY_STEP if role == "bench" else lowest(p, ai_years(p)))
	return mini(most, cap_room)


## A club's opening offer: his lowest price for the term he wants (a depth
## signing: the club's usual term).
static func opening_offer(p: Dictionary, role: String) -> Dictionary:
	var years := int(wants(p)["years"]) if role != "depth" else ai_years(p)
	return {"salary": lowest(p, years), "years": years}


## A rival's answer when `leader` is ahead of its offer `own`: the cheapest
## offer up to `most` a season that he would prefer (it may lengthen the
## deal to the term he wants first). Returns {"action": "improve" |
## "match" | "hold" | "withdraw", "salary", "years"}: "match" when it only
## draws level on money, "withdraw" once the leading salary is past what he
## is worth to the club, "hold" otherwise.
static func rival_response(p: Dictionary, own: Dictionary, leader: Dictionary, most: int) -> Dictionary:
	var wanted := int(wants(p)["years"])
	var years_options := [int(own["years"])]
	if wanted > int(own["years"]):
		years_options.append(wanted)
	for salary in range(int(own["salary"]), most + 1, SALARY_STEP):
		for years in years_options:
			var trial: Dictionary = own.duplicate()
			trial["salary"] = salary
			trial["years"] = years
			if prefers(p, trial, leader):
				var action := "match" if salary == int(leader["salary"]) else "improve"
				if salary == int(own["salary"]) and years == int(own["years"]):
					action = "hold"
				return {"action": action, "salary": salary, "years": years}
	if int(leader["salary"]) > most:
		return {"action": "withdraw", "salary": int(own["salary"]), "years": int(own["years"])}
	return {"action": "hold", "salary": int(own["salary"]), "years": int(own["years"])}


## Why he likes `o` more than `other`, in a few words: the factor that
## favours it most. "" when nothing does.
static func offer_view(p: Dictionary, o: Dictionary, other: Dictionary, club_name: String) -> String:
	if other.is_empty():
		return "The only offer."
	var wanted := int(wants(p)["years"])
	var gaps := {
		"money": salary_score(int(o["salary"])) - salary_score(int(other["salary"])),
		"security": 0.4 * float(mini(int(o["years"]), wanted) - mini(int(other["years"]), wanted)),
		"role": float(ROLE_WEIGHT.get(str(o.get("role", "depth")), 0.0)) - float(ROLE_WEIGHT.get(str(other.get("role", "depth")), 0.0)),
		"club": 0.8 * (float(other.get("finish_t", 0.5)) - float(o.get("finish_t", 0.5))),
	}
	var top := ""
	for k in ["money", "role", "security", "club"]:
		if float(gaps[k]) > 0.0 and (top == "" or float(gaps[k]) > float(gaps[top])):
			top = k
	match top:
		"money":
			return "Best financial offer."
		"role":
			return "Clearer path into the best 22."
		"security":
			return "More contract security."
		"club":
			return "Prefers %s offer after their stronger season." % (club_name + ("'" if club_name.ends_with("s") else "'s"))
	return ""


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


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
	var base := 0.4 * salary_score(salary) + 0.6 * rating
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
		total += int(p.get("salary", p.get("value", SENIOR_MIN_2027)))
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


## Would a rival keep this expiring player at his asking price? Keep good
## players the cap can carry; let the rest go.
static func ai_keeps(p: Dictionary, list: Array, cap: int) -> bool:
	return ai_release_reason(p, list, cap) == ""

## A draft pick in a trade: {"pick": true, "id", "year", "round", "origin",
## "owner", "positions": [[overall pick, weight]...]} (GameState.pick_asset).
static func is_pick(a: Dictionary) -> bool:
	return bool(a.get("pick", false))


## Does the AI club accept `give` (its players and picks, to you) for `take`
## (yours, to it)? Picks are valued as the prospect a club expects to get
## with them (TradeValue.pick_value, from ctx "prospects": {year: ranked
## class}) and join the package like players. It weighs both sides by TradeValue from its own position: `ctx` =
## {"phase": its cycle, "games": {player id: last season's games}, "name":
## its club name, "names": {player id: display name}}. What it receives is
## judged against its side without the players it gives up, and counted as
## a package (its lesser pieces for less); what it gives up is counted in
## full. Returns {"ok": bool,
## "reason": String, "in": value received, "out": value given}.
static func evaluate_trade(ai_list: Array, give: Array, take: Array, cap: int,
		my_list: Array, my_cap: int, margin := TRADE_MARGIN, ctx := {}) -> Dictionary:
	if give.is_empty() or take.is_empty():
		return {"ok": false, "reason": "Pick a player or a pick from each side."}
	# Draft picks ride along with players: no list spot, no salary.
	var give_picks := give.filter(func(a): return is_pick(a))
	var take_picks := take.filter(func(a): return is_pick(a))
	give = give.filter(func(a): return not is_pick(a))
	take = take.filter(func(a): return not is_pick(a))
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
	var phase := str(ctx.get("phase", "building"))
	var games: Dictionary = ctx.get("games", {})
	var remaining := ai_list.filter(func(q): return not give.has(q))
	# Newcomers are fitted one at a time, the most valuable first, each into
	# the side with the earlier ones already in it: two players for one
	# gap don't both fill it, and the order you pick them in changes nothing.
	var ranked := take.duplicate()
	var standalone := {}
	var start_bars := TradeValue.selection_bars(remaining)
	var start_proj := TradeValue.selection_bars(remaining, true)
	for p in ranked:
		standalone[str(p["id"])] = float(TradeValue.value(p, {"phase": phase, "bars": start_bars, "proj": start_proj,
				"games": int(games.get(str(p["id"]), -1))})["total"])
	ranked.sort_custom(func(a, b):
		var va := float(standalone[str(a["id"])])
		var vb := float(standalone[str(b["id"])])
		if va != vb:
			return va > vb
		return str(a["id"]) < str(b["id"]))
	var in_values := []
	var benchwarmer := ""
	var side := remaining.duplicate()
	for p in ranked:
		var bars := TradeValue.selection_bars(side)
		var v := TradeValue.value(p, {"phase": phase, "bars": bars, "proj": TradeValue.selection_bars(side, true),
				"games": int(games.get(str(p["id"]), -1))})
		in_values.append(float(v["total"]))
		if TradeValue.fit(p, bars) < 0.5 and benchwarmer == "":
			benchwarmer = str((ctx.get("names", {}) as Dictionary).get(str(p["id"]), p.get("name", "")))
		side.append(p)
	var prospects: Dictionary = ctx.get("prospects", {})
	for pk in take_picks:
		in_values.append(TradeValue.pick_value(pk["positions"], prospects.get(str(pk["year"]), []), phase))
	var in_value := TradeValue.package(in_values)
	var out_value := 0.0
	var cornerstone := ""
	var best_future := 0.0
	for p in give:
		var without := ai_list.filter(func(q): return q != p)
		var v := TradeValue.value(p, {"phase": phase, "bars": TradeValue.selection_bars(without),
				"proj": TradeValue.selection_bars(without, true), "games": int(games.get(str(p["id"]), -1)), "own": true})
		out_value += float(v["total"])
		if float(v["future"]) > best_future and TradeValue.future_rating(p) > TradeValue.now_rating(p) + 3.0:
			best_future = float(v["future"])
			cornerstone = str((ctx.get("names", {}) as Dictionary).get(str(p["id"]), p.get("name", "")))
	for pk in give_picks:
		out_value += TradeValue.pick_value(pk["positions"], prospects.get(str(pk["year"]), []), phase)
	var out := {"ok": false, "in": in_value, "out": out_value}
	if in_value < out_value * (1.0 + margin):
		var club := str(ctx.get("name", "They"))
		if phase == "rebuilding" and cornerstone != "":
			out["reason"] = "%s are rebuilding: %s is part of their future." % [club, cornerstone]
		elif benchwarmer != "" and in_value < 0.9 * out_value:
			out["reason"] = "%s wouldn't get a game in their side." % benchwarmer
		else:
			var short := "a little short" if in_value >= 0.9 * out_value else "well short"
			out["reason"] = "They want more for that: your offer is %s of what they give up." % short
		return out
	out["ok"] = true
	out["reason"] = "They accept."
	return out
