class_name ExpansionBuild
extends RefCounted
## GameState's side of a new club's list build (the rules are in Expansion).
## `gs` is GameState. Everything here is behind the feature switch
## "expansion_package": off, none of it runs and gs.expansion stays empty.
##
## A club entering in year E:
##   season E-1, late   approach(): it names the out-of-contract players it
##                      wants, one per rival club. Yours comes as a card.
##   season E-1 ends    resolve(): a rival re-signs the players it would have
##                      kept; the rest join the new club's list.
##   draft before E     draft_setup(): picks 1, 3, 5, 7 and the first pick of
##                      later rounds, one of the four traded for a senior
##                      player (forced_trade).
##   rollover into E    enter(): the list it built is the list it fields.
##   season E           a second, smaller round of approaches; pick 5 extra in
##                      that year's draft. Then nothing more.
##
## gs.expansion[code] = {"package": true, "list": [players before entry],
##   "approached": [years], "targets": [{"id", "club", "name", "year",
##   "status": "asked" | "kept" | "joining" | "joined" | "stayed", "carded"}],
##   "lost": [clubs that have lost a player to it], "signings": [player ids],
##   "relief": {year: sign-on money off the payroll}, "traded": bool}
## A coach running the new club himself comes later: the choices the club
## makes for itself here (who to approach, who to draft, which pick to trade)
## are the seams.


static func on() -> bool:
	return Features.on("expansion_package")


## Clubs whose first season is next year.
static func building(gs) -> Array:
	var out := []
	if not on() or gs.season == null:
		return out
	for code in GameDB.club_order:
		if GameDB.enter_year(str(code)) == int(gs.season_year) + 1:
			out.append(str(code))
	return out


## Clubs in their first season that built their list this way.
static func first_season(gs) -> Array:
	var out := []
	if not on() or gs.season == null:
		return out
	for code in gs.expansion:
		if GameDB.enter_year(str(code)) == int(gs.season_year) and has_package(gs, str(code)):
			out.append(str(code))
	return out


static func has_package(gs, code: String) -> bool:
	return bool((gs.expansion.get(code, {}) as Dictionary).get("package", false))


static func state(gs, code: String) -> Dictionary:
	if not gs.expansion.has(code):
		gs.expansion[code] = {"package": true, "list": [], "approached": [], "targets": [],
				"lost": [], "signings": [], "relief": {}, "traded": false}
	return gs.expansion[code]


## The club's players: its list once it plays, the list it is building before.
static func list_of(gs, code: String) -> Array:
	if gs.season != null and gs.season.lists.has(code):
		return gs.season.lists[code]
	return state(gs, code)["list"]


## The state-league signings, made once, the first time the club is needed.
static func ensure_foundation(gs, code: String) -> void:
	if gs.season != null and gs.season.lists.has(code):
		return
	var st := state(gs, code)
	if not (st["list"] as Array).is_empty():
		return
	st["list"] = Expansion.foundation_list(code, int(gs.season_year), int(gs.career_seed))
	for p in st["list"]:
		p["club"] = code


# ---------------------------------------------------------------------------
# Out-of-contract players
# ---------------------------------------------------------------------------
## Each week: with a few rounds left, the new clubs make their approaches.
static func week(gs) -> void:
	if not on() or gs.season == null or gs.season.is_regular_done():
		return
	if int(gs.season.round_index) < Season.REGULAR_ROUNDS - Expansion.APPROACH_ROUNDS_LEFT:
		return
	for code in building(gs) + first_season(gs):
		if not _approached(state(gs, code), int(gs.season_year)):
			approach(gs, code, true)


static func _approached(st: Dictionary, year: int) -> bool:
	for y in st.get("approached", []):
		if int(y) == year:
			return true
	return false


## How many more players the club may sign in this window.
static func quota(gs, code: String) -> int:
	var st := state(gs, code)
	var left := Expansion.SIGNINGS - (st["signings"] as Array).size()
	if GameDB.enter_year(code) > int(gs.season_year):
		left = mini(left, Expansion.FIRST_WINDOW)
	return maxi(0, left)


