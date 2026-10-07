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
## Pressure-rating gap worth a full-time line (about one match in five).
const PRESSURE_GAP := 8

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


## The calls made in the moment that still matter at the break: resting a
## tired player (or keeping him out there) and tagging a hot one. A set shot,
## a centre bounce or a run of goals has played out in the feed already.
## (A match-up change has its own line, from duel_change_lines.)
const LASTING_MOMENTS := ["tired", "hot"]


static func lasting_moment_lines(res: Dictionary, q: int) -> Array:
	var out := []
	for m in res.get("moments", []):
		if int(m.get("q", 0)) == q and LASTING_MOMENTS.has(str(m.get("kind", ""))):
			var t := tired_follow_through(res, m) if str(m.get("kind", "")) == "tired" else ""
			out.append(t if t != "" else moment_line(m))
	return out


## What followed a tired-star call, to the break: who played and what he
## did. Facts only - never whether it was the right call.
static func tired_follow_through(res: Dictionary, m: Dictionary) -> String:
	var q := int(m.get("q", 0))
	var snaps: Array = res.get("quarter_teams", [])
	var at: Dictionary = m.get("disp_at", {})
	if q < 1 or snaps.size() < q or at.is_empty():
		return ""
	var players: Dictionary = (snaps[q - 1] as Dictionary).get("players", {})
	var since := func(id: String) -> int:
		return int(float((players.get(id, {}) as Dictionary).get("disposals", 0.0)) - float(at.get(id, 0.0)))
	var star := str(m.get("player_id", ""))
	var on := str(m.get("on_id", ""))
	if on != "":
		var n: int = since.call(on)
		return "%s rested: %s came on and had %d disposal%s to the break." % [
			_pname(star), _pname(on), n, "" if n == 1 else "s"]
	if str(m.get("outcome", "")).begins_with("He stays"):
		var k: int = since.call(star)
		return "%s stayed out there: %d disposal%s to the break, on empty legs." % [
			_pname(star), k, "" if k == 1 else "s"]
	return ""


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
## answers: what you can do about their players right now, by player id -
## {"kind": "matchup", "who": your defender on him}, {"kind": "tagged", "who":
## your tagger} or {"kind": "tag"} - so a player hurting you is named with the
## lever that reaches him, and one no call reaches is stated as a fact.
static func quarter_facts(res: Dictionary, my_side: int, q: int, answers := {}) -> Array:
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

	var spare := _roamer_quarter_fact(res, now, was, opp)
	if spare != "":
		out.append(spare)

	var standout := _standout(res, now, was, opp, answers)
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


## A loose defender controlling the air is a genuine quarter fact, but only
## once he has actually won multiple roaming contests in that period.
static func _roamer_quarter_fact(res: Dictionary, now: Dictionary, was: Dictionary, side: int) -> String:
	var roster: Array = res.get("roster", [[], []])
	if roster.size() <= side:
		return ""
	var players_now: Dictionary = now.get("players", {})
	var players_was: Dictionary = was.get("players", {}) if not was.is_empty() else {}
	var best := {}
	var wins := 0
	for p in roster[side]:
		var id := str(p.get("id", ""))
		var a: Dictionary = players_now.get(id, {})
		var b: Dictionary = players_was.get(id, {})
		var w := int(a.get("roam_wins", 0)) - int(b.get("roam_wins", 0))
		if w > wins:
			wins = w
			best = p
	if best.is_empty() or wins < 2:
		return ""
	return "%s is controlling the air as their loose defender." % GameDB.player_display_name_by_id(
			str(best.get("id", "")), str(best.get("name", "Player")))


## Their player who hurt you most this quarter, if anyone clearly did. Said
## as "hurting you" only when a call reaches him (the defender on him, your
## tag, or a tag you could put on); otherwise just what he did.
static func _standout(res: Dictionary, now: Dictionary, was: Dictionary, side: int, answers := {}) -> String:
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
	var did := " and ".join(bits)
	var answer: Dictionary = answers.get(str(best["id"]), {})
	match str(answer.get("kind", "")):
		"matchup":
			return "%s is hurting you: %s this quarter. %s is on him." % [who, did, str(answer.get("who", ""))]
		"tagged":
			return "%s is hurting you: %s this quarter, with %s tagging him." % [who, did, str(answer.get("who", ""))]
		"tag":
			return "%s is hurting you: %s this quarter. He can be tagged." % [who, did]
	return "%s was their best this quarter: %s." % [who, did]


