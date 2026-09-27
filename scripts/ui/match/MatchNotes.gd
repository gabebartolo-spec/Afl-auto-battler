class_name MatchNotes
extends RefCounted
## What the match screen says, in football words. Presentation only: every
## line is read from MatchSim's event log or its quarter snapshots, never
## decided here, and nothing here reads or writes the simulation.
##
## The feed keeps what a supporter would talk about - goals, behinds, the
## breaks, the coach's calls - and leaves routine possession to the oval.
## Quarter-break facts surface what happened, never what to do about it.

## Event kinds the feed shows. Everything else (marks, kicks, tackles,
## entries, rebounds, clangers, interchanges) plays on the oval only.
const FEED_KINDS := ["goal", "behind", "quarter", "final", "moment"]

## A quarter edge worth saying out loud.
const CLEARANCE_EDGE := 4
const INSIDE50_EDGE := 5
const STANDOUT_DISPOSALS := 9
const STANDOUT_GOALS := 2
const MAX_FACTS := 3

## Legs in words (MatchSim energy, 0-100).
const FRESH := 75.0
const TIRING := 55.0
const EMPTY := 50.0

const BREAK_NAMES := {1: "Quarter time", 2: "Half time", 3: "Three-quarter time", 4: "Full time"}
const COUNT_WORDS := ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]


## "Melbourne lead by 7", "Scores level". `name` turns a club code into the
## name to show (short on a narrow screen).
static func lead_text(home: String, away: String, score: Array, name: Callable) -> String:
	var h := int(score[0]) if score.size() > 0 else 0
	var a := int(score[1]) if score.size() > 1 else 0
	if h == a:
		return "Scores level"
	return "%s by %d" % [str(name.call(home if h > a else away)), absi(h - a)]


## A full score sentence for a break: "Melbourne 4.2 (26) lead Collingwood
## 3.1 (19) by 7." Never "defeated": that is for a final result only.
static func break_score(home: String, away: String, goals: Array, behinds: Array) -> String:
	var hs := int(goals[0]) * 6 + int(behinds[0])
	var aws := int(goals[1]) * 6 + int(behinds[1])
	var h_line := "%s %s" % [GameDB.club_name(home), UiKit.scoreline(int(goals[0]), int(behinds[0]))]
	var a_line := "%s %s" % [GameDB.club_name(away), UiKit.scoreline(int(goals[1]), int(behinds[1]))]
	if hs == aws:
		return "%s and %s: scores level." % [h_line, a_line]
	if hs > aws:
		return "%s lead %s by %d." % [h_line, a_line, hs - aws]
	return "%s lead %s by %d." % [a_line, h_line, aws - hs]


## The feed line for an event, or {} to leave it to the oval.
## {"text", "tier"}: tier "goal" (its own row), "break" (bold), "play".
static func feed_line(ev: Dictionary, home: String, away: String) -> Dictionary:
	var kind := str(ev.get("kind", ""))
	if not FEED_KINDS.has(kind):
		return {}
	var side := int(ev.get("side", -1))
	var club := home if side == 0 else away
	var who := str(ev.get("name", ""))
	var score: Array = ev.get("score", [0, 0])
	match kind:
		"goal":
			return {"text": "Goal  " + (who if who != "" else GameDB.club_short(club)), "tier": "goal"}
		"behind":
			var by := who if who != "" else "rushed"
			return {"text": "Behind: %s (%s)" % [by, GameDB.club_short(club)], "tier": "play"}
		"moment":
			return {"text": _call_words(str(ev.get("text", ""))), "tier": "play"}
		"final":
			var extra := str(ev.get("text", "")).contains("extra time")
			var res := _result_words(home, away, score)
			return {"text": ("Full time after extra time: " if extra else "Full time: ") + res, "tier": "break"}
		"quarter":
			return {"text": _break_words(ev, home, away), "tier": "break"}
	return {}


static func _result_words(home: String, away: String, score: Array) -> String:
	var h := int(score[0])
	var a := int(score[1])
	if h == a:
		return "a draw"
	return "%s win by %d" % [GameDB.club_name(home if h > a else away), absi(h - a)]


## A break in the feed: "Quarter time: Melbourne lead by 7". The log's own
## text names the break; the words come from the structured score.
static func _break_words(ev: Dictionary, home: String, away: String) -> String:
	var raw := str(ev.get("text", ""))
	var score: Array = ev.get("score", [0, 0])
	var lead := lead_text(home, away, score, func(c): return GameDB.club_name(str(c)))
	if raw.begins_with("End of quarter"):
		var q := int(ev.get("q", 1))
		return "%s: %s" % [str(BREAK_NAMES.get(q, "Break")), lead.to_lower() if lead == "Scores level" else lead]
	if raw.begins_with("Scores level"):
		return "Scores level at full time: extra time"
	if raw.begins_with("Extra time, half time"):
		return "Extra-time break: %s" % (lead.to_lower() if lead == "Scores level" else lead)
	if raw.begins_with("Still level"):
		return "Still level: next score wins"
	return raw


