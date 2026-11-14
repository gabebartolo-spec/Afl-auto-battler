class_name Expansion
extends RefCounted
## How a new club builds its list (director's ruling, 2026-10-14, package
## "B: real-style, cut to size"). The rules and their sizes live here; what
## happens to the career's state is in ExpansionBuild.
##
##  - The list starts with state-league and overlooked players: honest
##    footballers with little room left to improve, different every career.
##  The AFL's published rules for Tasmania (director, 2026-11-09, "do it like
##  this then"; overrules the cut-down sizes of 2026-10-14):
##  - In the draft before its first season the club holds picks 1, 3, 5, 7, 9,
##    11 and 13 and the first pick of each later round. 5, 7, 11 and 13 must be
##    traded for senior players.
##  - In each of the next two drafts it holds picks 5 and 9 on top of its own,
##    and pick 5 must be traded.
##  - Over its first two off-seasons it may sign up to 18 out-of-contract
##    players, one per rival club. The player chooses; a club that wanted him
##    and lost him gets a draft pick, by the rule that already pays a club for
##    a lost free agent.
##  - Sign-on money for those players sits outside the cap for its first two
##    seasons, then steps down over the next two (SIGN_ON_TAPER; the director,
##    2026-11-11: the three-year founding deals outlast two seasons).
##  - For four drafts from the one before its first season, the prospects of
##    its home state join its list before the draft.

## Picks in the first round of the draft before the club's first season.
const FIRST_DRAFT_PICKS := [1, 3, 5, 7, 9, 11, 13]
## Those that must be traded for a senior player.
const MUST_TRADE_PICKS := [5, 7, 11, 13]
## The extra picks in each of the two drafts after that, and the one to trade.
const LATER_DRAFT_PICKS := [5, 9]
const LATER_MUST_TRADE_PICK := 5
## Out-of-contract players it may sign in all (the rules set no yearly limit).
const SIGNINGS := 18
const FIRST_WINDOW := 18
## A rival's player this good will not join a side yet to play: squeezed at his
## club, he goes to the open market instead (director, 2026-11-09, "Stars weigh
## it harder").
const STAR_STAYS_OVERALL := 80
## Drafts with first call on home-state prospects, from the first one.
const ACADEMY_DRAFTS := 4
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
## After those two seasons the money steps down instead of ending at once: the
## share of the second season's sign-on money the third and fourth seasons
## keep off the payroll. Nothing from the fifth.
const SIGN_ON_TAPER := [2.0 / 3.0, 1.0 / 3.0]
## When a player's club meets his price, does he still choose between the two
## clubs (true), or does meeting his price keep him (false)?
static var MATCHED_PLAYER_DECIDES := true
## A player his club wants but cannot fit under its cap: may the new club
## sign him first (true), or does he go to free agency like anyone else?
## Director, 2026-11-09: his club cannot stop him leaving.
static var FIRST_CALL_CAP_SQUEEZED := true
## A senior player, for the pick that must be traded: at least this old.
const SENIOR_AGE := 23.0
## An entry year that never comes: a club this career leaves out.
const NEVER := 9999


## The home state league of a club that entered before the expansion
## concessions (Legacy mode): Adelaide and Port Adelaide from the SANFL,
## Fremantle from the WAFL.
const EARLY_HOME := {"ADE": "SA", "PAD": "SA", "FRE": "WA"}


## Whether a club gets the expansion concessions (out-of-contract approaches,
## compensation, extra and traded picks, sign-on money): the rule of the
## season it enters (era_rules.csv expansion_concessions, from Gold Coast's
## 2011 entry; always on in the game's own seasons). Every club entering in
## the same season is treated the same.
static func concessions(code: String) -> bool:
	var y := GameDB.enter_year(code)
	return not EraRules.is_era(y) or EraRules.value("expansion_concessions", y) > 0.0


## How many players the club signs from the state leagues before anything
## else: FOUNDATION_SIZE with the concessions; without them its whole senior
## list for its first season (the era's senior maximum), since nothing else
## fills it.
static func foundation_size(code: String) -> int:
	if concessions(code):
		return FOUNDATION_SIZE
	return EraRules.senior_spots(GameDB.enter_year(code))


## The club's first players: foundation_size of them from the state leagues,
## seeded by the career so no two careers get the same list, each held to the
## room his age leaves him. `year` is the season they are that old in. A club
## entering before the concessions signs them from its home state league.
static func foundation_list(code: String, year: int, career_seed: int) -> Array:
	var salt := "%04d" % posmod(career_seed, 10000)
	var out: Array = Prospects.generate_expansion_list(code, year, foundation_size(code), salt)
	var home := "" if concessions(code) else str(EARLY_HOME.get(code, ""))
	var sides: Array = Prospects.JUNIOR_TEAMS.filter(func(t): return str(t[2]) == home)
	for i in out.size():
		var p: Dictionary = out[i]
		if not sides.is_empty():
			var side: Array = sides[i % sides.size()]
			p["draft_team"] = str(side[0])
			p["draft_league"] = str(side[1])
			p["draft_state"] = home
			p["state"] = home
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


## The extra picks in each of the two drafts after that.
static func later_draft_picks(code: String) -> Array:
	var out := []
	for i in range(LATER_DRAFT_PICKS.size()):
		var pick := int(LATER_DRAFT_PICKS[i])
		out.append(_entry(code, pick - 1 - i, 1, pick))
	return out


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


## The sign-on money in the club's season `nth` (1 = its first) once the two
## pool seasons are over: SIGN_ON_TAPER of the second season's money, never
## more than the salaries it is still paying those players.
static func tapered_relief(second_season: int, nth: int, signing_salaries: int) -> int:
	var step := nth - 3
	if step < 0 or step >= SIGN_ON_TAPER.size():
		return 0
	return maxi(0, mini(signing_salaries, int(round(float(second_season) * float(SIGN_ON_TAPER[step])))))
