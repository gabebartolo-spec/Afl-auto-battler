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
			"state": "active", "debut": games_played == 0, "club": str(p.get("club", ""))}
	if not (p.get("backed") is Array):
		p["backed"] = []
	(p["backed"] as Array).append(entry)
	return entry


## After one of your matches: `played` is whether he took the field, `was_fit`
## whether he could have. Every game he plays counts; left out while fit, the
## promise breaks; unfit, it waits. `when` is {"year", "label"} for the match,
## kept on a run that ends with it. Returns the state the run is in ("" when
## there is no run).
static func after_match(p: Dictionary, played: bool, was_fit: bool, when := {}, stats := {}) -> String:
	var run := current(p)
	if run.is_empty():
		return ""
	if played:
		run["played"] = int(run["played"]) + 1
		# What he did with it, for the sit-down when the run ends.
		var tot: Dictionary = run.get("tot", {})
		for k in KPI_LABEL:
			tot[k] = int(tot.get(k, 0)) + int(stats.get(k, 0))
		run["tot"] = tot
		if int(run["played"]) >= int(run["games"]):
			run["state"] = "done"
	elif was_fit:
		run["state"] = "broken"
	if str(run["state"]) != "active" and not when.is_empty():
		run["ended"] = when.duplicate()
	return str(run["state"])


## The numbers a player is judged on, by the job he does (director,
## 2026-10-09: "a key back shouldn't be rated by the goals scored"). Two match
## stats each; "good" when either reaches its rate a game, "quiet" when both
## are under theirs. Rates are for a young player's first games, not a star's.
const KPI := {
	"key_fwd": {"stats": ["goals", "marks"], "good": {"goals": 1.5, "marks": 6.0}, "quiet": {"goals": 0.34, "marks": 3.0}},
	"fwd": {"stats": ["goals", "tackles"], "good": {"goals": 1.3, "tackles": 5.0}, "quiet": {"goals": 0.34, "tackles": 2.0}},
	"mid": {"stats": ["disposals", "clearances"], "good": {"disposals": 20.0, "clearances": 4.0}, "quiet": {"disposals": 12.0, "clearances": 1.0}},
	"wing": {"stats": ["disposals", "inside50"], "good": {"disposals": 18.0, "inside50": 4.0}, "quiet": {"disposals": 11.0, "inside50": 1.5}},
	"ruck": {"stats": ["hitouts", "clearances"], "good": {"hitouts": 22.0, "clearances": 3.0}, "quiet": {"hitouts": 10.0, "clearances": 1.0}},
	"key_back": {"stats": ["spoils", "marks"], "good": {"spoils": 5.0, "marks": 6.0}, "quiet": {"spoils": 2.0, "marks": 3.0}},
	"def": {"stats": ["disposals", "rebounds"], "good": {"disposals": 18.0, "rebounds": 4.0}, "quiet": {"disposals": 11.0, "rebounds": 1.5}},
}
const KPI_LABEL := {"goals": "goals", "marks": "marks", "tackles": "tackles", "disposals": "disposals",
		"clearances": "clearances", "inside50": "inside 50s", "hitouts": "hit-outs", "spoils": "spoils",
		"rebounds": "rebound 50s"}
## A defender this tall plays on the key forwards.
const KEY_BACK_CM := 192


## The job he is judged on: key_fwd, fwd, mid, wing, ruck, key_back or def.
static func kpi_kind(p: Dictionary) -> String:
	match str(p.get("role", "MID")):
		"RUCK":
			return "ruck"
		"FWD":
			return "key_fwd" if PlayerProfile.forward_type(p) == "Key forward" else "fwd"
		"DEF":
			return "key_back" if int(p.get("height_cm", 0)) >= KEY_BACK_CM else "def"
	return "wing" if Roles.is_wing(p) else "mid"


## "Three games: four goals, 6 marks a game." or "Three games: 5 spoils and 6
## marks a game.": goals as a count, everything else a game.
static func kpi_line(kind: String, played: int, tot: Dictionary) -> String:
	var ks: Array = KPI[kind]["stats"]
	var head := "%s game%s: " % [MatchNotes.count_word(played).capitalize(), "" if played == 1 else "s"]
	var said := func(k):
		var r := int(round(float(tot.get(k, 0)) / float(maxi(1, played))))
		return "%d %s" % [r, KPI_LABEL[k] if r != 1 else str(KPI_LABEL[k]).trim_suffix("s")]
	if ks[0] == "goals":
		var g := int(tot.get("goals", 0))
		var gl := "no goals" if g == 0 else ("a goal" if g == 1 else "%s goals" % MatchNotes.count_word(g))
		return head + "%s, %s a game." % [gl, said.call(ks[1])]
	return head + "%s and %s a game." % [said.call(ks[0]), said.call(ks[1])]