## "Coach's call: Throw numbers at it - Throw numbers at it for the next few
## minutes." says the call twice; keep the outcome when it already names it.
static func _call_words(text: String) -> String:
	var prefix := "Coach's call: "
	if not text.begins_with(prefix) or not text.contains(" - "):
		return text
	var body := text.substr(prefix.length())
	var cut := body.find(" - ")
	var choice := body.substr(0, cut)
	var outcome := body.substr(cut + 3)
	return prefix + (outcome if outcome.begins_with(choice) else body)


## A call from the quarter, for the break: "They have kicked 3 in a row:
## Throw numbers at it for the next few minutes."
static func moment_line(m: Dictionary) -> String:
	var choice := str(m.get("choice_label", ""))
	var outcome := str(m.get("outcome", ""))
	var said := outcome if outcome.begins_with(choice) else "%s. %s" % [choice, outcome]
	return "%s: %s" % [str(m.get("title", "")), said]


static func count_word(n: int) -> String:
	return COUNT_WORDS[n] if n > 0 and n < COUNT_WORDS.size() else str(n)


## "Carlton have kicked three in a row." for a run of `n` goals.
static func run_line(club: String, n: int) -> String:
	return "%s have kicked %s in a row." % [GameDB.club_name(club), count_word(n)]


# ---------------------------------------------------------------------------
# Quarter-break facts
# ---------------------------------------------------------------------------
## Up to MAX_FACTS things that stood out in quarter `q` (1-4), from the
## quarter snapshots MatchSim records. Problems and strengths, never advice.
static func quarter_facts(res: Dictionary, my_side: int, q: int) -> Array:
	var snaps: Array = res.get("quarter_teams", [])
	if q < 1 or snaps.size() < q:
		return []
	var opp := 1 - my_side
	var now: Dictionary = snaps[q - 1]
	var was: Dictionary = snaps[q - 2] if q >= 2 else {}
	var mine := _team_delta(now, was, my_side)
	var theirs := _team_delta(now, was, opp)
	var out := []

	var clr_m := int(mine.get("clearances", 0.0))
	var clr_t := int(theirs.get("clearances", 0.0))
	if clr_t - clr_m >= CLEARANCE_EDGE:
		out.append("Their midfield is on top at the stoppages: clearances %d to %d." % [clr_t, clr_m])
	elif clr_m - clr_t >= CLEARANCE_EDGE:
		out.append("Your midfield is winning the stoppages: clearances %d to %d." % [clr_m, clr_t])

	var i50_m := int(mine.get("inside50", 0.0))
	var i50_t := int(theirs.get("inside50", 0.0))
	if i50_t - i50_m >= INSIDE50_EDGE:
		out.append("They have had most of the ball going forward: %d inside 50s to %d." % [i50_t, i50_m])
	elif i50_m - i50_t >= INSIDE50_EDGE:
		out.append("You have had most of the ball going forward: %d inside 50s to %d." % [i50_m, i50_t])

	var standout := _standout(res, now, was, opp)
	if not standout.is_empty():
		out.append(standout)

	for s in [my_side, opp]:
		var g := int((_team_delta(now, was, s)).get("goals", 0.0))
		var b := int((_team_delta(now, was, s)).get("behinds", 0.0))
		if b >= g + 2 and g + b >= 5:
			out.append(("Your kicking has cost you: %d.%d for the quarter." if s == my_side
					else "They have been wayward: %d.%d for the quarter.") % [g, b])
	return out.slice(0, MAX_FACTS)


static func _team_delta(now: Dictionary, was: Dictionary, side: int) -> Dictionary:
	var t: Dictionary = (now.get("team", [{}, {}]) as Array)[side]
	var b: Dictionary = {} if was.is_empty() else (was.get("team", [{}, {}]) as Array)[side]
	var out := {}
	for k in t:
		out[k] = float(t[k]) - float(b.get(k, 0.0))
	return out


