class_name MediaConference
extends RefCounted
## Post-match press conference rules. Questions come only from facts in the
## completed match/season. Consequences are deliberately smaller than results.
##
## The questions come from five recurring journalists (ROADMAP §9.4 RPG-002,
## the director's five types), each asking what suits them: the Muckraker
## after a heavy loss, a lead let slip, an upset loss, a losing run or a finals
## exit; the Sycophant after a big win, a winning run, a final won or a
## milestone; the Stats Geek on a close one (with a number that was true of
## the match), a comeback, an upset win or a wayward loss; the Bogan on a star,
## a debut or an injury; the Philosopher on a young side. A question with two
## written versions takes turns between them (director 2026-11-07: variety). They are invented people at invented
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


## Quarter breaks, for a comeback or a lead let slip.
const BREAKS := ["quarter time", "half-time", "three-quarter time"]
## A deficit (or a lead) this big at a break makes a comeback (or a collapse).
const TURN_GAP := 18
## Ladder places apart for an upset, asked from this round on.
const UPSET_GAP := 8
const UPSET_FROM_ROUND := 6
## A run asked about at this length, then every second game.
## The day's other stories, held back the round after any conference.
const STORY_KEYS := ["comeback", "blown_lead", "milestone", "debut", "upset_loss", "upset_win",
		"losing_run", "winning_run", "wayward"]
