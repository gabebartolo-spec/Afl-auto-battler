class_name ExpansionBuild
extends RefCounted
## GameState's side of a new club's list build (the rules are in Expansion).
## `gs` is GameState.
##
## A club entering in year E:
##   season E-1, late   approach(): it names the out-of-contract players it
##                      wants, one per rival club. Yours comes as a card.
##   season E-1 ends    resolve(): a rival re-signs the players it would have
##                      kept; the rest join the new club's list.
##   draft before E     draft_setup(): picks 1, 3, 5, 7, 9, 11, 13 and the first
##                      pick of later rounds; 5, 7, 11, 13 traded for senior
##                      players (forced_trade).
##   rollover into E    enter(): the list it built is the list it fields.
##   season E           a second round of approaches.
##   drafts E, E+1      picks 5 and 9 extra; pick 5 traded.
##   drafts E-1 to E+2  home-state prospects join before the draft.
##
## gs.expansion[code] = {"package": true, "list": [players before entry],
##   "approached": [years], "targets": [{"id", "club", "name", "year",
##   "status": "asked" | "kept" | "joining" | "joined" | "stayed", "carded"}],
##   "lost": [clubs that have lost a player to it], "signings": [player ids],
##   "relief": {year: sign-on money off the payroll}, "traded": bool}
## The package is the modern one (expansion_concessions in era_rules.csv, from
## Gold Coast's 2011 entry). A club entering before it (Adelaide 1991,
## Fremantle 1995, Port Adelaide 1997) approaches nobody, gets no extra or
## traded picks and no sign-on money: it enters on a full list from its home
## state league (ensure_foundation), as those clubs were built.
## A coach running the new club himself comes later: the choices the club
## makes for itself here (who to approach, who to draft, which pick to trade)
## are the seams.


## Clubs whose first season is next year and that build their list this way
## (every such club that enters with the expansion concessions).
static func building(gs) -> Array:
	return entering(gs).filter(func(code): return concessions(str(code)))


## Every club whose first season is next year, however it builds its list.
static func entering(gs) -> Array:
	var out := []
	if gs.season == null:
		return out
	for code in GameDB.club_order:
		if GameDB.enter_year(str(code)) == int(gs.season_year) + 1:
			out.append(str(code))
	return out


## Whether a club entering in its entry year gets the expansion concessions:
## approaches to rivals' out-of-contract players, the compensation that pays
## for them, extra and traded picks, sign-on money. The rule of the entry
## season (EraRules: from Gold Coast, 2011; always in the game's own seasons).
static func concessions(code: String) -> bool:
	return Expansion.concessions(code)


## Clubs in their first season that built their list this way.
static func first_season(gs) -> Array:
	var out := []
	if gs.season == null:
		return out
	for code in gs.expansion:
		if GameDB.enter_year(str(code)) == int(gs.season_year) and has_package(gs, str(code)):
			out.append(str(code))
	return out


## Clubs holding the extra picks in the draft after `year`'s season, past
## their first draft: the two drafts after it.
static func later_draft_clubs(gs, year: int) -> Array:
	var out := []
	for code in gs.expansion:
		var first := GameDB.enter_year(str(code))
		if (year == first or year == first + 1) and has_package(gs, str(code)):
			out.append(str(code))
	return out


## The club with first call on this prospect in this year's draft, or "".
static func academy_club(gs, p: Dictionary) -> String:
	if str(p.get("state", "")) != "TAS":
		return ""
	var year := int(gs.season_year)
	var first := GameDB.enter_year("TAS")
	if year < first - 1 or year >= first - 1 + Expansion.ACADEMY_DRAFTS:
		return ""
	return "TAS" if has_package(gs, "TAS") or year == first - 1 else ""


static func has_package(gs, code: String) -> bool:
	return bool((gs.expansion.get(code, {}) as Dictionary).get("package", false)) and concessions(code)


