class_name CoachMarket
extends RefCounted
## The coaching world moving (Coaching Phase 3): one offseason at a time.
## Pure rules over GameState.coaches - the same canonical records Coaches.gd
## describes - driven once at the close of each season.
##
## An offseason, in order:
##   1. coaches develop and age; the population is re-anchored
##   2. reputations move with results and service
##   3. coaches retire (from 64, certainly by 70)
##   4. AI senior coaches are judged: contract expiry, sackings (after two
##      failed seasons, not in a first season, not while premiership-
##      protected, at most MAX_SACKINGS a year)
##   5. expansion clubs open all six jobs
##   6. every vacancy is filled, senior jobs first; a promotion elsewhere
##      opens the job it leaves, so a chain resolves top-down and stops
##      (each coach moves once, and only upward)
##   7. long-unemployed coaches leave; the notable are archived
##   8. the external pool is topped up with generated coaches
##
## Former players (CoachPathway) wait out of sight in the pathways, then join
## step 6 as ordinary candidates: only their starting reputation, a small
## edge at clubs they played for and their biography set them apart.
##
## Your club: no senior coach record (you are him). Your assistants can be
## poached for a genuine promotion (at most MAX_POACHED_FROM_YOU a year);
## those vacancies wait for you (shortlist, appoint or auto-fill) and are
## auto-filled when the next season starts.
##
## Determinism: every roll is seeded from the career seed, the year and
## what is being decided, so reloading never rerolls an offseason.

const LEVEL := {"SC": 4, "SA": 3, "MID": 2, "FWD": 2, "DEF": 2, "DEV": 1}
## Vacancies are filled top-down, so a promotion's vacancy is filled after it.
const FILL_ORDER := ["SC", "SA", "MID", "FWD", "DEF", "DEV"]

const MIN_TENURE := 2               # seasons in a role before an ordinary promotion
const MAX_SACKINGS := 5            # league-wide senior coach sackings per offseason
const PREMIER_PROTECTION := 3      # seasons a premiership coach cannot be sacked
const SACKED_CLUB_COOLDOWN := 5    # seasons before a sacked coach returns to that club
const SACKED_SC_PENALTY_YEARS := 3
const UNEMPLOYED_YEARS := 4        # then an unemployed coach leaves the game
const MAX_POACHED_FROM_YOU := 2
## AI clubs and expiring assistants: kept at this reputation, otherwise kept
## this often.
const ASSISTANT_KEEP_REP := 60
const ASSISTANT_RENEW := 0.6
const NEW_SC_REPLACES_SA := 0.5
const RETIRE_FROM := 64
const RETIRE_BY := 70
const POOL_MIN := 34               # available + away coaches kept in the market
const POOL_TOP := 40
const POOL_FLOOR := 20             # generated top-up never lets the pool fall below this
const NEWS_CAP := 8

## Hiring score weights (sum 1.0 before penalties).
const W_FIT := 0.45
const W_REP := 0.25
const W_EXP := 0.10
const W_PATH := 0.10
const W_LINK := 0.05
const W_RAND := 0.10
## The club-link share a former player of the club carries (of W_LINK).
const PLAYED_LINK := 0.5
## Former-player coaches worth keeping in the archive: coached this long, or
## played this many games, or this many for your club.
const EX_PLAYER_ARCHIVE_SEASONS := 3
const EX_PLAYER_ARCHIVE_GAMES := 200
const MY_PLAYER_GAMES := 100

## Skill scale and the population's anchor.
const SKILL_MIN := 55
const SKILL_MAX := 92
const ANCHOR_MEAN := 70.0


# ---------------------------------------------------------------------------
# Move rules
# ---------------------------------------------------------------------------
static func level(job: String) -> int:
	return int(LEVEL.get(job, 0))


## "promotion", "lateral" or "demotion": from a job to another.
static func move_kind(from_job: String, to_job: String) -> String:
	var a := level(from_job)
	var b := level(to_job)
	if b > a:
		return "promotion"
	if b == a:
		return "lateral"
	return "demotion"


static func tenure(c: Dictionary, year: int) -> int:
	return year - int(c.get("since", year)) + 1


## Will this coach take this job? `year` is the season just finished.
static func would_take(c: Dictionary, club: String, job: String, year: int) -> bool:
	var status := str(c.get("status", ""))
	if status == "club":
		# Employed coaches only move up, and not straight out of a new role.
		if move_kind(str(c["job"]), job) != "promotion":
			return false
		if str(c.get("club", "")) == club and job == "SC":
			pass  # internal succession: tenure still applies below
		if tenure(c, year) < MIN_TENURE and not (job == "SC" and exceptional_for_sc(c)):
			return false
		# Not every step up appeals: settled below senior level, about half do.
		if level(job) < 4 and _roll(0, "keen|%d|%s|%s|%s" % [year, club, job, str(c.get("cid", ""))]) < 0.5:
			return false
		# A development coach does not jump to a senior job.
		if str(c["job"]) == "DEV" and level(job) >= 3:
			return false
		# Line coaches reach senior coach only as an exception.
		if job == "SC" and str(c["job"]) != "SA" and not exceptional_for_sc(c):
			return false
	elif status == "out" and int(c.get("free_from", 0)) > year + 1:
		return false
	elif status != "free" and status != "away" and status != "out":
		return false
	# Sacked here recently: not back yet.
	var sacked: Dictionary = c.get("sacked_by", {})
	if sacked.has(club) and year + 1 - int(sacked[club]) < SACKED_CLUB_COOLDOWN:
		return false
	if job == "SC" and not sc_eligible(c, year):
		return false
	return true


