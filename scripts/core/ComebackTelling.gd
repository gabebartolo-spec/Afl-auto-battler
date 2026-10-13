class_name ComebackTelling
extends RefCounted
## Comebacks told from the match's own facts (director, 2026-10-14: comebacks stay,
## told better, never more often). Two lines, both only said when the break scores
## and the scoring log truly show it, and nothing when there is nothing to say:
##  - break_line: at three-quarter time, one plain line for the coach's side;
##  - turn_line: at full time, the quarter that turned a win from behind or a
##    lost lead, and the player who did it.
## Nothing here is read by the sim; it only reads a result.

## A run of goals worth saying: this many in a row, with no goal from the other side.
const RUN := 3
## Leads and deficits worth saying at a break (three goals).
const BIG := 18
## A quarter has to be won by at least this (two goals) to be called the turn.
const TURN := 12
## Past this many points the match is decided, and a run or a lead worn down is not news
## (a run of LONG_RUN goals is, whatever the margin).
const CLOSE := 30
const LONG_RUN := 6
const ORDINALS := ["first", "second", "third", "fourth"]
const BREAK_WORDS := ["quarter time", "half time", "three-quarter time"]


## Your lead after each of the first `n` quarters (negative: behind), from the
## quarter goals and behinds. [] if they are not there.
static func leads_after(res: Dictionary, me: int, n: int) -> Array:
	var qg: Array = res.get("q_goals", [])
	var qb: Array = res.get("q_behinds", [])
	if qg.size() < n or qb.size() < n:
		return []
	var out := []
	var tot := 0
	for i in range(n):
		tot += (int(qg[i][me]) * 6 + int(qb[i][me])) - (int(qg[i][1 - me]) * 6 + int(qb[i][1 - me]))
		out.append(tot)
	return out


## The goals kicked last, in a row, by one side: {"side", "n"} ({} for none).
static func goal_run(res: Dictionary) -> Dictionary:
	var log: Array = res.get("scoring", [])
	var side := -1
	var n := 0
	for i in range(log.size() - 1, -1, -1):
		var e: Array = log[i]
		if int(e[3]) != 1:
			continue
		if side < 0:
			side = int(e[2])
		if int(e[2]) != side:
			break
		n += 1
	return {} if side < 0 else {"side": side, "n": n}


## At three-quarter time: where you stand and the one thing behind it, or "".
## Only for the break after the third quarter. `res` is the match so far.
static func break_line(res: Dictionary, me: int) -> String:
	var leads := leads_after(res, me, 3)
	if leads.size() != 3:
		return ""
	var now := int(leads[2])
	if now == 0:
		return ""
	var stand := ("You lead by %d" % now) if now > 0 else ("You trail by %d" % -now)
	# 1. A turn since the early breaks: the match is not where it was.
	var worst := 0
	var worst_at := -1
	var best := 0
	var best_at := -1
	for i in range(2):
		if int(leads[i]) < worst:
			worst = int(leads[i])
			worst_at = i
		if int(leads[i]) > best:
			best = int(leads[i])
			best_at = i
	if now > 0 and -worst >= BIG:
		return "%s, after trailing by %d at %s." % [stand, -worst, BREAK_WORDS[worst_at]]
	if now < 0 and best >= BIG:
		return "%s, after leading by %d at %s." % [stand, best, BREAK_WORDS[best_at]]
	# 2. A run of goals to finish the quarter.
	var run := goal_run(res)
	if not run.is_empty() and ((int(run["n"]) >= RUN and absi(now) <= CLOSE) or int(run["n"]) >= LONG_RUN):
		var mine := int(run["side"]) == me
		var who := "you have" if mine else "they have"
		var joiner := "but" if (mine != (now > 0)) else "and"
		return "%s, %s %s kicked the last %s goals." % [stand, joiner, who, MatchNotes.count_word(int(run["n"]))]
	# 3. A lead that has been eaten into, or a deficit cut, since half time.
	var half := int(leads[1])
	if absi(now) > CLOSE:
		return ""
	if now > 0 and half - now >= BIG:
		return "%s, down from %d at half time." % [stand, half]
	if now < 0 and half < 0 and now - half >= BIG:
		return "%s, back from %d down at half time." % [stand, -half]
	return ""