## The club names the players it wants: the best out-of-contract player at
## each rival club that it would play and that his club, by what anyone can
## see (his worth to their list, their cap room), will not keep. At your club
## it cannot know your mind, so it asks about your best one. One per club; the
## best of them up to its quota.
static func approach(gs, code: String, include_coach: bool) -> void:
	var st := state(gs, code)
	ensure_foundation(gs, code)
	(st["approached"] as Array).append(int(gs.season_year))
	var n := quota(gs, code)
	if n <= 0:
		return
	var bars: Dictionary = gs._selection_bars(list_of(gs, code))
	var cands := []
	for club in gs.season.lists:
		if str(club) == code or (st["lost"] as Array).has(str(club)):
			continue
		if str(club) == str(gs.my_club) and (not include_coach or gs.is_sacked()):
			continue
		var p := _candidate(gs, str(club), bars)
		if not p.is_empty():
			cands.append([p, str(club)])
	cands.sort_custom(func(a, b): return _better(a[0], b[0]))
	var named := PackedStringArray()
	for row in cands.slice(0, n):
		var p: Dictionary = row[0]
		(st["targets"] as Array).append({"id": str(p["id"]), "club": str(row[1]), "year": int(gs.season_year),
				"name": GameDB.player_display_name(p), "status": "asked"})
		named.append("%s (%s)" % [GameDB.player_display_name(p), GameDB.club_name(str(row[1]))])
	if not named.is_empty():
		gs.add_news("expansion", "%s have approached %s, out of contract at season's end: %s." % [
				GameDB.club_name(code), "one player" if named.size() == 1 else "%d players" % named.size(),
				", ".join(named)])
	gs.mark_dirty()


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a["overall"]) != int(b["overall"]):
		return int(a["overall"]) > int(b["overall"])
	if float(a.get("age", 25.0)) != float(b.get("age", 25.0)):
		return float(a.get("age", 25.0)) < float(b.get("age", 25.0))
	return str(a["id"]) < str(b["id"])


## The player a new club would ask `club` about, or {}.
static func _candidate(gs, club: String, bars: Dictionary) -> Dictionary:
	var list: Array = gs.season.lists[club]
	if list.size() <= Contracts.MIN_LIST:
		return {}
	var best := {}
	for p in Contracts.expiring(list):
		if not _available(gs, p) or role_at(p, bars) == "depth":
			continue
		if club != str(gs.my_club):
			var why := Contracts.ai_release_reason(p, list, gs.cap_for(club))
			if why == "cap" and not Expansion.FIRST_CALL_CAP_SQUEEZED:
				continue
			if why == "" and not leaves_if_matched(gs, p, club, bars):
				continue
		if best.is_empty() or _better(p, best):
			best = p
	return best


## His club has met his price: does he go anyway? He weighs the two offers as
## a free agent weighs any two (Contracts.prefers): the same money and term,
## his place in each side, and how his club finished (a new club has no
## finish, so it counts as last). No dice. Only when MATCHED_PLAYER_DECIDES.
static func leaves_if_matched(gs, p: Dictionary, club: String, bars: Dictionary) -> bool:
	if not Expansion.MATCHED_PLAYER_DECIDES:
		return false
	var deal := terms(p)
	var there := {"salary": int(deal["salary"]), "years": int(deal["years"]), "role": role_at(p, bars), "finish_t": 1.0}
	var here := {"salary": int(deal["salary"]), "years": int(deal["years"]), "role": gs.fa_role(p, club),
			"finish_t": gs._finish_t(club)}
	return Contracts.prefers(p, there, here)


static func _available(gs, p: Dictionary) -> bool:
	return int(p.get("contract_years", 1)) <= 1 and not bool(p.get("resigned", false)) \
			and float(p.get("age", 25.0)) < Expansion.TARGET_MAX_AGE and not gs.retiring_now(p)


## His place in a side with these selection bars (GameState.fa_role's rule).
static func role_at(p: Dictionary, bars: Dictionary) -> String:
	var ovr := int(p.get("overall", 0))
	for r in [str(p.get("role", "")), str(p.get("role2", ""))]:
		if r != "" and ovr > int(bars.get(r, 0)):
			return "ground"
	return "bench" if ovr > int(bars.get("bench", 0)) else "depth"


