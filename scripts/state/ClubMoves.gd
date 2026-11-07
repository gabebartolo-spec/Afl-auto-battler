class_name ClubMoves
extends RefCounted
## The coach changes clubs (coach arcs phase 2; catalogue arcs 2, 3, 7 and
## 11, docs/research/COACH_ARC_CATALOGUE_2026-11-03.md).
##
## Two steps, so the season he leaves is played out at the club he leaves:
##   season_close  (after the season's close and the coaching offseason): a
##                 coach who took a rival's offer (arc "poached") is going
##                 there. A sacked coach with a reprieve left is offered a few
##                 clubs with a job open (coach_arcs.offers); he takes one
##                 (take_job) or retires (retire_coach). With no reprieve left
##                 his coaching career is over (TODO T5.r22, Director Bible
##                 5.2.19-5.2.22). Every running arc ends at the old club, and
##                 the move waits in coach_arcs.move.
##   apply_move    (at the rollover, before the new lists are built; at once
##                 when he takes a rival board's letter): he is the
##                 new club's coach. That club's AI senior coach takes the job
##                 he left (or, when his assistant was after it, the assistant
##                 does and the AI coach is let go). His career record (seasons,
##                 games, flags, every club, every player he coached) carries on.
## `gs` is GameState; its state lives in gs.coach_arcs (CoachArcs).

## How each arc may end when the coach leaves; any other running arc stays
## behind at the old club ("moved_on").
const MOVE_ENDINGS := {"hot_seat": ["sacked"], "way_back": ["sacked_again"], "poached": ["left"],
		"assistant": ["took_job", "left_friend"]}
## A sacked coach is offered jobs at clubs that finished this low.
const SACKED_FROM_BOTTOM := 6
## How many clubs offer a sacked coach a job ("a choice of a few", 5.2.20).
const OFFERS := 3


# ---------------------------------------------------------------------------
# The season's close: is he leaving?
# ---------------------------------------------------------------------------
static func season_close(gs) -> void:
	if not ClubArcs.on(gs) or gs.season == null:
		return
	var st := ClubArcs._st(gs)
	var year := int(gs.season_year)
	var sacked := bool(gs.board.get("sacked", false))
	# A premiership earns back a second chance, one at most ("a premiership
	# restores it", T5.r22).
	if gs.premier() == str(gs.my_club):
		st["coach"]["reprieves"] = maxi(int(st["coach"]["reprieves"]), 1)
	var poach: Dictionary = st["active"].get("poached", {})
	var to := ""
	if not poach.is_empty() and (poach.get("flags", {}) as Dictionary).has("taking"):
		to = str(poach.get("mem", {}).get("suitor_code", ""))
	if to == "" and sacked:
		_sacked(gs, st)
		return
	_assistant_leaves(gs, st)
	if to == "":
		_rival_letter(gs, st)
		return
	# The assistant who may inherit the job (arc "assistant"), named now while
	# the arc still remembers him.
	var heir_id := str((st["active"].get("assistant", {}) as Dictionary).get("mem", {}).get("assistant_id", ""))
	_close_for_move(gs, st)
	st["move"] = {"to": to, "why": "poached", "from": str(gs.my_club), "year": year, "heir": heir_id}
	if sacked:
		# Sacked while already leaving for a rival: the signed job stands and
		# no second chance is spent, but the sacking is on his record.
		CoachArcs.log_line(st, year, "Season end", "move", "Sacked by %s, already on his way to %s." % [
				GameDB.club_name(gs.my_club), GameDB.club_name(to)])
		st["coach"]["sackings"] = int(st["coach"]["sackings"]) + 1
		gs.board["sacked"] = false
		gs.board["verdict"] = "Sacked. You were already leaving for %s." % GameDB.club_name(to)
	gs.add_news(ClubArcs.NEWS_KIND, "You leave %s for %s at season's end." % [GameDB.club_name(gs.my_club), GameDB.club_name(to)])