## Their player who hurt you most this quarter, if anyone clearly did.
static func _standout(res: Dictionary, now: Dictionary, was: Dictionary, side: int) -> String:
	var roster: Array = res.get("roster", [[], []])
	if roster.size() <= side:
		return ""
	var best := {}
	var best_inf := 0.0
	var players_now: Dictionary = now.get("players", {})
	var players_was: Dictionary = was.get("players", {}) if not was.is_empty() else {}
	for p in roster[side]:
		var id := str(p.get("id", ""))
		var a: Dictionary = players_now.get(id, {})
		var b: Dictionary = players_was.get(id, {})
		var d := {}
		for k in a:
			d[k] = float(a[k]) - float(b.get(k, 0.0))
		var disp := int(d.get("disposals", 0.0))
		var goals := int(d.get("goals", 0.0))
		if disp < STANDOUT_DISPOSALS and goals < STANDOUT_GOALS:
			continue
		var inf := CoachReport.influence(d)
		if inf > best_inf:
			best_inf = inf
			best = {"id": id, "name": str(p.get("name", "")), "disp": disp, "goals": goals}
	if best.is_empty():
		return ""
	var who := GameDB.player_display_name_by_id(str(best["id"]), str(best["name"]))
	var bits := PackedStringArray()
	if int(best["disp"]) > 0:
		bits.append("%d disposals" % int(best["disp"]))
	if int(best["goals"]) > 0:
		bits.append("%d goal%s" % [int(best["goals"]), "" if int(best["goals"]) == 1 else "s"])
	return "%s is hurting you: %s this quarter." % [who, " and ".join(bits)]


## How your tag went in quarter q: "Your tag on Walsh: 4 disposals, no goals."
static func tag_line(res: Dictionary, my_side: int, q: int) -> String:
	var hist: Array = res.get("tactics_history", [])
	var tag_id := ""
	for h in hist:
		if int(h.get("quarter", 0)) != q:
			continue
		tag_id = str(((h["plans"] as Array)[my_side] as Dictionary).get("tag_id", ""))
	if tag_id == "":
		return ""
	var snaps: Array = res.get("quarter_teams", [])
	if snaps.size() < q:
		return ""
	var now: Dictionary = ((snaps[q - 1] as Dictionary)["players"] as Dictionary).get(tag_id, {})
	var was: Dictionary = {}
	if q >= 2:
		was = ((snaps[q - 2] as Dictionary)["players"] as Dictionary).get(tag_id, {})
	var d := int(float(now.get("disposals", 0.0)) - float(was.get("disposals", 0.0)))
	var g := int(float(now.get("goals", 0.0)) - float(was.get("goals", 0.0)))
	var goals := "no goals" if g == 0 else ("1 goal" if g == 1 else "%d goals" % g)
	return "Your tag on %s: %d disposal%s, %s." % [
			GameDB.player_display_name_by_id(tag_id, "their player"), d, "" if d == 1 else "s", goals]


# ---------------------------------------------------------------------------
# Legs
# ---------------------------------------------------------------------------
static func legs_word(energy: float) -> String:
	if energy >= FRESH:
		return "fresh"
	if energy >= TIRING:
		return "tiring"
	return "running on empty"


## "Your midfield is fresh; theirs is tiring." from two group energies.
static func legs_line(mine: float, theirs: float) -> String:
	return "Your midfield is %s; theirs is %s." % [legs_word(mine), legs_word(theirs)]


## Names of your on-ground players below EMPTY energy, most tired first.
static func cooked(rows: Array, limit := 3) -> Array:
	var out := []
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a, b): return float(a["energy"]) < float(b["energy"]))
	for r in sorted:
		if bool(r["on"]) and float(r["energy"]) < EMPTY and out.size() < limit:
			out.append(str(r["name"]))
	return out


# ---------------------------------------------------------------------------
# Full time
# ---------------------------------------------------------------------------
const QUARTER_NAMES := ["first", "second", "third", "last", "extra time"]
const MAX_FACTORS := 3

