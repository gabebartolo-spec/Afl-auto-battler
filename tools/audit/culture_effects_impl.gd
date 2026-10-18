extends RefCounted
## Club culture's effects (small), on against off: does culture tilt the league
## or snowball it? Args after the impl name: seed club seasons on [force]
## (`culture_effects_impl 1 MEL 10 1 elite,very,rebuild`; on = 0 turns the effects off,
## nothing else changes; force pins your club's three strands to those bands at the
## start of every season, so a paired on/off run measures one known culture).
##
## With force, each ROW also prints your club: new injuries, mean morale at the end
## of the season, and the mean rating gained by its under-22s and first-season
## draftees (the players a patient club brings on).
##
## Per season prints one ROW: the spread (standard deviation) of wins across the clubs, new injuries
## across the league, mean morale of every list, the mean re-sign floor of your list, and how the
## top and bottom thirds by culture did the NEXT season (the snowball). SUMMARY averages them and
## adds where free agents went (share of signings to clubs that were "pushing to win now" or
## "all in" against their share of the league).


func _run_draft(d: Draft) -> void:
	var guard := 0
	while not d.is_finished() and guard < 5000:
		guard += 1
		var c := d._best_ai_pick(d.current_club())
		if c.is_empty() or not d._draft_pick(d.current_club(), c):
			d._skip_current_pick()