## Sacked at the season's close. His time at the club is over either way, so
## every arc there ends now. With a reprieve left, a few clubs have a job open
## for him (the Hub's sacked card lists them); with none, or no club to go
## to, his coaching career is over. The board stays "sacked" until he takes
## a job, so the Hub shows the sacked card.
static func _sacked(gs, st: Dictionary) -> void:
	var year := int(gs.season_year)
	var heir_id := str((st["active"].get("assistant", {}) as Dictionary).get("mem", {}).get("assistant_id", ""))
	var jobs := _jobs_after_sack(gs, st) if int(st["coach"]["reprieves"]) > 0 else []
	_assistant_leaves(gs, st)
	_close_for_move(gs, st)
	st["sack"] = {"from": str(gs.my_club), "year": year, "heir": heir_id}
	st["offers"] = jobs
	st["coach"]["sackings"] = int(st["coach"]["sackings"]) + 1
	var club := GameDB.club_name(gs.my_club)
	if jobs.is_empty():
		CoachArcs.log_line(st, year, "Season end", "move", "Sacked by %s. His coaching career is over." % club)
		gs.add_news(ClubArcs.NEWS_KIND, "Sacked by %s, your coaching career is over." % club)
		return
	var names := PackedStringArray()
	for o in jobs:
		names.append(str(o["name"]))
	CoachArcs.log_line(st, year, "Season end", "move", "Sacked by %s. Jobs open at %s." % [club, ", ".join(names)])
	gs.add_news(ClubArcs.NEWS_KIND, "Sacked by %s. %s have a senior job open." % [club, _and_list(names)])


static func _and_list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The clubs with a job open for him now ([] when none).
static func offers(gs) -> Array:
	if not ClubArcs.on(gs) or not (gs.coach_arcs is Dictionary):
		return []
	return ClubArcs._st(gs)["offers"]


## Second chances he has left: a sacking with one left brings job offers.
static func reprieves(gs) -> int:
	if not (gs.coach_arcs is Dictionary) or gs.coach_arcs.is_empty():
		return 1
	return int(ClubArcs._st(gs)["coach"]["reprieves"])


## Sacked with no job to take (no reprieve left, or he retired): the save is a
## finished career.
static func career_over(gs) -> bool:
	return gs.is_sacked() and offers(gs).is_empty()


## He takes the job at `code`, one of his offers. The move waits for the
## rollover like any other; the reprieve is spent.
static func take_job(gs, code: String) -> bool:
	var st := ClubArcs._st(gs)
	var pick := {}
	for o in st["offers"]:
		if str(o.get("code", "")) == code:
			pick = o
	if pick.is_empty():
		return false
	var sk: Dictionary = st["sack"]
	var year := int(sk.get("year", gs.season_year))
	var from := str(sk.get("from", gs.my_club))
	st["move"] = {"to": code, "why": "sacked", "from": from, "year": year, "heir": str(sk.get("heir", ""))}
	st["offers"] = []
	st["coach"]["reprieves"] = maxi(0, int(st["coach"]["reprieves"]) - 1)
	CoachArcs.log_line(st, year, "Season end", "move", "Takes the senior job at %s." % GameDB.club_name(code))
	gs.board["sacked"] = false
	gs.board["verdict"] = "Sacked. You have taken the senior job at %s." % GameDB.club_name(code)
	gs.add_news(ClubArcs.NEWS_KIND, "Sacked by %s, you have taken the senior job at %s for %d." % [
			GameDB.club_name(from), GameDB.club_name(code), year + 1])
	return true


## He retires instead: the career is over, and the save stays a finished one.
static func retire_coach(gs) -> void:
	var st := ClubArcs._st(gs)
	var year := int(gs.season_year)
	st["offers"] = []
	st["coach"]["retired"] = year
	gs.board["sacked"] = true
	CoachArcs.log_line(st, year, "Season end", "move", "Retires from coaching.")
	gs.add_news(ClubArcs.NEWS_KIND, "You have retired from coaching after %s." % record_summary(gs))


static func retired(gs) -> bool:
	return (gs.coach_arcs is Dictionary) and not gs.coach_arcs.is_empty() and int(ClubArcs._st(gs)["coach"]["retired"]) > 0


## Headless runs (audits, tests that roll seasons on): a pending choice takes
## the first club offered, so a career keeps rolling.
static func take_first_offer(gs) -> bool:
	var o := offers(gs)
	return not o.is_empty() and take_job(gs, str(o[0]["code"]))


