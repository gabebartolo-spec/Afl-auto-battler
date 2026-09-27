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