## Credible for a senior coaching job.
static func sc_eligible(c: Dictionary, year: int) -> bool:
	if bool(c.get("former_sc", false)):
		return true
	var status := str(c.get("status", ""))
	if status == "club" and str(c.get("job", "")) == "SA" and tenure(c, year) >= MIN_TENURE:
		return true
	if held_level(c) >= 3 and int(c.get("rep", 0)) >= 55:
		return true
	return exceptional_for_sc(c)


## An exceptional line coach or outsider: big reputation and a senior coach's fit.
static func exceptional_for_sc(c: Dictionary) -> bool:
	return int(c.get("rep", 0)) >= 72 and Coaches.role_fit(c, "SC") >= 74.0 \
			and str(c.get("job", "")) != "DEV"


## The highest job level he has held (from his stints, his current job and
## senior coaching before the records began).
static func held_level(c: Dictionary) -> int:
	var best := level(str(c.get("job", ""))) if str(c.get("status", "")) == "club" else 0
	for s in c.get("stints", []):
		best = maxi(best, level(str(s[1])))
	if bool(c.get("former_sc", false)):
		best = 4
	return best


# ---------------------------------------------------------------------------
# Hiring score
# ---------------------------------------------------------------------------
## How a club rates a candidate for a job: role fit first, then reputation,
## experience at that level, a natural next step, a small club link, and a
## seeded dash of chance that never outweighs a big gap in fit.
static func hire_score(c: Dictionary, club: String, job: String, year: int, seed: int) -> float:
	var fit := clampf((Coaches.role_fit(c, job) - 55.0) / 37.0, 0.0, 1.0)
	var rep := clampf(float(c.get("rep", 40)) / 100.0, 0.0, 1.0)
	var held := held_level(c)
	var lv := level(job)
	var exp := 1.0 if held >= lv else (0.5 if held == lv - 1 else 0.0)
	var path := 0.0
	var employed := str(c.get("status", "")) == "club"
	var cur := level(str(c.get("job", ""))) if employed else 0
	if employed and cur == lv - 1:
		path = 1.0
	var link := 0.0
	# A former player of the club: a small edge, never more than a coaching
	# connection there.
	if CoachPathway.played_for(c.get("played", {}), club):
		link = PLAYED_LINK
	if employed and str(c.get("club", "")) == club:
		link = 1.0
		# Internal succession: a settled senior assistant stepping up.
		if job == "SC" and str(c["job"]) == "SA" and tenure(c, year) >= MIN_TENURE:
			path += 0.3
	else:
		for s in c.get("stints", []):
			if str(s[0]) == club:
				link = maxf(link, 0.6)
	var score := W_FIT * fit + W_REP * rep + W_EXP * exp + W_PATH * path + W_LINK * link
	# A senior coach sacked in the last few years is a harder sell.
	if job == "SC" and year + 1 - int(c.get("last_sacked", -99)) <= SACKED_SC_PENALTY_YEARS:
		score -= 0.06
	score += W_RAND * _roll(seed, "hire|%d|%s|%s|%s" % [year, club, job, str(c["cid"])])
	return score


static func _roll(seed: int, key: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [seed, key])
	return rng.randf()


# ---------------------------------------------------------------------------
# Record upkeep
# ---------------------------------------------------------------------------
## New Phase 3 fields with safe defaults (older saves and the seed).
static func ensure_fields(c: Dictionary, year: int) -> void:
	var cid := str(c.get("cid", ""))
	if not c.has("born"):
		# The seed has no birthdays: a steady age from the record, senior
		# coaches a little older on average.
		var senior := str(c.get("job", "")) == "SC" or bool(c.get("former_sc", false))
		var base := 42 if senior else 32
		c["born"] = year - (base + int(_roll(7, "age|" + cid) * (14.0 if senior else 22.0)))
	if not c.has("rep"):
		var lv := held_level(c)
		var r: int = [30, 38, 46, 56, 66][clampi(lv, 0, 4)]
		c["rep"] = int(r + _roll(7, "rep|" + cid) * 12.0)
	if not c.has("since"):
		c["since"] = year - 1 if str(c.get("status", "")) == "club" else year
	if str(c.get("job", "")) == "SC" and str(c.get("status", "")) == "club":
		if not c.has("sc_since"):
			c["sc_since"] = year - 1
		if not c.has("contract_to"):
			c["contract_to"] = year + int(_roll(7, "con|" + cid) * 3.0)
	elif str(c.get("status", "")) == "club" and not c.has("contract_to"):
		# Assistants' terms are staggered: about a third end each season.
		c["contract_to"] = year + int(_roll(7, "acon|" + cid) * 3.0)
	for k in ["fail_streak", "protect_to"]:
		if not c.has(k):
			c[k] = 0
	if not c.has("sacked_by"):
		c["sacked_by"] = {}
	if not c.has("moves"):
		c["moves"] = []
	if not c.has("unemployed_since") and str(c.get("status", "")) != "club":
		c["unemployed_since"] = year