static func state(gs, code: String) -> Dictionary:
	if not gs.expansion.has(code):
		gs.expansion[code] = {"package": concessions(code), "list": [], "approached": [], "targets": [],
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
	# A Legacy club's foundation is its real state-league players; those past
	# Expansion.foundation_size go into the draft before it plays (LegacyRollover).
	var first := GameDB.enter_year(code)
	if LegacyRollover.has_foundation(code, first):
		var got := LegacyRollover.foundation(gs, code, first)
		st["list"] = got["list"]
		gs.draftee_pool.append_array(got["pool"])
	else:
		st["list"] = Expansion.foundation_list(code, int(gs.season_year), int(gs.career_seed))
	for p in st["list"]:
		p["club"] = code
		# State-league signings, no AFL games: a draftee's familiarity (row 125).
		TeamFamiliarity.arrive_draftee(p)


# ---------------------------------------------------------------------------
# Out-of-contract players
# ---------------------------------------------------------------------------
## Each week: with a few rounds left, the new clubs make their approaches.
static func week(gs) -> void:
	if gs.season == null or gs.season.is_regular_done():
		return
	if int(gs.season.round_index) < gs.season.regular_rounds() - Expansion.APPROACH_ROUNDS_LEFT:
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
	if list.size() <= Contracts.min_list():
		return {}
	var best := {}
	for p in Contracts.expiring(list):
		if not _available(gs, p) or role_at(p, bars) == "depth":
			continue
		if club != str(gs.my_club):
			if int(p.get("overall", 0)) >= Expansion.STAR_STAYS_OVERALL:
				continue
			var why: String = gs.ai_release_reason(club, p)
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
	for code in gs.expansion:
		for t in (gs.expansion[code] as Dictionary).get("targets", []):
			if str(t["club"]) == str(gs.my_club) and str(t["status"]) == "asked" \
					and int(t["year"]) == int(gs.season_year):
				return t
	return {}


## The new club that made this approach.
static func asked_by(gs, t: Dictionary) -> String:
	for code in gs.expansion:
		if ((gs.expansion[code] as Dictionary).get("targets", []) as Array).has(t):
			return str(code)
	return ""


## The new club asking about your player: the one with an approach waiting,
## else the next club to enter (so the card can always be read).
static func asking_club(gs) -> String:
	var t := pending_target(gs)
	if not t.is_empty():
		return asked_by(gs, t)
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
	return ClubStories.card_for(gs, "contracts_new_club_approach", p, card_facts(gs, p, asked_by(gs, t)))


## What the card needs to say: who is asking, what keeping him costs, and
## what losing him would bring.
static func card_facts(gs, p: Dictionary, code: String) -> Dictionary:
	var want := Contracts.wants(p)
	var price := int(want["salary"])
	var years := int(want["years"])
	var room: bool = int(gs.my_payroll()) - int(p.get("salary", 0)) + price <= int(gs.cap_for(str(gs.my_club)))
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
	if int(gs.my_payroll()) - int(p.get("salary", 0)) + price > int(gs.cap_for(str(gs.my_club))):
		if not t.is_empty():
			t["status"] = "joining"
		return "The cap has no room for %s a season. %s will go when the season ends." % [Contracts.money(price), name]
	# Under 50, he may refuse you (director 2026-11-08): the draw talks use.
	if gs.resign_refused(p):
		if not t.is_empty():
			t["status"] = "joining"
		return gs.refuse_resign(p, "He joins %s when the season ends." % GameDB.club_name(asked_by(gs, t))
				if not t.is_empty() else Contracts.REFUSED_SEASON_END)
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
			GameDB.club_name(asked_by(gs, t)), str(compensation(gs, p)["line"])]


