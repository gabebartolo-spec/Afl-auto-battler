class_name Backing
extends RefCounted
## A promise of a run: a young player told he has the next few senior games.
## Pure rules; GameState keeps the state and applies them.
##
## The ledger is a list on the player, p["backed"], one entry each time you
## backed him: {"year", "round", "games", "played", "state", "debut", "ended"}.
##   round   the round it was made in (0 in the finals)
##   played  senior games given so far
##   state   "active" while the run is on, then "done" (every game given),
##           "broken" (he was left out while fit) or "lapsed" (the season ended
##           first)
##   debut   he had not played a senior game when you backed him
##   ended   {"year", "label"} of the match that ended it, for done and broken
## It outlives the run, so a later line can say what you did for him.
##
## While a run is on, auto-pick names him (Ratings.select_22) and leaving him
## out while fit breaks the promise. A named side is your own call, and so is
## the price: the promise breaks once, it stings once, and the run is over.

## Senior games in a run.
const RUN_GAMES := 3
## A player with fewer senior games than this can be backed from selection.
const FEW_GAMES := 10
## His mood when he is told: he is thrilled.
const THRILL := 5
## What breaking the promise costs his mood, as the one-week promise always did.
const STING := 10


static func ledger(p: Dictionary) -> Array:
	var l = p.get("backed", [])
	return l if l is Array else []


## The run that is on now, or {}.
static func current(p: Dictionary) -> Dictionary:
	if not p.has("backed"):
		return {}
	var l := ledger(p)
	if l.is_empty():
		return {}
	var last: Dictionary = l[l.size() - 1]
	return last if str(last.get("state", "")) == "active" else {}


static func is_active(p: Dictionary) -> bool:
	return not current(p).is_empty()


## Fit to play: not injured or suspended. (Being rested is the coach's call, so
## it does not count as being unfit.)
static func fit(p: Dictionary) -> bool:
	return int(p.get("injury_weeks", 0)) <= 0 and int(p.get("suspension_weeks", 0)) <= 0


## Can he be backed from selection: few senior games on a career on record in
## full, available to play, and no run on already.
static func can_back(p: Dictionary, games_played: int) -> bool:
	return Career.complete(p) and games_played < FEW_GAMES and Ratings.available(p) \
			and not is_active(p)


## Start a run. The week it is made in is his first game, if he plays it.
static func start(p: Dictionary, year: int, round_no: int, games_played: int) -> Dictionary:
	var entry := {"year": year, "round": round_no, "games": RUN_GAMES, "played": 0,
			"state": "active", "debut": games_played == 0}
	if not (p.get("backed") is Array):
		p["backed"] = []
	(p["backed"] as Array).append(entry)
	return entry


## After one of your matches: `played` is whether he took the field, `was_fit`
## whether he could have. Every game he plays counts; left out while fit, the
## promise breaks; unfit, it waits. `when` is {"year", "label"} for the match,
## kept on a run that ends with it. Returns the state the run is in ("" when
## there is no run).
static func after_match(p: Dictionary, played: bool, was_fit: bool, when := {}) -> String:
	var run := current(p)
	if run.is_empty():
		return ""
	if played:
		run["played"] = int(run["played"]) + 1
		if int(run["played"]) >= int(run["games"]):
			run["state"] = "done"
	elif was_fit:
		run["state"] = "broken"
	if str(run["state"]) != "active" and not when.is_empty():
		run["ended"] = when.duplicate()
	return str(run["state"])


## The run that was finished by the match `label` played in `year`, or {}: every
## game given, the last of them that day. Full time says so.
static func finished_in(p: Dictionary, year: int, label: String) -> Dictionary:
	for e in ledger(p):
		var when = e.get("ended")
		if str(e.get("state", "")) == "done" and when is Dictionary \
				and int(when.get("year", 0)) == year and str(when.get("label", "")) == label:
			return e
	return {}


## He played his first senior game on a run you had promised him.
static func debuted_on_run(p: Dictionary) -> bool:
	for e in ledger(p):
		if bool(e.get("debut", false)) and int(e.get("played", 0)) >= 1:
			return true
	return false


## The season ended with the run unfinished.
static func lapse(p: Dictionary) -> void:
	var run := current(p)
	if not run.is_empty():
		run["state"] = "lapsed"


## "You promised Calder a run: game two of three." for a run that is on, ""
## for none. A player who cannot play waits for it: "...game two of three,
## when available."
static func note(p: Dictionary) -> String:
	var run := current(p)
	if run.is_empty():
		return ""
	var line := "You promised %s a run: game %s of %s" % [GameDB.player_display_name(p),
			MatchNotes.count_word(int(run["played"]) + 1), MatchNotes.count_word(int(run["games"]))]
	return line + ("." if fit(p) else ", when available.")