static func age(c: Dictionary, year: int) -> int:
	return year - int(c.get("born", year - 45))


static func _close_stint(c: Dictionary, year: int) -> void:
	for s in c.get("stints", []):
		if int(s[3]) == 0:
			s[3] = year


static func _leave_job(c: Dictionary, year: int, status := "free") -> void:
	_close_stint(c, year)
	c["status"] = status
	c["club"] = ""
	c["job"] = ""
	c["unemployed_since"] = year + 1
	c.erase("contract_to")


## Put `c` in `club`'s `job` from next season (year + 1).
static func _appoint(c: Dictionary, club: String, job: String, year: int, seed: int) -> void:
	if str(c.get("status", "")) == "club":
		_close_stint(c, year)
	c["status"] = "club"
	c["club"] = club
	c["job"] = job
	c["since"] = year + 1
	c["note"] = ""
	c.erase("unemployed_since")
	(c["stints"] as Array).append([club, job, year + 1, 0])
	(c["moves"] as Array).append(year + 1)
	if job == "SC":
		c["former_sc"] = true
		c["sc_since"] = year + 1
		c["fail_streak"] = 0
		c["contract_to"] = year + 2 + int(_roll(seed, "term|%d|%s" % [year, club]) * 3.0)
	else:
		# An assistant signs for two or three seasons.
		c["contract_to"] = year + 2 + int(_roll(seed, "aterm|%d|%s" % [year, str(c.get("cid", ""))]) * 2.0)


# ---------------------------------------------------------------------------
# A rival's approach for one of your coaches (director, 2026-10-07)
# ---------------------------------------------------------------------------
## Not a bidding war: you answer with an opportunity, and he weighs it against
## the job he has been offered. The chance he stays, by what you offer and
## the level of the rival job (SC 4 .. DEV 1); his years with you add to it.
## A senior coach's job is hard to turn down; a sideways move is not.
const STAY_CHANCE := {
	"promote": {4: 0.30, 3: 0.65, 2: 0.85, 1: 0.90},
	"stay": {4: 0.10, 3: 0.25, 2: 0.35, 1: 0.45},
}
const STAY_LOYALTY_PER_YEAR := 0.03
const STAY_LOYALTY_MAX := 0.10


static func stay_chance(c: Dictionary, offer: String, rival_job: String, year: int) -> float:
	var by: Dictionary = STAY_CHANCE.get(offer, {})
	var p := float(by.get(level(rival_job), 0.0))
	p += minf(STAY_LOYALTY_MAX, STAY_LOYALTY_PER_YEAR * float(tenure(c, year)))
	return clampf(p, 0.0, 0.95)


## Does he stay? Seeded, so a reload answers the same.
static func stays(c: Dictionary, offer: String, rival_job: String, year: int, seed: int) -> bool:
	return _roll(seed, "retain|%d|%s" % [year, str(c.get("cid", ""))]) < stay_chance(c, offer, rival_job, year)


## Your coach steps up to senior assistant at your club, from next season.
static func promote_to_sa(c: Dictionary, club: String, year: int, seed: int) -> void:
	_appoint(c, club, "SA", year, seed)