## The season is over: every approach is settled, before rivals re-sign and
## release as they always do. A rival keeps a player it would have kept and
## can pay; yours goes or stays as you answered (unanswered, with the story
## cards off, by the rule a rival follows). A club that was never approached
## this year (a career saved past that week) is approached now, rivals only.
static func resolve(gs) -> void:
	if gs.season == null:
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
	if p.is_empty() or not _available(gs, p) or list.size() <= Contracts.min_list() \
			or (st["signings"] as Array).size() >= Expansion.SIGNINGS \
			or not RookieList.senior_spot_free(list_of(gs, code)):
		t["status"] = "stayed"
		return
	var wanted := true
	if club != str(gs.my_club) or str(t["status"]) == "asked":
		var why: String = gs.ai_release_reason(club, p)
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
	TeamFamiliarity.arrive_club(p, gs.games_played(p) == 0)
	p["salary"] = salary
	p["contract_years"] = years
	for key in ["train_plan", "train_focus", "train_focus_year", "focus_ledger", "project", "released_by", "comp_eligible", "resigned", "talks", "rookie_list"]:
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
	var rounds := clampi(ceili(float(pool_size) / float(maxi(1, n_clubs))), 1, 4)
	for code in building(gs):
		ensure_foundation(gs, code)
		var picks: Array = Expansion.first_draft_picks(code, n_clubs, rounds)
		for pick in Expansion.MUST_TRADE_PICKS:
			forced_trade(gs, code, picks, int(pick))
		_make_room(gs, code, picks)
		comps.append_array(picks)
	for code in later_draft_clubs(gs, int(gs.season_year)):
		var picks: Array = Expansion.later_draft_picks(code)
		forced_trade(gs, code, picks, Expansion.LATER_MUST_TRADE_PICK)
		if code != str(gs.my_club):
			_make_room(gs, code, picks)
		comps.append_array(picks)
	return comps


## The club's lowest-rated state-league signings make way, so every pick it
## still holds fits in the senior spots the draft fills.
static func _make_room(gs, code: String, picks: Array) -> void:
	var list: Array = list_of(gs, code)
	var held := 0
	for e in picks:
		if str(e["club"]) == code:
			held += 1
	var over := RookieList.draft_size(list) + held - RookieList.senior_spots()
	if over <= 0:
		return
	var state_league := list.filter(func(p): return str(p["id"]).begins_with("FND_"))
	# A real player (a Legacy foundation) makes way last, and goes back into
	# the prospects for next year's draft rather than out of the game.
	state_league.sort_custom(func(a, b):
		var ra := str(a.get("real_name", "")) != ""
		var rb := str(b.get("real_name", "")) != ""
		if ra != rb:
			return rb
		return int(a["overall"]) < int(b["overall"]))
	for p in state_league.slice(0, over):
		list.erase(p)
		if str(p.get("real_name", "")) != "":
			p["club"] = ""
			p["draft_year"] = int(gs.season_year)
			gs.draftee_pool.append(p)


## How many of the new clubs' extra picks come before the `regular`-th
## ordinary pick of this year's draft (`n` clubs in the order): what a traded
## pick's number has to allow for. Nothing for any other year's draft.
static func picks_ahead(gs, year: int, regular: int, n: int) -> int:
	if gs.season == null:
		return 0
	var ahead := 0
	if year == int(gs.season_year):
		for code in building(gs):
			for e in Expansion.first_draft_picks(code, n, 4):
				if int(e["after"]) < regular:
					ahead += 1
		for code in later_draft_clubs(gs, year):
			for e in Expansion.later_draft_picks(code):
				if int(e["after"]) < regular:
					ahead += 1
	elif year == int(gs.season_year) + 1:
		# Next year's draft: a club entering then is in its first season.
		for code in building(gs) + later_draft_clubs(gs, year):
			for e in Expansion.later_draft_picks(code):
				if int(e["after"]) < regular:
					ahead += 1
	return ahead


## A seat at the draft for each club still to enter, with the list it has.
static func seat_guests(gs, draft: Draft) -> void:
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