func _std(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var m := 0.0
	for x in xs:
		m += float(x)
	m /= xs.size()
	var v := 0.0
	for x in xs:
		v += (float(x) - m) * (float(x) - m)
	return sqrt(v / xs.size())


func _culture_sum(code: String) -> int:
	var t := 0
	for s in Culture.STRANDS:
		t += Culture.value(GameState.relations, code, str(s[0]))
	return t


func _wins() -> Dictionary:
	var out := {}
	for c in GameState.season.ladder:
		out[str(c)] = int(GameState.season.ladder[c]["w"])
	return out


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[1]) if args.size() > 1 else 1
	var club := str(args[2]) if args.size() > 2 else "MEL"
	var seasons := int(args[3]) if args.size() > 3 else 10
	var on := (int(args[4]) if args.size() > 4 else 1) == 1
	var force: PackedStringArray = str(args[5]).split(",") if args.size() > 5 else PackedStringArray()
	GameState.reset()
	GameState.show_real_names = false
	GameState.career_seed = seed
	GameState.replay_seed = seed
	GameState.autosave_enabled = false
	GameState.culture_effects_on = on
	var pool: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	pool.sort_custom(func(a, b): return a["overall"] > b["overall"])
	GameState.draft = Draft.new(pool, GameDB.active_clubs(GameState.season_year).duplicate(), seed)
	GameState.draft.start_for_user(club)
	_run_draft(GameState.draft)
	GameState.start_season(club, GameState.draft.list())
	var spreads := []
	var injuries_all := []
	var morales := []
	var floors := []
	var snow := []
	var signed_total := 0
	var signed_push := 0
	var push_share := []
	var seen := {}
	var prev_culture := {}
	var inj := 0
	var mine_rows := []
	for s in range(seasons):
		var year := GameState.season_year
		inj = 0
		var my_inj := 0
		if force.size() == 3:
			for i in range(3):
				var strand := str(Culture.STRANDS[i][0])
				for b in Culture.BANDS[strand]:
					if str(b[1]) == force[i]:
						GameState.relations[Culture.key(GameState.my_club, strand)] = {"t": int(b[0]) + 25 if int(b[0]) > -100 else -80, "log": []}
		var young_start := {}
		for p in GameState.my_list:
			if Culture.young_for_growth(p, year):
				young_start[str(p["id"])] = int(p.get("overall", 0))
		while not GameState.season.is_season_over() and not GameState.is_sacked():
			if GameState.week_event_pending():
				GameState.resolve_week_event(0)
			if GameState.media_conference_pending():
				GameState.skip_media_conference()
			GameState.advance()
			inj += GameState.last_injuries.size()
			for e in GameState.last_injuries:
				if str((e as Dictionary).get("club", "")) == GameState.my_club:
					my_inj += 1
		if force.size() == 3:
			var gain := 0.0
			var n := 0
			for p in GameState.my_list:
				if young_start.has(str(p["id"])):
					gain += float(int(p.get("overall", 0)) - int(young_start[str(p["id"])]))
					n += 1
			var mm := 0.0
			for p in GameState.my_list:
				mm += float(ClubLife.morale(p))
			mm /= float(maxi(1, GameState.my_list.size()))
			mine_rows.append([my_inj, mm, gain / float(maxi(1, n))])
			print("MINE seed %d on %d year %d | bands %s | my injuries %d | my morale %.2f | young rating gain %.2f (%d players)" % [
					seed, 1 if on else 0, year, ",".join(force), my_inj, mm, gain / float(maxi(1, n)), n])
		var wins := _wins()
		if not prev_culture.is_empty():
			var codes: Array = prev_culture.keys()
			codes.sort_custom(func(a, b): return int(prev_culture[a]) > int(prev_culture[b]))
			var third := maxi(1, codes.size() / 3)
			var top := 0.0
			var bot := 0.0
			for i in range(third):
				top += float(wins.get(codes[i], 0))
				bot += float(wins.get(codes[codes.size() - 1 - i], 0))
			snow.append((top - bot) / float(third))
		var wl := []
		for c in wins:
			wl.append(wins[c])
		var morale_sum := 0.0
		var morale_n := 0
		for code in GameState.season.lists:
			for p in GameState.season.lists[code]:
				morale_sum += float(ClubLife.morale(p))
				morale_n += 1
		var floor_sum := 0.0
		for p in GameState.my_list:
			floor_sum += float(Contracts.lowest(p, 2)) * (1.0 - GameState.culture_effect(GameState.my_club, "resign_floor"))
		var row_spread := _std(wl)
		spreads.append(row_spread)
		injuries_all.append(inj)
		morales.append(morale_sum / float(maxi(1, morale_n)))
		floors.append(floor_sum / float(maxi(1, GameState.my_list.size())))
		prev_culture = {}
		for code in GameState.season.lists:
			prev_culture[str(code)] = _culture_sum(str(code))
		print("ROW seed %d on %d year %d | win spread %.2f | injuries %d | morale %.2f | re-sign floor %.0f | top-minus-bottom third wins next year %s" % [
				seed, 1 if on else 0, year, row_spread, inj, morales.back(), floors.back(),
				("%.2f" % snow.back()) if snow.size() > 0 and s > 0 else "-"])
		if s == seasons - 1 or GameState.is_sacked():
			break
		GameState.open_offseason()
		if GameState.begin_intake_draft():
			_run_draft(GameState.draft)
			GameState.finish_intake_draft()
		else:
			GameState.start_next_season()
		var amb_push := 0
		for code in GameState.season.lists:
			if ["now", "allin"].has(Culture.band_key("ambition", Culture.value(GameState.relations, str(code), "ambition"))):
				amb_push += 1
		push_share.append(float(amb_push) / float(maxi(1, GameState.season.lists.size())))
		for e in GameState.offseason_log:
			if str(e.get("kind", "")) != "signed":
				continue
			var k := "%d:%s" % [year, str(e["id"])]
			if seen.has(k):
				continue
			seen[k] = true
			signed_total += 1
			var band := Culture.band_key("ambition", Culture.value(GameState.relations, str(e["club"]), "ambition"))
			if ["now", "allin"].has(band):
				signed_push += 1
	var mean := func(xs: Array) -> float:
		var t := 0.0
		for x in xs:
			t += float(x)
		return t / float(maxi(1, xs.size()))
	if not mine_rows.is_empty():
		var a := [0.0, 0.0, 0.0]
		for r in mine_rows:
			for i in range(3):
				a[i] += float(r[i]) / float(mine_rows.size())
		print("MINESUM seed %d on %d %s | my injuries a season %.2f | my morale %.2f | young rating gain a season %.2f" % [
				seed, 1 if on else 0, club, a[0], a[1], a[2]])
	print("SUMMARY seed %d on %d %s | win spread %.2f | injuries a season %.1f | morale %.2f | re-sign floor %.0f | top-minus-bottom third next-year wins %.2f | free agents signed %d, to pushing clubs %d (%.0f%%) against %.0f%% of clubs" % [
			seed, 1 if on else 0, club, mean.call(spreads), mean.call(injuries_all), mean.call(morales), mean.call(floors),
			mean.call(snow), signed_total, signed_push, 100.0 * float(signed_push) / float(maxi(1, signed_total)),
			100.0 * mean.call(push_share)])
