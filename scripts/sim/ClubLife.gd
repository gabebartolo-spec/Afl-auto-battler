class_name ClubLife
extends RefCounted
## The club around the team: the board's expectations, player morale and the
## weekly event card. Pure rules; GameState keeps the state and applies them.
##
## Board: each season the board sets a goal from where your list ranks
## (a top-four list must finish top four; a bottom list must win seven).
## Results move its confidence (0-100). Miss the goal and it drops sharply;
## finish a season under WARN_LINE and you get a final warning, do it again
## and you are sacked.
##
## Morale (0-100, 70 is settled): playing and winning lift it, being left out
## while fit drags it down - stars most. It nudges match form (+/-3%) and an
## unhappy player asks 25% more to re-sign.

const START_CONFIDENCE := 60
const WARN_LINE := 30
const MORALE_BASE := 70
const EVENT_CHANCE := 0.7


static func board_goal(rank: int) -> Dictionary:
	if rank <= 4:
		return {"key": "top4", "text": "Finish in the top four", "pos": 4}
	if rank <= 9:
		return {"key": "finals", "text": "Make the finals", "pos": 8}
	if rank <= 14:
		return {"key": "top12", "text": "Finish in the top 12", "pos": 12}
	return {"key": "wins7", "text": "Win at least 7 games", "wins": 7}


static func goal_met(goal: Dictionary, position: int, wins: int) -> bool:
	if goal.has("wins"):
		return wins >= int(goal["wins"])
	return position <= int(goal.get("pos", 18))


## Confidence after one of your matches (margin from your side).
static func after_match(confidence: int, margin: int) -> int:
	var d := 0
	if margin > 0:
		d = 3 + (1 if margin >= 40 else 0)
	elif margin < 0:
		d = -3 - (1 if margin <= -40 else 0)
	return clampi(confidence + d, 0, 100)


## Confidence after the season: goal met or missed, a flag on top.
static func after_season(confidence: int, met: bool, premier: bool) -> int:
	var c := confidence + (20 if met else -25)
	if premier:
		c += 30
	return clampi(c, 0, 100)


static func morale(p: Dictionary) -> int:
	return int(p.get("morale", MORALE_BASE))


static func add_morale(p: Dictionary, d: int) -> void:
	p["morale"] = clampi(morale(p) + d, 5, 100)


## After your match: who played gets a lift (more for a win), a fit player
## left out loses some - a star left out loses more.
static func morale_after_match(list: Array, played: Dictionary, won: bool) -> void:
	for p in list:
		var id := str(p["id"])
		if played.has(id):
			add_morale(p, 2 + (2 if won else 0) - (0 if won else 1))
		elif int(p.get("injury_weeks", 0)) <= 0:
			add_morale(p, -6 if int(p.get("overall", 0)) >= 78 else -3)
		else:
			# Injured players drift back toward settled.
			add_morale(p, signi(MORALE_BASE - morale(p)))


static func mood(m: int) -> String:
	if m >= 85:
		return "Flying"
	if m >= 65:
		return "Settled"
	if m >= 40:
		return "Flat"
	return "Unhappy"


## Match-form nudge from morale: +3% at 100, -3% at 40 and below.
static func form(p: Dictionary) -> float:
	return clampf(float(morale(p) - MORALE_BASE) / 1000.0, -0.03, 0.03)


