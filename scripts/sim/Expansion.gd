class_name Expansion
extends RefCounted
## How a new club builds its list (director's ruling, 2026-10-14, package
## "B: real-style, cut to size"). The rules and their sizes live here; what
## happens to the career's state is in ExpansionBuild. Behind the feature
## switch "expansion_package" (Features): off, a new club arrives with the 36
## generated players it always did.
##
##  - The list starts with state-league and overlooked players: honest
##    footballers with little room left to improve, different every career.
##  - In the draft before its first season the club holds picks 1, 3, 5 and 7
##    and the first pick of each later round. One of the four must be traded
##    for a senior player (the league wants a side that can compete in year 1).
##  - In the draft after its first season it holds pick 5 on top of its own.
##  - Over its first two off-seasons it may sign up to eight out-of-contract
##    players, one per rival club. A player's club keeps him by re-signing him
##    first; a club that wanted him and lost him gets a draft pick, by the
##    rule that already pays a club for a lost free agent.
##  - Sign-on money for those players sits outside the cap for its first two
##    seasons, from a pool the size the AFL gave Tasmania.
##  - After its second draft the club is treated like every other.

## Picks in the first round of the draft before the club's first season.
const FIRST_DRAFT_PICKS := [1, 3, 5, 7]
## The one of those that must be traded for a senior player.
const MUST_TRADE_PICK := 7
## The extra pick in the draft after its first season.
const SECOND_DRAFT_PICK := 5
## Out-of-contract players it may sign in all, and in the first off-season.
const SIGNINGS := 8
const FIRST_WINDOW := 5
## The approaches are made with this many home-and-away rounds still to play.
const APPROACH_ROUNDS_LEFT := 4
## Nobody this old, or older, is approached.
const TARGET_MAX_AGE := 30.0
## The players it signs from the state leagues before anything else.
const FOUNDATION_SIZE := 30
## The most a state-league signing can improve past his rating, by age:
## [oldest age, points]. They are who they are; the club's stars come from
## the draft and from rival clubs.
const FOUNDATION_ROOM := [[22.0, 4], [24.0, 3], [26.0, 2], [99.0, 1]]
## Sign-on money outside the cap: the pool for the first two seasons, and the
## most of it one season can use (the AFL's figures for Tasmania, in 2027
## dollars; both move with the cap).
const SIGN_ON_POOL := 5000000
const SIGN_ON_SEASON_MAX := 3000000
## When a player's club meets his price, does he still choose between the two
## clubs (true), or does meeting his price keep him (false)?
static var MATCHED_PLAYER_DECIDES := false
## A player his club wants but cannot fit under its cap: may the new club
## sign him first (true), or does he go to free agency like anyone else?
static var FIRST_CALL_CAP_SQUEEZED := true
## A senior player, for the pick that must be traded: at least this old.
const SENIOR_AGE := 23.0
## An entry year that never comes: a club this career leaves out.
const NEVER := 9999


## The club's first players: FOUNDATION_SIZE of them from the state leagues,
## seeded by the career so no two careers get the same list, each held to the
## room his age leaves him. `year` is the season they are that old in.
static func foundation_list(code: String, year: int, career_seed: int) -> Array:
	var salt := "%04d" % posmod(career_seed, 10000)
	var out: Array = Prospects.generate_expansion_list(code, year, FOUNDATION_SIZE, salt)
	for p in out:
		var ovr := int(p.get("overall", 50))
		var room := 1
		for band in FOUNDATION_ROOM:
			if float(p.get("age", 25.0)) <= float(band[0]):
				room = int(band[1])
				break
		p["potential"] = clampi(mini(int(p.get("potential", ovr)), ovr + room), ovr, 99)
		p["note"] = "State-league signing, %d" % year
	return out


## The club's extra picks in the draft before its first season, as entries the
## draft slots in beside the compensation picks: {"club", "after": the regular
## picks taken before it, "round", "concession": true, "pick": the overall
## pick it is, "value"}. `n` clubs draft in the ordinary order over `rounds`.
static func first_draft_picks(code: String, n: int, rounds: int) -> Array:
	var out := []
	for i in range(FIRST_DRAFT_PICKS.size()):
		var pick := int(FIRST_DRAFT_PICKS[i])
		out.append(_entry(code, pick - 1 - i, 1, pick))
	for r in range(2, rounds + 1):
		var before := n * (r - 1)
		out.append(_entry(code, before, r, before + FIRST_DRAFT_PICKS.size() + (r - 1)))
	return out


## The one extra pick in the draft after its first season.
static func second_draft_picks(code: String) -> Array:
	return [_entry(code, SECOND_DRAFT_PICK - 1, 1, SECOND_DRAFT_PICK)]


static func _entry(code: String, after: int, rnd: int, pick: int) -> Dictionary:
	return {"club": code, "origin": code, "after": after, "round": rnd, "pick": pick,
			"concession": true, "value": 99.0}


## The sign-on money a season may keep off the payroll: no more than the
## salaries it is paying those players, the season's limit, or what is left
## of the pool. All in that year's dollars.
static func sign_on_relief(signing_salaries: int, year: int, already_used: int) -> int:
	var pool := Contracts.indexed_money_2027(SIGN_ON_POOL, year)
	var most := Contracts.indexed_money_2027(SIGN_ON_SEASON_MAX, year)
	return maxi(0, mini(signing_salaries, mini(most, pool - already_used)))