## His coaching record: seasons, wins, losses, draws, premierships (by year),
## seasons in the finals and every club. Counts every season he coached, this
## one included (coach_arcs counts a season only at the next one's start).
static func record(gs) -> Dictionary:
	var st := ClubArcs._st(gs)
	var c: Dictionary = st["coach"]
	var start := int(c["start"])
	var out := {"seasons": 0, "w": 0, "l": 0, "d": 0, "flags": [], "finals": 0, "clubs": []}
	for h in gs.honour_roll:
		var y := int(h.get("year", 0))
		if str(h.get("my_club", "")) == "" or (start > 0 and y < start):
			continue
		out["seasons"] = int(out["seasons"]) + 1
		var wld := str(h.get("my_record", "0-0-0")).split("-")
		if wld.size() == 3:
			out["w"] = int(out["w"]) + int(wld[0])
			out["l"] = int(out["l"]) + int(wld[1])
			out["d"] = int(out["d"]) + int(wld[2])
		if str(h.get("my_finals", "")) != "":
			out["finals"] = int(out["finals"]) + 1
		if str(h.get("premier", "")) != "" and str(h.get("premier", "")) == str(h.get("my_club", "")):
			(out["flags"] as Array).append(y)
	var sk: Dictionary = st["sack"]
	for h in c["clubs"]:
		var code := str(h.get("code", ""))
		var to := int(h.get("to", 0))
		var why := str(h.get("why_left", ""))
		if to == 0 and gs.is_sacked() and code == str(sk.get("from", "")):
			to = int(sk.get("year", gs.season_year))
			why = "sacked"
		(out["clubs"] as Array).append({"code": code, "name": GameDB.club_name(code), "from": int(h.get("from", 0)),
				"to": to, "why": why})
	if (out["clubs"] as Array).is_empty() and str(gs.my_club) != "":
		(out["clubs"] as Array).append({"code": str(gs.my_club), "name": GameDB.club_name(gs.my_club),
				"from": start if start > 0 else int(gs.season_year), "to": int(gs.season_year) if gs.is_sacked() else 0,
				"why": "sacked" if gs.is_sacked() else ""})
	return out


static func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## "4 seasons: 40 wins, 46 losses and 2 draws".
static func record_summary(gs) -> String:
	var r := record(gs)
	var games := [_plural(int(r["w"]), "win", "wins"), _plural(int(r["l"]), "loss", "losses")]
	if int(r["d"]) > 0:
		games.append(_plural(int(r["d"]), "draw", "draws"))
	return "%s: %s" % [_plural(int(r["seasons"]), "season", "seasons"), _and_list(PackedStringArray(games))]


## The record read out, line by line: the games, the flags and finals, then
## every club with its years and how he left.
static func record_lines(gs) -> PackedStringArray:
	var r := record(gs)
	var out := PackedStringArray()
	var sum := record_summary(gs)
	out.append(sum.substr(0, 1).to_upper() + sum.substr(1) + ".")
	var flags: Array = r["flags"]
	var finals := "Finals in %d of %s." % [int(r["finals"]), _plural(int(r["seasons"]), "season", "seasons")]
	if flags.is_empty():
		out.append("No premiership. " + finals)
	else:
		var ys := PackedStringArray()
		for y in flags:
			ys.append(str(y))
		out.append("Premiership%s: %s. %s" % ["" if flags.size() == 1 else "s", _and_list(ys), finals])
	for h in r["clubs"]:
		var from := int(h["from"])
		var to := int(h["to"])
		var span := str(from) if to == 0 or to == from else "%d to %d" % [from, to]
		if to == 0:
			span += " on"
		var left := str({"sacked": "sacked", "poached": "left for another job"}.get(str(h["why"]), ""))
		out.append("%s, %s%s" % [str(h["name"]), span, (", " + left) if left != "" and to != 0 else ""])
	return out


## What the next sacking means, from his reprieves (rule 60: shown plainly).
static func reprieve_line(gs) -> String:
	if reprieves(gs) > 0:
		return "Sacked here, you would get one more chance at another club."
	return "This is your last chance: sacked again and your coaching career is over. A premiership earns you another."


## Every running arc ends at the club he is leaving: by its own rule when that
## rule is about him leaving (MOVE_ENDINGS), otherwise it stays behind.
static func _close_for_move(gs, st: Dictionary) -> void:
	var defs := CoachArcs.all()
	for id in (st["active"] as Dictionary).keys():
		var def := CoachArcs.by_id(defs, str(id))
		var rec: Dictionary = st["active"][id]
		var own := CoachArcs.closing(def, rec, ClubArcs.close_facts(gs, rec), int(gs.season_year))
		# A reunion is about a game already played: it keeps its own ending.
		if (MOVE_ENDINGS.get(str(id), []) as Array).has(own) or str(id) == "reunion":
			ClubArcs._end(gs, st, def, rec, own, "Season end")
			continue
		# An arc with its own line for him leaving says it.
		if (def.get("endings", {}) as Dictionary).has("moved_on"):
			ClubArcs._end(gs, st, def, rec, "moved_on", "Season end")
			continue
		var name := str(rec.get("mem", {}).get("name", ""))
		var line := "%s stays at %s: the coach has moved on." % [name, GameDB.club_name(gs.my_club)] if str(def.get("kind", "")) == "player" and name != "" \
				else "%s stays behind at %s: the coach has moved on." % [str(def.get("name", id)), GameDB.club_name(gs.my_club)]
		CoachArcs.log_line(st, int(gs.season_year), "Season end", str(id), "ENDS (moved_on): " + line)
		CoachArcs.finish(st, str(id), "moved_on", int(gs.season_year))