## Why the result happened, from `my_side`'s point of view, in two to four
## sentences. Facts from the result, most telling first; never advice.
static func match_factors(res: Dictionary, my_side: int) -> Array:
	var out := []
	var opp := 1 - my_side
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	var score: Array = res.get("score", [0, 0])
	var won := int(score[my_side]) > int(score[opp])
	var lost := int(score[my_side]) < int(score[opp])
	var team: Array = res.get("team", [{}, {}])
	var t_me: Dictionary = team[my_side] if team.size() > my_side else {}
	var t_op: Dictionary = team[opp] if team.size() > opp else {}

	# 1. The run that decided it: four or more goals in a row.
	var run := _longest_run(res.get("events", []))
	if int(run["len"]) >= 4:
		var who := GameDB.club_name(codes[int(run["side"])])
		var when := " in the %s quarter" % QUARTER_NAMES[mini(int(run["q"]) - 1, 4)] if bool(run["one_q"]) else ""
		out.append("%s kicked %s unanswered goals%s." % [who, count_word(int(run["len"])), when])

	# 2. A quarter that swung it: won by four goals or more.
	var qg: Array = res.get("q_goals", [])
	var qb: Array = res.get("q_behinds", [])
	var best_q := -1
	var best_m := 0
	for i in range(mini(qg.size(), 4)):
		var m := (int(qg[i][0]) * 6 + int(qb[i][0])) - (int(qg[i][1]) * 6 + int(qb[i][1]))
		if absi(m) > absi(best_m):
			best_m = m
			best_q = i
	if best_q >= 0 and absi(best_m) >= 24 and (out.is_empty() or int(run["q"]) != best_q + 1):
		var s := 0 if best_m > 0 else 1
		out.append("%s won the %s quarter %d.%d to %d.%d." % [GameDB.club_name(codes[s]),
				QUARTER_NAMES[best_q], int(qg[best_q][s]), int(qb[best_q][s]),
				int(qg[best_q][1 - s]), int(qb[best_q][1 - s])])

	# 3. The stoppages.
	var clr_m := int(float(t_me.get("clearances", 0.0)))
	var clr_t := int(float(t_op.get("clearances", 0.0)))
	if clr_t - clr_m >= 6:
		out.append("You were beaten at the stoppages: clearances %d to %d." % [clr_m, clr_t])
	elif clr_m - clr_t >= 6:
		out.append("Your midfield won the stoppages: clearances %d to %d." % [clr_m, clr_t])

	# 4. Territory, read against the result.
	var i50_m := int(float(t_me.get("inside50", 0.0)))
	var i50_t := int(float(t_op.get("inside50", 0.0)))
	if i50_t - i50_m >= 8:
		if won:
			out.append("Your defence held firm despite losing the inside 50s %d to %d." % [i50_m, i50_t])
		else:
			out.append("They had the ball in their forward half far more: %d inside 50s to %d." % [i50_t, i50_m])
	elif i50_m - i50_t >= 8:
		if lost:
			out.append("You won the inside 50s %d to %d but could not make it count." % [i50_m, i50_t])
		else:
			out.append("You had the ball going forward far more: %d inside 50s to %d." % [i50_m, i50_t])

	# 5. Kicking for goal.
	var g_m := int(res.get("goals", [0, 0])[my_side])
	var b_m := int(res.get("behinds", [0, 0])[my_side])
	var g_t := int(res.get("goals", [0, 0])[opp])
	var b_t := int(res.get("behinds", [0, 0])[opp])
	if b_m >= g_m + 3 and g_m + b_m >= 12:
		out.append("Wayward kicking cost you: %d.%d." % [g_m, b_m])
	elif b_t >= g_t + 3 and g_t + b_t >= 12:
		out.append("They let you off the hook in front of goal: %d.%d." % [g_t, b_t])
	elif g_m >= b_m + 8:
		out.append("You kicked straight: %d.%d." % [g_m, b_m])

	# 6. Pressure.
	var tk_m := int(float(t_me.get("tackles", 0.0)))
	var tk_t := int(float(t_op.get("tackles", 0.0)))
	if tk_m - tk_t >= 15:
		out.append("Your pressure told: %d tackles to %d." % [tk_m, tk_t])
	elif tk_t - tk_m >= 15:
		out.append("Their pressure told: %d tackles to %d." % [tk_t, tk_m])

	if out.is_empty():
		out.append("Nothing much between the sides all day." if absi(int(score[0]) - int(score[1])) <= 12
				else "No single edge: the winners were just better across the ground.")
	return out.slice(0, MAX_FACTORS)


## The longest run of goals by one side: {"side", "len", "q", "one_q"}.
static func _longest_run(events: Array) -> Dictionary:
	var best := {"side": 0, "len": 0, "q": 1, "one_q": true}
	var side := -1
	var n := 0
	var q0 := 1
	var one_q := true
	for ev in events:
		if str(ev.get("kind", "")) != "goal":
			continue
		var s := int(ev.get("side", 0))
		var q := int(ev.get("q", 1))
		if s == side:
			n += 1
			one_q = one_q and q == q0
		else:
			side = s
			n = 1
			q0 = q
			one_q = true
		if n > int(best["len"]):
			best = {"side": side, "len": n, "q": q0, "one_q": one_q}
	return best


