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
				"We won't use it as an excuse.", "The group had to adjust, but that's footy.",
				"It clearly hurt us. We'll look after him."))
	if margin <= -40:
		# What you told the Sycophant after a big win this season comes back.
		var said: Dictionary = recent["said|big_win"] if recent.get("said|big_win") is Dictionary else {}
		if not said.is_empty() and int(said.get("year", -1)) == year and int(said.get("option", -1)) == 1:
			candidates.append(_q("heavy_loss", "muckraker",
					"After beating %s you said your method was the standard. Where was it today against %s?" % [
					str(said.get("opp", "them")), opp], round_no,
					"Fair question. It wasn't there today.", "One bad day doesn't change the method.",
					"Ask the players whether they believe in it. They do."))
		else:
			candidates.append(_q("heavy_loss", "muckraker", "%s beat you by %d. Was that acceptable?" % [opp, -margin],
					round_no, "We own it. That wasn't our standard.",
					"The system held up in patches; our execution didn't.", "I'll back the players to respond."))
	elif margin >= 40:
		candidates.append(_q("big_win", "sycophant", "That was a clinic against %s. Is this the best side in the competition?" % opp,
				round_no, "Plenty to like, but it's one game.", "Our method stood up. That's the standard.",
				"The players deserve the credit."))
	elif absi(margin) <= 6:
		candidates.append(_q("close_game", "stats", _close_question(res, side, margin, opp), round_no,
				"Our composure in the big moments.", "A handful of contests. That's how tight games go.",
				"I loved the way the players stayed in it."))

	var star: Dictionary = ctx.get("star", {})
	if not star.is_empty():
		var line := str(star.get("line", "had a huge night"))
		candidates.append(_q("star", "bogan", "%s %s. Is there a better player in the comp right now?" %
				[str(star.get("name", "One of your players")), line], round_no,
				"He was excellent, but it was a team performance.", "We put him in positions to influence the game.",
				"He stood up when we needed him."))

	var young := int(ctx.get("young", 0))
	if young >= YOUNG_SIDE:
		candidates.append(_q("young_side", "philosopher",
				"%s of your side today were %d or younger. Is this the club you're building?" % [
				MatchNotes.count_word(young).capitalize(), int(YOUNG_AGE)], round_no,
				"They're in on merit, not on age.", "It's where the club is going, and we'll wear the bad days.",
				"They've earned it. I'm proud of them."))

	# Not every ordinary match earns a conference. A notable factual trigger is required.
	for q in candidates:
		var key := str(q["key"])
		var last = recent.get(key, -999)
		if typeof(last) != TYPE_INT and typeof(last) != TYPE_FLOAT:
			last = -999
		if round_no - int(last) > COOLDOWN_ROUNDS:
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


## What an answer does, in football words and no numbers, shown under its
## button (director, 2026-10-10: the effects stay, and the player sees them).
## Read from the answer's own "board" and "morale", so the line can never
## drift from what resolve_media_conference applies.
static func effect_line(option: Dictionary) -> String:
	var board := int(option.get("board", 0))
	var morale := int(option.get("morale", 0))
	if board > 0 and morale < 0:
		return "The board likes it; the players feel hung out to dry."
	if board < 0 and morale > 0:
		return "The players feel backed; the board wanted accountability."
	if board > 0:
		return "The board likes it."
	if board < 0:
		return "The board wanted more accountability."
	if morale > 0:
		return "The players feel backed."
	if morale < 0:
		return "The players feel hung out to dry."
	return "Neither the board nor the players read much into it."


static func _q(key: String, journalist: String, question: String, round_no: int, accountable: String,
		tactical: String, protective: String) -> Dictionary:
	return {
		"key": key, "round": round_no, "question": question, "journalist": journalist,
		"by": byline(journalist),
		"options": [
			{"label": accountable, "board": 1, "morale": -1},
			{"label": tactical, "board": 0, "morale": 0},
			{"label": protective, "board": -1, "morale": 1},
		]
	}