## A pick that must be traded for a senior player. The club offers it round
## the league; each rival puts up the senior player it would
## give for that pick by its own valuation (the one it uses in every trade),
## and the new club takes the best of them. Never with your club yet.
static func forced_trade(gs, code: String, picks: Array, pick_no: int) -> void:
	var st := state(gs, code)
	# A save from before these rules made its one trade already.
	if bool(st.get("traded", false)) and int(gs.season_year) < GameDB.enter_year(code):
		return
	var done_key := "%d:%d" % [int(gs.season_year), pick_no]
	if not st.has("traded_picks"):
		st["traded_picks"] = []
	if (st["traded_picks"] as Array).has(done_key):
		return
	var entry := {}
	for e in picks:
		if int(e["pick"]) == pick_no and int(e["round"]) == 1:
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
		if list.size() <= Contracts.min_list():
			continue
		var phase: String = gs.club_phase(str(club))
		var most := TradeValue.pick_value([[pick_no, 1.0]], prospects, phase) \
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
	# His deal runs on from where it was, ticked down a season at the rollover
	# like everyone's (the list he joins is not ticked).
	var years := maxi(1, int(best.get("contract_years", 1)) - (0 if gs.season.lists.has(code) else 1))
	_sign(gs, code, best, int(best.get("salary", Contracts.asking_salary(best))), years)
	entry["club"] = best_club
	entry["traded"] = true
	(st["traded_picks"] as Array).append(done_key)
	var said := "%s trade pick %d to %s for %s." % [GameDB.club_name(code), pick_no,
			GameDB.club_name(best_club), GameDB.player_display_name(best)]
	gs.offseason_log.append({"kind": "ai_trade", "club": code, "with": best_club, "in": [str(best["id"])],
			"out": ["pick %d" % pick_no], "text": said, "phases": ["building", gs.club_phase(best_club)]})
	gs.add_news("trade", "Trade: " + said)


# ---------------------------------------------------------------------------
# Entry, and the sign-on money
# ---------------------------------------------------------------------------
## The rollover into a club's first season: the list it built becomes its
## list, before the league ages a year. False when it built none (the career
## was saved past its build): the caller generates the old list.
static func enter(gs, code: String) -> bool:
	# A club with the concessions that built nothing was saved past its build;
	# one entering before them builds its state-league list now.
	if concessions(code) and not has_package(gs, code):
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
	if signed == 0 and drafted == 0:
		return "Their list: %d players from the state leagues." % state_league
	return "Their list: %d from the state leagues, %d from rival clubs and %d from the draft." % [
			state_league, signed, drafted]


## The season has its lists and contracts: set this year's sign-on money for
## each club still inside its first two seasons, or the two after them, when
## it steps down (Expansion.SIGN_ON_TAPER).
static func set_relief(gs, year: int) -> void:
	for code in gs.expansion:
		if not has_package(gs, str(code)):
			continue
		var first := GameDB.enter_year(str(code))
		if year < first or year > first + 1 + Expansion.SIGN_ON_TAPER.size():
			continue
		(gs.expansion[code]["relief"] as Dictionary)[str(year)] = _relief_in(gs, str(code), year)


## `code`'s sign-on money in `year`: from the pool in its first two seasons,
## a share of the second season's in the two after, nothing otherwise.
static func _relief_in(gs, code: String, year: int) -> int:
	var st: Dictionary = gs.expansion[code]
	var first := GameDB.enter_year(code)
	if year < first:
		return 0
	if year > first + 1:
		return Expansion.tapered_relief(int((st["relief"] as Dictionary).get(str(first + 1), 0)),
				year - first + 1, _signing_salaries(gs, code))
	var used := 0
	for y in st["relief"]:
		if int(y) < year:
			used += int(st["relief"][y])
	return Expansion.sign_on_relief(_signing_salaries(gs, code), year, used)


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
	if not has_package(gs, code) or gs.season == null:
		return 0
	var st: Dictionary = gs.expansion[code]
	var year := int(gs.season_year)
	if not gs.offseason_open():
		# A save from before the money stepped down has no figure for its
		# third or fourth season: worked out here, the same way.
		if not (st["relief"] as Dictionary).has(str(year)):
			return _relief_in(gs, code, year) if year > GameDB.enter_year(code) + 1 else 0
		return int((st["relief"] as Dictionary).get(str(year), 0))
	return _relief_in(gs, code, year + 1)
