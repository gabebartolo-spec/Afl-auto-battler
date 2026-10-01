class_name MediaConference
extends RefCounted
## Post-match press conference rules. Questions come only from facts in the
## completed match/season. Consequences are deliberately smaller than results.

const COOLDOWN_ROUNDS := 3

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
	var candidates := []

	var injuries: Array = ctx.get("injuries", [])
	if not injuries.is_empty():
		candidates.append(_q("injury", "You lost %s during the game. How much did that affect the result?" %
				str(injuries[0].get("name", "a player")), round_no,
				"We won't use it as an excuse.", "The group had to adjust, but that's footy.",
				"It clearly hurt us. We'll look after him."))
	if margin <= -40:
		candidates.append(_q("heavy_loss", "That was a heavy loss to %s. What concerned you most?" % opp, round_no,
				"We own it. That wasn't our standard.", "The system held up in patches; our execution didn't.",
				"I'll back the players to respond."))
	elif margin >= 40:
		candidates.append(_q("big_win", "You controlled that game against %s. How much can you take from it?" % opp, round_no,
				"Plenty, but it's one game.", "Our method stood up. That's the standard.",
				"The players deserve the credit."))
	elif absi(margin) <= 6:
		candidates.append(_q("close_game", "It came down to the last few minutes against %s. What decided it?" % opp, round_no,
				"Our composure in the big moments.", "A handful of contests. That's how tight games go.",
				"I loved the way the players stayed in it."))

	var star: Dictionary = ctx.get("star", {})
	if not star.is_empty():
		var line := str(star.get("line", "had a huge night"))
		candidates.append(_q("star", "%s %s. How important was his performance?" %
				[str(star.get("name", "One of your players")), line], round_no,
				"He was excellent, but it was a team performance.", "We put him in positions to influence the game.",
				"He stood up when we needed him."))

	# Not every ordinary match earns a conference. A notable factual trigger is required.
	for q in candidates:
		var key := str(q["key"])
		var last := int(recent.get(key, -999))
		if round_no - last > COOLDOWN_ROUNDS:
			return q
	return {}


static func _q(key: String, question: String, round_no: int, accountable: String,
		tactical: String, protective: String) -> Dictionary:
	return {
		"key": key, "round": round_no, "question": question,
		"options": [
			{"label": accountable, "board": 1, "morale": -1},
			{"label": tactical, "board": 0, "morale": 0},
			{"label": protective, "board": -1, "morale": 1},
		]
	}