## What your calls did in quarter q, one line each, against the quarter
## before where there is one: the stat each call is about, in its own words,
## so a problem at the break and the call you answered it with read the same.
## Facts only - never whether it was the right call.
static func calls_lines(res: Dictionary, my_side: int, q: int) -> Array:
	var hist: Array = res.get("tactics_history", [])
	var snaps: Array = res.get("quarter_teams", [])
	if q < 1 or snaps.size() < q:
		return []
	var calls: Dictionary = {}
	for h in hist:
		if int(h.get("quarter", 0)) == q:
			calls = ((h["plans"] as Array)[my_side] as Dictionary)
	if calls.is_empty():
		return []
	var opp := 1 - my_side
	var now: Dictionary = snaps[q - 1]
	var was: Dictionary = snaps[q - 2] if q >= 2 else {}
	var before: Dictionary = snaps[q - 3] if q >= 3 else {}
	var mine := _team_delta(now, was, my_side)
	var theirs := _team_delta(now, was, opp)
	var p_mine := _team_delta(was, before, my_side) if q >= 2 else {}
	var p_theirs := _team_delta(was, before, opp) if q >= 2 else {}
	var prev := (" in the %s" % QUARTER_NAMES[q - 2]) if q >= 2 else ""
	var n := func(d: Dictionary, k: String) -> int: return int(d.get(k, 0.0))
	var out := []
	var plan := MatchSim.plan_key(str(calls.get("gameplan", "balanced")))
	var label := CoachReport.plan_label(plan)
	match plan:
		"attacking":
			out.append(("%s: %d inside 50s and %s" % [label, n.call(mine, "inside50"), _goals_word(n.call(mine, "goals"))])
					+ ((", from %d and %d%s." % [n.call(p_mine, "inside50"), n.call(p_mine, "goals"), prev]) if q >= 2 else "."))
		"defensive":
			out.append(("%s: they had %d inside 50s and kicked %s" % [label, n.call(theirs, "inside50"), _goals_word(n.call(theirs, "goals"))])
					+ ((", from %d and %d%s." % [n.call(p_theirs, "inside50"), n.call(p_theirs, "goals"), prev]) if q >= 2 else "."))
		"contest":
			out.append(("%s: clearances %d to %d" % [label, n.call(mine, "clearances"), n.call(theirs, "clearances")])
					+ ((", from %d to %d%s." % [n.call(p_mine, "clearances"), n.call(p_theirs, "clearances"), prev]) if q >= 2 else "."))
		"controlled":
			out.append(("%s: %d clangers" % [label, n.call(mine, "clangers")])
					+ ((", from %d%s." % [n.call(p_mine, "clangers"), prev]) if q >= 2 else "."))
		"through_stars":
			var stars := _stars_disposals(res, now, was, my_side)
			if stars >= 0:
				out.append(("%s: your stars had %d disposals" % [label, stars])
						+ ((", from %d%s." % [_stars_disposals(res, was, before, my_side), prev]) if q >= 2 else "."))
	for key in [["tag_id", "Tag on %s: %d disposal%s", opp], ["focus_id", "Through %s: %d disposal%s", my_side]]:
		var id := str(calls.get(key[0], ""))
		if id == "":
			continue
		var d_now := _player_delta(now, was, id, "disposals")
		var line := str(key[1]) % [GameDB.player_display_name_by_id(id, "him"), d_now, "" if d_now == 1 else "s"]
		if q >= 2:
			line += ", from %d%s" % [_player_delta(was, before, id, "disposals"), prev]
		out.append(line + ".")
	return out


static func _goals_word(g: int) -> String:
	return "no goals" if g == 0 else ("1 goal" if g == 1 else "%d goals" % g)


static func _player_delta(now: Dictionary, was: Dictionary, id: String, key: String) -> int:
	var a: Dictionary = (now.get("players", {}) as Dictionary).get(id, {})
	var b: Dictionary = {} if was.is_empty() else (was.get("players", {}) as Dictionary).get(id, {})
	return int(float(a.get(key, 0.0)) - float(b.get(key, 0.0)))


