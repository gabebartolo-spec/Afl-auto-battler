class_name CoachPathway
extends RefCounted
## Retired players becoming coaches (Coaching Phase 4). Pure rules; GameState
## calls them at the moment a player retires, and CoachMarket moves the coach
## he becomes like any other.
##
## The chain: a player retires -> his playing career is captured as a compact
## snapshot -> one seeded roll decides, once, whether he goes into coaching ->
## if so he becomes a new coach record (C_P_<player id>, his own name and
## alias kept) who spends one to three seasons out of sight in the pathways
## -> then he joins the ordinary coaching market.
##
## Fame is not coaching ability. A playing career sets the chance he coaches,
## his starting reputation (which fades as he coaches) and a small edge at
## clubs he played for. His skills are rolled from his coach id alone: a
## 300-game champion and a 40-game battler start from the same spread.
##
## The `played` snapshot is shaped like a Career record (games, goals,
## stints, unknown), so Career's text helpers read it directly, plus:
##   draft    [year, pick, type] or [] when unknown
##   pos      his listed position; pos2 a second one, "" if none
##   retired  his last season as a player
##   honours  {"brownlow": n, "coleman": n}, in-game wins only, absent if none
## Nothing else from the player is kept: no attributes, ratings, contract,
## training, injuries or season stats.

const BASE_INTEREST := 0.06
const GAMES_150 := 0.02
const GAMES_250 := 0.02
const HONOUR := 0.01
const MAX_INTEREST := 0.15
const DEV_SPEC := 0.22            # enters as a development specialist
const WHOLE_GAME := 0.08          # 200+ gamers who coach the whole game
const PATHWAY_MIN := 1            # seasons out of sight before he is hireable
const PATHWAY_MAX := 3
const FAME_FADE_YEARS := 9        # seasons of coaching for fame to wash out
const SKILL_CENTRE := 62.0
const SKILL_SPREAD := 10.0        # sum of two uniforms: 52-72, most near 62
const SKILL_FLOOR := 55
const SKILL_CEIL := 72
const OVERLOADED := 12            # pool this far over target: wait a season more
const MAX_WAIT := 3


static func cid_for(player_id: String) -> String:
	return "C_P_" + player_id


## The playing career to keep, captured before the player leaves the lists.
static func snapshot(p: Dictionary, last_season: int, honour_roll: Array) -> Dictionary:
	var c := Career.of(p)
	var played := {
		"games": int(c.get("games", 0)),
		"goals": int(c.get("goals", 0)),
		"stints": (c.get("stints", []) as Array).duplicate(true),
		"unknown": (c.get("unknown", []) as Array).duplicate(true),
		"draft": [],
		"pos": str(p.get("own_role", p.get("role", ""))),
		"pos2": str(p.get("role2", "")),
		"retired": last_season,
	}
	if p.has("drafted_year"):
		played["draft"] = [int(p.get("drafted_year", 0)), int(p.get("drafted_pick", 0)),
				str(p.get("drafted_type", ""))]
	var h := honours(str(p.get("id", "")), honour_roll)
	if not h.is_empty():
		played["honours"] = h
	return played


## Brownlows and Colemans he won in this save (the honour roll names each
## winner by id). Premierships are left out: the game does not record who
## played in a Grand Final, and a guess is not an honour.
static func honours(player_id: String, honour_roll: Array) -> Dictionary:
	var out := {}
	for e in honour_roll:
		for key in ["brownlow", "coleman"]:
			var top: Array = (e as Dictionary).get(key, [])
			if not top.is_empty() and str((top[0] as Dictionary).get("id", "")) == player_id:
				out[key] = int(out.get(key, 0)) + 1
	return out


static func honour_count(played: Dictionary) -> int:
	var n := 0
	for k in (played.get("honours", {}) as Dictionary):
		n += int(played["honours"][k])
	return n


## The chance a retiree ever goes into coaching: modest, a little higher
## for a long career or a major award.
static func interest_chance(played: Dictionary) -> float:
	var games := int(played.get("games", 0))
	var ch := BASE_INTEREST
	if games >= 150:
		ch += GAMES_150
	if games >= 250:
		ch += GAMES_250
	ch += HONOUR * mini(2, honour_count(played))
	return minf(ch, MAX_INTEREST)


## Decided once, at retirement, from the career seed and his id: reloading
## never rerolls it.
static func interested(player_id: String, played: Dictionary, seed: int) -> bool:
	return _roll(seed, "interest|" + player_id) < interest_chance(played)


## Playing prominence, 0-24: what it adds to his starting reputation.
static func fame(played: Dictionary) -> int:
	var games := int(played.get("games", 0))
	var f := mini(16, games / 18)
	f += 4 * mini(2, honour_count(played))
	return mini(24, f)


