class_name CareerFacts
extends RefCounted
## One durable record of what happened in a player's career (ROADMAP §9.4,
## G7; audit: docs/research/RPG_G7_CAREER_FACTS_AUDIT.md). Pure rules;
## GameState keeps the store and saves it with the career.
##
## The store is keyed by player id, not kept on the player, so a fact outlives
## a trade, a delisting and retirement (into coaching or not), and a name
## change cannot touch it:
##
##   store = {player id: [row, ...]}, oldest first
##   row   = [y, at, k, club, d, out] - kept as a row, like Career's stints,
##           because every club's injuries go in it every season
##     y     the season
##     at    when in it: the match label ("Round 7", "Grand Final"), or ""
##           when the record never kept it (a fact moved from an older save)
##     k     what happened: KINDS
##     club  his club when it happened, or "" when not known
##     d     the coach's decision behind it, or ""
##     out   what came of it, or "" (an injury: its kind, "hamstring")
##
## Read it with of(), which hands back {y, at, k, club, d, out} dictionaries.
## Facts are written once, when they happen, from the full match result; the
## save's slimmed results are never read to rebuild one.

## What a fact can be. Only injuries are kept here so far; the other stores
## the audit lists move one at a time.
const KINDS := ["injury"]

const Y := 0
const AT := 1
const K := 2
const CLUB := 3
const D := 4
const OUT := 5


static func row(y: int, at: String, k: String, club: String, d := "", out := "") -> Array:
	return [y, at, k, club, d, out]


## Add one fact for a player.
static func add(store: Dictionary, id: String, r: Array) -> void:
	if id == "":
		return
	if not (store.get(id) is Array):
		store[id] = []
	(store[id] as Array).append(r)


## His facts as dictionaries, oldest first; only `kind` when one is given.
static func of(store: Dictionary, id: String, kind := "") -> Array:
	var out := []
	var rows = store.get(id, [])
	if not (rows is Array):
		return out
	for r in rows:
		if kind != "" and str(r[K]) != kind:
			continue
		out.append({"y": int(r[Y]), "at": str(r[AT]), "k": str(r[K]), "club": str(r[CLUB]),
				"d": str(r[D]), "out": str(r[OUT])})
	return out


## How many of his `kind` facts fall in `from_year` or later.
static func count_since(store: Dictionary, id: String, kind: String, from_year: int) -> int:
	var n := 0
	var rows = store.get(id, [])
	if rows is Array:
		for r in rows:
			if str(r[K]) == kind and int(r[Y]) >= from_year:
				n += 1
	return n


## An older save kept injuries on the player as bare years (p["injury_log"]).
## Move them here as injury facts with no label, club or kind - what the old
## record knew and nothing more - and drop the old key. Returns how many moved.
static func migrate_injury_log(store: Dictionary, p: Dictionary) -> int:
	var log = p.get("injury_log", [])
	p.erase("injury_log")
	if not (log is Array):
		return 0
	var id := str(p.get("id", ""))
	for y in log:
		add(store, id, row(int(y), "", "injury", ""))
	return (log as Array).size()


## The names a departed player is shown by, kept when he leaves the lists so
## an honour-roll or record line can still name him. Not his identity: the id
## is the key; these only feed GameDB.player_display_name.
static func name_card(p: Dictionary) -> Dictionary:
	return {"real_name": str(p.get("real_name", "")),
			"generic_name": str(p.get("generic_name", p.get("name", ""))),
			"first": str(p.get("first", "")), "last": str(p.get("last", ""))}