## Disposals by your stars (the three Through stars goes through) between
## two snapshots (-1: none).
static func _stars_disposals(res: Dictionary, now: Dictionary, was: Dictionary, side: int) -> int:
	var stars: Array = res.get("stars", [[], []])
	if stars.size() <= side or (stars[side] as Array).is_empty() or now.is_empty():
		return -1
	var total := 0
	for id in stars[side]:
		total += _player_delta(now, was, str(id), "disposals")
	return total


## A player picked to play through, by the slot he fills: "Matthew Jefferson
## our key forward target". The engine favours him as the carrier in chains,
## and carriers are picked by zone, so what it does is where he plays.
const FOCUS_ROLES := {
	"MID": ["our key midfielder", "more of the ball in the midfield chains"],
	"FWD": ["our key forward target", "more of the ball up forward; he is not made the shooter"],
	"DEF": ["our key distributor out of defence", "more of the ball coming out of defence"],
	"RUCK": ["our key man around the ball", "more of the ball around the stoppages"],
}


static func focus_role_text(name: String, role: String) -> String:
	if not FOCUS_ROLES.has(role):
		return name
	return "%s %s" % [name, str(FOCUS_ROLES[role][0])]


static func focus_effect_text(role: String) -> String:
	if not FOCUS_ROLES.has(role):
		return "more of the ball in the chains"
	return str(FOCUS_ROLES[role][1])


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

	# The turning points first: the score that put the winners in front for
	# good, a star lost to injury, a late miss in a close loss.
	out.append_array(turning_points(res, my_side))

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

	# 6. Pressure: the pressure rating, which allows for how much of the
	# ball each side had to pressure.
	var pr_m := MatchSim.pressure_rating(t_me, t_op)
	var pr_t := MatchSim.pressure_rating(t_op, t_me)
	if pr_m - pr_t >= PRESSURE_GAP:
		out.append("Your pressure told: a pressure rating of %d to %d." % [pr_m, pr_t])
	elif pr_t - pr_m >= PRESSURE_GAP:
		out.append("Their pressure told: a pressure rating of %d to %d." % [pr_t, pr_m])

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
			["tackles", 7, "tackles"], ["pressure_acts", 18, "pressure acts"],
			["spoils", 5, "spoils"], ["intercepts", 6, "intercepts"],
			["rebounds", 6, "rebound 50s"], ["one_percenters", 7, "one percenters"]]:
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
## Points per recorded stat, on a fantasy-style scale: an ordinary game is
## 50-80, a strong one 80-105, best on ground 110 and up, a freak game 150+.
## Read from THIS match's box score only - never OVR, value or potential.
##
## Tuned over 400 simulated matches so every position has a path to best on
## ground. The engine gives forwards few touches (about 9 a game), so
## possession counts for less than in AFL Fantasy and scoreboard impact for
## more: a goal is 14. A hit-out is 1, as in AFL Fantasy: in the engine the
## tap itself decides little (under half a point of margin each, measured
## over 1,000 matches), and a ruck with no opposite number can take 60 of
## them - worth recording, not a best-on-ground game on its own.
## An inside 50 is creation (4, what an entry earned before goal assists
## were counted properly); a goal assist - the last kick to a goalkicker - is
## 2 more. A free kick drawn is +1, one given away -1 (plus the clanger).
## A clearance is always followed by the disposal it produces, so it earns
## nothing extra. Every free against is also a clanger: -3 in all.
## Every tackle is also a pressure act, so a tackle is 2 + 1 = 3 in all and
## pressure without a tackle (a rushed disposal, a forced turnover) is 1.
const RATING_POINTS := {
	"kicks": 2, "handballs": 1, "marks": 3, "tackles": 2, "pressure_acts": 1,
	"goals": 14, "behinds": 1, "hitouts": 1,
	"inside50": 4, "goal_assists": 2, "rebounds": 3, "one_percenters": 1,
	"clangers": -2, "frees_for": 1, "frees_against": -1,
}


## A whole number, never below 0.
static func rating(st: Dictionary) -> int:
	var total := 0.0
	for k in RATING_POINTS:
		total += float(RATING_POINTS[k]) * float(st.get(k, 0.0))
	return maxi(0, int(round(total)))


