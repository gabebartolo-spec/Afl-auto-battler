class_name SkipOrders
extends RefCounted
## The survey before the season skip (row 70, bible T5.Q20; director,
## 2026-11-07: "I do want the survey"; 2026-11-08: "It's just skipping games,
## no off season skipping"). The skip plays out only the rest of the season's
## matches, so the survey asks only about them. The coach answers a short run
## of questions and the skip follows each answer (GameState.skip_season):
##   game_plan  the standing plan every match is played with (set_club_plan)
##   youth      selection: best side, or promised runs for players with few
##              senior games (Backing, through auto-pick)
##   questions  how the week's cards are answered while he is away
## Each option says what it does for him and what it costs, never which is
## better (bible principle 4). Pure rules and words; GameState applies them.

## Promised runs kept going at once under "Give the kids a run".
const YOUTH_RUNS := 2
const KEYS := ["game_plan", "youth", "questions"]
## Each question in a word or two, for the sheet that sums up your answers.
const SHORT := {"game_plan": "Game plan", "youth": "Selection", "questions": "Questions during the week"}


## The answers the survey opens on: the club's plan as it stands, and for the
## rest what the skip does when nobody asks (so a straight run of Next changes
## nothing the club already does).
static func defaults(club_plan: String) -> Dictionary:
	return {"game_plan": club_plan, "youth": "form", "questions": "usual"}


## The questions in order: {"key", "title", "lead", "options": [{"key",
## "label", "gain", "cost"}]}.
static func questions() -> Array:
	var plans := []
	for k in ["balanced", "attacking", "defensive", "contest", "controlled"]:
		var part: Dictionary = CoachReport.PLAN_PARTS[k]
		var gain := str(part.get("gain", ""))
		var cost := str(part.get("cost", ""))
		if k == "balanced":
			gain = "Nothing for them to exploit."
			cost = "No extra edge."
		plans.append({"key": k, "label": str(CoachReport.PLAN_NAMES[k]), "gain": gain, "cost": cost})
	return [
		{"key": "game_plan", "title": "How do we play?",
			"lead": "Your game plan for every match left this season.", "options": plans},
		{"key": "youth", "title": "Who gets picked?",
			"lead": "Selection, every week you are away.", "options": [
				{"key": "form", "label": "Best side on form",
					"gain": "Your best available 23 every week.",
					"cost": "Young players only play when they force their way in."},
				{"key": "kids", "label": "Give the kids a run",
					"gain": "%s players with fewer than %d senior games are promised a run of %d games at a time, and get the match experience." % [
						"Two", Backing.FEW_GAMES, Backing.RUN_GAMES],
					"cost": "Seasoned players sit out for them, so the side is weaker some weeks. Auto-pick replaces a side you named."},
			]},
		{"key": "questions", "title": "Questions during the week",
			"lead": "The cards that come up while you are away.", "options": [
				{"key": "usual", "label": "The club's usual answer",
					"gain": "No new promises made in your name.",
					"cost": "A card with no usual answer goes unanswered, which can cost the board's confidence or a player's trust."},
				{"key": "players", "label": "Back the players",
					"gain": "Each card answered the way that does most for the players' mood and trust.",
					"cost": "The board's confidence can slip."},
				{"key": "board", "label": "Keep the board onside",
					"gain": "Each card answered the way that does most for the board's confidence.",
					"cost": "Players' mood and trust can slip."},
			]},
	]


## The label of answer `key` to question `q`.
static func label(qs: Array, q: String, key: String) -> String:
	for qd in qs:
		if str(qd["key"]) != q:
			continue
		for o in qd["options"]:
			if str(o["key"]) == key:
				return str(o["label"])
	return ""


## Which option of a week's card the "questions" answer picks, or -1 to leave
## it to the club's usual way. "players" weighs what each option does to the
## players' mood and trust (and half their development); "board" what it does
## to the board's confidence. A tie goes to the card's usual answer, then to
## the first option.
static func card_choice(card: Dictionary, policy: String) -> int:
	if policy != "players" and policy != "board":
		return -1
	var opts: Array = card.get("options", [])
	if opts.is_empty():
		return -1
	var dflt := int(card.get("default", -1))
	var best := -1
	var best_score := -INF
	for i in range(opts.size()):
		var s := option_score(opts[i] as Dictionary, policy)
		var better := s > best_score or (s == best_score and i == dflt)
		if better:
			best = i
			best_score = s
	return best


static func option_score(o: Dictionary, policy: String) -> float:
	var s := 0.0
	for e in o.get("effects", []):
		var op := str((e as Dictionary).get("op", ""))
		var d := float((e as Dictionary).get("d", 0))
		if policy == "board":
			if op == "board":
				s += d
		elif op == "morale" or op == "trust":
			s += d
		elif op == "xp":
			s += d * 0.5
	return s
