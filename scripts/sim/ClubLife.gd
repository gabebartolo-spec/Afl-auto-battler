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
	if rank <= Season.FINALISTS:
		return {"key": "finals", "text": "Make the finals", "pos": Season.FINALISTS}
	if rank <= 14:
		return {"key": "top12", "text": "Finish in the top 12", "pos": 12}
	return {"key": "wins7", "text": "Win at least 7 games", "wins": 7}


static func goal_met(goal: Dictionary, position: int, wins: int) -> bool:
	if goal.has("wins"):
		return wins >= int(goal["wins"])
	return position <= int(goal.get("pos", 18))


## How one result moves the board, by what the season's goal asks: a side
## expected to finish top four gains little for a win and loses more for a
## loss; a side asked to win seven games, the other way round. [win, loss].
const GOAL_STEPS := {"top4": [2, -3], "finals": [2, -2], "top12": [2, -2], "wins7": [3, -1]}
## Losses in a row before the board starts to count them extra.
const RESTLESS_AFTER := 3


static func goal_steps(goal: Dictionary) -> Array:
	return GOAL_STEPS.get(str(goal.get("key", "")), [2, -2])


## Confidence after one of your matches (margin from your side), weighed
## against what the goal needs. A thrashing either way counts one extra, and
## a long losing run starts to tell. {"confidence", "delta"}.
static func after_match(confidence: int, margin: int, steps := [2, -2], losses_in_row := 0) -> Dictionary:
	var d := 0
	if margin > 0:
		d = int(steps[0]) + (1 if margin >= 40 else 0)
	elif margin < 0:
		d = int(steps[1]) - (1 if margin <= -40 else 0)
		if losses_in_row >= RESTLESS_AFTER:
			d -= 1
	var c := clampi(confidence + d, 0, 100)
	return {"confidence": c, "delta": c - confidence}


## The board's mood in words; the number stays behind the scenes.
static func board_state(confidence: int) -> String:
	if confidence >= 80:
		return "Very secure"
	if confidence >= 62:
		return "Secure"
	if confidence >= 45:
		return "Stable"
	if confidence >= WARN_LINE:
		return "Under pressure"
	return "In trouble"


## The goal as the board would put it in a sentence.
const GOAL_PHRASE := {"top4": "a top-four finish", "finals": "a finals spot",
		"top12": "a top-12 finish", "wins7": "seven wins"}


## Why the board moved after a match, in a sentence.
static func match_reason(goal: Dictionary, opp_name: String, margin: int, losses_in_row: int) -> String:
	var aim := str(GOAL_PHRASE.get(str(goal.get("key", "")), "the season's goal"))
	if margin < 0 and losses_in_row >= RESTLESS_AFTER:
		return "%s losses in a row: the board is getting restless about %s." % [
				MatchNotes.count_word(losses_in_row).capitalize(), aim]
	if margin > 0:
		return "The win over %s keeps %s in reach." % [opp_name, aim]
	if margin < 0:
		return "The loss to %s puts %s under threat." % [opp_name, aim]
	return "A draw with %s leaves the board where it was." % opp_name


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
## `soften` (id -> 0..0.4, from your man-managers) spares part of what being
## left out costs; it never adds to it.
static func morale_after_match(list: Array, played: Dictionary, won: bool, soften: Dictionary = {}) -> void:
	for p in list:
		var id := str(p["id"])
		if played.has(id):
			add_morale(p, 2 + (2 if won else 0) - (0 if won else 1))
		elif int(p.get("injury_weeks", 0)) <= 0:
			var loss := 6 if int(p.get("overall", 0)) >= 78 else 3
			add_morale(p, -CoachEffects.softened(loss, float(soften.get(id, 0.0))))
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


## What his mood is doing to his footy, in a coach's words ("" when it is
## doing nothing worth saying). Mirrors `form`: settled is neutral.
static func mood_effect(m: int) -> String:
	if m >= 85:
		return "It's lifting his footy."
	if m >= 65:
		return ""
	if m >= 40:
		return "It's taking a little off his footy."
	return "It's costing him on the field."


## Match-form nudge from morale: +3% at 100, -3% at 40 and below.
static func form(p: Dictionary) -> float:
	return clampf(float(morale(p) - MORALE_BASE) / 1000.0, -0.03, 0.03)