static func rating_text(r) -> String:
	return str(int(r))


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
		["clearances", "Clearances"], ["pressure_rating", "Pressure rating"]]

static func key_stats(res: Dictionary, my_side: int) -> Array:
	var team: Array = res.get("team", [{}, {}])
	var mine: Dictionary = team[my_side]
	var theirs: Dictionary = team[1 - my_side]
	var out := []
	for row in KEY_STATS:
		if str(row[0]) == "pressure_rating":
			out.append([str(row[1]), MatchSim.pressure_rating(mine, theirs),
					MatchSim.pressure_rating(theirs, mine)])
		else:
			out.append([str(row[1]), int(float(mine.get(row[0], 0.0))),
					int(float(theirs.get(row[0], 0.0)))])
	return out


# ---------------------------------------------------------------------------
# Key match-ups (Matchups): the named forward-50 contests, in counts a coach
# would quote. Every line is built from the contests the engine logged.
# ---------------------------------------------------------------------------
## Contests `fid` had: [contests, marked, goals], in quarter q (0 = the whole
## match) and against defender def_id ("" = anyone).
static func duel_tally(res: Dictionary, fid: String, q := 0, def_id := "") -> Array:
	var n := 0
	var won := 0
	var goals := 0
	for c in ((res.get("duels", {}) as Dictionary).get(fid, {}) as Dictionary).get("contests", []):
		if (q > 0 and int(c[0]) != q) or (def_id != "" and str(c[1]) != def_id):
			continue
		n += 1
		if bool(c[2]):
			won += 1
		if bool(c[3]):
			goals += 1
	return [n, won, goals]


static func _pname(id: String) -> String:
	return GameDB.player_display_name_by_id(id, "")


const QUARTER_WORDS := {1: "the first", 2: "the second", 3: "the third", 4: "the last"}


## "Maynard is on Curnow. Curnow marked 4 of 6 in the first." At a break,
## for the quarter just played.
static func duel_quarter_line(res: Dictionary, fid: String, def_id: String, q: int) -> String:
	var t := duel_tally(res, fid, q)
	var f := _pname(fid)
	var who := matchup_line(f, _pname(def_id))
	var when := str(QUARTER_WORDS.get(q, "that quarter"))
	if int(t[0]) == 0:
		return "%s No contests in %s." % [who, when]
	return "%s %s marked %d of %d in %s." % [who, f, int(t[1]), int(t[0]), when]


## Who is on whom, both named: "Maynard is on Curnow." A defender who cannot
## be named is left out rather than leaving a gap in the line.
static func matchup_line(fwd_name: String, def_name: String) -> String:
	if def_name == "":
		return "Nobody is on %s." % fwd_name
	return "%s is on %s." % [def_name, fwd_name]


## What a match-up change at the break did in quarter q: "Moore onto Curnow:
## Curnow marked 1 of 4, from 4 of 6 in the first." [] when you made none.
static func duel_change_lines(res: Dictionary, my_side: int, q: int) -> Array:
	var out := []
	for ch in res.get("duel_changes", []):
		if int(ch.get("from", ch.get("q", 0))) != q or int(ch.get("side", -1)) != my_side:
			continue
		var fid := str(ch["fwd"])
		var now := duel_tally(res, fid, q)
		var was := duel_tally(res, fid, q - 1) if q > 1 else [0, 0, 0]
		var line := "%s onto %s: " % [_pname(str(ch["def"])), _pname(fid)]
		if int(now[0]) == 0:
			line += "no contests yet."
		else:
			line += "%s marked %d of %d" % [_pname(fid), int(now[1]), int(now[0])]
			if int(was[0]) > 0:
				line += ", from %d of %d in %s" % [int(was[1]), int(was[0]), str(QUARTER_WORDS.get(q - 1, "the quarter before"))]
			line += "."
		out.append(line)
	return out


## The key match-ups at full time, one honest line each, theirs first:
## who had the better of whom, and - where you moved a defender - whether
## the contests changed. Quiet match-ups (fewer than MIN_DUELS) stay quiet.
const MIN_DUELS := 4
const CLEAR_EDGE := 0.25

