class_name ClubLife
extends RefCounted
## The club around the team: the board's expectations, player morale and the
## weekly event card. Pure rules; GameState keeps the state and applies them.
##
## Board: each season the board sets a goal from where your list ranks
## (a top-four list must finish top four; a bottom list must win seven).
## Results move its confidence (0-100). Miss the goal and it drops sharply;
## finish a season under WARN_LINE and you get a final warning, do it again
## and you are sacked. How many poor seasons the board puts up with before
## the warning is the board-patience dial (season_end, data/difficulty_dials.json).
##
## Morale (0-100, 70 is settled): playing and winning lift it, being left out
## while fit drags it down - stars most. It nudges match form (+/-3%) and an
## unhappy player asks 25% more to re-sign.

const START_CONFIDENCE := 60
const WARN_LINE := 30
const MORALE_BASE := 70


## The season's goal from where the list ranks pre-season (`rank`, by
## Squad.strength) and where the club finished last season (`prev`, 0 when
## there is no last season). Calibrated against replayed seasons
## (ARD-M6-003): a pre-season list ranking is a rough guide - the best list
## averages about fifth - so the bands ask for what a list of that rank
## reaches in most seasons, about four times in five:
##   top four   only a top-two list that also finished top four last year
##              (a list ranking alone makes the top four well under half
##              the time, so it never sets that demand by itself);
##   finals     the top seven lists;
##   top 12     ranks 8-12;
##   seven wins the rest.
const TOP4_LIST_RANK := 2
const TOP4_LAST_FINISH := 4
const FINALS_LIST_RANK := 7
const TOP12_LIST_RANK := 12


static func board_goal(rank: int, prev := 0) -> Dictionary:
	if rank <= TOP4_LIST_RANK and prev >= 1 and prev <= TOP4_LAST_FINISH:
		return {"key": "top4", "text": "Finish in the top four", "pos": 4}
	if rank <= FINALS_LIST_RANK:
		return {"key": "finals", "text": "Make the finals", "pos": Season.FINALISTS}
	if rank <= TOP12_LIST_RANK:
		return {"key": "top12", "text": "Finish in the top 12", "pos": 12}
	return {"key": "wins7", "text": "Win at least 7 games", "wins": 7}


static func goal_met(goal: Dictionary, position: int, wins: int, clubs := 18) -> bool:
	if goal.has("wins"):
		return wins >= int(goal["wins"])
	return position <= int(goal.get("pos", clubs))


## Where a club with no recorded expectation is taken to sit: mid-table.
static func default_rank(clubs: int) -> int:
	return clubs / 2


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


## What the board does at the end of a season, by how patient it is
## (DifficultyDials.step("board_patience", ...)). `conf` is the confidence
## after the season (after_season). A season is poor when it ends under the
## step's poor_season_below. The board warns you on the poor season that
## reaches poor_seasons_before_warning, and the next poor season after the
## warning is the sacking; a season that meets the goal clears both.
## Returns {"confidence", "warned", "sacked", "poor_seasons", "verdict"}.
static func season_end(conf: int, met: bool, warned: bool, poor_seasons: int, patience: Dictionary) -> Dictionary:
	var verdict := "The board is delighted." if met else "The board is disappointed."
	var sacked := false
	var poor_n := poor_seasons
	var c := conf
	if conf < int(patience.get("poor_season_below", WARN_LINE)):
		poor_n += 1
		if warned:
			sacked = true
			verdict = "The board has sacked you."
		elif poor_n >= int(patience.get("poor_seasons_before_warning", 1)):
			warned = true
			c = maxi(conf, WARN_LINE + 5)
			verdict = "Final warning: miss again next year and you are gone."
		else:
			verdict = "The board is losing patience."
	elif met:
		warned = false
		poor_n = 0
	return {"confidence": c, "warned": warned, "sacked": sacked, "poor_seasons": poor_n, "verdict": verdict}


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


