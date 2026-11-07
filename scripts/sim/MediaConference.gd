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
## "21 or younger" counts a player until his 22nd birthday (is_young).
const YOUNG_AGE := 21.0
const YOUNG_SIDE := 5
## She writes the long piece, so she asks less often than the others: about one
## conference in six (director 2026-11-07; tools/audit/press_impl.gd measures it).
const YOUNG_SIDE_COOLDOWN := 7
## A gap this wide in inside 50s or clearances is worth a Stats Geek question.
const STAT_GAP := 8

const JOURNALISTS := {
	"muckraker": {"name": "Gary Haddon", "outlet": "The Siren"},
	"sycophant": {"name": "Trish Lomax", "outlet": "Footy Tonight", "her": true},
	"stats": {"name": "Dev Mehta", "outlet": "Ladder Watch"},
	"bogan": {"name": "Kev Pollard", "outlet": "Outer Wing Radio"},
	"philosopher": {"name": "Margaret Ashby", "outlet": "The Long Kick", "her": true},
}


## Whether a player of this age is "21 or younger": ages are fractional, so a
## 21-and-a-half-year-old still counts.
static func is_young(age: float) -> bool:
	return age < YOUNG_AGE + 1.0


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
	# Who a fourth answer can name, per question (director 2026-11-06, Q3).
	var named: Dictionary = ctx.get("named", {})

	var injuries: Array = ctx.get("injuries", [])
	# Asked after a loss only: its answers say the injury cost the game.
	if not injuries.is_empty() and margin < 0:
		candidates.append(_q("injury", "bogan", "Tough blow losing %s. How much did that hurt you out there?" %
				str(injuries[0].get("name", "a player")), round_no,
				"The blokes who came in fell short.", "We had to adjust. That's footy.",
				"That injury cost us the game.",
				_named(injuries[0], "back_named", "%s will come back better.")))
	if margin <= -40:
		# What you told the Sycophant after a big win this season comes back.
		var said: Dictionary = recent["said|big_win"] if recent.get("said|big_win") is Dictionary else {}
		if not said.is_empty() and int(said.get("year", -1)) == year and int(said.get("option", -1)) == 1:
			candidates.append(_q("heavy_loss", "muckraker",
					"After beating %s you said your method was the standard. Where was it today against %s?" % [
					str(said.get("opp", "them")), opp], round_no,
					"The players didn't live up to it.", "One bad day doesn't change it.",
					"The players still believe in it.",
					_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today.")))
		else:
			candidates.append(_q("heavy_loss", "muckraker", "%s beat you by %d. Was that acceptable?" % [opp, -margin],
					round_no, "That was soft from the players.",
					"Our execution let the system down.", "The players will respond.",
					_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today.")))
	elif margin >= 40:
		candidates.append(_q("big_win", "sycophant", "That was a clinic against %s. Is this the best side in the competition?" % opp,
				round_no, "Plenty of it was sloppy.", "Our method's the standard now.",
				"All credit to the players.",
				_named(named.get("big_win", {}), "back_named", "%s was enormous today.")))
	elif absi(margin) <= 6:
		candidates.append(_q("close_game", "stats", _close_question(res, side, margin, opp), round_no,
				"Too many went missing late.", "That's how tight games go.",
				"The players did everything right."))

	var star: Dictionary = ctx.get("star", {})
	if not star.is_empty():
		var line := str(star.get("line", "had a huge night"))
		candidates.append(_q("star", "bogan", "%s %s. Is there a better player in the comp right now?" %
				[str(star.get("name", "One of your players")), line], round_no,
				"Too many others were passengers.", "Our structure set him up.",
				"Credit to him and the whole group.",
				_named(star, "back_named", "%s's the best in the comp.")))

	var young := int(ctx.get("young", 0))
	if young >= YOUNG_SIDE:
		candidates.append(_q("young_side", "philosopher",
				"%s of your side today were %d or younger. Is this the club you're building?" % [
				MatchNotes.count_word(young).capitalize(), int(YOUNG_AGE)], round_no,
				"Perform or they'll be dropped.", "We'll wear the bad days for it.",
				"I'm proud of every one of them.",
				_named(named.get("young_side", {}), "criticise_named", "%s has to learn quicker.")))

	# Not every ordinary match earns a conference. A notable factual trigger is required.
	for q in candidates:
		var key := str(q["key"])
		var last = recent.get(key, -999)
		# {"year", "round"}: rounds restart each season, so last year's ask is off cooldown.
		if last is Dictionary:
			last = int(last.get("round", -999)) if int(last.get("year", 0)) == int(ctx.get("year", 0)) else -999
		if typeof(last) != TYPE_INT and typeof(last) != TYPE_FLOAT:
			last = -999
		var wait := YOUNG_SIDE_COOLDOWN if key == "young_side" else COOLDOWN_ROUNDS
		if round_no - int(last) > wait:
			# A young side moves the odds of every answer (see chance()).
			q["young"] = young
			# The result, so a lift after a loss can be held under a win's.
			q["margin"] = margin
			return q
	return {}


## A named answer's option, {} when nobody fits (no id).
static func _named(who: Dictionary, kind: String, label: String) -> Dictionary:
	var id := str(who.get("id", ""))
	if id == "":
		return {}
	var name := str(who.get("name", "He"))
	return {"id": id, "name": name, "kind": kind, "label": label % name}


## The Stats Geek's close-game question, from a number that was true of the
## match: a big gap in inside 50s or clearances against the result, or else the
## scoring shots.
static func _close_question(res: Dictionary, side: int, margin: int, opp: String) -> String:
	# A draw: nothing decided it.
	if margin == 0:
		return "Level at the final siren against %s. Was a draw a fair result?" % opp
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
## questions' order: criticise the players, talk the method, back them, and on
## some questions a fourth answer about one named player (director 2026-11-06).
const KINDS := ["criticise", "method", "back"]
const NAMED_KINDS := ["back_named", "criticise_named"]

## Caps. Every press move fades (FADE_ROUNDS). Sizes and stacking stay inside
## these; none is tied to what the match itself moved.
const LIST_CAP := 2
const NAMED_CAP := 3
## The board (director 2026-11-07): a press answer can move the board's view
## further than the match result moved it (a win moves it +2 or +3,
## ClubLife.after_match). This only stops stacked answers running away.
const BOARD_CAP := 3
## Morale after a loss (director 2026-11-07, replacing the 2026-11-06 "below
## the match result's own" cap): an answer can lift a player up to just below
## what a win would have given him. A player who played gets
## ClubLife.MATCH_MORALE_LOSS for a loss and MATCH_MORALE_WIN for a win, so the
## press lift after a loss stops one short of that gap (+2 today).
const LOSS_LIFT_CAP := 2   # ClubLife.MATCH_MORALE_WIN - MATCH_MORALE_LOSS - 1 (tests pin it)

## Per answer: the chance of outcome "a" before the facts move it ("base"),
## which way the mood moves it ("pull": +1 a settled player or group takes it
## better, -1 a flat one needs it more), what youth does to it, and what the
## match result does to it. Each outcome moves board confidence ("board"),
## every listed player's morale ("morale") or one named player's ("his");
## "odds" is its words at the gate, "after" what the coach reads once it has
## landed (%s is the named player). "both" names what moves the same way
## whichever way it lands, by the sign of the shared board move.
const ANSWERS := {
	"criticise": {"base": 50, "pull": 1, "young": -15, "result": {},
		"both": {0: "board unchanged"},
		"a": {"board": 1, "morale": 1, "his": 0, "odds": "resolve tightens", "after": "The players' resolve tightened"},
		"b": {"board": 1, "morale": -2, "his": 0, "odds": "hung out to dry", "after": "The players felt hung out to dry"}},
	"method": {"base": 50, "pull": 0, "young": 0, "result": {"heavy_loss": -15, "big_win": 15},
		"both": {0: "morale unchanged"},
		"a": {"board": 1, "morale": 0, "his": 0, "odds": "the board buys it", "after": "The board bought it"},
		"b": {"board": -1, "morale": 0, "his": 0, "odds": "the board hears excuses", "after": "The board heard excuses"}},
	"back": {"base": 60, "pull": -1, "young": 10, "result": {},
		"both": {0: "board unchanged"},
		"a": {"board": -1, "morale": 2, "his": 0, "odds": "the players lift", "after": "The players lifted"},
		"b": {"board": -1, "morale": -1, "his": 0, "odds": "it rings hollow", "after": "It rang hollow with the players"}},
	"back_named": {"base": 60, "pull": -1, "young": 0, "result": {},
		"both": {0: "nothing else moves"},
		"a": {"board": 0, "morale": 0, "his": 2, "odds": "%s grows another leg", "after": "%s grew another leg"},
		"b": {"board": 0, "morale": 0, "his": -1, "odds": "the spotlight weighs on him", "after": "The spotlight weighed on %s"}},
	"criticise_named": {"base": 45, "pull": 1, "young": -15, "result": {},
		"both": {0: "nothing else moves"},
		"a": {"board": 0, "morale": 0, "his": 1, "odds": "%s's resolve tightens", "after": "%s's resolve tightened"},
		"b": {"board": 0, "morale": 0, "his": -3, "odds": "he takes it personally", "after": "%s took it personally"}},
}

## The five journalists' personalities (director 2026-11-06: personality
## changes what an answer does, shown openly on the gate). "likes" and
## "dislikes" move your standing with him by one; "odds" moves outcome "a";
## "board_up" adds one to every board size (to the cap), "named_up" one to
## every named size (to the cap), "slow" stretches the morale fade to every
## third round (SLOW_FADE_ROUNDS);
## "record" means the record check decides his standing and odds.
const PERSONA := {
	"muckraker": {"likes": ["criticise", "criticise_named"], "dislikes": ["back", "back_named"],
		"odds": {"criticise": -10, "criticise_named": -10}, "odds_note": "His headline",
		"board_up": true, "board_note": "The Siren gets read upstairs",
		"rule": "The Siren gets read upstairs: a board move that hangs on how it lands is a point bigger."},
	"sycophant": {"likes": ["back", "back_named"], "dislikes": ["criticise"],
		"odds": {"back": -5, "back_named": -5}, "odds_note": "Praise is expected"},
	"stats": {"likes": [], "dislikes": [], "odds": {}, "record": true,
		"rule": "The board reads Ladder Watch: when the record says otherwise, confidence drops a point more."},
	"bogan": {"likes": ["back"], "dislikes": ["method"], "odds": {},
		"named_up": true, "named_note": "The players listen to his show",
		"rule": "The players listen to his show: a named player's move is a point bigger."},
	"philosopher": {"likes": ["method"], "dislikes": ["criticise", "criticise_named"], "odds": {},
		"slow": true, "slow_note": "Her piece lingers: morale moves wear off a point every third round, board moves a point a round."},
}

## Standing with each journalist, -2..+2 (director 2026-11-06, Q1): each step
## moves outcome "a" of every answer to him by this much, and fades one step a
## season.
const STANDING_MIN := -2
const STANDING_MAX := 2
const STANDING_ODDS := 5
## His opinion of you, one word per step (director 2026-11-07: "it should
## read opinion of you: neutral"; he chose the five words).
const STANDING_WORDS := {-2: "Hostile", -1: "Wary", 0: "Neutral", 1: "Warm", 2: "Firm fan"}
## "Gary's opinion of you is Wary: every answer is 5% less likely to land well."
const STANDING_EFFECT := "%s's opinion of you is %s: every answer is %d%% %s likely to land well."
## The question body never changes (5.50); standing only adds a lead-in.
const LEAD_INS := {
	"muckraker": ["You ducked me last time, so I'll try again.", "You've always fronted up, so here goes."],
	"sycophant": ["Let's try this one more time, coach.", "Coach, what a day for the club."],
	"stats": ["Your numbers didn't back you last time.", "Your numbers have stacked up so far."],
	"bogan": ["The outer's not happy with you, coach.", "The fans are right behind you, coach."],
	"philosopher": ["Last time you gave me the short version.", "You always give me the long answer."],
}

## The Stats Geek's record check (ruling 5.48): a claim the record contradicts
## costs you, one it supports lands harder. Under this many games, neutral.
const RECORD_MIN_GAMES := 4
const RECORD_ODDS := 10
const RECORD_CLAUSE := {"supported": "The record backs this.", "contradicted": "The record says otherwise.",
		"neutral": "The record doesn't settle it.", "early": "Too early for the record to say."}
## The same, as a reason on the gate: "Record backs it: 10% more likely".
const RECORD_REASON := {"supported": "Record backs it", "contradicted": "Record says otherwise"}
const RECORD_BOARD_NOTE := "the board reads Ladder Watch"

## The group's (or the named player's) morale against the settled line moves
## the odds by half a point per point, at most this far either way.
const MORALE_WEIGHT := 0.5
const MORALE_CAP := 10.0
## Odds are shown in steps of five, never a sure thing.
const ODDS_STEP := 5
const ODDS_MIN := 20
const ODDS_MAX := 80
## How many rounds each point of a press move lasts (director 2026-11-07,
## "Fade every 2nd round"): a player's morale move fades a point every second
## round (+1 lasts 2 rounds, -2 lasts 4), every third after the Philosopher;
## the board's fades a point a round.
const FADE_ROUNDS := 2
const SLOW_FADE_ROUNDS := 3
const BOARD_FADE_ROUNDS := 1

## The gate's templates: no digits here, every number comes from the tables.
## One answer's line (director 2026-11-07, "Trim odds lines"): "40% resolve
## tightens, morale +1% · 60% hung out to dry, morale -2% · Board +1% either
## way · His headline: 10% less likely · Gary warms to you (+5% next time)".
const ODDS_TEMPLATE := "%d%% %s, %s · %d%% %s, %s"
const SEP := " · "
const EITHER_WAY := "%s either way"
const MORALE_SIZE := "morale %+d%%"
const HIS_SIZE := "his morale %+d%%"
const BOARD_SIZE := "board %+d%%"
const NO_BOARD := "board unchanged"
const AFTER_MORALE := "morale %+d%% across the list"
const AFTER_HIS := "%s's morale %+d%%"
const AFTER_BOARD := "board confidence %+d%%"
## One odds twist on the gate: "Heavy loss: 15% less likely".
const REASON := "%s: %d%% %s likely"
## Said once on the screen, not under every answer: how long the moves last.
const FADE_NOTE := "Morale moves wear off a point every second round, board moves a point a round."
## Your standing with him moves: what that does to his later questions.
const LIKES := "%s warms to you (+%d%% next time)"
const DISLIKES := "%s cools on you (-%d%% next time)"

## A named answer stays with him (director 2026-11-07: "And it should weigh on
## future contract choices"): whichever way it lands, his price to re-sign with
## you moves by this share - dearer once you called him out, cheaper once you
## backed him. Full for the rest of this season (its off-season talks and any
## early extension), half the next season, then gone. The newest named answer
## about him replaces an older one. His price is Contracts.asking_salary, so his
## ask, his lowest and an early extension all move by the same share.
const CONTRACT_PCT := {"criticise_named": 4, "back_named": -2}
## On the gate, in the "either way" slot of a named answer: the talks it
## reaches - this year's and next year's when his deal ends this season, only
## next year's when it ends next season.
const CONTRACT_LINE := "Re-signing him: %d%% %s this year, %d%% next"
const CONTRACT_LINE_NEXT := "Re-signing him next year: %d%% %s"
## In contract talks: why his price moved - what you said, when, and the
## share now.
const CONTRACT_MEMORY := "Remembers you %s %s, so he %s."
const CONTRACT_MORE := "wants %d%% more"
const CONTRACT_LESS := "will take %d%% less"
const CONTRACT_SAID := {"criticise_named": "called him out", "back_named": "backed him"}


## The answer an option is. A save from before the roll kept fixed effects on
## its pending options; those map by their place in the list.
static func kind_of(option: Dictionary, index: int) -> String:
	var k := str(option.get("kind", ""))
	if ANSWERS.has(k):
		return k
	return str(KINDS[clampi(index, 0, KINDS.size() - 1)])


## Whether the pending conference followed a loss. A save from before the
## margin was kept reads it from the question: only a loss asks these.
static func after_loss(mc: Dictionary) -> bool:
	if mc.has("margin"):
		return int(mc["margin"]) < 0
	return ["heavy_loss", "injury"].has(str(mc.get("key", "")))


static func is_named(kind: String) -> bool:
	return NAMED_KINDS.has(kind)


## The chance (percent) that an answer lands its first way, from the facts:
## {"morale": the group's average, "young": young players in the side,
## "journalist": who asked, "key": what the question is about, "standing":
## your standing with him, "verdict": the record check (Stats Geek),
## "his_morale" and "his_age": the named player's, for a named answer}.
static func chance(kind: String, facts: Dictionary) -> int:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var c := int(s["base"])
	for part in chance_parts(kind, facts):
		c += int(part["pct"])
	c += clampi(int(facts.get("standing", 0)), STANDING_MIN, STANDING_MAX) * STANDING_ODDS
	return clampi(roundi(float(c) / ODDS_STEP) * ODDS_STEP, ODDS_MIN, ODDS_MAX)


## Every twist that moves one answer's odds apart from your standing (the
## byline states that once, for every answer), each in football words:
## [{"why", "pct"}], in whole steps of five so the gate's sum is exact.
## `facts` also takes "name": the named player's.
static func chance_parts(kind: String, facts: Dictionary) -> Array:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var out := []
	var named := is_named(kind)
	var name := str(facts.get("name", "He"))
	var mood_of := float(facts.get("his_morale", ClubLife.MORALE_BASE)) if named \
			else float(facts.get("morale", ClubLife.MORALE_BASE))
	var mood := mood_of - float(ClubLife.MORALE_BASE)
	var m := int(s["pull"]) * roundi(clampf(mood * MORALE_WEIGHT, -MORALE_CAP, MORALE_CAP) / ODDS_STEP) * ODDS_STEP
	if m != 0:
		var feel := "up and about" if mood > 0.0 else "flat"
		out.append({"pct": m, "why": ("%s is %s" % [name, feel]) if named else ("The group is %s" % feel)})
	if named:
		if is_young(float(facts.get("his_age", 30.0))) and int(s["young"]) != 0:
			out.append({"pct": int(s["young"]), "why": "%s is young" % name})
	elif int(facts.get("young", 0)) >= YOUNG_SIDE and int(s["young"]) != 0:
		out.append({"pct": int(s["young"]), "why": "Young side"})
	var j: Dictionary = PERSONA.get(str(facts.get("journalist", "")), {})
	var jo := int((j.get("odds", {}) as Dictionary).get(kind, 0))
	if jo != 0:
		out.append({"pct": jo, "why": str(j.get("odds_note", ""))})
	var key := str(facts.get("key", ""))
	var r := int((s["result"] as Dictionary).get(key, 0))
	if r != 0:
		out.append({"pct": r, "why": "Heavy loss" if key == "heavy_loss" else "Big win"})
	var verdict := str(facts.get("verdict", ""))
	if RECORD_REASON.has(verdict):
		out.append({"pct": RECORD_ODDS if verdict == "supported" else -RECORD_ODDS, "why": str(RECORD_REASON[verdict])})
	return out


## "Heavy loss: 15% less likely" (to land well).
static func reason_line(part: Dictionary) -> String:
	var pct := int(part["pct"])
	return REASON % [str(part["why"]), absi(pct), "more" if pct > 0 else "less"]


## What an answer does once the journalist's personality and the record check
## have had their say: {"a": {board, morale, his, odds, after}, "b": ..., "both",
## "notes": the twists that changed it, in words}. `ctx`: {"journalist",
## "verdict", "name": the named player, "lost": the match was a loss}. Every
## size stays inside its cap (LOSS_LIFT_CAP for a lift after a loss).
static func effects(kind: String, ctx: Dictionary = {}) -> Dictionary:
	var s: Dictionary = ANSWERS.get(kind, ANSWERS["method"])
	var j: Dictionary = PERSONA.get(str(ctx.get("journalist", "")), {})
	var verdict := str(ctx.get("verdict", ""))
	var name := str(ctx.get("name", "him"))
	var out := {"notes": []}
	for w in ["a", "b"]:
		var o: Dictionary = (s[w] as Dictionary).duplicate()
		# His paper amplifies the board's read of the answer, never a move it
		# makes whichever way it lands (no free, sure-thing lever).
		if bool(j.get("board_up", false)) and int(o["board"]) != 0 \
				and int((s["a"] as Dictionary)["board"]) != int((s["b"] as Dictionary)["board"]):
			o["board"] = clampi(int(o["board"]) + signi(int(o["board"])), -BOARD_CAP, BOARD_CAP)
		if bool(j.get("named_up", false)) and int(o["his"]) != 0:
			o["his"] = clampi(int(o["his"]) + signi(int(o["his"])), -NAMED_CAP, NAMED_CAP)
		if verdict == "supported" and w == "a":
			# The lead size of "a" lands harder, within its cap.
			if kind == "method":
				o["board"] = clampi(int(o["board"]) + 1, -BOARD_CAP, BOARD_CAP)
			elif int(o["morale"]) > 0:
				o["morale"] = clampi(int(o["morale"]) + 1, -LIST_CAP, LIST_CAP)
		elif verdict == "contradicted":
			o["board"] = clampi(int(o["board"]) - 1, -BOARD_CAP, BOARD_CAP)
		if bool(ctx.get("lost", false)):
			# After a loss, a lift stops just below what a win gave.
			o["morale"] = mini(int(o["morale"]), LOSS_LIFT_CAP)
			o["his"] = mini(int(o["his"]), LOSS_LIFT_CAP)
		if is_named(kind):
			# Named once per line: the second outcome says "he".
			if str(o["odds"]).contains("%s"):
				o["odds"] = str(o["odds"]) % name
			o["after"] = str(o["after"]) % name
		out[w] = o
	var a: Dictionary = out["a"]
	var b: Dictionary = out["b"]
	# What moves the same whichever way it lands, with its size, or what
	# does not move at all ("Board unchanged").
	var same := _shared_size(a, b)
	out["both"] = EITHER_WAY % _cap_first(same) if same != "" else _cap_first(str((s["both"] as Dictionary).get(0, "")))
	var notes: Array = out["notes"]
	if bool(j.get("board_up", false)) and int((s["a"] as Dictionary)["board"]) != int((s["b"] as Dictionary)["board"]):
		notes.append(str(j["board_note"]))
	if bool(j.get("named_up", false)) and is_named(kind):
		notes.append(str(j["named_note"]))
	if verdict == "contradicted":
		notes.append(_cap_first(RECORD_BOARD_NOTE))
	# A named answer weighs on his next contract (CONTRACT_PCT), said only when
	# a re-signing falls inside the two seasons it lasts (his deal has at most
	# two seasons left, counting this one).
	if CONTRACT_PCT.has(kind) and int(ctx.get("contract_years", 1)) <= 2:
		out["contract"] = int(CONTRACT_PCT[kind])
		out["both"] = contract_line(kind, int(ctx.get("contract_years", 1)))
	return out


## "Re-signing him: 4% dearer this year, 2% next" (his deal ends this
## season) or "Re-signing him next year: 2% dearer" (it ends next season).
static func contract_line(kind: String, contract_years := 1) -> String:
	var pct := int(CONTRACT_PCT.get(kind, 0))
	var way := "dearer" if pct > 0 else "cheaper"
	if contract_years >= 2:
		return CONTRACT_LINE_NEXT % [absi(contract_pct_after(pct, 1)), way]
	return CONTRACT_LINE % [absi(pct), way, absi(contract_pct_after(pct, 1))]


## The share left `seasons` rollovers after the answer: full, half, then 0.
static func contract_pct_after(full: int, seasons: int) -> int:
	if seasons <= 0:
		return full
	return full / 2 if seasons == 1 else 0


## He remembers a named answer: kept on him with your club, the season and
## round, and how it landed. Any other answer leaves him as he was.
static func remember(p: Dictionary, kind: String, landed: String, club: String, year: int, round_no: int) -> void:
	if not CONTRACT_PCT.has(kind) or p.is_empty():
		return
	var pct := int(CONTRACT_PCT[kind])
	p["press_memory"] = {"kind": kind, "landed": landed, "club": club, "year": year, "round": round_no,
			"full": pct, "pct": pct}


## The share his price to re-sign moves now (+ dearer, - cheaper); 0 when he
## remembers nothing, or what he remembers was said at another club. An
## older save has no memory, so 0.
static func contract_pct(p: Dictionary) -> int:
	var m = p.get("press_memory")
	if not (m is Dictionary) or str(m.get("club", "")) != str(p.get("club", "")):
		return 0
	return int(m.get("pct", 0))


## At the rollover: the memory halves after its first season and is gone after
## its second; it is dropped at once when he is not at `my_club` or it was said
## at another club (a trade, or a coach who moved on).
static func age_memory(p: Dictionary, my_club: String) -> void:
	var m = p.get("press_memory")
	if not (m is Dictionary):
		p.erase("press_memory")
		return
	var full := int(m.get("full", 0))
	var now := int(m.get("pct", 0))
	if str(m.get("club", "")) != my_club or str(p.get("club", "")) != my_club or now != full:
		p.erase("press_memory")
		return
	now = contract_pct_after(full, 1)
	if now == 0:
		p.erase("press_memory")
	else:
		m["pct"] = now


## His line in contract talks, "" when he remembers nothing: "Remembers you
## called him out in round 8, so he wants 4% more." `year` is the
## season now.
static func contract_memory_line(p: Dictionary, year: int) -> String:
	var pct := contract_pct(p)
	if pct == 0:
		return ""
	var m: Dictionary = p["press_memory"]
	var said := int(m.get("round", 0))
	var when := "in the finals" if said > Season.REGULAR_ROUNDS else "in round %d" % said
	if int(m.get("year", year)) < year:
		when += " last season"
	return CONTRACT_MEMORY % [str(CONTRACT_SAID.get(str(m.get("kind", "")), "spoke about him")), when,
			(CONTRACT_MORE if pct > 0 else CONTRACT_LESS) % absi(pct)]


## How your standing with the journalist who asked moves when you give this
## answer: +1, 0 or -1. The Stats Geek goes by the record check instead.
static func standing_move(journalist: String, kind: String, verdict := "") -> int:
	var j: Dictionary = PERSONA.get(journalist, {})
	if bool(j.get("record", false)):
		return 1 if verdict == "supported" else (-1 if verdict == "contradicted" else 0)
	if (j.get("likes", []) as Array).has(kind):
		return 1
	if (j.get("dislikes", []) as Array).has(kind):
		return -1
	return 0


## Standing after one more move, inside -2..+2.
static func standing_after(v: int, move: int) -> int:
	return clampi(v + move, STANDING_MIN, STANDING_MAX)


## Standing after `years` seasons: one step toward even a season.
static func standing_decayed(v: int, years: int) -> int:
	if years <= 0:
		return v
	return v - signi(v) * mini(absi(v), years)


## His opinion of you in one word: "Warm".
static func standing_word(v: int) -> String:
	return str(STANDING_WORDS.get(clampi(v, STANDING_MIN, STANDING_MAX), ""))


## "Gary's opinion of you is Warm: every answer is 5% more likely to land
## well."; "" when Neutral.
static func standing_effect(journalist: String, v: int) -> String:
	if v == 0:
		return ""
	return STANDING_EFFECT % [first_name(journalist), standing_word(v), absi(v) * STANDING_ODDS,
			"more" if v > 0 else "less"]


## The lead-in for a question at this standing, "" when even.
static func lead_in(journalist: String, v: int) -> String:
	var pair: Array = LEAD_INS.get(journalist, ["", ""])
	if v <= -1:
		return str(pair[0])
	if v >= 1:
		return str(pair[1])
	return ""


static func first_name(journalist: String) -> String:
	return str(JOURNALISTS.get(journalist, {}).get("name", "")).get_slice(" ", 0)


static func is_woman(journalist: String) -> bool:
	return bool(JOURNALISTS.get(journalist, {}).get("her", false))


## How many rounds a player's press lift of this size takes to fade (fade_lift
## counts its rounds from the presser, so this is exact).
static func fade_rounds(size: int, slow: bool) -> int:
	return absi(size) * (SLOW_FADE_ROUNDS if slow else FADE_ROUNDS)


## How many rounds the board's press move of this size takes to fade.
static func board_fade_rounds(size: int) -> int:
	return absi(size) * BOARD_FADE_ROUNDS


## The record the Stats Geek reads: {"w", "l", "d", "pct", "pos", "form" (-1..1),
## "last" ("WWLWW"), "streak" (losses in a row)}.
static func record_verdict(kind: String, rec: Dictionary) -> String:
	var w := int(rec.get("w", 0))
	var l := int(rec.get("l", 0))
	var games := w + l + int(rec.get("d", 0))
	if games < RECORD_MIN_GAMES:
		return "early"
	var pct := float(rec.get("pct", 100.0))
	var form := float(rec.get("form", 0.0))
	match kind:
		"method":
			if pct < 95.0 or form <= -0.25:
				return "contradicted"
			if pct >= 110.0 and form >= 0.25:
				return "supported"
		"back", "back_named":
			if l >= w + 2:
				return "contradicted"
			if w >= l + 2:
				return "supported"
		"criticise", "criticise_named":
			if form >= 0.6:
				return "contradicted"
			if int(rec.get("streak", 0)) >= 2 or form <= -0.25:
				return "supported"
	return "neutral"


## "Your record: 7-3, 4th, 118%, form WWLWW."
static func record_line(rec: Dictionary) -> String:
	var w := int(rec.get("w", 0))
	var l := int(rec.get("l", 0))
	var d := int(rec.get("d", 0))
	var wl := "%d-%d" % [w, l] if d == 0 else "%d-%d-%d" % [w, l, d]
	var bits: PackedStringArray = [wl]
	if int(rec.get("pos", 0)) > 0:
		bits.append(_ordinal(int(rec["pos"])))
	bits.append("%d%%" % roundi(float(rec.get("pct", 0.0))))
	var last := str(rec.get("last", ""))
	if last != "":
		bits.append("form " + last)
	return "Your record: %s." % ", ".join(bits)


## What an answer can do, under its button: both outcomes with their odds and
## sizes, what moves the same either way (bible §4), each twist in the odds,
## and how your standing with him moves. How long the moves last and why his
## personality changes a size are said once on the screen (rules_line), not
## under every answer. `fx` is effects() (the base answer when empty); `ctx`
## {"journalist", "verdict", "name", "standing", "facts"}.
static func odds_line(kind: String, chance_a: int, fx: Dictionary = {}, ctx: Dictionary = {}) -> String:
	if fx.is_empty():
		fx = effects(kind, ctx)
	var a: Dictionary = fx["a"]
	var b: Dictionary = fx["b"]
	var parts: PackedStringArray = [ODDS_TEMPLATE % [chance_a, str(a["odds"]), _sizes(a, b), 100 - chance_a,
			str(b["odds"]), _sizes(b, a)]]
	if str(fx["both"]) != "":
		parts.append(str(fx["both"]))
	var journalist := str(ctx.get("journalist", ""))
	var verdict := str(ctx.get("verdict", ""))
	# Every twist in the odds, named (director 2026-11-06: shown openly).
	var facts: Dictionary = ctx.get("facts", {})
	if not facts.is_empty():
		for part in chance_parts(kind, facts):
			parts.append(reason_line(part))
	elif RECORD_REASON.has(verdict):
		parts.append(reason_line({"pct": RECORD_ODDS if verdict == "supported" else -RECORD_ODDS,
				"why": RECORD_REASON[verdict]}))
	var now := int(ctx.get("standing", 0))
	var move := standing_after(now, standing_move(journalist, kind, verdict)) - now if journalist != "" else 0
	if move > 0:
		parts.append(LIKES % [first_name(journalist), STANDING_ODDS])
	elif move < 0:
		parts.append(DISLIKES % [first_name(journalist), STANDING_ODDS])
	return SEP.join(parts)


## Said once on the gate, above the answers: how long a press move lasts, and
## what this journalist's personality does to the sizes.
static func rules_line(journalist: String) -> String:
	var j: Dictionary = PERSONA.get(journalist, {})
	if bool(j.get("slow", false)):
		return str(j["slow_note"])
	var rule := str(j.get("rule", ""))
	return FADE_NOTE if rule == "" else "%s %s" % [rule, FADE_NOTE]


## How it landed, for the sheet after the tap and the news.
static func after_line(kind: String, landed: String, fx: Dictionary = {}, name := "") -> String:
	if fx.is_empty():
		fx = effects(kind, {"name": name})
	var o: Dictionary = fx.get(landed, fx["b"])
	var bits: PackedStringArray = []
	if int(o["morale"]) != 0:
		bits.append(AFTER_MORALE % int(o["morale"]))
	if int(o["his"]) != 0:
		bits.append(AFTER_HIS % [name if name != "" else "his", int(o["his"])])
	if int(o["board"]) != 0:
		bits.append(AFTER_BOARD % int(o["board"]))
	var tail := ", ".join(bits)
	return "%s: %s." % [str(o["after"]), tail] if tail != "" else str(o["after"]) + "."


## The board's reason gains one sentence when an answer moved it (director
## 2026-11-06: add to the match reason, never overwrite it). "" for no move.
static func board_sentence(journalist: String, board: int) -> String:
	if board == 0:
		return ""
	var who := str(JOURNALISTS.get(journalist, {}).get("name", "the press"))
	return ("The board liked what you told %s (%+d%% confidence)." if board > 0
			else "The board didn't like what you told %s (%+d%% confidence).") % [who, board]


## Moves one player's press lift by `delta` within `cap`, through his morale:
## stacking can never pass the cap, and only what really moved his morale is
## kept to fade. `up` (>= 0) caps a lift lower than `cap`: LOSS_LIFT_CAP after
## a loss. Returns the change applied.
static func apply_lift(p: Dictionary, delta: int, cap: int, slow: bool, up := -1) -> int:
	if delta == 0:
		return 0
	var old := int(p.get("press_lift", 0))
	var lo := mini(-cap, old)
	var hi := maxi(mini(cap, up) if up >= 0 else cap, old)
	var want := clampi(clampi(old + delta, lo, hi), -NAMED_CAP, NAMED_CAP)
	var before := ClubLife.morale(p)
	ClubLife.add_morale(p, want - old)
	var moved := ClubLife.morale(p) - before
	var now := old + moved
	p.erase("press_wait")
	if now == 0:
		p.erase("press_lift")
		p.erase("press_slow")
	else:
		p["press_lift"] = now
		p["press_slow"] = slow
	return moved


## One round's fade of a player's press lift: a point back toward where he was
## every FADE_ROUNDS rounds (SLOW_FADE_ROUNDS after the Philosopher), counted
## from when it was set. True when it moved.
static func fade_lift(p: Dictionary, _round_no: int) -> bool:
	var lift := int(p.get("press_lift", 0))
	if lift == 0:
		return false
	# "press_wait" counts the rounds since the last step (an old save's true reads as 1).
	var waited := int(p.get("press_wait", 0)) + 1
	if waited < (SLOW_FADE_ROUNDS if bool(p.get("press_slow", false)) else FADE_ROUNDS):
		p["press_wait"] = waited
		return false
	p.erase("press_wait")
	ClubLife.add_morale(p, -signi(lift))
	lift -= signi(lift)
	if lift == 0:
		p.erase("press_lift")
		p.erase("press_slow")
		p.erase("press_wait")
	else:
		p["press_lift"] = lift
	return true


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
	if int(o["his"]) != int(other["his"]):
		bits.append(HIS_SIZE % int(o["his"]))
	if int(o["board"]) != int(other["board"]):
		bits.append(BOARD_SIZE % int(o["board"]) if int(o["board"]) != 0 else NO_BOARD)
	return ", ".join(bits)


## The size both outcomes share (the same move either way), or "".
static func _shared_size(a: Dictionary, b: Dictionary) -> String:
	var bits: PackedStringArray = []
	if int(a["morale"]) == int(b["morale"]) and int(a["morale"]) != 0:
		bits.append(MORALE_SIZE % int(a["morale"]))
	if int(a["his"]) == int(b["his"]) and int(a["his"]) != 0:
		bits.append(HIS_SIZE % int(a["his"]))
	if int(a["board"]) == int(b["board"]) and int(a["board"]) != 0:
		bits.append(BOARD_SIZE % int(a["board"]))
	return ", ".join(bits)


static func _cap_first(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


static func _q(key: String, journalist: String, question: String, round_no: int, accountable: String,
		tactical: String, protective: String, named: Dictionary = {}) -> Dictionary:
	var opts := [
		{"label": accountable, "kind": "criticise"},
		{"label": tactical, "kind": "method"},
		{"label": protective, "kind": "back"},
	]
	# The fourth answer, about one named player (director 2026-11-06, Q3).
	if not named.is_empty() and str(named.get("id", "")) != "":
		opts.append({"label": str(named["label"]), "kind": str(named["kind"]), "player": str(named["id"]),
				"name": str(named.get("name", "him"))})
	return {"key": key, "round": round_no, "question": question, "journalist": journalist,
		"by": byline(journalist), "options": opts}