# ---------------------------------------------------------------------------
# The offseason
# ---------------------------------------------------------------------------
## One offseason. `ctx`:
##   coaches     cid -> record (mutated in place)
##   archive     cid -> slim record of notable departed coaches (mutated)
##   year        the season just finished
##   my_club     your club ("" in a probe with no human club)
##   clubs       clubs active next season (expansion clubs included)
##   results     club -> {"met": bool, "severe": bool, "finals": bool}
##   premier     this season's premier
##   seed        the career seed
##   release     cids you released this offseason (already free)
##   protected   cids of your coaches no rival may take this offseason: every
##               one you kept or were never asked about (GameState approaches)
##   promised    cid -> [club, job]: your coaches leaving for a job agreed in
##               the finals; that job is his when it opens, and no other
## Returns {"news": [...], "vacancies": [{job, reason}], "log": {...}} where
## vacancies are your club's jobs left for you to fill.
static func offseason(ctx: Dictionary) -> Dictionary:
	var coaches: Dictionary = ctx["coaches"]
	var archive: Dictionary = ctx.get("archive", {})
	var year := int(ctx["year"])
	var my_club := str(ctx.get("my_club", ""))
	var clubs: Array = ctx["clubs"]
	var results: Dictionary = ctx.get("results", {})
	var seed := int(ctx.get("seed", 0))
	var news: Array = []   # [priority, text]
	var log := {"sackings": 0, "retired": 0, "expired": 0, "sc_changes": 0, "internal_sc": 0,
			"promotions": 0, "poached_from_you": 0, "generated": 0, "emergency": 0,
			"line_to_sc": 0, "archived": 0, "pruned": 0}
	var my_vacancies: Array = []
	var kept_by_you: Dictionary = ctx.get("protected", {})
	var promised: Dictionary = ctx.get("promised", {})

	for cid in coaches:
		ensure_fields(coaches[cid], year)

	_develop(coaches, year, seed)
	_reputation(coaches, results, str(ctx.get("premier", "")), year)

	# Retirements.
	for cid in coaches.keys():
		var c: Dictionary = coaches[cid]
		var a := age(c, year + 1)
		var go := a >= RETIRE_BY or (a >= RETIRE_FROM
				and _roll(seed, "retire|%d|%s" % [year, cid]) < float(a - RETIRE_FROM + 1) * 0.12)
		if not go:
			continue
		var was_club := str(c.get("club", ""))
		var was_job := str(c.get("job", ""))
		if str(c.get("status", "")) == "club":
			_leave_job(c, year, "retired")
			if was_club == my_club:
				my_vacancies.append({"job": was_job, "reason": "%s has retired." % _name(c)})
				news.append([1, "Your %s, %s, has retired." % [_job_word(was_job), _name(c)]])
			elif was_job == "SC":
				news.append([2, "%s coach %s has retired." % [GameDB.club_name(was_club), _name(c)]])
		c["status"] = "retired"
		log["retired"] += 1

	# Senior coaches: contract expiry and sackings.
	var sack_list: Array = []
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) != "club" or str(c.get("job", "")) != "SC":
			continue
		var club := str(c["club"])
		if club == my_club or not results.has(club):
			continue
		var r: Dictionary = results[club]
		var first := int(c.get("sc_since", year)) >= year
		if bool(r.get("met", true)):
			c["fail_streak"] = 0
		elif not first:
			c["fail_streak"] = int(c.get("fail_streak", 0)) + 1
		if str(ctx.get("premier", "")) == club:
			c["protect_to"] = year + PREMIER_PROTECTION
		var protected := int(c.get("protect_to", 0)) > year
		var fails := int(c["fail_streak"])
		if not protected and not first and (fails >= 2 or (fails >= 1 and bool(r.get("severe", false))
				and year - int(c.get("sc_since", year)) >= 2)):
			sack_list.append([fails + (1 if bool(r.get("severe", false)) else 0), cid])
		elif int(c.get("contract_to", year + 1)) <= year:
			var roll := _roll(seed, "renew|%d|%s" % [year, cid])
			var keep := bool(r.get("met", false)) or int(c.get("rep", 0)) >= 70 or roll < 0.4
			if keep:
				c["contract_to"] = year + 2 + int(_roll(seed, "reterm|%d|%s" % [year, cid]) * 3.0)
			else:
				_leave_job(c, year)
				log["expired"] += 1
				news.append([2, "%s have not renewed %s's contract." % [GameDB.club_name(club), _name(c)]])
	# Assistants at the end of their term (AI clubs; yours wait for you):
	# a club keeps a well-regarded one, and most of the rest.
	for cid in coaches.keys():
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) != "club" or str(c.get("job", "")) == "SC" \
				or str(c.get("club", "")) == my_club or int(c.get("contract_to", year + 1)) > year:
			continue
		var keep := int(c.get("rep", 0)) >= ASSISTANT_KEEP_REP \
				or _roll(seed, "arenew|%d|%s" % [year, cid]) < ASSISTANT_RENEW
		if keep:
			c["contract_to"] = year + 2 + int(_roll(seed, "aterm|%d|%s" % [year, cid]) * 2.0)
		else:
			_leave_job(c, year)
			log["assistant_expired"] = int(log.get("assistant_expired", 0)) + 1
	sack_list.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for i in range(mini(MAX_SACKINGS, sack_list.size())):
		var c: Dictionary = coaches[str(sack_list[i][1])]
		var club := str(c["club"])
		(c["sacked_by"] as Dictionary)[club] = year
		c["last_sacked"] = year
		c["rep"] = maxi(20, int(c.get("rep", 50)) - 8)
		_leave_job(c, year)
		log["sackings"] += 1
		news.append([2, "%s have sacked senior coach %s." % [GameDB.club_name(club), _name(c)]])

	# Coaches you released are already free; nothing else to do for them.

	# Former players whose pathway years are up join the market.
	_enter_from_pathway(coaches, year, my_club, clubs, news, log)

	# Fill every vacancy, senior jobs first. A promotion from another club
	# opens his old job, which joins the queue; each coach moves at most once.
	var moved := {}
	var poached_from_you := 0
	var guard := 0
	while guard < 2000:
		guard += 1
		var vac := _next_vacancy(coaches, clubs, my_club)
		if vac.is_empty():
			break
		var club := str(vac["club"])
		var job := str(vac["job"])
		if club == my_club:
			# Your jobs wait for you; they are not filled here.
			if not _has_pending(my_vacancies, job):
				my_vacancies.append({"job": job, "reason": ""})
			_block(coaches, club, job)
			continue
		var best := {}
		var best_score := -INF
		for cid in promised:
			var deal: Array = promised[cid]
			if str(deal[0]) == club and str(deal[1]) == job and not moved.has(cid) and coaches.has(cid):
				best = coaches[cid]
				best_score = INF
		for cid in coaches:
			if best_score == INF:
				break
			var c: Dictionary = coaches[cid]
			if moved.has(cid) or promised.has(cid) or not would_take(c, club, job, year):
				continue
			if str(c.get("status", "")) == "club" and str(c["club"]) == my_club \
					and (poached_from_you >= MAX_POACHED_FROM_YOU or kept_by_you.has(cid)):
				continue
			var s := hire_score(c, club, job, year, seed)
			if s > best_score:
				best_score = s
				best = c
		if best.is_empty():
			best = _generate(coaches, year, seed, log, job)
			log["emergency"] += 1
		var from_club := str(best.get("club", "")) if str(best.get("status", "")) == "club" else ""
		var from_job := str(best.get("job", "")) if from_club != "" else ""
		var outside_sc := job == "SC" and from_club != club
		var first_job := (best.get("stints", []) as Array).is_empty()
		_appoint(best, club, job, year, seed)
		if first_job and str(best.get("former_player_id", "")) != "" and job != "SC":
			_first_job_news(best, club, job, my_club, news)
		moved[str(best["cid"])] = true
		if from_club != "":
			log["promotions"] += 1
			if from_club == my_club:
				poached_from_you += 1
				log["poached_from_you"] += 1
				my_vacancies.append({"job": from_job, "reason": "%s left to become %s at %s." % [
						_name(best), _job_phrase(job), GameDB.club_name(club)]})
				news.append([1, "Your %s, %s, has accepted the %s role at %s." % [
						_job_word(from_job), _name(best), _job_word(job), GameDB.club_name(club)]])
		if job == "SC":
			log["sc_changes"] += 1
			if from_club == club:
				log["internal_sc"] += 1
				news.append([2, "%s have promoted %s to senior coach." % [GameDB.club_name(club), _name(best)]])
			else:
				if from_job in ["MID", "FWD", "DEF"]:
					log["line_to_sc"] += 1
				news.append([2, "%s have appointed %s as senior coach." % [GameDB.club_name(club), _name(best)]])
			# A new senior coach from outside may bring his own assistant.
			if outside_sc and _roll(seed, "sa|%d|%s" % [year, club]) < NEW_SC_REPLACES_SA:
				for cid in coaches:
					var sa: Dictionary = coaches[cid]
					if str(sa.get("status", "")) == "club" and str(sa["club"]) == club \
							and str(sa["job"]) == "SA" and not moved.has(cid):
						_leave_job(sa, year)
						break
		elif GameDB.enter_year(club) == year + 1:
			news.append([3, "%s appoint %s (%s)." % [GameDB.club_name(club), _name(best), _job_word(job)]])
	_unblock(coaches)
	# A job agreed in the finals that never came open: he stays where he is.
	for cid in promised:
		if not moved.has(cid) and coaches.has(cid):
			news.append([1, "%s's move to %s fell through when the job never came up. He stays with you." % [
					_name(coaches[cid]), GameDB.club_name(str((promised[cid] as Array)[0]))]])

	_prune(coaches, archive, year, my_club, log)
	_top_up(coaches, year, seed, log, clubs)

	news.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var texts: Array = []
	for n in news.slice(0, NEWS_CAP):
		texts.append(str(n[1]))
	return {"news": texts, "vacancies": my_vacancies, "log": log}