## A roaming defender earns a full-time line only from real contests. No
## structural role is praised merely because it was selected.
static func interceptor_story(res: Dictionary, my_side: int) -> Array:
	var roster: Array = res.get("roster", [[], []])
	var players: Dictionary = res.get("players", {})
	var out := []
	for side in range(mini(2, roster.size())):
		var best := {}
		var best_wins := 0
		for p in roster[side]:
			var st: Dictionary = players.get(str(p.get("id", "")), {})
			var contests := int(st.get("roam_contests", 0))
			var wins := int(st.get("roam_wins", 0))
			if contests >= 3 and wins > best_wins:
				best = p
				best_wins = wins
		if best.is_empty():
			continue
		var st: Dictionary = players.get(str(best.get("id", "")), {})
		var contests := int(st.get("roam_contests", 0))
		var wins := int(st.get("roam_wins", 0))
		var losses := int(st.get("roam_losses", 0))
		var who := GameDB.player_display_name_by_id(str(best.get("id", "")), str(best.get("name", "Player")))
		var ours := side == my_side
		if wins >= 3 and wins > losses:
			out.append(("%s controlled the air as your spare: %d wins from %d roaming contests." if ours
					else "%s controlled the air as their spare: %d wins from %d roaming contests.") % [
					who, wins, contests])
		elif losses >= 3 and losses > wins:
			out.append(("%s was exposed when roaming: %d lost contests." if ours
					else "%s's roaming left space behind him: %d lost contests.") % [who, losses])
	return out


static func duel_story(res: Dictionary, my_side: int) -> Array:
	# Your changes first (the calls you made), then their key forwards by
	# how many contests they had, then at most one of your own forwards.
	var moved := {}
	for ch in res.get("duel_changes", []):
		if int(ch.get("side", -1)) == my_side:
			moved[str(ch["fwd"])] = true
	var theirs := []
	var ours := []
	var duels: Dictionary = res.get("duels", {})
	for fid in duels:
		var d: Dictionary = duels[fid]
		var all := duel_tally(res, str(fid))
		if int(all[0]) < MIN_DUELS:
			continue
		var line := _duel_line(res, str(fid), int(d.get("side", 0)) != my_side, my_side)
		if line == "":
			continue
		var row := [0 if moved.has(str(fid)) else 1, -int(all[0]), line]
		if int(d.get("side", 0)) != my_side:
			theirs.append(row)
		else:
			ours.append(row)
	theirs.sort()
	ours.sort()
	var out := []
	for r in theirs:
		out.append(r[2])
	if not ours.is_empty():
		out.append(ours[0][2])
	return out


static func _duel_line(res: Dictionary, fid: String, theirs: bool, my_side: int) -> String:
	var fname := _pname(fid)
	# The defenders he met, in the order he met them.
	var order := []
	for c in ((res.get("duels", {}) as Dictionary).get(fid, {}) as Dictionary).get("contests", []):
		if not order.has(str(c[1])):
			order.append(str(c[1]))
	var goals := int(duel_tally(res, fid)[2])
	var kicked := "" if goals == 0 else (", and kicked %d %s from them" % [goals, "goal" if goals == 1 else "goals"])
	if order.size() >= 2:
		# Told in order - who had the better of it first, and after the
		# change - so it never reads as if what was said live was wrong.
		var first := str(order[0])
		var last := str(order[order.size() - 1])
		var a := duel_tally(res, fid, 0, first)
		var b := duel_tally(res, fid, 0, last)
		# "The move" only when a side made one; otherwise the other man just
		# took him (a rotation, an injury).
		var after := "after the move" if _moved_onto(res, fid, last) else "once he took over"
		if int(a[0]) < 3 or int(b[0]) < 3:
			return "%s won %d of %d contests; too few after %s took him to tell." % [
					fname, int(a[1]) + int(b[1]), int(a[0]) + int(b[0]), _pname(last)]
		var ra := float(a[1]) / float(a[0])
		var rb := float(b[1]) / float(b[0])
		var early := "%s had the better of %s early (%d of %d)" % [fname, _pname(first), int(a[1]), int(a[0])] \
				if ra >= 0.5 else "%s held %s early (%d of %d)" % [_pname(first), fname, int(a[1]), int(a[0])]
		if rb <= ra - CLEAR_EDGE and rb <= 0.40:
			return "%s; %s held him %s (%d of %d)." % [early, _pname(last), after, int(b[1]), int(b[0])]
		if rb >= ra + CLEAR_EDGE:
			return "%s; he got on top of %s %s too (%d of %d)." % [early, _pname(last), after, int(b[1]), int(b[0])]
		return "%s; much the same on %s %s (%d of %d)." % [early, _pname(last), after, int(b[1]), int(b[0])]
	var t := duel_tally(res, fid)
	var dname := _pname(str(order[0])) if not order.is_empty() else "his man"
	# A quarter where he was on top of this man (what the live call said):
	# the full-time line keeps that part of the story.
	var hot_q := _on_top_quarter(res, fid, str(order[0]) if not order.is_empty() else "")
	var verdict := duel_verdict(int(t[1]), int(t[0]))
	if verdict > 0:
		return "%s beat %s in the air: %d marks from %d contests%s." % [fname, dname, int(t[1]), int(t[0]), kicked]
	if verdict < 0:
		if hot_q > 0:
			return "%s got on top of %s in %s, but %s held him over the match: %d marks from %d contests%s." % [
					fname, dname, str(QUARTER_WORDS.get(hot_q, "one quarter")), dname, int(t[1]), int(t[0]), kicked]
		return "%s held %s: %d marks from %d contests." % [dname, fname, int(t[1]), int(t[0])]
	return "An even battle, %s and %s: %d marks from %d contests%s." % [fname, dname, int(t[1]), int(t[0]), kicked]


