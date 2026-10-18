class_name MediaConference
extends RefCounted
## Post-match press conference rules. Questions come only from facts in the
## completed match/season. Consequences are deliberately smaller than results.
##
## The questions come from five recurring journalists (ROADMAP §9.4 RPG-002,
## the director's five types), each asking what suits them: the Muckraker
## after a heavy loss, the Sycophant after a big win, the Stats Geek on a close
## one (with a number that was true of the match), the Bogan on a star or an
## injury, the Philosopher on a young side. They are invented people at invented
## outlets. What you say can come back: claim your method after a big win, and
## the Muckraker quotes it to you after the next heavy loss that season.

const COOLDOWN_ROUNDS := 3
## Players this young in your side, this many of them, and the Philosopher asks.
const YOUNG_AGE := 21.0
const YOUNG_SIDE := 5
## A gap this wide in inside 50s or clearances is worth a Stats Geek question.
const STAT_GAP := 8

const JOURNALISTS := {
	"muckraker": {"name": "Gary Haddon", "outlet": "The Siren"},
	"sycophant": {"name": "Trish Lomax", "outlet": "Footy Tonight"},
	"stats": {"name": "Dev Mehta", "outlet": "Ladder Watch"},
	"bogan": {"name": "Kev Pollard", "outlet": "Outer Wing Radio"},
	"philosopher": {"name": "Margaret Ashby", "outlet": "The Long Kick"},
}


## "Gary Haddon, The Siren"
static func byline(journalist: String) -> String:
	var j: Dictionary = JOURNALISTS.get(journalist, {})
	return "%s, %s" % [str(j.get("name", "")), str(j.get("outlet", ""))] if not j.is_empty() else "Journalist"


static func pick(ctx: Dictionary, recent: Dictionary) -> Dictionary:
	var res: Dictionary = ctx.get("result", {})
	if res.is_empty():
		return {}
	var club := str(ctx.get("club", ""))
	var side := 0 if str(res.get("home", "")) == club else 1
	var score: Array = res.get("score", [0, 0])
	if score.size() < 2:
		return {}
	var margin := int(score[side]) - int(score[1 - side])
	var opp := str(ctx.get("opponent_name", "the opposition"))
	var round_no := int(ctx.get("round", 0))
	var year := int(ctx.get("year", 0))
	var candidates := []

	var injuries: Array = ctx.get("injuries", [])
	if not injuries.is_empty():
		candidates.append(_q("injury", "bogan", "Tough blow losing %s. How much did that hurt you out there?" %
				str(injuries[0].get("name", "a player")), round_no,
				"No excuses. The blokes who came in weren't up to it.", "The group had to adjust, but that's footy.",
				"Losing %s cost us the game. Nothing more to it." % str(injuries[0].get("name", "him"))))
	if margin <= -40:
		# What you told the Sycophant after a big win this season comes back.
		var said: Dictionary = recent["said|big_win"] if recent.get("said|big_win") is Dictionary else {}
		if not said.is_empty() and int(said.get("year", -1)) == year and int(said.get("option", -1)) == 1:
			candidates.append(_q("heavy_loss", "muckraker",
					"After beating %s you said your method was the standard. Where was it today against %s?" % [
					str(said.get("opp", "them")), opp], round_no,
					"Fair question. The players didn't live up to it today.", "One bad day doesn't change the method.",
					"The players believe in it. I won't blame them for one bad day."))
		else:
			candidates.append(_q("heavy_loss", "muckraker", "%s beat you by %d. Was that acceptable?" % [opp, -margin],
					round_no, "That was soft from the players. It wasn't good enough.",
					"The system held up in patches; our execution didn't.", "Don't blame the players. They'll respond."))
	elif margin >= 40:
		candidates.append(_q("big_win", "sycophant", "That was a clinic against %s. Is this the best side in the competition?" % opp,
				round_no, "Don't get carried away. Some of it was sloppy, and the players know it.", "Our method stood up. That's the standard.",
				"All credit to the players. It wasn't down to the system."))
	elif absi(margin) <= 6:
		candidates.append(_q("close_game", "stats", _close_question(res, side, margin, opp), round_no,
				"We left too much to chance. Some players weren't good enough when it counted.", "A handful of contests. That's how tight games go.",
				"The players did everything right. I won't take a thing off them."))

	var star: Dictionary = ctx.get("star", {})
	if not star.is_empty():
		var line := str(star.get("line", "had a huge night"))
		candidates.append(_q("star", "bogan", "%s %s. Is there a better player in the comp right now?" %
				[str(star.get("name", "One of your players")), line], round_no,
				"He was good, but too many others were passengers.", "We put him in positions to influence the game.",
				"Credit to him and the whole group. I won't hear a word against them."))

	var young := int(ctx.get("young", 0))
	if young >= YOUNG_SIDE:
		candidates.append(_q("young_side", "philosopher",
				"%s of your side today were %d or younger. Is this the club you're building?" % [
				MatchNotes.count_word(young).capitalize(), int(YOUNG_AGE)], round_no,
				"They're here on merit, and the ones who don't perform will be dropped.", "It's where the club is going, and we'll wear the bad days.",
				"They've earned it, and I won't have them criticised. I'm proud of them."))

	# Not every ordinary match earns a conference. A notable factual trigger is required.
	for q in candidates:
		var key := str(q["key"])
		var last = recent.get(key, -999)
		if typeof(last) != TYPE_INT and typeof(last) != TYPE_FLOAT:
			last = -999
		if round_no - int(last) > COOLDOWN_ROUNDS:
			# A young side moves the odds of every answer (see chance()).
			q["young"] = young
			return q
	return {}