## The quarter (1-4) that turned a comeback win or a lost lead, or {}. Same bar
## as Headlines: a win after trailing by COMEBACK at a break; a loss after
## leading by LED at a break; and a later quarter won by TURN. Returns
## {"q", "side"} with the side that won the turning quarter.
static func turning_quarter(res: Dictionary, me: int) -> Dictionary:
	var s: Array = res.get("score", [0, 0])
	var margin := int(s[me]) - int(s[1 - me])
	if margin == 0:
		return {}
	var leads: Array = Headlines._break_leads(res, me)
	if leads.is_empty():
		return {}
	var qg: Array = res.get("q_goals", [])
	var qb: Array = res.get("q_behinds", [])
	if qg.size() != 4:
		return {}
	# The bar (as Headlines): the win followed a deficit of COMEBACK at a break, or the
	# loss a lead of LED.
	var extreme := 0
	for i in range(3):
		extreme = mini(extreme, int(leads[i])) if margin > 0 else maxi(extreme, int(leads[i]))
	if margin > 0 and -extreme < Headlines.COMEBACK:
		return {}
	if margin < 0 and extreme < Headlines.LED:
		return {}
	# The turn is the quarter after the last break at which the eventual loser was in
	# front (the winner behind): the quarter that took the lead for good.
	var last_wrong := -1
	for i in range(3):
		if (margin > 0 and int(leads[i]) < 0) or (margin < 0 and int(leads[i]) > 0):
			last_wrong = i
	if last_wrong < 0:
		return {}
	var qi := last_wrong + 1
	var net := (int(qg[qi][me]) * 6 + int(qb[qi][me])) - (int(qg[qi][1 - me]) * 6 + int(qb[qi][1 - me]))
	var turn_net := net if margin > 0 else -net
	var turn_q := qi + 1
	if turn_net < TURN:
		return {}
	return {"q": turn_q, "side": me if margin > 0 else 1 - me}


## "Turned in the third: Jones, 3.1 and 9 clearances." Or "Turned in the third."
## when nobody stood out; "" when there was no turn.
static func turn_line(res: Dictionary, me: int) -> String:
	var t := turning_quarter(res, me)
	if t.is_empty():
		return ""
	var q := int(t["q"])
	var head := "Turned in the %s" % ORDINALS[q - 1]
	var who := _turner(res, q, int(t["side"]))
	return head + (": " + who if who != "" else "") + "."


## The turning side's best player in quarter q, as "Name, 3.1 and 9 clearances".
static func _turner(res: Dictionary, q: int, side: int) -> String:
	var snaps: Array = res.get("quarter_teams", [])
	var roster: Array = res.get("roster", [[], []])
	if snaps.size() < q or roster.size() <= side:
		return ""
	var now: Dictionary = (snaps[q - 1] as Dictionary).get("players", {})
	var was: Dictionary = (snaps[q - 2] as Dictionary).get("players", {}) if q >= 2 else {}
	var best_id := ""
	var best_name := ""
	var best_inf := 0.0
	var best_d := {}
	for p in roster[side]:
		var id := str(p.get("id", ""))
		var a: Dictionary = now.get(id, {})
		var b: Dictionary = was.get(id, {})
		var d := {}
		for k in a:
			d[k] = float(a[k]) - float(b.get(k, 0.0))
		# Only a player with something to name: a goal, 6 clearances or 9 disposals.
		if int(d.get("goals", 0.0)) < 1 and int(d.get("clearances", 0.0)) < 6 				and int(d.get("disposals", 0.0)) < 9:
			continue
		var inf := CoachReport.influence(d)
		if inf > best_inf:
			best_inf = inf
			best_id = id
			best_name = str(p.get("name", ""))
			best_d = d
	if best_id == "":
		return ""
	var name := GameDB.player_display_name_by_id(best_id, best_name)
	var g := int(best_d.get("goals", 0.0))
	var bh := int(best_d.get("behinds", 0.0))
	var cl := int(best_d.get("clearances", 0.0))
	var disp := int(best_d.get("disposals", 0.0))
	var other := ""
	if cl >= 6:
		other = "%d clearances" % cl
	elif disp >= 9:
		other = "%d disposals" % disp
	if g > 0 and other == "":
		return "%s kicked %d.%d" % [name, g, bh]
	if g > 0:
		return "%s, %d.%d and %s" % [name, g, bh, other]
	if other != "":
		return "%s, %s" % [name, other]
	return ""