# ---------------------------------------------------------------------------
# Team form: the club's last five results
# ---------------------------------------------------------------------------
## How much each of the last five results counts, most recent first. They add
## to 1.0, so five straight wins is +1 (the cap) and a sixth adds nothing.
## One loss after five wins drops +1 to +0.40; a second to -0.10.
const FORM_WEIGHTS := [0.30, 0.25, 0.20, 0.15, 0.10]


## Team form, -1..1, from results oldest first ("W", "L" or "D"). Only the
## last five count; a draw counts 0. Every club starts a season at 0.
## Summed in whole hundredths so the label thresholds (0.25, 0.6) are hit
## exactly: in floats, 0.30 - 0.25 + 0.20 comes to 0.2499999...
static func team_form(results: Array) -> float:
	var f := 0
	var n := results.size()
	for i in range(mini(n, FORM_WEIGHTS.size())):
		var r := str(results[n - 1 - i])
		var w := roundi(float(FORM_WEIGHTS[i]) * 100.0)
		if r == "W":
			f += w
		elif r == "L":
			f -= w
	return clampf(float(f) / 100.0, -1.0, 1.0)


## "Hot", "Good", "Steady", "Poor" or "Cold".
static func team_form_label(f: float) -> String:
	if f >= 0.6:
		return "Hot"
	if f >= 0.25:
		return "Good"
	if f > -0.25:
		return "Steady"
	if f > -0.6:
		return "Poor"
	return "Cold"