## The clubs with a senior job for a sacked coach: first the bottom-half clubs
## whose senior coach left at this off-season (the jobs open that off-season),
## then filled from the bottom of the final ladder; never a club that has
## sacked him (seeded, so a reload agrees). Facts only, in ladder order:
## where they finished, the list in words, the goal their board would set and
## why the job is open.
static func _jobs_after_sack(gs, st: Dictionary) -> Array:
	var table: Array = gs.season.ladder_sorted()
	var year := int(gs.season_year)
	var sacked_him := {}
	for h in st["coach"]["clubs"]:
		if str(h.get("why_left", "")) == "sacked":
			sacked_him[str(h["code"])] = true
	# Not the club his own assistant is leaving to coach.
	var asst: Dictionary = st["active"].get("assistant", {})
	if (asst.get("flags", {}) as Dictionary).has("backed"):
		sacked_him[str(asst.get("mem", {}).get("assistant_code", ""))] = true
	var finish := {}
	for i in range(table.size()):
		finish[str(table[i]["code"])] = i + 1
	var half := maxi(1, table.size() / 2)
	var why_open := _coaches_gone(gs, year)
	var open := []
	var bottom := []
	for i in range(table.size() - 1, -1, -1):
		var code := str(table[i]["code"])
		if code == str(gs.my_club) or sacked_him.has(code):
			continue
		if why_open.has(code) and i + 1 > half:
			open.append(code)
		elif bottom.size() < SACKED_FROM_BOTTOM:
			bottom.append(code)
	var picked := _pick(gs, open, OFFERS, "sackjob|%d" % year)
	picked.append_array(_pick(gs, bottom, OFFERS - picked.size(), "sackjob2|%d" % year))
	picked.sort_custom(func(a, b): return int(finish[a]) < int(finish[b]))
	var out := []
	for code in picked:
		var outlook: Dictionary = gs.team_outlook(code)
		var rank := int(gs.club_expect.get(code, ClubLife.default_rank(table.size())))
		out.append({"code": code, "name": GameDB.club_name(code), "finish": int(finish[code]), "clubs": table.size(),
				"list": str(outlook.get("line", "")),
				"goal": str(ClubLife.board_goal(rank, int(finish[code]), table.size()).get("text", "")),
				"why_open": str(why_open.get(code, "The board wants a new senior coach."))})
	return out


## `n` of `pool`, seeded.
static func _pick(gs, pool: Array, n: int, key: String) -> Array:
	var left := pool.duplicate()
	var out := []
	var i := 0
	while out.size() < n and not left.is_empty():
		out.append(left.pop_at(_roll(gs, "%s|%d" % [key, i], left.size())))
		i += 1
	return out


## Clubs whose senior coach left his job at this off-season, with why.
static func _coaches_gone(gs, year: int) -> Dictionary:
	var out := {}
	for cid in gs.coaches:
		var c: Dictionary = gs.coaches[cid]
		for s in c.get("stints", []):
			if str(s[1]) != "SC" or int(s[3]) != year:
				continue
			var club := str(s[0])
			var who := GameDB.player_display_name(c)
			if int((c.get("sacked_by", {}) as Dictionary).get(club, 0)) == year:
				out[club] = "They sacked %s." % who
			elif str(c.get("status", "")) == "retired":
				out[club] = "%s has retired." % who
			elif str(c.get("status", "")) == "club" and str(c.get("club", "")) != club:
				out[club] = "%s has left to coach %s." % [who, GameDB.club_name(str(c.get("club", "")))]
			elif str(c.get("status", "")) != "club":
				out[club] = "%s's contract was not renewed." % who
	return out


## The assistant (arc "assistant") who was backed to go: he takes the rival's
## senior job now (their coach is let go) and his own job is open.
static func _assistant_leaves(gs, st: Dictionary) -> void:
	var rec: Dictionary = st["active"].get("assistant", {})
	if rec.is_empty() or not (rec.get("flags", {}) as Dictionary).has("backed"):
		return
	var mem: Dictionary = rec.get("mem", {})
	var asst: Dictionary = gs.coaches.get(str(mem.get("assistant_id", "")), {})
	var to := str(mem.get("assistant_code", ""))
	if asst.is_empty() or to == "" or str(asst.get("club", "")) != str(gs.my_club):
		return
	var year := int(gs.season_year)
	var job := str(asst.get("job", "SA"))
	var sc := _senior_coach(gs, to)
	if not sc.is_empty():
		CoachMarket._leave_job(sc, year)
	CoachMarket._appoint(asst, to, "SC", year, int(gs.career_seed))
	if not gs._vacancy_open(job):
		gs.staff_vacancies.append({"job": job, "reason": "%s has left to coach %s." % [str(mem.get("assistant", "")), GameDB.club_name(to)]})