## The deal the new club signs him on: what a rival club offers a player it
## re-signs (the least he takes, over the term a club gives his age).
static func terms(p: Dictionary) -> Dictionary:
	var years := Contracts.ai_years(p)
	return {"years": years, "salary": Contracts.lowest(p, years)}


## Your player a new club has asked about and you have not answered, or {}.
static func pending_target(gs) -> Dictionary:
	if not on():
		return {}
	for code in gs.expansion:
		for t in (gs.expansion[code] as Dictionary).get("targets", []):
			if str(t["club"]) == str(gs.my_club) and str(t["status"]) == "asked" \
					and int(t["year"]) == int(gs.season_year):
				var out: Dictionary = t
				out["to"] = str(code)
				return out
	return {}


## The new club asking about your player: the one with an approach waiting,
## else the next club to enter (so the card can always be read).
static func asking_club(gs) -> String:
	var t := pending_target(gs)
	if not t.is_empty():
		return str(t["to"])
	var next := ""
	for code in GameDB.club_order:
		var y := GameDB.data_enter_year(str(code))
		if y > GameDB.START_YEAR and (next == "" or y < GameDB.data_enter_year(next)):
			next = str(code)
	return next


## This week's card about him, once (ClubStories.pick deals it first).
static func card(gs) -> Dictionary:
	var t := pending_target(gs)
	if t.is_empty() or bool(t.get("carded", false)):
		return {}
	var p: Dictionary = gs.list_player(str(t["id"]))
	if p.is_empty() or not _available(gs, p):
		t["status"] = "stayed"
		return {}
	t["carded"] = true
	return ClubStories.card_for(gs, "contracts_new_club_approach", p, card_facts(gs, p, str(t["to"])))


## What the card needs to say: who is asking, what keeping him costs, and
## what losing him would bring.
static func card_facts(gs, p: Dictionary, code: String) -> Dictionary:
	var want := Contracts.wants(p)
	var price := int(want["salary"])
	var years := int(want["years"])
	var room: bool = int(gs.my_payroll()) - int(p.get("salary", 0)) + price <= int(gs.salary_cap)
	var comp := compensation(gs, p)
	return {"new_club": GameDB.club_name(code), "new_club_code": code,
			"keep_price": Contracts.money(price),
			"keep_seasons": "%s more season%s" % [MatchNotes.count_word(years), "" if years == 1 else "s"],
			"keep_room": room,
			"keep_note": "" if room else "You do not have the cap room for his price today.",
			"comp_after": int(comp["after"]),
			"comp_line": str(comp["line"])}


## What your club gets if he goes to the new club on the deal it signs him to
## (terms): {"after": the pick it follows, 0 for none, "line": in words}. The
## rule that pays any club for a free agent it wanted and lost.
static func compensation(gs, p: Dictionary) -> Dictionary:
	if not gs.comp_tenure_ok(p):
		return {"after": 0, "line": "He has not been at your club two seasons, so you receive no draft pick."}
	var deal := terms(p)
	var clubs: int = GameDB.active_clubs(int(gs.season_year)).size()
	var after := Contracts.compensation_after(Contracts.compensation_value(p, int(deal["salary"]), int(deal["years"])), clubs)
	if after <= 0:
		return {"after": 0, "line": "A player on his wage earns his club no draft pick."}
	return {"after": after, "line": "You receive a draft pick %s." % Contracts.pick_words(after, clubs)}


## You re-sign him at his asking price: he stays, and the new club looks
## elsewhere. Returns what happened.
static func keep(gs, p: Dictionary) -> String:
	var t := pending_target(gs)
	var name := GameDB.player_display_name(p)
	var want := Contracts.wants(p)
	var price := int(want["salary"])
	if int(gs.my_payroll()) - int(p.get("salary", 0)) + price > int(gs.salary_cap):
		if not t.is_empty():
			t["status"] = "joining"
		return "The cap has no room for %s a season. %s will go when the season ends." % [Contracts.money(price), name]
	gs._resign(p, int(want["years"]), price)
	if not t.is_empty():
		t["status"] = "kept"
	return "%s re-signs for %s more season%s at %s a season." % [name, MatchNotes.count_word(int(want["years"])),
			"" if int(want["years"]) == 1 else "s", Contracts.money(price)]