## This week's event for your club, or {} (about 30% of weeks are quiet).
## `ctx`: list, round, seed, losses (current losing streak), selected (ids
## in this week's side), cap_room (cap points free), memory (what has
## already come up this season: "extension|id", "media|id" -> true,
## "unhappy|id" -> round) and last_key (last week's event).
##
## Every card is a trade-off a coach could make either way, depending on
## the week: short term against long term, the board against the player,
## development against the side, certainty against flexibility.
static func pick_event(ctx: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("event|%d|%d" % [int(ctx.get("seed", 0)), int(ctx.get("round", 0))])
	if rng.randf() >= EVENT_CHANCE:
		return {}
	var list: Array = ctx.get("list", [])
	var selected: Dictionary = ctx.get("selected", {})
	var memory: Dictionary = ctx.get("memory", {})
	var round_no := int(ctx.get("round", 0))
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
		if selected.has(str(p["id"])) and not memory.has("media|" + str(p["id"])) and (worst.is_empty() \
				or int(p["attr"]["discipline"]) < int(worst["attr"]["discipline"])):
			worst = p
	if not worst.is_empty() and int(worst["attr"]["discipline"]) <= 40:
		pool.append(_media(worst))
	var cap_room := int(ctx.get("cap_room", 0))
	for p in fit:
		if extension_wanted(p, memory) and early_price(p) - int(p.get("salary", 0)) <= cap_room:
			pool.append(_extension(p))
			break
	# The board calls at three straight losses, not every week of a slump.
	var losses := int(ctx.get("losses", 0))
	if losses >= 3 and losses % 3 == 0:
		pool.append(_pressure())
	for p in fit:
		if float(p.get("age", 30.0)) <= 21.0 and int(p.get("potential", 0)) >= int(p["overall"]) + 8 \
				and not selected.has(str(p["id"])):
			pool.append(_young_gun(p))
			break
	for p in fit:
		var last := int(memory.get("unhappy|" + str(p["id"]), -99))
		if morale(p) < 35 and round_no - last >= UNHAPPY_GAP:
			pool.append(_unhappy(p))
			break
	# Not the same card two weeks running when there is anything else.
	var last_key := str(ctx.get("last_key", ""))
	if pool.size() > 1:
		var fresh := pool.filter(func(e): return str(e["key"]) != last_key)
		if not fresh.is_empty():
			pool = fresh
	var e: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	e["round"] = round_no
	return e


## Rounds before the same unhappy player can come to you again.
const UNHAPPY_GAP := 5
## Injury risk for a sore player who plays, and his legs.
const SORE_RISK := 6.0
const SORE_LEGS := 90.0
## A heavy week's and a recovery week's effect on this week's injury risk.
const HEAVY_RISK := 1.25
const FRESH_RISK := 0.75
## XP: a heavy week, a closed session, a development week (between a
## reserves game and a senior game, so playing stays the best teacher).
const HEAVY_XP := 12
const CLOSED_XP := 8
const DEV_WEEK_XP := 26


## Is this player the kind who asks to extend early: good, out of contract
## at season's end, settled enough to want to stay, not asked yet this season.
static func extension_wanted(p: Dictionary, memory: Dictionary) -> bool:
	return int(p.get("contract_years", 2)) <= 1 and int(p.get("overall", 0)) >= 72 \
			and morale(p) >= 40 and not memory.has("extension|" + str(p["id"]))


## Signing now, a season early, costs a certainty premium on today's price:
## at least a cap point, about 15%. Waiting pays whatever his rating is worth
## at season's end - less if he drops, more if he improves.
static func early_price(p: Dictionary) -> int:
	var ask := Contracts.asking_salary(p)
	return ask + maxi(1, roundi(float(ask) * 0.15))


## Seasons an early extension runs, counting this one: younger players sign
## on for longer.
static func early_years(p: Dictionary) -> int:
	return 3 if float(p.get("age", 25.0)) <= 28.0 else 2


static func _opt(key: String, label: String, detail: String) -> Dictionary:
	return {"key": key, "label": label, "detail": detail}


## "about a 1 in 4": a risk in words.
static func _odds(chance: float) -> String:
	return "about a 1 in %d" % maxi(2, roundi(1.0 / maxf(0.01, chance)))


static func _sore_star(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	var sore := p.duplicate()
	sore["sore"] = true
	return {"key": "sore_star", "player_id": str(p["id"]), "default": 1,
		"title": "%s pulled up sore" % n,
		"text": "The physio says he can play, but he is not right.",
		"options": [
			_opt("rest", "Rest him this week", "He misses the game, but he is right for next week."),
			_opt("play", "Play him", "He starts short of a gallop, and there is %s chance he breaks down for weeks." % _odds(Injuries.chance(sore))),
		]}


static func _training() -> Dictionary:
	return {"key": "training", "default": 1,
		"title": "Coaches want an extra session",
		"text": "A heavy week on the track, or a week to freshen up?",
		"options": [
			_opt("heavy", "Heavy session", "+%d XP for everyone, but heavy legs on game day and more soft-tissue risk." % HEAVY_XP),
			_opt("recover", "Recovery week", "Fresher bodies: fewer injuries this week and morale +3. No extra development."),
		]}


static func _fans() -> Dictionary:
	return {"key": "fans", "default": 1,
		"title": "Members want an open training day",
		"text": "The fans would love it. The coaches would rather work.",
		"options": [
			_opt("open", "Open the doors", "The board is pleased (+4) and the group enjoys it (morale +3)."),
			_opt("closed", "Closed session", "+%d XP for everyone." % CLOSED_XP),
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
	var ask := Contracts.asking_salary(p)
	var years := early_years(p)
	return {"key": "extension", "player_id": str(p["id"]), "default": 1,
		"title": "%s wants to talk contract" % n,
		"text": "He is out of contract at season's end and wants security now. Today his rating is worth %d a season." % ask,
		"options": [
			_opt("extend", "Extend him now",
					"He signs on for %d more season%s at %d a season: a premium for certainty, locked in whatever he does next." % [
						years - 1, "" if years == 2 else "s", early_price(p)]),
			_opt("wait", "Wait for the off-season",
					"No commitment yet. He asks what his rating is worth then - less if he drops, more if he improves. He is disappointed (morale -5)."),
		]}


static func _pressure() -> Dictionary:
	return {"key": "pressure", "default": 1,
		"title": "The board wants answers",
		"text": "Another losing run. The chairman asks what happens next.",
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
			_opt("blood", "Give him a senior game",
					"Nothing develops a player like AFL footy, and he is thrilled (morale +5) - but he expects to be picked. Leave him out and it stings (-10)."),
			_opt("develop", "A week with the development coaches",
					"+%d XP without taking a spot in the side, but no game at all this week." % DEV_WEEK_XP),
		]}


static func _unhappy(p: Dictionary) -> Dictionary:
	var n := GameDB.player_display_name(p)
	return {"key": "unhappy", "player_id": str(p["id"]), "default": 1,
		"title": "%s is unhappy" % n,
		"text": "He feels he is being overlooked. Unhappy players play below their best and cost more to re-sign.",
		"options": [
			_opt("talk", "Sit down with him", "Morale +15, but he expects a game this week. Leave him out fit and it sours (-12)."),
			_opt("earn", "Tell him to earn it", "His morale -5; the rest of the group respects the standard (+2)."),
		]}