## This week's event for your club, or {} (about 30% of weeks are quiet).
## `ctx`: list, round, seed, losses (current losing streak), selected (ids
## in this week's side).
static func pick_event(ctx: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("event|%d|%d" % [int(ctx.get("seed", 0)), int(ctx.get("round", 0))])
	if rng.randf() >= EVENT_CHANCE:
		return {}
	var list: Array = ctx.get("list", [])
	var selected: Dictionary = ctx.get("selected", {})
	var fit := []
	for p in list:
		if int(p.get("injury_weeks", 0)) <= 0:
			fit.append(p)
	fit.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var pool := []
	if fit.size() >= 5:
		pool.append(_sore_star(fit[rng.randi_range(0, 4)]))
	pool.append(_training())
	pool.append(_fans())
	var worst := {}
	for p in fit:
		if selected.has(str(p["id"])) and (worst.is_empty() \
				or int(p["attr"]["discipline"]) < int(worst["attr"]["discipline"])):
			worst = p
	if not worst.is_empty() and int(worst["attr"]["discipline"]) <= 40:
		pool.append(_media(worst))
	for p in fit:
		if int(p.get("contract_years", 2)) <= 1 and int(p["overall"]) >= 72:
			pool.append(_extension(p))
			break
	if int(ctx.get("losses", 0)) >= 3:
		pool.append(_pressure())
	for p in fit:
		if float(p.get("age", 30.0)) <= 21.0 and int(p.get("potential", 0)) >= int(p["overall"]) + 8 \
				and not selected.has(str(p["id"])):
			pool.append(_young_gun(p))
			break
	for p in list:
		if morale(p) < 35:
			pool.append(_unhappy(p))
			break
	var e: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	e["round"] = int(ctx.get("round", 0))
	return e


static func _opt(key: String, label: String, detail: String) -> Dictionary:
	return {"key": key, "label": label, "detail": detail}


static func _sore_star(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "sore_star", "player_id": str(p["id"]), "default": 1,
		"title": "%s pulled up sore" % n,
		"text": "The physio says he can play, but it is a risk.",
		"options": [
			_opt("rest", "Rest him this week", "He misses the game and is a little flat about it."),
			_opt("play", "Play him", "Four times his usual injury risk this week."),
		]}


static func _training() -> Dictionary:
	return {"key": "training", "default": 2,
		"title": "Coaches want an extra session",
		"text": "A heavy week on the track, or a week to freshen up?",
		"options": [
			_opt("heavy", "Heavy session", "+12 XP for everyone, but they start the game on 88% legs."),
			_opt("recover", "Recovery week", "Everyone's morale lifts (+4)."),
			_opt("normal", "Normal week", "No change."),
		]}


static func _fans() -> Dictionary:
	return {"key": "fans", "default": 1,
		"title": "Members want an open training day",
		"text": "The fans would love it. The coaches would rather work.",
		"options": [
			_opt("open", "Open the doors", "Morale +3 for everyone and the board is pleased (+2)."),
			_opt("closed", "Closed session", "+6 XP for everyone."),
		]}


static func _media(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "media", "player_id": str(p["id"]), "default": 1,
		"title": "%s is in the papers" % n,
		"text": "An off-field incident. The board is watching how you handle it.",
		"options": [
			_opt("suspend", "Suspend him for a week", "He misses this game; the board approves (+4); his morale drops."),
			_opt("back", "Back your player", "His morale lifts (+8); the board is unimpressed (-4)."),
		]}


static func _extension(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "extension", "player_id": str(p["id"]), "default": 1,
		"title": "%s wants to talk contract" % n,
		"text": "He is out of contract at season's end and wants security now.",
		"options": [
			_opt("extend", "Extend him now (2 more seasons)", "10% above his asking price if the cap allows; his morale lifts."),
			_opt("wait", "Wait for the off-season", "He is disappointed (morale -8)."),
		]}


static func _pressure() -> Dictionary:
	return {"key": "pressure", "default": 1,
		"title": "The board wants answers",
		"text": "Three losses in a row. The chairman asks what happens next.",
		"options": [
			_opt("promise", "Promise a win this week", "Win and the board is won over (+8); lose and it is -10."),
			_opt("patience", "Ask for patience", "Confidence -3."),
		]}


static func _young_gun(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "young_gun", "player_id": str(p["id"]), "default": 1,
		"title": "%s is pushing for games" % n,
		"text": "The kid is flying at training and wants a senior game.",
		"options": [
			_opt("develop", "Extra development session", "+40 XP for him and a morale lift."),
			_opt("wait", "Tell him to be patient", "His morale drops (-10)."),
		]}


static func _unhappy(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "unhappy", "player_id": str(p["id"]), "default": 1,
		"title": "%s is unhappy" % n,
		"text": "He feels he is being overlooked. Unhappy players play below their best and cost more to re-sign.",
		"options": [
			_opt("talk", "Sit down with him", "Morale +15."),
			_opt("earn", "Tell him to earn it", "Morale -5; the group respects the standard."),
		]}