## The Stats Geek's close-game question, from a number that was true of the
## match: a big gap in inside 50s or clearances against the result, or else the
## scoring shots.
static func _close_question(res: Dictionary, side: int, margin: int, opp: String) -> String:
	var teams: Array = res.get("team", [])
	if teams.size() >= 2:
		var mine: Dictionary = teams[side]
		var theirs: Dictionary = teams[1 - side]
		for k in [["inside50", "inside 50s"], ["clearances", "clearances"]]:
			var a := int(mine.get(k[0], 0))
			var b := int(theirs.get(k[0], 0))
			if margin < 0 and a - b >= STAT_GAP:
				return "You won the %s %d to %d and still lost by %d. What went wrong?" % [k[1], a, b, -margin]
			if margin > 0 and b - a >= STAT_GAP:
				return "%s won the %s %d to %d, and you still got there by %d. How?" % [opp, k[1], b, a, margin]
	var goals: Array = res.get("goals", [])
	var behinds: Array = res.get("behinds", [])
	if goals.size() >= 2 and behinds.size() >= 2:
		return "Scoring shots were %d to %d against %s. What decided it?" % [
				int(goals[side]) + int(behinds[side]), int(goals[1 - side]) + int(behinds[1 - side]), opp]
	return "It came down to the last few minutes against %s. What decided it?" % opp


## Every answer is a roll based on logic (bible: "An answer is a dice roll
## based on logic"; director 2026-10-18, ch. 30 row 33: "Code follows the
## bible"). Each has two outcomes, and the gate shows both with their odds and
## sizes (bible §4), never which answer is better. Option order is the
## questions' order: criticise the players, talk the method, back them.
const KINDS := ["criticise", "method", "back"]

## Per answer: the chance of outcome "a" before the facts move it ("base"),
## which way the group's mood moves it ("pull": +1 a settled group takes it
## better, -1 a flat group needs it more), what a young side does to it, which
## journalist's write-up moves it, and what the match result does to it. Each
## outcome moves board confidence and every listed player's morale; "odds" is
## its words at the gate, "after" what the coach reads once it has landed.
## "both" names the lever that moves the same way whichever way it lands.
const ANSWERS := {
	"criticise": {"base": 50, "pull": 1, "young": -15, "journalist": {"muckraker": -10}, "result": {},
		"both": "The board likes it either way",
		"a": {"board": 2, "morale": 3, "odds": "their resolve tightens", "after": "The players' resolve tightened"},
		"b": {"board": 2, "morale": -4, "odds": "they feel hung out to dry", "after": "The players felt hung out to dry"}},
	"method": {"base": 50, "pull": 0, "young": 0, "journalist": {"stats": 10},
		"result": {"heavy_loss": -15, "big_win": 15},
		"both": "The players read nothing into it",
		"a": {"board": 2, "morale": 0, "odds": "the board buys it", "after": "The board bought it"},
		"b": {"board": -2, "morale": 0, "odds": "the board hears excuses", "after": "The board heard excuses"}},
	"back": {"base": 60, "pull": -1, "young": 10, "journalist": {}, "result": {},
		"both": "The board wanted accountability either way",
		"a": {"board": -2, "morale": 4, "odds": "the players lift", "after": "The players lifted"},
		"b": {"board": -2, "morale": -2, "odds": "it rings hollow with them", "after": "It rang hollow with the players"}},
}
## The group's average morale against the settled line moves the odds by
## half a point per point, at most this far either way.
const MORALE_WEIGHT := 0.5
const MORALE_CAP := 10.0
## Odds are shown in steps of five, never a sure thing.
const ODDS_STEP := 5
const ODDS_MIN := 20
const ODDS_MAX := 80