## The week's card itself is data now (data/stories, StoryDeck, StoryEngine);
## the rules below stay here because the cards and the rest of the game share
## them. The story tests check the deck's sizes against these constants.


## Rounds before the same unhappy player can come to you again.
const UNHAPPY_GAP := 5
## Injury risk for a sore player who plays, and his legs.
const SORE_RISK := 6.0
const SORE_LEGS := 90.0
## A heavy week's and a recovery week's effect on this week's injury risk.
const HEAVY_RISK := 1.25
const FRESH_RISK := 0.75
## A slow start (a story card's "small chance"): the legs a player takes to the
## first bounce, a little under a heavy week's, so the first quarter is the
## cost and the rest of the match is his own (energy comes back at each break).
const SLOW_LEGS := 82.0
## XP: a heavy week, a closed session, a development week (between a
## reserves game and a senior game, so playing stays the best teacher).
const HEAVY_XP := 12
const CLOSED_XP := 8
const DEV_WEEK_XP := 26


## Rating from which a player is a star who may ask to extend early (the
## line MatchSim calls a star).
const EXTENSION_MIN_OVR := 80


## Is this player the kind who asks to extend early: a star, out of contract
## at season's end, settled enough to want to stay - and nobody has asked yet
## this season, so most contract calls wait for the off-season.
static func extension_wanted(p: Dictionary, memory: Dictionary) -> bool:
	if int(p.get("contract_years", 2)) > 1 or int(p.get("overall", 0)) < EXTENSION_MIN_OVR or morale(p) < 40:
		return false
	for key in memory:
		if str(key).begins_with("extension|"):
			return false
	return true


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


## "about a 1 in 4": a risk in words.
static func odds(chance: float) -> String:
	return "about a 1 in %d" % maxi(2, roundi(1.0 / maxf(0.01, chance)))


# --- The sit-down that grows out of what happened (RPG-003 slice 1, director
# 2026-10-09). Three facts open it, in this order:
#   dropped  a veteran (VETERAN_GAMES+) in your last side, fit, left out now
#   back     back from an injury he has not played since, fit, left out now
#   waiting  a fit youngster (YOUNG_AGE or under) without a senior game for
#            WAITING_WEEKS+ of your rounds
# `info` per player id (GameState.talk_info): {"games", "in_last_side",
# "selected", "age", "weeks_without" (-1 unknown), "injury" (the injury he
# is back from, "" for none), "kpi" (his season on his job's numbers, "")}.

const VETERAN_GAMES := 100
const YOUNG_AGE := 21.0
const WAITING_WEEKS := 5
const TALK_CASES := ["dropped", "back", "waiting"]
## Morale for being told why, on the numbers (between the old card's two:
## heard, but nothing promised).
const EXPLAIN_LIFT := 5


## Which fact, if any, he has to talk about: "dropped", "back", "waiting" or "".
## `p` must be fit (the caller passes fit players only).
static func talk_case(p: Dictionary, i: Dictionary) -> String:
	if i.is_empty() or bool(i.get("selected", false)):
		return ""
	if int(i.get("games", 0)) >= VETERAN_GAMES and bool(i.get("in_last_side", false)):
		return "dropped"
	if str(i.get("injury", "")) != "":
		return "back"
	if float(i.get("age", 99.0)) <= YOUNG_AGE and int(i.get("weeks_without", -1)) >= WAITING_WEEKS:
		return "waiting"
	return ""


## What the card opens on, in a coach's words.
static func talk_text(case: String, i: Dictionary) -> String:
	match case:
		"dropped":
			return "%d games, fit, and dropped from the side this week. He wants to know why." % int(i.get("games", 0))
		"back":
			return "Over the %s and fit again, and still not picked. He wants to know where he stands." % str(i.get("injury", "injury"))
		"waiting":
			var w := int(i.get("weeks_without", 0))
			return "%s weeks without a senior game, and he's fit. He wants to know what he has to do." % MatchNotes.count_word(w).capitalize()
	return ""