## You let it run: he goes when the season ends.
static func let_go(gs, p: Dictionary) -> String:
	var t := pending_target(gs)
	if t.is_empty():
		return ""
	t["status"] = "joining"
	return "%s will join %s when the season ends. %s" % [GameDB.player_display_name(p),
			GameDB.club_name(str(t["to"])), str(compensation(gs, p)["line"])]


## The season is over: every approach is settled, before rivals re-sign and
## release as they always do. A rival keeps a player it would have kept and
## can pay; yours goes or stays as you answered (unanswered, with the story
## cards off, by the rule a rival follows). A club that was never approached
## this year (a career saved past that week) is approached now, rivals only.
static func resolve(gs) -> void:
	if not on() or gs.season == null:
		return
	for code in building(gs) + first_season(gs):
		var st := state(gs, code)
		if not _approached(st, int(gs.season_year)):
			approach(gs, code, false)
		for t in st["targets"]:
			if int(t["year"]) != int(gs.season_year) or not ["asked", "joining"].has(str(t["status"])):
				continue
			_settle(gs, code, st, t)
	gs.mark_dirty()


static func _settle(gs, code: String, st: Dictionary, t: Dictionary) -> void:
	var club := str(t["club"])
	var list: Array = gs.season.lists.get(club, [])
	var p := {}
	for q in list:
		if str(q["id"]) == str(t["id"]):
			p = q
	if p.is_empty() or not _available(gs, p) or list.size() <= Contracts.MIN_LIST \
			or (st["signings"] as Array).size() >= Expansion.SIGNINGS \
			or list_of(gs, code).size() >= Contracts.MAX_LIST:
		t["status"] = "stayed"
		return
	var wanted := true
	if club != str(gs.my_club) or str(t["status"]) == "asked":
		var why := Contracts.ai_release_reason(p, list, gs.cap_for(club))
		if why == "cap" and not Expansion.FIRST_CALL_CAP_SQUEEZED:
			t["status"] = "stayed"   # he goes to free agency, as he would have
			return
		if why == "" and not leaves_if_matched(gs, p, club, gs._selection_bars(list_of(gs, code))):
			t["status"] = "stayed"   # his club re-signs him, as it would have
			return
		wanted = why != "delist"
	if role_at(p, gs._selection_bars(list_of(gs, code))) == "depth":
		t["status"] = "stayed"   # he would not get a game there either
		return
	var deal := terms(p)
	list.erase(p)
	p["released_by"] = club
	p["comp_eligible"] = wanted and gs.comp_tenure_ok(p)
	gs.offseason_log.append({"kind": "released", "club": club, "id": str(p["id"]), "wanted": wanted,
			"eligible": bool(p["comp_eligible"]), "to": code})
	gs._record_departure(p, code, int(deal["salary"]), int(deal["years"]))
	_sign(gs, code, p, int(deal["salary"]), int(deal["years"]))
	(st["signings"] as Array).append(str(p["id"]))
	(st["lost"] as Array).append(club)
	t["status"] = "joined"
	gs.offseason_log.append({"kind": "signed", "club": code, "id": str(p["id"]),
			"salary": int(deal["salary"]), "years": int(deal["years"])})
	if club == str(gs.my_club) or int(p.get("overall", 0)) >= int(gs.NEWS_MIN_OVR):
		gs.add_news("expansion", "%s sign %s from %s: %s for %d season%s." % [GameDB.club_name(code),
				GameDB.player_display_name(p), GameDB.club_name(club), Contracts.money(int(deal["salary"])),
				int(deal["years"]), "" if int(deal["years"]) == 1 else "s"])