# ---------------------------------------------------------------------------
# The rollover: the move
# ---------------------------------------------------------------------------
static func apply_move(gs) -> void:
	if not ClubArcs.on(gs):
		return
	var st := ClubArcs._st(gs)
	# A letter never answered by the rollover is a no: he stays.
	settle_letter(gs)
	var mv: Dictionary = st["move"]
	var to := str(mv.get("to", ""))
	if to == "" or to == str(gs.my_club):
		st["move"] = {}
		return
	var from := str(gs.my_club)
	var year := int(gs.season_year)
	var seed := int(gs.career_seed)
	# The new club's senior coach makes way: he takes the job left open, or
	# the assistant who was after it does and he is let go.
	var theirs := _senior_coach(gs, to)
	var heir := {}
	var a: Dictionary = st["done"].get("assistant", {})
	if str(a.get("ending", "")) == "took_job" and int(a.get("year", 0)) == year:
		heir = gs.coaches.get(str(mv.get("heir", "")), {})
		# Only while he is still on staff at the club he would take over.
		if str(heir.get("status", "")) != "club" or str(heir.get("club", "")) != from:
			heir = {}
	if not heir.is_empty():
		CoachMarket._appoint(heir, from, "SC", year, seed)
		if not theirs.is_empty():
			CoachMarket._leave_job(theirs, year)
	elif not theirs.is_empty():
		CoachMarket._appoint(theirs, from, "SC", year, seed)
	# His record: the club he leaves, the club he joins.
	var c: Dictionary = st["coach"]
	for h in c["clubs"]:
		if str(h.get("code", "")) == from and int(h.get("to", 0)) == 0:
			h["to"] = year
			h["why_left"] = str(mv.get("why", ""))
			h["chairman"] = str(st["people"].get("chairman", ""))
	(c["clubs"] as Array).append({"code": to, "name": GameDB.club_name(to), "from": year + 1, "to": 0, "why": str(mv.get("why", ""))})
	c["club"] = to
	c["moved"] = {"year": year, "why": str(mv.get("why", "")), "from": from, "to": to}
	st["people"].erase("chairman")
	st["move"] = {}
	# The club he joins: a fresh board (its history of his seasons kept), and
	# nothing left over from the old club's office.
	var hist: Array = gs.board.get("history", [])
	gs.board = {}
	# The old club's honour board is put away and the new club's taken up.
	HonourBoard.change_club(gs, from, to)
	gs.my_club = to
	gs.board = {"confidence": ClubLife.START_CONFIDENCE, "warned": false, "sacked": false, "history": hist}
	gs.staff_vacancies = []
	gs.coach_approaches = []
	gs.trade_requests = {}
	gs.week_events = []
	var old_name := GameDB.club_name(from)
	gs.add_news(ClubArcs.NEWS_KIND, "You are the new senior coach of %s. %s takes over at %s." % [GameDB.club_name(to),
			(GameDB.player_display_name(heir) if not heir.is_empty() else (GameDB.player_display_name(theirs) if not theirs.is_empty() else "A new coach")), old_name])
	# The reprieve, said plainly at the new club (rule 60).
	if str(mv.get("why", "")) == "sacked":
		gs.add_news(ClubArcs.NEWS_KIND, reprieve_line(gs))


static func _senior_coach(gs, code: String) -> Dictionary:
	for cid in gs.coaches:
		var c: Dictionary = gs.coaches[cid]
		if str(c.get("status", "")) == "club" and str(c.get("club", "")) == code and str(c.get("job", "")) == "SC":
			return c
	return {}