## The gate's templates: no digits here, every number comes from ANSWERS.
const ODDS_TEMPLATE := "%d%% %s (%s), %d%% %s (%s). %s."
const MORALE_SIZE := "%+d%% morale"
const BOARD_SIZE := "%+d%% confidence"
const AFTER_MORALE := "morale %+d%% across the list"
const AFTER_BOARD := "board confidence %+d%%"


## The answer an option is. A save from before the roll kept fixed effects on
## its pending options; those map by their place in the list.
static func kind_of(option: Dictionary, index: int) -> String:
	var k := str(option.get("kind", ""))
	if ANSWERS.has(k):
		return k
	return str(KINDS[clampi(index, 0, KINDS.size() - 1)])


## The chance (percent) that an answer lands its first way, from the facts:
## {"morale": the group's average, "young": young players in the side,
## "journalist": who asked, "key": what the question is about}.
static func chance(kind: String, facts: Dictionary) -> int:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var c := float(s["base"])
	var mood := float(facts.get("morale", ClubLife.MORALE_BASE)) - float(ClubLife.MORALE_BASE)
	c += float(s["pull"]) * clampf(mood * MORALE_WEIGHT, -MORALE_CAP, MORALE_CAP)
	if int(facts.get("young", 0)) >= YOUNG_SIDE:
		c += float(s["young"])
	c += float((s["journalist"] as Dictionary).get(str(facts.get("journalist", "")), 0))
	c += float((s["result"] as Dictionary).get(str(facts.get("key", "")), 0))
	return clampi(roundi(c / ODDS_STEP) * ODDS_STEP, ODDS_MIN, ODDS_MAX)


## What an answer can do, under its button: both outcomes with their odds and
## sizes, and the lever that moves the same either way (bible §4).
static func odds_line(kind: String, chance_a: int) -> String:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var a: Dictionary = s["a"]
	var b: Dictionary = s["b"]
	var both := str(s["both"])
	var shared := _shared_size(a, b)
	if shared != "":
		both += " (%s)" % shared
	return ODDS_TEMPLATE % [chance_a, str(a["odds"]), _sizes(a, b), 100 - chance_a, str(b["odds"]), _sizes(b, a), both]


## How it landed, for the sheet after the tap and the news.
static func after_line(kind: String, landed: String) -> String:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var o: Dictionary = s.get(landed, s["b"])
	var bits: PackedStringArray = []
	if int(o["morale"]) != 0:
		bits.append(AFTER_MORALE % int(o["morale"]))
	if int(o["board"]) != 0:
		bits.append(AFTER_BOARD % int(o["board"]))
	var tail := ", ".join(bits)
	return "%s: %s." % [str(o["after"]), tail] if tail != "" else str(o["after"]) + "."


## The press stream's draw for one answer, 1..100: seeded from the career's
## seed, the season, the round, the question and the answer (as the story
## stream's risk_hit), so the same career gives the same answer the same way
## however often it is reloaded. Never the clock.
static func roll(seed: int, year: int, round_no: int, key: String, option: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("press|%d|%d|%d|%s|%d" % [seed, year, round_no, key, option])
	return rng.randi_range(1, 100)


## The sizes that differ between the two outcomes, for one outcome.
static func _sizes(o: Dictionary, other: Dictionary) -> String:
	var bits: PackedStringArray = []
	if int(o["morale"]) != int(other["morale"]):
		bits.append(MORALE_SIZE % int(o["morale"]))
	if int(o["board"]) != int(other["board"]):
		bits.append(BOARD_SIZE % int(o["board"]))
	return ", ".join(bits)


## The size both outcomes share (the same move either way), or "".
static func _shared_size(a: Dictionary, b: Dictionary) -> String:
	var bits: PackedStringArray = []
	if int(a["morale"]) == int(b["morale"]) and int(a["morale"]) != 0:
		bits.append(MORALE_SIZE % int(a["morale"]))
	if int(a["board"]) == int(b["board"]) and int(a["board"]) != 0:
		bits.append(BOARD_SIZE % int(a["board"]))
	return ", ".join(bits)


static func _q(key: String, journalist: String, question: String, round_no: int, accountable: String,
		tactical: String, protective: String) -> Dictionary:
	return {
		"key": key, "round": round_no, "question": question, "journalist": journalist,
		"by": byline(journalist),
		"options": [
			{"label": accountable, "kind": "criticise"},
			{"label": tactical, "kind": "method"},
			{"label": protective, "kind": "back"},
		]
	}