## Clubs with nobody on staff - a created club in a new career's first season,
## or one an older save brought in that way - are staffed the way an expansion
## club is before it plays (step 6): from coaches out of work, best fit first,
## a newly made coach when nobody suits. Nobody is taken from another club, and
## your senior coach's job is yours. `year` is the season before the one about
## to be played. Returns what was filled: [{club, job, cid}].
static func staff_new_clubs(coaches: Dictionary, clubs: Array, my_club: String, year: int, seed: int) -> Array:
	var filled := []
	var log := {"generated": 0}
	for club in clubs:
		if not Coaches.staff(coaches, club).is_empty():
			continue
		for job in FILL_ORDER:
			if job == "SC" and club == my_club:
				continue
			var best := {}
			var best_score := -INF
			for cid in coaches:
				var c: Dictionary = coaches[cid]
				if str(c.get("status", "")) == "club" or not would_take(c, club, job, year):
					continue
				var probe := c.duplicate(true)
				ensure_fields(probe, year + 1)
				var s := hire_score(probe, club, job, year, seed)
				if s > best_score:
					best_score = s
					best = c
			if best.is_empty():
				best = _generate(coaches, year, seed, log, job)
			ensure_fields(best, year + 1)
			_appoint(best, club, job, year, seed)
			filled.append({"club": club, "job": job, "cid": str(best["cid"])})
	return filled


## The highest vacancy left: a job at an active club nobody holds.
static func _next_vacancy(coaches: Dictionary, clubs: Array, my_club: String) -> Dictionary:
	var held := {}
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) == "club" or str(c.get("status", "")) == "blocked":
			held["%s|%s" % [str(c["club"]), str(c["job"])]] = true
	for job in FILL_ORDER:
		for club in clubs:
			if job == "SC" and club == my_club:
				continue
			if not held.has("%s|%s" % [club, job]):
				return {"club": club, "job": job}
	return {}


## Your vacancies are held open while the league fills around them: a
## placeholder record, removed again before returning.
static func _block(coaches: Dictionary, club: String, job: String) -> void:
	coaches["__block_%s_%s" % [club, job]] = {"cid": "__block", "status": "blocked",
			"club": club, "job": job, "skills": {}, "stints": []}


static func _unblock(coaches: Dictionary) -> void:
	for cid in coaches.keys():
		if str(cid).begins_with("__block_"):
			coaches.erase(cid)


static func _has_pending(vacancies: Array, job: String) -> bool:
	for v in vacancies:
		if str(v["job"]) == job:
			return true
	return false