static func _roll(gs, key: String, n: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("clubmove|%d|%s" % [int(gs.career_seed), key])
	return rng.randi_range(0, maxi(n - 1, 0))


# ---------------------------------------------------------------------------
# Triggers (ClubArcs.trigger)
# ---------------------------------------------------------------------------
## Arc 3: top-4 finishes twice at this club, or last season's flag, and a
## struggling club wants him. At a season's start.
static func poach_trigger(gs, st: Dictionary, tr: Dictionary, season_start: bool) -> Dictionary:
	if not season_start or gs.honour_roll.is_empty():
		return {}
	var since := _club_since(st, str(gs.my_club))
	var tops := 0
	for h in gs.honour_roll:
		if int(h.get("year", 0)) >= since and str(h.get("my_club", "")) == str(gs.my_club) \
				and int(h.get("my_position", 99)) > 0 and int(h.get("my_position", 99)) <= int(tr.get("top", 4)):
			tops += 1
	var flag := str(gs.honour_roll[-1].get("premier", "")) == str(gs.my_club)
	if tops < int(tr.get("top4", 2)) and not flag:
		return {}
	var pool := []
	var finish: Dictionary = gs._last_finish
	var half := maxi(1, finish.size() / 2)
	for code in finish:
		if str(code) != str(gs.my_club) and int(finish[code]) > half and not _coached_at(st, str(code)) \
				and not _senior_coach(gs, str(code)).is_empty():
			pool.append(str(code))
	if pool.is_empty():
		return {}
	pool.sort()
	var code: String = pool[_roll(gs, "suitor|%d" % int(gs.season_year), pool.size())]
	return {"mem": {"suitor": GameDB.club_name(code), "suitor_code": code,
			"suitor_president": ClubArcs._gen_name(int(gs.career_seed), "president|" + code)}}


## Arc 7: this week's opponent is a club he coached before (not while the way
## back, which has its own first meeting, still runs). The same club comes
## round again at most once every `club_every` seasons (counted from when its
## last reunion ended), except a club he won a flag at: in each year a whole
## `anniversary` of seasons on from that flag, it is the premiership reunion,
## whatever the cooldown.
static func reunion_trigger(gs, st: Dictionary, club: Dictionary, ctx: Dictionary, season_start: bool) -> Dictionary:
	if season_start or str(ctx["phase"]) != "regular" or (st["active"] as Dictionary).has("way_back"):
		return {}
	var tr: Dictionary = CoachArcs.by_id(CoachArcs.all(), "reunion").get("trigger", {})
	var year := int(gs.season_year)
	for h in st["coach"]["clubs"]:
		var code := str(h.get("code", ""))
		if code == str(gs.my_club) or int(h.get("to", 0)) == 0 or str(club.get("opp", "")) != GameDB.club_name(code):
			continue
		var flag := anniversary_flag(gs, code, year, int(tr.get("anniversary", 10)))
		if flag > 0 and int(h.get("anniv", 0)) == year:
			flag = 0
		var last := int(h.get("reunion", 0))
		if flag == 0 and last > 0 and year - last < int(tr.get("club_every", 10)):
			continue
		var mem := ClubArcs._old_club_mem(gs, st, code)
		if str(mem["former"]) == "" and flag == 0:
			return {}
		if flag > 0:
			mem["flag_year"] = flag
			mem["flag_years_on"] = year - flag
			mem["flag_reunion"] = true
		return {"mem": mem}
	return {}


## The flag he won at `code` a whole number of `every` seasons before `year`
## (the latest, if more than one), or 0.
static func anniversary_flag(gs, code: String, year: int, every: int) -> int:
	var best := 0
	for h in gs.honour_roll:
		var y := int(h.get("year", 0))
		if every > 0 and y < year and (year - y) % every == 0 and str(h.get("premier", "")) == code \
				and str(h.get("my_club", "")) == code:
			best = maxi(best, y)
	return best


## Arc 11: a senior assistant with a name while the board wavers.
static func assistant_trigger(gs, st: Dictionary, tr: Dictionary, ctx: Dictionary, season_start: bool) -> Dictionary:
	if season_start or str(ctx["phase"]) != "regular" or gs.board_confidence() >= int(tr.get("board_below", 50)):
		return {}
	var best := {}
	var best_id := ""
	for cid in gs.coaches:
		var c: Dictionary = gs.coaches[cid]
		if str(c.get("status", "")) == "club" and str(c.get("club", "")) == str(gs.my_club) and str(c.get("job", "")) == "SA" \
				and int(c.get("rep", 0)) >= int(tr.get("rep_min", 55)) and int(c.get("rep", 0)) > int(best.get("rep", -1)):
			best = c
			best_id = str(cid)
	if best.is_empty():
		return {}
	var pool := []
	for code in gs.season.ladder:
		if str(code) != str(gs.my_club) and not _senior_coach(gs, str(code)).is_empty():
			pool.append(str(code))
	if pool.is_empty():
		return {}
	pool.sort()
	var to: String = pool[_roll(gs, "assistant_to|%d|%s" % [int(gs.season_year), best_id], pool.size())]
	return {"mem": {"assistant": GameDB.player_display_name(best), "assistant_id": best_id,
			"assistant_to": GameDB.club_name(to), "assistant_code": to}}


## The best player still at `code` whom the coach coached there, or "".
static func former_player(gs, st: Dictionary, code: String) -> String:
	var list: Array = gs.season.lists.get(code, []) if gs.season != null else []
	var best := {}
	for p in list:
		if (st["coach"]["coached"] as Dictionary).has(str(p["id"])) and int(p.get("overall", 0)) > int(best.get("overall", -1)):
			best = p
	return GameDB.player_display_name(best) if not best.is_empty() else ""


## The reunion's result, from the round just played against the old club.
static func record_reunion(gs, st: Dictionary) -> void:
	var rec: Dictionary = st["active"].get("reunion", {})
	if rec.is_empty() or gs.season == null or (gs.season.results as Array).is_empty():
		return
	var flags: Dictionary = rec["flags"]
	if flags.has("won") or flags.has("lost") or flags.has("drew"):
		return
	var old := str(rec.get("mem", {}).get("old_code", ""))
	for res in gs.season.results[-1]:
		var side := -1
		if str(res.get("home", "")) == str(gs.my_club) and str(res.get("away", "")) == old:
			side = 0
		elif str(res.get("away", "")) == str(gs.my_club) and str(res.get("home", "")) == old:
			side = 1
		if side < 0:
			continue
		var s: Array = res["score"]
		# A draw is neither: it is recorded only so the result is not read again.
		var mine := int(s[side])
		var theirs := int(s[1 - side])
		flags["won" if mine > theirs else ("drew" if mine == theirs else "lost")] = gs.story_week()


static func _club_since(st: Dictionary, code: String) -> int:
	var since := 0
	for h in st["coach"]["clubs"]:
		if str(h.get("code", "")) == code:
			since = int(h.get("from", 0))
	return since


static func _coached_at(st: Dictionary, code: String) -> bool:
	for h in st["coach"]["clubs"]:
		if str(h.get("code", "")) == code:
			return true
	return false


# ---------------------------------------------------------------------------
# A rival board's letter (TODO T5.r23, Director Bible 5.2.23)
# ---------------------------------------------------------------------------
## After a strong season (the finals played and the board's goal met) one rival
## board writes to offer him its senior job: one letter a season at most, in
## the off-season, never while he is sacked or already leaving, and not in a
## season a rival already chased him (arc "poached"). The club: one whose
## senior coach left at this off-season, else a bottom-half club (seeded, so a
## reload agrees); never his own or a club that sacked him. Facts only: where
## they finished, why the job is open, the list in words and the goal their
## board would set, then the risk. The off-season waits for his answer
## (GameState.open_offseason). Taking it moves him straight away (apply_move):
## he runs the new club's off-season (contracts, trades, the draft) and the old
## club carries on under the new club's old coach. Declining changes nothing.
static func _rival_letter(gs, st: Dictionary) -> void:
	var year := int(gs.season_year)
	if gs.is_sacked() or not (st["move"] as Dictionary).is_empty() or int(st["letter"].get("year", 0)) == year:
		return
	if not strong_season(gs):
		return
	if (st["active"] as Dictionary).has("poached") or int((st["done"].get("poached", {}) as Dictionary).get("year", 0)) == year:
		return
	var table: Array = gs.season.ladder_sorted()
	var finish := {}
	for i in range(table.size()):
		finish[str(table[i]["code"])] = i + 1
	var not_him := {str(gs.my_club): true}
	for h in st["coach"]["clubs"]:
		if str(h.get("why_left", "")) == "sacked":
			not_him[str(h["code"])] = true
	var asst: Dictionary = st["active"].get("assistant", {})
	if (asst.get("flags", {}) as Dictionary).has("backed"):
		not_him[str(asst.get("mem", {}).get("assistant_code", ""))] = true
	var why_open := _coaches_gone(gs, year)
	var open := []
	var bottom := []
	var half := maxi(1, table.size() / 2)
	for i in range(table.size()):
		var code := str(table[i]["code"])
		if not_him.has(code) or _senior_coach(gs, code).is_empty():
			continue
		if why_open.has(code):
			open.append(code)
		elif i + 1 > half:
			bottom.append(code)
	var pool := open if not open.is_empty() else bottom
	if pool.is_empty():
		return
	var code: String = pool[_roll(gs, "letter|%d" % year, pool.size())]
	var outlook: Dictionary = gs.team_outlook(code)
	var mine: Dictionary = gs.team_outlook(str(gs.my_club))
	var rank := int(gs.club_expect.get(code, ClubLife.default_rank(table.size())))
	st["letter"] = {"year": year, "code": code, "name": GameDB.club_name(code), "from": str(gs.my_club),
			"finish": int(finish.get(code, 0)), "clubs": table.size(), "list": str(outlook.get("line", "")),
			"my_list": str(mine.get("line", "")), "board": gs.board_confidence(),
			"goal": str(ClubLife.board_goal(rank, int(finish.get(code, 0)), table.size()).get("text", "")),
			"why_open": str(why_open.get(code, "The board wants a new senior coach.")),
			"president": ClubArcs._gen_name(int(gs.career_seed), "president|" + code), "answer": ""}
	CoachArcs.log_line(st, year, "Season end", "letter", "A letter from %s offers him their senior job." % GameDB.club_name(code))
	gs.add_news(ClubArcs.NEWS_KIND, "A letter from %s: their board offers you the senior job." % GameDB.club_name(code))


## A strong season: he took the club to the finals and met the board's goal
## (this season's close, read from the honour roll and the board's history).
static func strong_season(gs) -> bool:
	var year := int(gs.season_year)
	var hist: Array = gs.board.get("history", [])
	if hist.is_empty() or int(hist[-1].get("year", 0)) != year or not bool(hist[-1].get("met", false)):
		return false
	if gs.honour_roll.is_empty():
		return false
	var h: Dictionary = gs.honour_roll[-1]
	return int(h.get("year", 0)) == year and str(h.get("my_club", "")) == str(gs.my_club) and str(h.get("my_finals", "")) != ""


## This off-season's letter ({} when none was written).
static func letter(gs) -> Dictionary:
	if not ClubArcs.on(gs) or not (gs.coach_arcs is Dictionary) or gs.coach_arcs.is_empty():
		return {}
	var l: Dictionary = ClubArcs._st(gs)["letter"]
	return l if int(l.get("year", 0)) == int(gs.season_year) else {}


## A letter waiting for his answer.
static func letter_open(gs) -> bool:
	var l := letter(gs)
	return not l.is_empty() and str(l.get("answer", "")) == ""


## What taking the job risks, in facts: the new board, the list he leaves and
## what a sacking there would mean.
static func letter_risk(gs) -> PackedStringArray:
	var l := letter(gs)
	var out := PackedStringArray()
	if l.is_empty():
		return out
	out.append("Their board starts you at %d out of 100. %s's board is at %d now." % [ClubLife.START_CONFIDENCE,
			GameDB.club_name(str(l["from"])), int(l["board"])])
	if str(l.get("my_list", "")) != "":
		out.append("You leave %s's list behind: %s" % [GameDB.club_name(str(l["from"])), str(l["my_list"])])
	out.append("Sacked there, you would get one more chance at another club." if reprieves(gs) > 0
			else "Sacked there, your coaching career is over. A premiership earns you another chance.")
	return out


## He takes the job and moves now: every running arc ends at the club he is
## leaving, he becomes the new club's coach (apply_move, as at a rollover) and
## the off-season opens there. One club at a time: once he has signed, nothing
## else can move him.
static func accept_letter(gs) -> bool:
	if not letter_open(gs):
		return false
	var st := ClubArcs._st(gs)
	var l: Dictionary = st["letter"]
	var year := int(l["year"])
	var heir_id := str((st["active"].get("assistant", {}) as Dictionary).get("mem", {}).get("assistant_id", ""))
	_close_for_move(gs, st)
	l["answer"] = "taken"
	st["move"] = {"to": str(l["code"]), "why": "poached", "from": str(gs.my_club), "year": year, "heir": heir_id}
	CoachArcs.log_line(st, year, "Season end", "letter", "Takes the senior job at %s." % str(l["name"]))
	var from := str(gs.my_club)
	apply_move(gs)
	# Your list is the new club's from now (a rollover rebuilds it anyway).
	if gs.season != null:
		gs.my_list = gs.season.lists.get(str(gs.my_club), [])
	var successor := _senior_coach(gs, from)
	l["successor"] = GameDB.player_display_name(successor) if not successor.is_empty() else ""
	gs.open_offseason()
	return true


## He says no: nothing changes.
static func decline_letter(gs) -> bool:
	if not letter_open(gs):
		return false
	var st := ClubArcs._st(gs)
	st["letter"]["answer"] = "declined"
	CoachArcs.log_line(st, int(st["letter"]["year"]), "Season end", "letter", "Turns down %s." % str(st["letter"]["name"]))
	# The off-season waited for his answer: it opens at his club.
	gs.open_offseason(true)
	return true


## A letter still unanswered when the off-season moves on (a headless draft,
## the rollover) is a no.
static func settle_letter(gs) -> void:
	if letter_open(gs):
		decline_letter(gs)