## He joins the new club: its list if it plays already, the list it is
## building if not (a contract that starts with its first season).
static func _sign(gs, code: String, p: Dictionary, salary: int, years: int) -> void:
	if gs.season.lists.has(code):
		gs._join(code, p)
		gs._resign(p, years, salary)
		return
	p["joined"] = GameDB.enter_year(code)
	p["club"] = code
	p["salary"] = salary
	p["contract_years"] = years
	for key in ["train_plan", "project", "released_by", "comp_eligible", "resigned", "talks"]:
		p.erase(key)
	(state(gs, code)["list"] as Array).append(p)


# ---------------------------------------------------------------------------
# The draft
# ---------------------------------------------------------------------------
## The new clubs' extra picks in this year's draft, as entries the draft
## slots in beside the compensation picks (Draft.add_compensation). Made
## before the draft is built, because a club still to enter trades the pick it
## must here and that moves a player. `pool_size` prospects, `n_clubs` clubs
## in the ordinary order.
static func draft_picks(gs, n_clubs: int, pool_size: int) -> Array:
	var comps := []
	if not on():
		return comps
	var rounds := clampi(ceili(float(pool_size) / float(maxi(1, n_clubs))), 1, 4)
	for code in building(gs):
		ensure_foundation(gs, code)
		var picks: Array = Expansion.first_draft_picks(code, n_clubs, rounds)
		forced_trade(gs, code, picks)
		comps.append_array(picks)
	for code in first_season(gs):
		comps.append_array(Expansion.second_draft_picks(code))
	return comps


## How many of the new clubs' extra picks come before the `regular`-th
## ordinary pick of this year's draft (`n` clubs in the order): what a traded
## pick's number has to allow for. Nothing for any other year's draft.
static func picks_ahead(gs, year: int, regular: int, n: int) -> int:
	if not on() or gs.season == null or year != int(gs.season_year):
		return 0
	var ahead := 0
	for code in building(gs):
		for e in Expansion.first_draft_picks(code, n, 4):
			if int(e["after"]) < regular:
				ahead += 1
	for code in first_season(gs):
		for e in Expansion.second_draft_picks(code):
			if int(e["after"]) < regular:
				ahead += 1
	return ahead


## A seat at the draft for each club still to enter, with the list it has.
static func seat_guests(gs, draft: Draft) -> void:
	if not on():
		return
	for code in building(gs):
		if not has_package(gs, code):
			continue
		var list: Array = list_of(gs, code)
		var counts := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		var pairs := []
		for p in list:
			var r := str(p["role"])
			if counts.has(r):
				counts[r] = int(counts[r]) + 1
			pairs.append([r, str(p.get("role2", ""))])
		draft.add_guest(code, list.size(), counts, pairs)


## One of the four early picks must be traded for a senior player. The club
## offers it round the league; each rival puts up the senior player it would
## give for that pick by its own valuation (the one it uses in every trade),
## and the new club takes the best of them. Never with your club yet.
static func forced_trade(gs, code: String, picks: Array) -> void:
	var st := state(gs, code)
	if bool(st.get("traded", false)):
		return
	var entry := {}
	for e in picks:
		if int(e["pick"]) == Expansion.MUST_TRADE_PICK and int(e["round"]) == 1:
			entry = e
	if entry.is_empty():
		return
	var prospects: Array = (gs.trade_prospects() as Dictionary).get(str(gs.season_year), [])
	var best := {}
	var best_club := ""
	for club in gs.season.lists:
		if str(club) == str(gs.my_club) or str(club) == code:
			continue
		var list: Array = gs.season.lists[club]
		if list.size() <= Contracts.MIN_LIST:
			continue
		var phase: String = gs.club_phase(str(club))
		var most := TradeValue.pick_value([[Expansion.MUST_TRADE_PICK, 1.0]], prospects, phase) \
				/ (1.0 + Contracts.TRADE_MARGIN)
		var bars := TradeValue.selection_bars(list)
		var proj := TradeValue.selection_bars(list, true)
		for q in list:
			if float(q.get("age", 0.0)) < Expansion.SENIOR_AGE or float(q.get("age", 0.0)) >= Expansion.TARGET_MAX_AGE \
					or gs.retiring_now(q) or gs.trade_requests.has(str(q["id"])):
				continue
			var v := float(TradeValue.value(q, {"phase": phase, "bars": bars, "proj": proj, "own": true})["total"])
			if v > most:
				continue
			if best.is_empty() or _better(q, best):
				best = q
				best_club = str(club)
	if best.is_empty():
		return   # nobody would deal: the pick stays, and the news says nothing
	(gs.season.lists[best_club] as Array).erase(best)
	var years := maxi(1, int(best.get("contract_years", 1)))
	_sign(gs, code, best, int(best.get("salary", Contracts.asking_salary(best))), years)
	entry["club"] = best_club
	entry["traded"] = true
	st["traded"] = true
	var said := "%s trade pick %d to %s for %s." % [GameDB.club_name(code), Expansion.MUST_TRADE_PICK,
			GameDB.club_name(best_club), GameDB.player_display_name(best)]
	gs.offseason_log.append({"kind": "ai_trade", "club": code, "with": best_club, "in": [str(best["id"])],
			"out": ["pick %d" % Expansion.MUST_TRADE_PICK], "text": said, "phases": ["building", gs.club_phase(best_club)]})
	gs.add_news("trade", "Trade: " + said)