## Who won a key match-up over a whole match, from the forward's marks in
## `n` contests: 1 he beat his man, -1 his man held him, 0 an even battle.
## A side needs two-thirds of the contests and two more than the other to
## win it. Four or five contests is a small sample: on a straight 60/40 cut,
## two evenly matched men produced a winner nearly three times in four, and
## a slight aerial edge read as a forward who "beat" his man most weeks.
static func duel_verdict(won: int, n: int) -> int:
	var lost := n - won
	if won - lost >= 2 and won * 3 >= n * 2:
		return 1
	if lost - won >= 2 and won * 3 <= n:
		return -1
	return 0


## Whether a side actually moved `def_id` onto `fid` (a recorded change,
## not a rotation or an injury).
static func _moved_onto(res: Dictionary, fid: String, def_id: String) -> bool:
	for ch in res.get("duel_changes", []):
		if str(ch.get("fwd", "")) == fid and str(ch.get("def", "")) == def_id:
			return true
	return false


## The first quarter in which `fid` won three or more contests against
## `def_id` - the threshold the live "getting on top" call uses. 0 if none.
static func _on_top_quarter(res: Dictionary, fid: String, def_id: String) -> int:
	var wins := {}
	for c in ((res.get("duels", {}) as Dictionary).get(fid, {}) as Dictionary).get("contests", []):
		if str(c[1]) == def_id and bool(c[2]):
			wins[int(c[0])] = int(wins.get(int(c[0]), 0)) + 1
	for q in [1, 2, 3, 4, 5]:
		if int(wins.get(q, 0)) >= 3:
			return q
	return 0



## The battle in the feed, rarely: the first contest after a defender goes
## to him, or a third contest in a row to the same man. At most MAX_DUEL_LINES a
## quarter, and not twice on one forward inside DUEL_LINE_GAP minutes (a
## change always shows). `mem` is the caller's memory for the match. ""
## when the contest is not worth a line; quiet games stay quiet.
const MAX_DUEL_LINES := 2
const DUEL_LINE_GAP := 6