# ---------------------------------------------------------------------------
# Development, reputation, departures, generation
# ---------------------------------------------------------------------------
## A season in a job: the skill the job leans on grows 0-2, another 0-1,
## slower near the top; from 60 a coach slowly declines. Coaches out of
## work drift a little. Then the population is re-anchored so the average
## stays in the low 70s and Elite stays rare.
static func _develop(coaches: Dictionary, year: int, seed: int) -> void:
	var main_for := {"SC": "tactics", "SA": "manage", "MID": "teach", "FWD": "teach",
			"DEF": "teach", "DEV": "teach"}
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		var status := str(c.get("status", ""))
		if status == "retired" or CoachPathway.in_pathway(c):
			continue
		var sk: Dictionary = c["skills"]
		var r: Callable = func(k: String) -> float: return _roll(seed, "dev|%d|%s|%s" % [year, cid, k])
		if status == "club":
			var main := str(main_for.get(str(c["job"]), "teach"))
			if str(c["job"]) == "DEV" and r.call("devmix") < 0.4:
				main = "manage"
			var g := int(r.call("main") * 2.5)
			if int(sk.get(main, 70)) >= 80 and r.call("slow") < 0.65:
				g = maxi(0, g - 1)
			sk[main] = int(sk.get(main, 70)) + g
			var others := ["teach", "tactics", "manage"]
			others.erase(main)
			var other := str(others[int(r.call("which") * 2.0)])
			sk[other] = int(sk.get(other, 70)) + int(r.call("other") * 2.0)
		elif r.call("drift") < 0.3:
			var k := str(["teach", "tactics", "manage"][int(r.call("dk") * 3.0)])
			sk[k] = int(sk.get(k, 70)) - 1
		if age(c, year + 1) >= 60:
			for k in ["teach", "tactics", "manage"]:
				if r.call("old" + k) < 0.4:
					sk[k] = int(sk.get(k, 70)) - 1
	# Re-anchor: shift the active population's mean back to ANCHOR_MEAN.
	var total := 0.0
	var n := 0
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) == "retired" or CoachPathway.in_pathway(c):
			continue
		for k in ["teach", "tactics", "manage"]:
			total += float(c["skills"].get(k, 70))
			n += 1
	var shift := 0.0
	if n > 0:
		shift = ANCHOR_MEAN - total / float(n)
	var step := int(round(clampf(shift, -1.0, 1.0)))
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if CoachPathway.in_pathway(c):
			continue
		for k in ["teach", "tactics", "manage"]:
			c["skills"][k] = clampi(int(c["skills"].get(k, 70)) + step, SKILL_MIN, SKILL_MAX)


## Reputation follows results for senior coaches and service for assistants;
## it opens doors, it does not make anyone a better coach.
static func _reputation(coaches: Dictionary, results: Dictionary, premier: String, year: int) -> void:
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		var status := str(c.get("status", ""))
		if CoachPathway.in_pathway(c):
			continue   # out of sight in the pathways: nothing to judge yet
		var rep := int(c.get("rep", 40))
		# A playing name opens early doors; over his first seasons in coaching
		# it washes out and his coaching record takes over.
		var fame_left := int(c.get("fame_left", 0))
		if fame_left > 0:
			var d := mini(fame_left, maxi(1, int(ceil(float(c.get("fame", 0)) / float(CoachPathway.FAME_FADE_YEARS)))))
			rep -= d
			c["fame_left"] = fame_left - d
		if status == "club":
			var club := str(c["club"])
			var r: Dictionary = results.get(club, {})
			if str(c["job"]) == "SC":
				rep += 4 if bool(r.get("met", false)) else -4
				if bool(r.get("finals", false)):
					rep += 2
				if premier == club:
					rep += 10
			else:
				rep += 2 if str(c["job"]) == "SA" else 1
				if premier == club:
					rep += 2
		elif status == "free" or status == "away" or status == "out":
			rep -= 2
		c["rep"] = clampi(rep, 10, 99)


## Coaches out of work for UNEMPLOYED_YEARS, and the retired, leave the
## records; the notable are kept in the archive.
static func _prune(coaches: Dictionary, archive: Dictionary, year: int, my_club: String, log: Dictionary) -> void:
	for cid in coaches.keys():
		var c: Dictionary = coaches[cid]
		var status := str(c.get("status", ""))
		var gone := status == "retired"
		if (status == "free" or status == "away") \
				and year + 1 - int(c.get("unemployed_since", year + 1)) >= UNEMPLOYED_YEARS:
			gone = true
		if not gone:
			continue
		if _notable(c, my_club):
			archive[cid] = {"cid": cid, "real_name": c.get("real_name", ""),
					"generic_name": c.get("generic_name", ""), "stints": c.get("stints", []),
					"former_sc": c.get("former_sc", false), "left": year + 1,
					"former_player_id": c.get("former_player_id", ""), "spec": c.get("spec", ""),
					"played": c.get("played", {})}
			log["archived"] += 1
		else:
			log["pruned"] += 1
		coaches.erase(cid)