## The coach he becomes. `p` is the retiring player; `last_season` his final
## season as a player.
static func make_coach(p: Dictionary, played: Dictionary, last_season: int, seed: int) -> Dictionary:
	var pid := str(p.get("id", ""))
	var cid := cid_for(pid)
	var r: Callable = func(k: String) -> float: return _roll(seed, "coach|%s|%s" % [cid, k])
	var skills := {}
	for k in Coaches.SKILLS:
		var v := SKILL_CENTRE + (float(r.call("s1" + k)) + float(r.call("s2" + k)) - 1.0) * SKILL_SPREAD
		skills[k] = clampi(int(round(v)), SKILL_FLOOR, SKILL_CEIL)
	var f := fame(played)
	var gap := PATHWAY_MIN + int(float(r.call("gap")) * float(PATHWAY_MAX - PATHWAY_MIN + 1))
	var age := int(float(p.get("age", 30.0)))
	return {
		"cid": cid,
		"real_name": str(p.get("real_name", "")),
		"generic_name": str(p.get("generic_name", p.get("name", ""))),
		"former_player_id": pid,
		"skills": skills,
		"spec": specialty(played, r),
		"status": "out",
		"club": "", "job": "",
		"free_from": last_season + 1 + gap,
		"stints": [],
		"former_sc": false,
		"note": "Coaching in the state leagues",
		"origin": "player",
		"played": played,
		"born": last_season - age,
		"rep": 22 + f + int(float(r.call("rep")) * 7.0),
		"fame": f,
		"fame_left": f,
		"since": last_season + 1,
		"fail_streak": 0, "protect_to": 0, "sacked_by": {}, "moves": [],
	}


## His playing position's line, a development specialist about one time in
## five, and now and then a long-career player who coaches the whole game.
static func specialty(played: Dictionary, r: Callable) -> String:
	if float(r.call("dev")) < DEV_SPEC:
		return "DEV"
	if int(played.get("games", 0)) >= 200 and float(r.call("whole")) < WHOLE_GAME:
		return ""
	var pos := str(played.get("pos", ""))
	return pos if pos in ["MID", "RUCK", "FWD", "DEF"] else "MID"


## His pathway is over: from here he is an ordinary coach looking for work.
## Returns false when the market is overloaded and he waits a season more.
static func enter_market(c: Dictionary, year: int, pool: int, target: int) -> bool:
	var waited := int(c.get("pathway_wait", 0))
	if pool >= target + OVERLOADED and waited < MAX_WAIT:
		c["pathway_wait"] = waited + 1
		c["free_from"] = int(c.get("free_from", year + 1)) + 1
		return false
	c["status"] = "free"
	c["note"] = ""
	c["unemployed_since"] = year + 1
	return true


## True while he is still in the pathways, out of sight.
static func in_pathway(c: Dictionary) -> bool:
	return str(c.get("origin", "")) == "player" and str(c.get("status", "")) == "out"


## The club he played most games for ("" if none).
static func main_club(played: Dictionary) -> String:
	var games := {}
	for s in played.get("stints", []):
		games[str(s[0])] = int(games.get(str(s[0]), 0)) + int(s[3])
	var best := ""
	for code in games:
		if best == "" or int(games[code]) > int(games[best]):
			best = str(code)
	return best


static func played_for(played: Dictionary, club: String) -> bool:
	for s in played.get("stints", []):
		if str(s[0]) == club and int(s[3]) > 0:
			return true
	return false


static func games_for(played: Dictionary, club: String) -> int:
	var n := 0
	for s in played.get("stints", []):
		if str(s[0]) == club:
			n += int(s[3])
	return n


## "Midfielder", "ruckman", ... for news copy.
static func position_word(played: Dictionary) -> String:
	return str({"MID": "midfielder", "RUCK": "ruckman", "FWD": "forward", "DEF": "defender"}
			.get(str(played.get("pos", "")), "player"))


## "Pick 31, 2027 national draft", "" when unknown.
static func draft_line(played: Dictionary) -> String:
	var d: Array = played.get("draft", [])
	if d.size() < 3 or int(d[0]) <= 0:
		return ""
	var kind := str({"midseason": "mid-season", "preseason": "pre-season"}.get(str(d[2]), str(d[2]))) \
			.to_lower().replace("_", "-")
	var what := "%s draft" % kind if kind != "" else "draft"
	if int(d[1]) > 0:
		return "Pick %d, %d %s" % [int(d[1]), int(d[0]), what]
	return "%d %s" % [int(d[0]), what]


static func _roll(seed: int, key: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [seed, key])
	return rng.randf()