## How the run went on his job's numbers: "good", "quiet" or "".
static func kpi_verdict(kind: String, played: int, tot: Dictionary) -> String:
	var k: Dictionary = KPI[kind]
	var n := float(maxi(1, played))
	for s in k["good"]:
		if float(tot.get(s, 0)) / n >= float(k["good"][s]):
			return "good"
	for s in k["quiet"]:
		if float(tot.get(s, 0)) / n >= float(k["quiet"][s]):
			return ""
	return "quiet"


## The sit-down when a run ends (director, 2026-10-09: the conversation comes
## at the end of the run, with what he actually did, on the numbers his job is
## judged by). {} for a run still on or one that lapsed with the season.
## Reported, never a quote: real players are in the game.
## {"player_id", "title", "lines"}.
static func talk(p: Dictionary, run: Dictionary) -> Dictionary:
	var state := str(run.get("state", ""))
	if state != "done" and state != "broken":
		return {}
	var played := int(run.get("played", 0))
	var games := int(run.get("games", RUN_GAMES))
	var tot: Dictionary = run.get("tot", {})
	var kind := kpi_kind(p)
	var lines := []
	if played > 0:
		lines.append(kpi_line(kind, played, tot))
	if state == "broken":
		lines.append("You told him %s games and he got %s. He wants to know where he stands." % [
				MatchNotes.count_word(games), MatchNotes.count_word(played) if played > 0 else "none"])
	else:
		match kpi_verdict(kind, played, tot):
			"good":
				lines.append("He feels he showed you something, and he wants more of it.")
			"quiet":
				lines.append("He knows it was quiet. He wants another go when he has earned it.")
			_:
				lines.append("He is glad of the chance and knows there is more in him.")
	return {"player_id": str(p.get("id", "")), "title": "Sit-down with %s" % GameDB.player_display_name(p),
			"lines": lines}


## The run that was finished by the match `label` played in `year`, or {}: every
## game given, the last of them that day. Full time says so.
static func finished_in(p: Dictionary, year: int, label: String) -> Dictionary:
	return ended_in(p, year, label, "done")


## The run that ended `state` ("done" or "broken") with the match `label`
## played in `year`, or {}.
static func ended_in(p: Dictionary, year: int, label: String, state: String) -> Dictionary:
	for e in ledger(p):
		var when = e.get("ended")
		if str(e.get("state", "")) == state and when is Dictionary \
				and int(when.get("year", 0)) == year and str(when.get("label", "")) == label:
			return e
	return {}


## What became of each run you promised him, for his "With us" line, in the
## order they were made: "Given a three-game run in 2028.", "Promised a run in
## 2028, left out after one game.", "Promised a run in 2028; the season ended
## with one game to go." A run on now says nothing here (the reminder does),
## and a run that gave him his debut is already in "Debuted ..., on your say-so."
static func memory_bits(p: Dictionary) -> Array:
	var out := []
	for e in ledger(p):
		# A run promised at another club is not this club's promise (an old entry
		# without a club still shows).
		var made_at := str(e.get("club", ""))
		if made_at != "" and made_at != str(p.get("club", "")):
			continue
		var year := int(e.get("year", 0))
		var played := int(e.get("played", 0))
		var games := int(e.get("games", RUN_GAMES))
		match str(e.get("state", "")):
			"done":
				if not bool(e.get("debut", false)):
					out.append("Given a %s-game run in %d." % [MatchNotes.count_word(games), year])
			"broken":
				out.append("Promised a run in %d, left out %s." % [year,
						"before he played a game of it" if played == 0
						else "after %s game%s" % [MatchNotes.count_word(played), "" if played == 1 else "s"]])
			"lapsed":
				var left := games - played
				out.append("Promised a run in %d; the season ended with %s game%s to go." % [year,
						MatchNotes.count_word(left), "" if left == 1 else "s"])
	return out


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
## when available." A fit player your named side leaves out is told plainly
## what that does: "... Not named: leave him out and the promise breaks."
static func note(p: Dictionary, named := true) -> String:
	var run := current(p)
	if run.is_empty():
		return ""
	var line := "You promised %s a run: game %s of %s" % [GameDB.player_display_name(p),
			MatchNotes.count_word(int(run["played"]) + 1), MatchNotes.count_word(int(run["games"]))]
	if not fit(p):
		return line + ", when available."
	return line + ("." if named else ". Not named: leave him out and the promise breaks.")