static func _notable(c: Dictionary, my_club: String) -> bool:
	if bool(c.get("former_sc", false)) or str(c.get("origin", "")) == "seed":
		return true
	var seasons := 0
	for s in c.get("stints", []):
		if str(s[0]) == my_club:
			return true
		seasons += maxi(1, int(s[3]) - int(s[2]) + 1) if int(s[3]) > 0 else 1
	# A former player's two careers together are worth keeping sooner: a few
	# seasons coaching, a long playing career, or one of your own players.
	var played: Dictionary = c.get("played", {})
	if not played.is_empty():
		if seasons >= EX_PLAYER_ARCHIVE_SEASONS or int(played.get("games", 0)) >= EX_PLAYER_ARCHIVE_GAMES:
			return true
		if my_club != "" and CoachPathway.games_for(played, my_club) >= MY_PLAYER_GAMES:
			return true
	return seasons >= 8


## Keep the market deep: generated state-league and pathway coaches when the
## available/away pool runs short (more in an expansion year).
static func _top_up(coaches: Dictionary, year: int, seed: int, log: Dictionary, clubs: Array) -> void:
	var pool := 0
	for cid in coaches:
		var s := str(coaches[cid].get("status", ""))
		if s == "free" or s == "away":
			pool += 1
	var target := POOL_TOP
	for club in clubs:
		if GameDB.enter_year(club) == year + 2:
			target += 8   # next year's new club will hire six
	# Generated coaches are the top-up, not a fixed supply: former players
	# coming through the pathways take their place as the pipeline fills.
	var coming := 0
	for cid in coaches:
		if CoachPathway.in_pathway(coaches[cid]):
			coming += 1
	target = maxi(POOL_FLOOR, target - coming)
	if pool >= mini(POOL_MIN, target) and pool >= target - 6:
		return
	while pool < target:
		_generate(coaches, year, seed, log, "")
		pool += 1


## A generated coach from outside the AFL: 32-48, skills 58-74, a plausible
## specialty. `for_job` biases the specialty when he is made to fill a job.
static func _generate(coaches: Dictionary, year: int, seed: int, log: Dictionary, for_job: String) -> Dictionary:
	var n := 0
	while coaches.has("C_G%d_%d" % [year + 1, n]):
		n += 1
	var cid := "C_G%d_%d" % [year + 1, n]
	var r: Callable = func(k: String) -> float: return _roll(seed, "gen|%s|%s" % [cid, k])
	var specs := ["MID", "MID", "RUCK", "FWD", "FWD", "DEF", "DEF", "DEV", "DEV", ""]
	var spec := str(specs[int(r.call("spec") * specs.size())])
	match for_job:
		"MID":
			spec = "MID"
		"FWD", "DEF", "DEV":
			spec = for_job
		"SC", "SA":
			spec = ""
	# New to AFL coaching, like a former player out of the pathways: the same
	# starting spread (52-72, most near 62), so neither is favoured.
	var sk := {}
	for k in ["teach", "tactics", "manage"]:
		var v := CoachPathway.SKILL_CENTRE + (float(r.call("s1" + k)) + float(r.call("s2" + k)) - 1.0) * CoachPathway.SKILL_SPREAD
		sk[k] = clampi(int(round(v)), CoachPathway.SKILL_FLOOR, CoachPathway.SKILL_CEIL)
	var c := {
		"cid": cid, "real_name": "", "generic_name": _gen_name(cid, seed),
		"former_player_id": "", "spec": spec,
		"skills": sk,
		"status": "free" if r.call("status") < 0.65 else "away",
		"club": "", "job": "", "free_from": 0, "stints": [], "former_sc": false,
		"note": "" , "origin": "generated", "played": {},
		"born": year + 1 - (32 + int(r.call("age") * 17.0)),
		"rep": 25 + int(r.call("rep") * 25.0),
		"since": year + 1, "unemployed_since": year + 1,
		"fail_streak": 0, "protect_to": 0, "sacked_by": {}, "moves": [],
	}
	if str(c["status"]) == "away":
		c["note"] = "Coaching in the state league"
	if for_job == "SC" or for_job == "SA":
		c["rep"] = 60
		c["skills"]["tactics"] = maxi(int(c["skills"]["tactics"]), 70)
		c["skills"]["manage"] = maxi(int(c["skills"]["manage"]), 70)
	coaches[cid] = c
	log["generated"] = int(log.get("generated", 0)) + 1
	return c