const STORY_GAP := 2
const LOSING_RUN_AT := 3
const WINNING_RUN_AT := 4


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
	# How often each question has been asked this career: its written versions
	# take turns, so the same words come round only after the other's have.
	var asked: Dictionary = recent["asked"] if recent.get("asked") is Dictionary else {}

	# A final: the season goes on or ends on it, so it comes first.
	var fin: Dictionary = ctx.get("final", {})
	if not fin.is_empty():
		var label := str(fin.get("label", "final"))
		if margin < 0 and str(fin.get("status", "")) in ["eliminated", "runner_up"]:
			candidates.append(_q("final_loss", "muckraker", "Your season ends in the %s. Where did it fall short?" % label,
					round_no, "Too many didn't stand up in September.", "We'll review how we play, top to bottom.",
					"I'm proud of this group's year.",
					_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing when it counted.")))
		elif margin > 0 and str(fin.get("status", "")) == "alive":
			candidates.append(_q("final_win", "sycophant", "You've won the %s against %s. Is this the year?" % [label, opp],
					round_no, "Not on that effort. Some were off today.", "We stick to what got us here.",
					"The players have earned this shot.",
					_named(named.get("big_win", {}), "back_named", "%s was enormous today.")))

	if margin <= -40:
		# What you told the Sycophant after a big win this season comes back.
		var said: Dictionary = recent["said|big_win"] if recent.get("said|big_win") is Dictionary else {}
		if not said.is_empty() and int(said.get("year", -1)) == year and int(said.get("option", -1)) == 1:
			var cb := _q("heavy_loss", "muckraker",
					"After beating %s you said your method was the standard. Where was it today against %s?" % [
					str(said.get("opp", "them")), opp], round_no,
					"The players didn't live up to it.", "One bad day doesn't change it.",
					"The players still believe in it.",
					_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today."))
			cb["qid"] = "heavy_loss.said"
			candidates.append(cb)
		else:
			var goals: Array = res.get("goals", [])
			if goals.size() >= 2 and _turn(asked, "heavy_loss", 2) == 1:
				candidates.append(_q("heavy_loss", "muckraker", "%s kicked %d goals to your %d. Where do you even start?" % [
						opp, int(goals[1 - side]), int(goals[side])], round_no,
						"With the players. Too many dropped their heads.", "With our structure. It let us down.",
						"With belief. This group will respond.",
						_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today."), 1))
			else:
				candidates.append(_q("heavy_loss", "muckraker", "%s beat you by %d. Was that acceptable?" % [opp, -margin],
						round_no, "That was soft from the players.",
						"Our execution let the system down.", "The players will respond.",
						_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today.")))
	elif margin >= 40:
		if _turn(asked, "big_win", 2) == 1:
			candidates.append(_q("big_win", "sycophant", "A %d-point win over %s. Has this side ever looked better?" % [margin, opp],
					round_no, "Some of them got sloppy. Not good enough.", "That's our system done right.",
					"That's all the players. They were superb.",
					_named(named.get("big_win", {}), "back_named", "%s was enormous today."), 1))
		else:
			candidates.append(_q("big_win", "sycophant", "That was a clinic against %s. Is this the best side in the competition?" % opp,
					round_no, "Plenty of it was sloppy.", "Our method's the standard now.",
					"All credit to the players.",
					_named(named.get("big_win", {}), "back_named", "%s was enormous today.")))
	elif absi(margin) <= 6:
		var cq := _q("close_game", "stats", _close_question(res, side, margin, opp), round_no,
				"Too many went missing late.", "That's how tight games go.",
				"The players did everything right.")
		cq["qid"] = _close_qid(res, side, margin)
		candidates.append(cq)

	# A big turn at a quarter break: a comeback won, or a lead let slip.
	var turn := _turnaround(res, side, margin)
	if not turn.is_empty():
		if margin > 0:
			candidates.append(_q("comeback", "stats", "You trailed by %d at %s and won by %d. What changed?" % [
					int(turn["gap"]), str(turn["at"]), margin], round_no,
					"Too many were asleep early. Not good enough.", "We changed the setup at the break.",
					"The players never stopped believing."))
		else:
			candidates.append(_q("blown_lead", "muckraker", "You led by %d at %s and lost by %d. How does that happen?" % [
					int(turn["gap"]), str(turn["at"]), -margin], round_no,
					"Some of them switched off. Not good enough.", "We stopped playing our way. We'll fix it.",
					"They're hurting. They'll learn from it.",
					_named(named.get("heavy_loss", {}), "criticise_named", "%s went missing today.")))

	var star: Dictionary = ctx.get("star", {})
	if not star.is_empty():
		var line := str(star.get("line", "had a huge night"))
		var who := str(star.get("name", "One of your players"))
		if _turn(asked, "star", 2) == 1:
			candidates.append(_q("star", "bogan", "%s %s. Do you just get it to him and stand back?" % [who, line], round_no,
					"Some days it looks that way. That's a worry.", "That's the plan. Our setup feeds him.",
					"No. The blokes around him made it happen.",
					_named(star, "back_named", "%s's the best in the comp."), 1))
		else:
			candidates.append(_q("star", "bogan", "%s %s. Is there a better player in the comp right now?" % [who, line],
					round_no, "Too many others were passengers.", "Our structure set him up.",
					"Credit to him and the whole group.",
					_named(star, "back_named", "%s's the best in the comp.")))

	# The Philosopher's young side comes before the day's other stories (about one
	# conference in six, director ruling).
	var young := int(ctx.get("young", 0))
	if young >= YOUNG_SIDE:
		if _turn(asked, "young_side", 2) == 1:
			candidates.append(_q("young_side", "philosopher",
					"You picked %s players %d or under today. Are you playing for this year or for later?" % [
					MatchNotes.count_word(young), int(YOUNG_AGE)], round_no,
					"This year. They earn spots or lose them.", "Both. We're building a way that lasts.",
					"They're good enough now. That's why they play.",
					_named(named.get("young_side", {}), "criticise_named", "%s has to learn quicker."), 1))
		else:
			candidates.append(_q("young_side", "philosopher",
					"%s of your side today were %d or younger. Is this the club you're building?" % [
					MatchNotes.count_word(young).capitalize(), int(YOUNG_AGE)], round_no,
					"Perform or they'll be dropped.", "We'll wear the bad days for it.",
					"I'm proud of every one of them.",
					_named(named.get("young_side", {}), "criticise_named", "%s has to learn quicker.")))

	# A player's milestone or first game, on the day.
	var ms: Dictionary = ctx.get("milestone", {})
	if not ms.is_empty():
		candidates.append(_q("milestone", "sycophant", "%s played his %s game today. What has he meant to this club?" % [
				str(ms.get("name", "He")), _ordinal(int(ms.get("games", 100)))], round_no,
				"The rest have to match his standards.", "He sets the standard for how we play.",
				"The whole group lifted for him.",
				_named(ms, "back_named", "%s has earned every one of them.")))
	var debut: Dictionary = ctx.get("debut", {})
	if not debut.is_empty():
		candidates.append(_q("debut", "bogan", "%s played his first game today. Do you keep him in the side?" %
				str(debut.get("name", "The new boy")), round_no,
				"The senior blokes let him down today.", "He did the job we picked him for.",
				"The whole group got around him.",
				_named(debut, "back_named", "%s belongs at this level.")))

	var injuries: Array = ctx.get("injuries", [])
	# Asked after a loss only: its answers say the injury cost the game.
	if not injuries.is_empty() and margin < 0:
		var hurt := str(injuries[0].get("name", "a player"))
		if _turn(asked, "injury", 2) == 1:
			candidates.append(_q("injury", "bogan", "Losing %s hurt. Have you got the depth to cover him?" % hurt, round_no,
					"The depth players fell short today.", "We'll cover it with a change of setup.",
					"Our depth will stand up. I trust them.",
					_named(injuries[0], "back_named", "%s will come back better."), 1))
		else:
			candidates.append(_q("injury", "bogan", "Tough blow losing %s. How much did that hurt you out there?" % hurt,
					round_no, "The blokes who came in fell short.", "We had to adjust. That's footy.",
					"That injury cost us the game.",
					_named(injuries[0], "back_named", "%s will come back better.")))

	# The ladder says it was an upset (home-and-away only).
	var my_pos := int(ctx.get("my_pos", 0))
	var opp_pos := int(ctx.get("opp_pos", 0))
	if fin.is_empty() and my_pos > 0 and opp_pos > 0 and round_no >= UPSET_FROM_ROUND:
		if margin < 0 and opp_pos - my_pos >= UPSET_GAP:
			candidates.append(_q("upset_loss", "muckraker", "%s are %s on the ladder and they beat you. Is that embarrassing?" % [
					opp, _ordinal(opp_pos)], round_no,
					"Yes. Some of ours thought it was a gimme.", "Our pressure was off. We'll fix that.",
					"No. They earned it. We'll bounce back."))
		elif margin > 0 and my_pos - opp_pos >= UPSET_GAP:
			candidates.append(_q("upset_win", "stats", "You're %s, %s are %s, and you beat them. Do you read much into it?" % [
					_ordinal(my_pos), opp, _ordinal(opp_pos)], round_no,
					"Not much. Too many of ours were off.", "Yes. The plan works against anyone.",
					"Yes. It shows what this group can do."))

	# A run of results, asked as it reaches a length worth a headline.
	var lost_run := int(ctx.get("losing_run", 0))
	var won_run := int(ctx.get("winning_run", 0))
	if margin < 0 and lost_run >= LOSING_RUN_AT and (lost_run - LOSING_RUN_AT) % 2 == 0:
		candidates.append(_q("losing_run", "muckraker", "That's %s losses in a row. Is the message still getting through?" %
				MatchNotes.count_word(lost_run), round_no,
				"Some aren't doing what's asked of them.", "The plan's right. We're not executing it.",
				"Yes. This group hasn't stopped working.",
				_named(named.get("heavy_loss", {}), "criticise_named", "%s has to lift, starting now.")))
	elif margin > 0 and won_run >= WINNING_RUN_AT and (won_run - WINNING_RUN_AT) % 2 == 0:
		candidates.append(_q("winning_run", "sycophant", "That's %s wins in a row. Can anyone stop this side?" %
				MatchNotes.count_word(won_run), round_no,
				"We've got away with some sloppy footy.", "We're winning because the plan works.",
				"The players deserve every bit of it.",
				_named(named.get("big_win", {}), "back_named", "%s has driven this run.")))

	# Lost with as many shots at goal: the kicking.
	var gl: Array = res.get("goals", [])
	var bh: Array = res.get("behinds", [])
	if margin < 0 and gl.size() >= 2 and bh.size() >= 2 and int(bh[side]) > int(gl[side]) \
			and int(gl[side]) + int(bh[side]) >= int(gl[1 - side]) + int(bh[1 - side]):
		candidates.append(_q("wayward", "stats", "You kicked %d.%d and lost by %d. Is goal kicking costing you games?" % [
				int(gl[side]), int(bh[side]), -margin], round_no,
				"Our forwards have to kick straighter.", "We're creating the shots. They'll come.",
				"They'll kick them next week. I back them."))

	# Not every ordinary match earns a conference. A notable factual trigger is required.
	var last_any := -999
	for k in recent:
		var v = recent[k]
		if v is Dictionary and v.has("round") and int(v.get("year", -1)) == year:
			last_any = maxi(last_any, int(v["round"]))
	for q in candidates:
		var key := str(q["key"])
		var last = recent.get(key, -999)
		# {"year", "round"}: rounds restart each season, so last year's ask is off cooldown.
		if last is Dictionary:
			last = int(last.get("round", -999)) if int(last.get("year", 0)) == int(ctx.get("year", 0)) else -999
		if typeof(last) != TYPE_INT and typeof(last) != TYPE_FLOAT:
			last = -999
		# A story of the day (a milestone, a run, an upset) is not asked the week
		# after a conference: fewer, weightier pressers.
		if key in STORY_KEYS and round_no - last_any < STORY_GAP:
			continue
		var wait := YOUNG_SIDE_COOLDOWN if key == "young_side" else COOLDOWN_ROUNDS
		if round_no - int(last) > wait:
			# A young side moves the odds of every answer (see chance()).
			q["young"] = young
			# The result, so a lift after a loss can be held under a win's.
			q["margin"] = margin
			return q
	return {}


## Which written version of a question comes up: they take turns by how often
## the question has been asked this career.
static func _turn(asked: Dictionary, key: String, versions: int) -> int:
	return int(asked.get(key, 0)) % maxi(1, versions)


## The biggest turn at a quarter break against the result: {"gap", "at"} when
## you won from TURN_GAP or more down, or lost from TURN_GAP or more up; else {}.
static func _turnaround(res: Dictionary, side: int, margin: int) -> Dictionary:
	var qs: Array = res.get("quarters", [])
	if margin == 0 or qs.size() < 4:
		return {}
	var run := 0
	var best := {}
	for i in range(BREAKS.size()):
		var q: Array = qs[i]
		run += int(q[side]) - int(q[1 - side])
		var gap := -run if margin > 0 else run
		if gap >= TURN_GAP and gap > int(best.get("gap", 0)):
			best = {"gap": gap, "at": BREAKS[i]}
	return best


## Which of the Stats Geek's close-game questions _close_question wrote.
static func _close_qid(res: Dictionary, side: int, margin: int) -> String:
	if margin == 0:
		return "close_game.draw"
	var teams: Array = res.get("team", [])
	if teams.size() >= 2:
		for k in ["inside50", "clearances"]:
			var a := int((teams[side] as Dictionary).get(k, 0))
			var b := int((teams[1 - side] as Dictionary).get(k, 0))
			if margin < 0 and a - b >= STAT_GAP:
				return "close_game.won_%s_lost" % k
			if margin > 0 and b - a >= STAT_GAP:
				return "close_game.lost_%s_won" % k
	if (res.get("goals", []) as Array).size() >= 2 and (res.get("behinds", []) as Array).size() >= 2:
		return "close_game.shots"
	return "close_game.late"


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
		"both": {1: "The board likes it either way", 0: "The board shrugs either way", -1: "The board frowns on it either way"},
		"a": {"board": 1, "morale": 1, "his": 0, "odds": "their resolve tightens", "after": "The players' resolve tightened"},
		"b": {"board": 1, "morale": -2, "his": 0, "odds": "they feel hung out to dry", "after": "The players felt hung out to dry"}},
	"method": {"base": 50, "pull": 0, "young": 0, "result": {"heavy_loss": -15, "big_win": 15},
		"both": {1: "The players read nothing into it", 0: "The players read nothing into it", -1: "The players read nothing into it"},
		"a": {"board": 1, "morale": 0, "his": 0, "odds": "the board buys it", "after": "The board bought it"},
		"b": {"board": -1, "morale": 0, "his": 0, "odds": "the board hears excuses", "after": "The board heard excuses"}},
	"back": {"base": 60, "pull": -1, "young": 10, "result": {},
		"both": {1: "The board likes it either way", 0: "The board shrugs either way", -1: "The board wanted accountability either way"},
		"a": {"board": -1, "morale": 2, "his": 0, "odds": "the players lift", "after": "The players lifted"},
		"b": {"board": -1, "morale": -1, "his": 0, "odds": "it rings hollow with them", "after": "It rang hollow with the players"}},
	"back_named": {"base": 60, "pull": -1, "young": 0, "result": {},
		"both": {0: "No one else's morale moves, and the board reads nothing into it"},
		"a": {"board": 0, "morale": 0, "his": 2, "odds": "%s grows another leg", "after": "%s grew another leg"},
		"b": {"board": 0, "morale": 0, "his": -1, "odds": "the spotlight weighs on %s", "after": "The spotlight weighed on %s"}},
	"criticise_named": {"base": 45, "pull": 1, "young": -15, "result": {},
		"both": {0: "No one else's morale moves, and the board reads nothing into it"},
		"a": {"board": 0, "morale": 0, "his": 1, "odds": "%s's resolve tightens", "after": "%s's resolve tightened"},
		"b": {"board": 0, "morale": 0, "his": -3, "odds": "%s takes it personally", "after": "%s took it personally"}},
}

## The five journalists' personalities (director 2026-11-06: personality
## changes what an answer does, shown openly on the gate). "likes" and
## "dislikes" move your standing with him by one; "odds" moves outcome "a";
## "board_up" adds one to every board size (to the cap), "named_up" one to
## every named size (to the cap), "slow" makes the morale fade at half pace;
## "record" means the record check decides his standing and odds.
const PERSONA := {
	"muckraker": {"likes": ["criticise", "criticise_named"], "dislikes": ["back", "back_named"],
		"odds": {"criticise": -10, "criticise_named": -10}, "odds_note": "The players read his headline",
		"board_up": true, "board_note": "The Siren gets read upstairs"},
	"sycophant": {"likes": ["back", "back_named"], "dislikes": ["criticise"],
		"odds": {"back": -5, "back_named": -5}, "odds_note": "Praise after a thumping is what everyone expects"},
	"stats": {"likes": [], "dislikes": [], "odds": {}, "record": true},
	"bogan": {"likes": ["back"], "dislikes": ["method"], "odds": {},
		"named_up": true, "named_note": "The players listen to his show"},
	"philosopher": {"likes": ["method"], "dislikes": ["criticise", "criticise_named"], "odds": {},
		"slow": true, "slow_note": "Her piece lingers: the players' moves wear off a point every second round"},
}

## Standing with each journalist, -2..+2 (director 2026-11-06, Q1): each step
## moves outcome "a" of every answer to him by this much, and fades one step a
## season.
const STANDING_MIN := -2
const STANDING_MAX := 2
const STANDING_ODDS := 5
## How he stands with you, after his name ("Gary is warm to you").
const STANDING_WORDS := {-2: "has it in for you", -1: "is cool on you", 0: "takes you as %s finds you",
		1: "is warm to you", 2: "is in your corner"}
## Under the byline: "Gary is warm to you: every answer is 5% more likely to land well."
const STANDING_EFFECT := "%s %s: every answer is %d%% %s likely to land well."
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
## The same, as a reason on the gate: "The record backs this: 10% more likely
## to land well."
const RECORD_REASON := {"supported": "The record backs this", "contradicted": "The record says otherwise"}
const RECORD_BOARD_NOTE := "the board reads Ladder Watch"

## The group's (or the named player's) morale against the settled line moves
## the odds by half a point per point, at most this far either way.
const MORALE_WEIGHT := 0.5
const MORALE_CAP := 10.0
## Odds are shown in steps of five, never a sure thing.
const ODDS_STEP := 5
const ODDS_MIN := 20
const ODDS_MAX := 80
## Every press move (morale and the board) fades a point a round; the
## Philosopher's morale moves a point every second round.
const FADE_ROUNDS := 1
const SLOW_FADE_ROUNDS := 2

## The gate's templates: no digits here, every number comes from the tables.
const ODDS_TEMPLATE := "%d%% %s (%s), %d%% %s (%s). %s."
const MORALE_SIZE := "%+d%% morale"
const HIS_SIZE := "%+d%% %s's morale"
const BOARD_SIZE := "%+d%% confidence"
const NO_BOARD := "confidence unchanged"
const AFTER_MORALE := "morale %+d%% across the list"
const AFTER_HIS := "%s's morale %+d%%"
const AFTER_BOARD := "board confidence %+d%%"
## One odds twist on the gate: "After a heavy loss: 15% less likely to land well."
const REASON := "%s: %d%% %s likely to land well."
const FADE_NOTE := "These moves wear off a point a round."
const SLOW_FADE_NOTE := "The board's move wears off a point a round."
## Your standing with him moves: what that does to his later questions.
const LIKES := "%s will like that: answers to %s land well %d%% more often after it."
const DISLIKES := "%s won't like that: answers to %s land well %d%% less often after it."


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
			out.append({"pct": int(s["young"]), "why": "%s is still young" % name})
	elif int(facts.get("young", 0)) >= YOUNG_SIDE and int(s["young"]) != 0:
		out.append({"pct": int(s["young"]), "why": "It's a young side"})
	var j: Dictionary = PERSONA.get(str(facts.get("journalist", "")), {})
	var jo := int((j.get("odds", {}) as Dictionary).get(kind, 0))
	if jo != 0:
		out.append({"pct": jo, "why": str(j.get("odds_note", ""))})
	var key := str(facts.get("key", ""))
	var r := int((s["result"] as Dictionary).get(key, 0))
	if r != 0:
		out.append({"pct": r, "why": "After a heavy loss" if key == "heavy_loss" else "After a big win"})
	var verdict := str(facts.get("verdict", ""))
	if RECORD_REASON.has(verdict):
		out.append({"pct": RECORD_ODDS if verdict == "supported" else -RECORD_ODDS, "why": str(RECORD_REASON[verdict])})
	return out


## "After a heavy loss: 15% less likely to land well."
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
			o["odds"] = str(o["odds"]) % name
			o["after"] = str(o["after"]) % name
		out[w] = o
	var a: Dictionary = out["a"]
	var b: Dictionary = out["b"]
	var shared := signi(int(a["board"])) if int(a["board"]) == int(b["board"]) else 0
	var both: Dictionary = s["both"]
	out["both"] = str(both.get(shared, both.get(0, "")))
	var notes: Array = out["notes"]
	if bool(j.get("board_up", false)) and int((s["a"] as Dictionary)["board"]) != int((s["b"] as Dictionary)["board"]):
		notes.append(str(j["board_note"]))
	if bool(j.get("named_up", false)) and is_named(kind):
		notes.append(str(j["named_note"]))
	if verdict == "contradicted":
		notes.append(_cap_first(RECORD_BOARD_NOTE))
	return out


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


## "is warm to you", after his first name.
static func standing_word(v: int, journalist := "") -> String:
	var w := str(STANDING_WORDS.get(clampi(v, STANDING_MIN, STANDING_MAX), ""))
	return w % ("she" if is_woman(journalist) else "he") if w.contains("%s") else w


## "Gary is warm to you: every answer is 5% more likely to land well."; ""
## when he takes you as he finds you.
static func standing_effect(journalist: String, v: int) -> String:
	if v == 0:
		return ""
	return STANDING_EFFECT % [first_name(journalist), standing_word(v, journalist), absi(v) * STANDING_ODDS,
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


## How many rounds a press lift of this size takes to fade (fade_lift steps a
## slow lift every second round counted from the presser, so this is exact).
static func fade_rounds(size: int, slow: bool) -> int:
	return absi(size) * (SLOW_FADE_ROUNDS if slow else FADE_ROUNDS)


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
## sizes, the lever that moves the same either way (bible §4), then what the
## journalist and the record make of it, and how your standing with him moves.
## `fx` is effects() (the base answer when empty); `ctx` {"journalist",
## "verdict", "name"}.
static func odds_line(kind: String, chance_a: int, fx: Dictionary = {}, ctx: Dictionary = {}) -> String:
	if fx.is_empty():
		fx = effects(kind, ctx)
	var a: Dictionary = fx["a"]
	var b: Dictionary = fx["b"]
	var name := str(ctx.get("name", "his"))
	var both := str(fx["both"])
	var shared := _shared_size(a, b, name)
	if shared != "":
		both += " (%s)" % shared
	var line: String = ODDS_TEMPLATE % [chance_a, str(a["odds"]), _sizes(a, b, name), 100 - chance_a, str(b["odds"]),
			_sizes(b, a, name), both]
	for n in fx.get("notes", []):
		line += " %s." % str(n)
	var journalist := str(ctx.get("journalist", ""))
	var verdict := str(ctx.get("verdict", ""))
	# Every twist in the odds, named (director 2026-11-06: shown openly).
	var facts: Dictionary = ctx.get("facts", {})
	if not facts.is_empty():
		for part in chance_parts(kind, facts):
			line += " " + reason_line(part)
	elif RECORD_REASON.has(verdict):
		line += " " + reason_line({"pct": RECORD_ODDS if verdict == "supported" else -RECORD_ODDS,
				"why": RECORD_REASON[verdict]})
	# How long it lasts is part of its size.
	var any_move := false
	var players_move := false
	for w in ["a", "b"]:
		var o: Dictionary = fx[w]
		any_move = any_move or int(o["board"]) != 0 or int(o["morale"]) != 0 or int(o["his"]) != 0
		players_move = players_move or int(o["morale"]) != 0 or int(o["his"]) != 0
	var slow := bool((PERSONA.get(journalist, {}) as Dictionary).get("slow", false))
	if any_move:
		if slow and players_move:
			line += " " + str(PERSONA[journalist]["slow_note"]) + "."
			if int(a["board"]) != 0 or int(b["board"]) != 0:
				line += " " + SLOW_FADE_NOTE
		else:
			line += " " + FADE_NOTE
	var now := int(ctx.get("standing", 0))
	var move := standing_after(now, standing_move(journalist, kind, verdict)) - now if journalist != "" else 0
	var pron := "her" if is_woman(journalist) else "him"
	if move > 0:
		line += " " + LIKES % [first_name(journalist), pron, STANDING_ODDS]
	elif move < 0:
		line += " " + DISLIKES % [first_name(journalist), pron, STANDING_ODDS]
	return line


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


## One round's fade of a player's press lift: a point back toward where he was,
## every round (every second round after the Philosopher). True when it moved.
static func fade_lift(p: Dictionary, _round_no: int) -> bool:
	var lift := int(p.get("press_lift", 0))
	if lift == 0:
		return false
	# A slow lift waits every other round, counted from when it was set.
	if bool(p.get("press_slow", false)):
		if not bool(p.get("press_wait", false)):
			p["press_wait"] = true
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
static func _sizes(o: Dictionary, other: Dictionary, name: String) -> String:
	var bits: PackedStringArray = []
	if int(o["morale"]) != int(other["morale"]):
		bits.append(MORALE_SIZE % int(o["morale"]))
	if int(o["his"]) != int(other["his"]):
		bits.append(HIS_SIZE % [int(o["his"]), name])
	if int(o["board"]) != int(other["board"]):
		bits.append(BOARD_SIZE % int(o["board"]) if int(o["board"]) != 0 else NO_BOARD)
	return ", ".join(bits)


## The size both outcomes share (the same move either way), or "".
static func _shared_size(a: Dictionary, b: Dictionary, name: String) -> String:
	var bits: PackedStringArray = []
	if int(a["morale"]) == int(b["morale"]) and int(a["morale"]) != 0:
		bits.append(MORALE_SIZE % int(a["morale"]))
	if int(a["his"]) == int(b["his"]) and int(a["his"]) != 0:
		bits.append(HIS_SIZE % [int(a["his"]), name])
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
		tactical: String, protective: String, named: Dictionary = {}, version := 0) -> Dictionary:
	var opts := [
		{"label": accountable, "kind": "criticise"},
		{"label": tactical, "kind": "method"},
		{"label": protective, "kind": "back"},
	]
	# The fourth answer, about one named player (director 2026-11-06, Q3).
	if not named.is_empty() and str(named.get("id", "")) != "":
		opts.append({"label": str(named["label"]), "kind": str(named["kind"]), "player": str(named["id"]),
				"name": str(named.get("name", "him"))})
	# "qid": which written question this is, before names and numbers fill it.
	return {"key": key, "qid": "%s.%d" % [key, version], "round": round_no, "question": question,
		"journalist": journalist, "by": byline(journalist), "options": opts}
