class_name Trust
extends RefCounted
## How far a person trusts you, the coach, and why (club-life stories, phase 1).
##
## One model for every relationship: phase 1 keys your players ("p:<id>");
## later phases add rival coaches ("c:"), journalists ("j:") and board figures
## ("b:") to the same map. The map lives in GameState.relations and is saved
## with the career; a person with no entry is neutral, so an older save loads
## with everyone neutral.
##
## Trust is shown in words, never as a number, and every change keeps its
## reason ("You dropped him after three games"), so the player can always look
## up why. It has no passive effect: it moves only through the choices on the
## week's cards, and it changes what those choices do only where the card says
## so (a talk lands harder with a player who trusts you).

const LOWEST := -100
const HIGHEST := 100
## The most one moment can move it, either way (StoryDeck checks every card).
const STEP_MAX := 20
## Reasons kept per person, newest last.
const LOG_KEEP := 8

## Bands, highest first: [floor, key, words]. Neutral says nothing.
const BANDS := [
	[50, "close", "Trusts you completely"],
	[20, "trusts", "Trusts you"],
	[-19, "neutral", ""],
	[-49, "wary", "Wary of you"],
	[LOWEST, "lost", "Stopped listening"],
]

## What trust does to a lift that depends on it (a talk, a promise): it lands
## harder with a player who trusts you, softer with one who doesn't.
const LIFT_SCALE := {"close": 1.4, "trusts": 1.2, "neutral": 1.0, "wary": 0.7, "lost": 0.4}


static func player_key(id: String) -> String:
	return "p:" + id


static func value(rel: Dictionary, key: String) -> int:
	return int((rel.get(key, {}) as Dictionary).get("t", 0))


static func band(t: int) -> String:
	for b in BANDS:
		if t >= int(b[0]):
			return str(b[1])
	return "lost"


## "Trusts you", "Wary of you"... or "" when he has no strong view of you.
static func words(t: int) -> String:
	for b in BANDS:
		if t >= int(b[0]):
			return str(b[2])
	return ""


## Move trust by `d` (clamped to one moment's limit) and keep the reason.
## Returns what actually changed.
static func change(rel: Dictionary, key: String, d: int, why: String, year: int, when: String) -> int:
	if d == 0:
		return 0
	var entry: Dictionary = rel.get(key, {})
	var before := int(entry.get("t", 0))
	var after := clampi(before + clampi(d, -STEP_MAX, STEP_MAX), LOWEST, HIGHEST)
	entry["t"] = after
	var log: Array = entry.get("log", [])
	log.append({"y": year, "w": when, "d": after - before, "why": why})
	while log.size() > LOG_KEEP:
		log.pop_front()
	entry["log"] = log
	rel[key] = entry
	return after - before


## His reasons, newest first: [{"y", "w", "d", "why"}].
static func reasons(rel: Dictionary, key: String) -> Array:
	var log: Array = ((rel.get(key, {}) as Dictionary).get("log", []) as Array).duplicate()
	log.reverse()
	return log


## A lift that depends on trust, scaled by his band. Only lifts scale; a cost
## is the same whoever pays it.
static func scaled(d: int, t: int) -> int:
	if d <= 0:
		return d
	return maxi(1, roundi(float(d) * float(LIFT_SCALE[band(t)])))
