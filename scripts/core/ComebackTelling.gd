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
## leading by LED at a break; and the quarter that took the lead for good won by TURN.
## Returns {"q", "side"} with the side that won the turning quarter (the side that
## turned it), plus "from"/"to": that side's deficit before and after the quarter
## before it when that quarter cut the gap by TURN too (0 and 0 otherwise).
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
	if turn_net < TURN:
		return {}
	var out := {"q": qi + 1, "side": me if margin > 0 else 1 - me, "from": 0, "to": 0}
	# Spread over two quarters: the quarter before also cut the winners' deficit by TURN.
	if last_wrong >= 1:
		var sign := 1 if margin > 0 else -1
		var d_before := -int(leads[last_wrong - 1]) * sign
		var d_after := -int(leads[last_wrong]) * sign
		if d_before > 0 and d_after > 0 and d_before - d_after >= TURN:
			out["from"] = d_before
			out["to"] = d_after
	return out


static func _quarter_word(q: int) -> String:
	return ["first", "second", "third", "last"][clampi(q - 1, 0, 3)]


## What the turn is told as, for the full-time lines: {"text", "quarters", "player"} or {}.
## "Brisbane turned it in the third: Andrew Brayshaw had 9 touches in the quarter." or, when
## two quarters did it, "Brisbane cut 37 to 9 in the third and ran over the top in the last:
## Logan Morris kicked three in the quarter." It names the club that turned it, so a loss
## does not read as if you did. The player is the go-ahead goal's kicker when he qualifies.
static func turn_facts(res: Dictionary, me: int) -> Dictionary:
	var t := turning_quarter(res, me)
	if t.is_empty():
		return {}
	var q := int(t["q"])
	var side := int(t["side"])
	var code := str(res.get("home" if side == 0 else "away", ""))
	var club := GameDB.club_name(code)
	var who := _turner(res, q, side)
	var quarters := [q]
	var head := "%s turned it in the %s" % [club, _quarter_word(q)]
	if int(t["from"]) > 0:
		quarters = [q - 1, q]
		head = "%s cut %d to %d in the %s and ran over the top in the %s" % [club, int(t["from"]),
				int(t["to"]), _quarter_word(q - 1), _quarter_word(q)]
	var text := head + (": " + str(who["text"]) if not who.is_empty() else "") + "."
	return {"text": text, "quarters": quarters, "player": str(who.get("id", ""))}


## The sentence alone, or "" (the hub's result card carries just this).
static func turn_line(res: Dictionary, me: int) -> String:
	return str(turn_facts(res, me).get("text", ""))


## The go-ahead score's kicker: the goal or behind after which the eventual winner stayed in
## front for good, as a player id ("" when there is none).
static func go_ahead_id(res: Dictionary) -> String:
	var score: Array = res.get("score", [0, 0])
	if int(score[0]) == int(score[1]):
		return ""
	var winner := 0 if int(score[0]) > int(score[1]) else 1
	var took := ""
	var was_ahead := false
	for ev in res.get("events", []):
		var kind := str(ev.get("kind", ""))
		if kind != "goal" and kind != "behind":
			continue
		var sc: Array = ev.get("score", [0, 0])
		var ahead := int(sc[winner]) > int(sc[1 - winner])
		if ahead and not was_ahead:
			took = str(ev.get("player_id", ""))
		was_ahead = ahead
	return took


## The turning side's player in quarter q: {"id", "text"} where text reads
## "Logan Morris kicked three in the quarter" or "Andrew Brayshaw had 9 touches in the
## quarter", or {} when nobody has a goal, 6 clearances or 9 disposals. The go-ahead
## goal's kicker is preferred when he qualifies; otherwise the best by influence.
static func _turner(res: Dictionary, q: int, side: int) -> Dictionary:
	var snaps: Array = res.get("quarter_teams", [])
	var roster: Array = res.get("roster", [[], []])
	if snaps.size() < q or roster.size() <= side:
		return {}
	var now: Dictionary = (snaps[q - 1] as Dictionary).get("players", {})
	var was: Dictionary = (snaps[q - 2] as Dictionary).get("players", {}) if q >= 2 else {}
	var key := go_ahead_id(res)
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
		if int(d.get("goals", 0.0)) < 1 and int(d.get("clearances", 0.0)) < 6 \
				and int(d.get("disposals", 0.0)) < 9:
			continue
		var inf := CoachReport.influence(d) + (1000.0 if id == key else 0.0)
		if inf > best_inf:
			best_inf = inf
			best_id = id
			best_name = str(p.get("name", ""))
			best_d = d
	if best_id == "":
		return {}
	var who := GameDB.player_display_name_by_id(best_id, best_name)
	var g := int(best_d.get("goals", 0.0))
	var cl := int(best_d.get("clearances", 0.0))
	var disp := int(best_d.get("disposals", 0.0))
	var bits := PackedStringArray()
	if g > 0:
		bits.append("kicked a goal" if g == 1 else "kicked %s" % _count(g))
	if cl >= 6:
		bits.append("had %d clearances" % cl)
	elif disp >= 9:
		bits.append("had %d touches" % disp)
	return {"id": best_id, "text": "%s %s in the quarter" % [who, " and ".join(bits)]}


## Words up to nine, then digits.
static func _count(n: int) -> String:
	return MatchNotes.count_word(n) if n >= 1 and n <= 9 else str(n)
