class_name TradeRequests
extends RefCounted
## Players who ask to be traded when a season ends, as real players do: to go
## home, or to get a game. A request names the clubs he would go to; only
## they can trade for him, and his own club, knowing it can't keep an
## unhappy player, lets him go for less (KEEP). A request nobody meets lapses
## when the trade period closes: he stays, with no other effect.
## Real AFL, 2019-2025: about 21 trades a year move a player
## (tools/balance/afl_trade_volume.json), and a stated request or a move home
## is behind some of them, not most.

## The chance, each season, that a contracted player of 20-29 living away
## from his home state asks to go home (when a club there would have him).
const HOME_CHANCE := 0.04
## The chance that a fringe player who'd start elsewhere asks for a trade.
const GAMES_CHANCE := 0.35
## At most this many games last season, outside his club's best 22, to ask
## for a trade to get a game.
const FRINGE_GAMES := 8
## What his club still counts a player who has asked out for, of his usual
## value.
const KEEP := 0.6
## Most clubs a request names.
const MAX_CLUBS := 3
const MIN_AGE := 20.0
const MAX_AGE := 29.9

## Each club's home state.
const CLUB_STATES := {"ADE": "SA", "BRL": "QLD", "CAR": "VIC", "COL": "VIC", "ESS": "VIC",
		"FRE": "WA", "GEE": "VIC", "GCS": "QLD", "GWS": "NSW", "HAW": "VIC", "MEL": "VIC",
		"NTH": "VIC", "PAD": "SA", "RIC": "VIC", "STK": "VIC", "SYD": "NSW", "WCE": "WA",
		"WBD": "VIC", "TAS": "TAS"}


## A player's home state, where it is known: the state he was drafted from
## (metro and country Victoria are both Victoria; Canberra is Giants
## country). "" when nobody knows.
static func home_state(p: Dictionary) -> String:
	for key in ["home_state", "draft_state"]:
		var s := str(p.get(key, "")).strip_edges().to_upper()
		if s.begins_with("VIC"):
			return "VIC"
		if s == "ACT":
			return "NSW"
		if s != "":
			return s
	return ""


## A roll in [0, 1) that is the same for a player in a season, however often
## it's asked: a request can't be rerolled by reloading.
static func roll(year: int, id: String, why: String) -> float:
	return float(absi(hash([year, "trade_request", why, id])) % 10000) / 10000.0


## Would `p` (on `club`'s list, contracted beyond this season) ask for a
## trade this year? `states`: {club: state} for the league's clubs;
## `starts_at`: the clubs whose side he'd walk into, keenest first;
## `in_side`: he is in his club's best 22; `games`: his games last season.
## {"why": "home" or "games", "to": [clubs]} or {}.
static func asks(p: Dictionary, club: String, year: int, states: Dictionary,
		starts_at: Array, in_side: bool, games: int) -> Dictionary:
	var age := float(p.get("age", 25.0))
	if age < MIN_AGE or age > MAX_AGE or int(p.get("contract_years", 1)) <= 1:
		return {}
	var id := str(p.get("id", ""))
	var home := home_state(p)
	if home != "" and str(states.get(club, "")) != home:
		var there := []
		for c in states:
			if str(states[c]) == home and str(c) != club:
				there.append(str(c))
		there.sort()
		if not there.is_empty() and roll(year, id, "home") < HOME_CHANCE:
			return {"why": "home", "to": there.slice(0, MAX_CLUBS)}
	if not in_side and games <= FRINGE_GAMES and not starts_at.is_empty() \
			and roll(year, id, "games") < GAMES_CHANCE:
		return {"why": "games", "to": starts_at.slice(0, MAX_CLUBS)}
	return {}