static func duel_feed_line(mem: Dictionary, ev: Dictionary) -> String:
	if not ev.has("duel"):
		return ""
	var d: Dictionary = ev["duel"]
	var fid := str(d["fwd"])
	var did := str(d["def"])
	var fwd_won := str(d["won"]) == "fwd"
	var q := int(ev.get("q", 1))
	var mins := int(ev.get("min", 0))
	var seen_all: Dictionary = mem.get("seen", {})
	var seen: Dictionary = seen_all.get(fid, {})
	var changed := not seen.is_empty() and str(seen.get("def", "")) != did
	var streak := 1
	if not changed and str(seen.get("def", "")) == did and bool(seen.get("fwd_won", false)) == fwd_won:
		streak = int(seen.get("streak", 0)) + 1
	var f := _pname(fid)
	var dn := _pname(did)
	var text := ""
	if changed:
		text = ("%s beats %s in the air at the first contest." % [f, dn]) if fwd_won \
				else ("%s gets across %s at the first contest." % [dn, f])
	elif streak == 3:
		text = ("%s is getting on top of %s in the air." % [f, dn]) if fwd_won \
				else ("%s has had the better of %s again." % [dn, f])
	var last_min := int(seen.get("last_min", -99))
	seen_all[fid] = {"def": did, "streak": streak, "fwd_won": fwd_won, "last_min": last_min}
	mem["seen"] = seen_all
	var per_q: Dictionary = mem.get("per_q", {})
	if text == "" or int(per_q.get(q, 0)) >= MAX_DUEL_LINES:
		return ""
	if not changed and mins - last_min < DUEL_LINE_GAP:
		return ""
	seen_all[fid]["last_min"] = mins
	per_q[q] = int(per_q.get(q, 0)) + 1
	mem["per_q"] = per_q
	return text


## The match's other turning points in the feed, from the log: a player going
## off hurt (always), a first AFL goal for one of yours (always, once a player),
## a Big-game player's goal when he lifts (once a side), a goal from an
## intercept that takes or levels the
## lead, and a missed set shot in a close last quarter. At most one of each
## and MAX_STORY_LINES of them a quarter, so quiet games stay quiet. "" to
## leave it to the oval.
const MAX_STORY_LINES := 2
const CLOSE_MISS := 6

static func story_feed_line(mem: Dictionary, ev: Dictionary) -> String:
	var kind := str(ev.get("kind", ""))
	var who := str(ev.get("name", ""))
	var club := GameDB.club_short(str(ev.get("club", "")))
	if kind == "injury":
		var on := str(ev.get("on", ""))
		var hurt := "%s (%s) is hurt and won't return" % [who, club]
		if on != "":
			return "%s: %s comes on." % [hurt, _pname(on)]
		return hurt + "."
	# A first AFL goal for one of yours. mem["first_goal"] holds the ids it would
	# be a first for (GameState.first_goal_candidates), so it is never said of
	# the other side, and each is said once.
	if kind == "goal" and who != "":
		var firsts: Dictionary = mem.get("first_goal", {})
		var kicker := str(ev.get("player_id", ""))
		if kicker != "" and firsts.has(kicker):
			firsts.erase(kicker)
			return "First AFL goal for %s." % who
	var text := ""
	var side := int(ev.get("side", 0))
	var score: Array = ev.get("score", [0, 0])
	var line_kind := ""
	# A Big-game player's goal when he lifts: once a match for each side.
	if kind == "goal" and str(ev.get("trait", "")) == "big_game" and not mem.has("big|%d" % side):
		mem["big|%d" % side] = true
		return "%s lifts when it matters." % who
	# A goal from an intercept that takes the lead or levels it.
	if kind == "goal" and ev.has("from_id") and str(ev["from_id"]) != str(ev.get("player_id", "")):
		var before := int(score[side]) - 6
		if int(score[side]) >= int(score[1 - side]) and before <= int(score[1 - side]):
			text = "From %s's intercept." % _pname(str(ev["from_id"]))
			line_kind = "intercept"
	elif kind == "behind" and bool(ev.get("set", false)) and int(ev.get("q", 1)) >= 4 and who != "":
		var gap := int(score[1 - side]) - int(score[side])
		if gap >= 0 and gap <= CLOSE_MISS:
			text = "%s misses a set shot: %s." % [who,
					"scores level" if gap == 0 else "%s still %d down" % [club, gap]]
			line_kind = "miss"
	if text == "":
		return ""
	var q := int(ev.get("q", 1))
	var per_q: Dictionary = mem.get("story_q", {})
	var key := "%d|%s" % [q, line_kind]
	if int(per_q.get(q, 0)) >= MAX_STORY_LINES or per_q.has(key):
		return ""
	per_q[q] = int(per_q.get(q, 0)) + 1
	per_q[key] = true
	mem["story_q"] = per_q
	return text