## A player's game in a few natural words: "31 disposals, 8 clearances".
## Only what stands out, most telling first; never a stat-sheet row.
static func game_line(st: Dictionary) -> String:
	var bits := PackedStringArray()
	var g := int(float(st.get("goals", 0.0)))
	var d := int(float(st.get("disposals", 0.0)))
	if g > 0:
		bits.append("%d goal%s" % [g, "" if g == 1 else "s"])
	if d >= 15 or bits.is_empty():
		bits.append("%d disposal%s" % [d, "" if d == 1 else "s"])
	for row in [["clearances", 5, "clearances"], ["hitouts", 20, "hit-outs"], ["marks", 8, "marks"],
			["tackles", 7, "tackles"], ["rebounds", 6, "rebound 50s"], ["one_percenters", 7, "one percenters"]]:
		var v := int(float(st.get(row[0], 0.0)))
		if v >= int(row[1]) and bits.size() < 3:
			bits.append("%d %s" % [v, row[2]])
	return ", ".join(bits)


## The best few players of a side by influence: [{"id", "name", "line"}].
static func standouts(res: Dictionary, side: int, n: int) -> Array:
	var ranked := rated_players(res, side)
	var out := []
	for r in ranked.slice(0, n):
		out.append({"id": r["id"], "name": r["name"], "line": game_line(r["stats"]),
				"rating": r["rating"], "inf": r["rating"]})
	return out


# ---------------------------------------------------------------------------
# Player rating: one number for one match
# ---------------------------------------------------------------------------
## What each tracked stat is worth toward a player's rating. Read from THIS
## match's box score only (never OVR). Possession counts, but less than what
## it does: a handball is worth little, a goal a lot. Tuned over simulated
## matches so defenders, midfielders, forwards and rucks reach the same top
## ratings their own ways (see docs/DESIGN.md, Player rating).
const RATING_WEIGHTS := {
	"goals": 5.0, "behinds": 0.6, "goal_assists": 0.6,
	"kicks": 0.30, "handballs": 0.15, "marks": 0.7,
	"tackles": 0.8, "clearances": 0.9, "inside50": 0.4,
	"rebounds": 0.9, "one_percenters": 0.9, "hitouts": 0.5,
	"clangers": -0.6, "frees_against": -0.8,
}
## Contribution to rating: an average game is about 5, a very good one 7.5,
## a best-on-ground 8.5 and up. Above 8 each point comes at half the rate,
## so 10 stays out of reach but for the game of the season.
const RATING_BASE := 1.5
const RATING_SLOPE := 0.2
const RATING_KNEE := 8.0


static func rating(st: Dictionary) -> float:
	var raw := 0.0
	for k in RATING_WEIGHTS:
		raw += float(RATING_WEIGHTS[k]) * float(st.get(k, 0.0))
	var r := RATING_BASE + raw * RATING_SLOPE
	if r > RATING_KNEE:
		r = RATING_KNEE + (r - RATING_KNEE) * 0.5
	return snappedf(clampf(r, 0.0, 10.0), 0.1)


## "7.4": one decimal, always.
static func rating_text(r: float) -> String:
	return "%.1f" % r


## Every player of a side who took the field, best rated first:
## [{id, num, name, stats, rating}].
static func rated_players(res: Dictionary, side: int) -> Array:
	var roster: Array = res.get("roster", [[], []])
	var players: Dictionary = res.get("players", {})
	if roster.size() <= side:
		return []
	var out := []
	for p in roster[side]:
		var st: Dictionary = players.get(str(p["id"]), {})
		out.append({"id": str(p["id"]), "num": int(p.get("num", 0)),
				"name": GameDB.player_display_name_by_id(str(p["id"]), str(p.get("name", "Player"))),
				"role": str(p.get("list_role", p.get("role", ""))),
				"stats": st, "rating": rating(st)})
	out.sort_custom(func(a, b):
		if float(a["rating"]) != float(b["rating"]):
			return float(a["rating"]) > float(b["rating"])
		return int(float(a["stats"].get("disposals", 0.0))) > int(float(b["stats"].get("disposals", 0.0))))
	return out


## The few team numbers worth a glance at full time: [label, mine, theirs].
const KEY_STATS := [["disposals", "Disposals"], ["inside50", "Inside 50s"],
		["clearances", "Clearances"]]

static func key_stats(res: Dictionary, my_side: int) -> Array:
	var team: Array = res.get("team", [{}, {}])
	var out := []
	for row in KEY_STATS:
		out.append([str(row[1]), int(float((team[my_side] as Dictionary).get(row[0], 0.0))),
				int(float((team[1 - my_side] as Dictionary).get(row[0], 0.0)))])
	return out