# ---------------------------------------------------------------------------
# Entry, and the sign-on money
# ---------------------------------------------------------------------------
## The rollover into a club's first season: the list it built becomes its
## list, before the league ages a year. False when it built none (the switch
## is off, or the career was saved past its build): the caller generates the
## old list.
static func enter(gs, code: String) -> bool:
	if not on() or not has_package(gs, code):
		return false
	var st := state(gs, code)
	ensure_foundation(gs, code)
	var list: Array = st["list"]
	if list.is_empty():
		return false
	gs.unique_jumpers(list)
	gs.league_lists[code] = list
	st["list"] = []
	return true


## Where the list a club enters with came from, for the news.
static func entry_line(gs, code: String) -> String:
	var st: Dictionary = gs.expansion.get(code, {})
	var state_league := 0
	var signed := 0
	var drafted := 0
	for p in gs.league_lists.get(code, []):
		if str(p["id"]).begins_with("FND_"):
			state_league += 1
		elif (st.get("signings", []) as Array).has(str(p["id"])) or p.has("joined"):
			signed += 1
		else:
			drafted += 1
	return "Their list: %d from the state leagues, %d from rival clubs and %d from the draft." % [
			state_league, signed, drafted]


## The season has its lists and contracts: set this year's sign-on money for
## each club still inside its first two seasons.
static func set_relief(gs, year: int) -> void:
	if not on():
		return
	for code in gs.expansion:
		if not has_package(gs, str(code)):
			continue
		var first := GameDB.enter_year(str(code))
		if year < first or year > first + 1:
			continue
		var st: Dictionary = gs.expansion[code]
		var used := 0
		for y in st["relief"]:
			if int(y) < year:
				used += int(st["relief"][y])
		(st["relief"] as Dictionary)[str(year)] = Expansion.sign_on_relief(
				_signing_salaries(gs, str(code)), year, used)


static func _signing_salaries(gs, code: String) -> int:
	var st: Dictionary = gs.expansion.get(code, {})
	var total := 0
	for p in list_of(gs, code):
		if (st.get("signings", []) as Array).has(str(p["id"])):
			total += int(p.get("salary", 0))
	return total


## Sign-on money off `code`'s payroll: this season's, or, once the season is
## over and clubs are deciding next year's lists, next season's.
static func relief(gs, code: String) -> int:
	if not on() or not has_package(gs, code) or gs.season == null:
		return 0
	var st: Dictionary = gs.expansion[code]
	var year := int(gs.season_year)
	if not gs.offseason_open():
		return int((st["relief"] as Dictionary).get(str(year), 0))
	var first := GameDB.enter_year(code)
	if year + 1 < first or year + 1 > first + 1:
		return 0
	var used := 0
	for y in st["relief"]:
		used += int(st["relief"][y])
	return Expansion.sign_on_relief(_signing_salaries(gs, code), year + 1, used)