## The moments a match turned on, from the log, as sentences: the score
## that put the winners in front for good (when they had been behind or
## level after the first quarter), a star who went off hurt before the last
## quarter, and your missed set shot late in a close loss. [] for a match
## that never turned.
static func turning_points(res: Dictionary, my_side: int) -> Array:
	var out := []
	var events: Array = res.get("events", [])
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	var score: Array = res.get("score", [0, 0])
	var winner := -1 if int(score[0]) == int(score[1]) else (0 if int(score[0]) > int(score[1]) else 1)
	if winner >= 0:
		var took: Dictionary = {}
		var was_ahead := false
		for ev in events:
			var kind := str(ev.get("kind", ""))
			if kind != "goal" and kind != "behind":
				continue
			var sc: Array = ev.get("score", [0, 0])
			var ahead := int(sc[winner]) > int(sc[1 - winner])
			if ahead and not was_ahead:
				took = ev
			was_ahead = ahead
		if not took.is_empty() and int(took.get("q", 1)) >= 2 and int(took.get("q", 1)) <= 4 \
				and str(took.get("name", "")) != "":
			out.append("%s's %s %s put %s in front for good." % [str(took["name"]), str(took["kind"]),
					_when(took), GameDB.club_name(codes[winner])])
	var overall := {}
	for side in range(2):
		for r in (res.get("roster", [[], []]) as Array)[side]:
			overall[str(r["id"])] = int(r.get("overall", 0))
	for inj in res.get("injuries", []):
		if int(inj.get("q", 4)) >= 4 or int(overall.get(str(inj["id"]), 0)) < MatchSim.STAR_OVR:
			continue
		var whose := "You" if int(inj["side"]) == my_side else GameDB.club_name(codes[int(inj["side"])])
		out.append("%s lost %s to a %s in the %s quarter." % [whose, _pname(str(inj["id"])),
				str(inj.get("kind", "injury")), QUARTER_NAMES[int(inj["q"]) - 1]])
		break
	if winner != my_side and absi(int(score[0]) - int(score[1])) <= CLOSE_MISS:
		for ev in events:
			if str(ev.get("kind", "")) == "behind" and int(ev.get("side", -1)) == my_side \
					and bool(ev.get("set", false)) and int(ev.get("q", 1)) == 4 \
					and int(ev.get("min", 0)) - 90 >= 20 and str(ev.get("name", "")) != "":
				out.append("%s missed a set shot late in the last quarter." % str(ev["name"]))
				break
	return out


## "12 minutes into the last quarter", "early in the second quarter".
static func _when(ev: Dictionary) -> String:
	var q := int(ev.get("q", 1))
	var m := int(ev.get("min", 0)) - (q - 1) * 30
	var qn: String = QUARTER_NAMES[mini(q - 1, 4)]
	if m <= 3:
		return "early in the %s quarter" % qn
	return "%d minutes into the %s quarter" % [m, qn]


## What each synergy you had switched on is about, from this match: the
## stat it shows up in, yours against theirs, as "What your calls did" does for
## calls. Facts only - no claim of what the synergy itself was worth.
static func synergy_lines(res: Dictionary, my_side: int) -> Array:
	var out := []
	var opp := 1 - my_side
	var syn: Array = (res.get("synergies", [[], []]) as Array)[my_side]
	var team: Array = res.get("team", [{}, {}])
	var me: Dictionary = team[my_side]
	var them: Dictionary = team[opp]
	var goals: Array = res.get("goals", [0, 0])
	for key in syn:
		var fact := ""
		match str(key):
			"engine_room":
				fact = "clearances %d to %d." % [int(me.get("clearances", 0)), int(them.get("clearances", 0))]
			"tall_small":
				fact = "%s goals from %d inside 50s." % [str(goals[my_side]), int(me.get("inside50", 0))]
			"intercept_wall":
				fact = "they kicked %s goals from %d inside 50s." % [str(goals[opp]), int(them.get("inside50", 0))]
			"lockdown_unit":
				fact = "a pressure rating of %d to %d." % [MatchSim.pressure_rating(me, them), MatchSim.pressure_rating(them, me)]
			"supply_line":
				fact = "%d inside 50s to %d." % [int(me.get("inside50", 0)), int(them.get("inside50", 0))]
		if fact != "":
			out.append("%s: %s" % [Traits.label(str(key)), fact])
	return out