static func _gen_name(cid: String, seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("name|%d|%s" % [seed, cid])
	var first: String = Coaches.COACH_FIRST_NAMES[rng.randi_range(0, Coaches.COACH_FIRST_NAMES.size() - 1)]
	var last: String = GameDB.FICTIONAL_LAST_NAMES[rng.randi_range(0, GameDB.FICTIONAL_LAST_NAMES.size() - 1)]
	return "%s %s" % [first, last]


static func _name(c: Dictionary) -> String:
	return GameDB.player_display_name(c)


static func _job_word(job: String) -> String:
	return str(Coaches.JOB_LABEL.get(job, job)).to_lower() + ("" if job == "SC" or job == "SA" else " coach")


static func _job_phrase(job: String) -> String:
	return _job_word(job)


# ---------------------------------------------------------------------------
# Former players
# ---------------------------------------------------------------------------
## Former players whose pathway years end this offseason become ordinary
## available coaches (a season later when the market is badly overloaded).
static func _enter_from_pathway(coaches: Dictionary, year: int, my_club: String, clubs: Array,
		news: Array, log: Dictionary) -> void:
	var pool := 0
	for cid in coaches:
		var st := str(coaches[cid].get("status", ""))
		if st == "free" or st == "away":
			pool += 1
	var target := POOL_TOP
	for club in clubs:
		if GameDB.enter_year(club) == year + 2:
			target += 8
	for cid in coaches.keys():
		var c: Dictionary = coaches[cid]
		if not CoachPathway.in_pathway(c) or int(c.get("free_from", 0)) > year + 1:
			continue
		if not CoachPathway.enter_market(c, year, pool, target):
			continue
		pool += 1
		log["ex_players_in"] = int(log.get("ex_players_in", 0)) + 1
		var played: Dictionary = c.get("played", {})
		var mine := my_club != "" and CoachPathway.played_for(played, my_club)
		if mine or int(played.get("games", 0)) >= 150:
			var club := my_club if mine else CoachPathway.main_club(played)
			news.append([1 if mine else 3, "Former %s %s %s has joined the coaching ranks." % [
					GameDB.club_name(club), CoachPathway.position_word(played), _name(c)]])


## "Lachlan Mercer, who played 241 games for Adelaide, has been appointed
## Fremantle's forwards coach." Only for a notable former player or one of
## yours: not every retiree's first job is news.
static func _first_job_news(c: Dictionary, club: String, job: String, my_club: String, news: Array) -> void:
	var played: Dictionary = c.get("played", {})
	var mine := my_club != "" and CoachPathway.played_for(played, my_club)
	if not mine and int(played.get("games", 0)) < 150:
		return
	var home := my_club if mine else CoachPathway.main_club(played)
	var n := CoachPathway.games_for(played, home)
	var who := "%s, who played %d game%s for %s," % [_name(c), n, "" if n == 1 else "s", GameDB.club_name(home)]
	var where := "%s's %s" % [GameDB.club_name(club), _job_word(job)]
	if club == my_club:
		where = "your %s" % _job_word(job)
	news.append([1 if mine or club == my_club else 3, "%s has been appointed %s." % [who, where]])


# ---------------------------------------------------------------------------
# Your vacancies
# ---------------------------------------------------------------------------
## A shortlist for one of your jobs: the best 3-5 by the same hiring score
## the AI uses, from coaches free to take it (and your own staff stepping up).
static func shortlist(coaches: Dictionary, my_club: String, job: String, year: int, seed: int, n := 4) -> Array:
	var scored := []
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		var status := str(c.get("status", ""))
		if status == "club" and str(c.get("club", "")) != my_club:
			continue   # no poaching from rivals for your jobs: no chain to follow
		if status == "club" and move_kind(str(c["job"]), job) != "promotion":
			continue
		if not would_take(c, my_club, job, year):
			continue
		scored.append([hire_score(c, my_club, job, year, seed), cid])
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var out := []
	for s in scored.slice(0, n):
		out.append(str(s[1]))
	return out


## Appoint `cid` to your `job`. Returns the job he left at your club ("" if none).
static func appoint_mine(coaches: Dictionary, cid: String, my_club: String, job: String, year: int, seed: int) -> String:
	var c: Dictionary = coaches[cid]
	ensure_fields(c, year)
	var left := ""
	if str(c.get("status", "")) == "club" and str(c.get("club", "")) == my_club:
		left = str(c["job"])
	_appoint(c, my_club, job, year, seed)
	return left


## Auto-fill: the shortlist's first choice (the AI's pick), or a generated
## coach when nobody is free.
static func auto_fill(coaches: Dictionary, my_club: String, job: String, year: int, seed: int) -> String:
	var sl := shortlist(coaches, my_club, job, year, seed, 1)
	var cid := ""
	if sl.is_empty():
		var log := {}
		cid = str(_generate(coaches, year, seed, log, job)["cid"])
	else:
		cid = str(sl[0])
	return appoint_mine(coaches, cid, my_club, job, year, seed)


## Release one of your assistants (offseason only): he joins the market.
## Your assistant at the end of his term, in his own words: how long he will
## sign for. {"key", "years", "text"}.
static func assistant_stance(c: Dictionary, year: int) -> Dictionary:
	if age(c, year + 1) >= RETIRE_FROM - 2:
		return {"key": "winding", "years": 1, "text": "Near the end of his career: he will sign for one more season."}
	if str(c.get("job", "")) in ["MID", "FWD", "DEF", "DEV"] and int(c.get("rep", 0)) >= ASSISTANT_KEEP_REP \
			and tenure(c, year) >= MIN_TENURE:
		return {"key": "ambitious", "years": 1, "text": "Wants a bigger role: he will only commit for a season."}
	return {"key": "keen", "years": 2, "text": "Keen to stay: he will sign for two more seasons."}


## Your assistant re-signs on his terms (assistant_stance).
static func resign(c: Dictionary, year: int) -> void:
	c["contract_to"] = year + int(assistant_stance(c, year)["years"])


static func release(coaches: Dictionary, cid: String, year: int) -> String:
	var c: Dictionary = coaches[cid]
	var job := str(c.get("job", ""))
	# Let go: he is not straight back at the club that released him.
	(c["sacked_by"] as Dictionary)[str(c.get("club", ""))] = year
	_leave_job(c, year)
	return job
