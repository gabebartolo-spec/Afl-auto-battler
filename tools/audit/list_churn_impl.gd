extends RefCounted
## P-81 "List churn stays real" (proposals pass 2, director yes 2026-10-18).
## How many players does each AI club move on and bring in each year, against
## the real AFL yardstick (roughly 8 to 12 list changes a club a year; source
## and cross-check in docs/research/LIST_CHURN_AUDIT_<date>.md)?
##
## One career per seed, on autopilot: the seeded League Draft, then every
## season played with advance() and every off-season run by the same calls the
## game makes (open_offseason, the intake draft, start_next_season) with no
## management of any list. Your club is on autopilot too, so its numbers are
## printed (user=1) but the aggregator leaves it out; every other club is an AI
## club.
## For each club and off-season the list is compared before the off-season
## opens (season over) and after the next season is built. Every id that left
## is a retirement, a trade (named in the off-season log), a walk (the log
## says the club wanted him but could not fit him) or a delisting. Every id
## that arrived is a draftee, a trade or a free-agent signing.
## Measurement only: it changes no rule.
##
## Args after the impl name: seeds (comma-separated, default 301) seasons
## (default 10).
## godot --headless --path . --script tools/audit/run_audit.gd -- list_churn_impl 301,302 10
## Aggregate downloaded logs: python tools/audit/list_churn_agg.py run_*/audit.log

var dyn = load("res://tools/balance/dynasty.gd").new()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := str(args[1]) if args.size() > 1 else "301"
	var seasons := int(args[2]) if args.size() > 2 else 10
	for sd in seeds.split(",", false):
		_career(int(sd), seasons)


func _ids(list: Array) -> Dictionary:
	var out := {}
	for p in list:
		out[str(p["id"])] = true
	return out


func _career(seed: int, seasons: int) -> void:
	var gs := GameDB.get_tree().root.get_node("GameState")
	gs.autosave_enabled = false
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	var d: Draft = dyn.make_upside_draft(seed, 5)
	var user := d.user_club if d.user_club != "" else str(d.draft_order[0])
	gs.draft = d
	gs.start_season(user, [])
	var done := 0
	for y in range(seasons):
		# The lists as they stood before the last week: advance() on the last
		# week opens the off-season itself, and rivals decide their expiring
		# players there.
		var before := {}
		while not gs.season.is_season_over():
			before = {}
			for code in gs.season.lists:
				before[str(code)] = _ids(gs.season.lists[code])
			gs.advance()
		var year: int = gs.season_year
		gs.open_offseason()
		var drafting: bool = gs.begin_intake_draft()
		if drafting:
			var guard := 0
			while not gs.draft.is_finished() and guard < 5000:
				guard += 1
				var code: String = gs.draft.current_club()
				var c: Dictionary = gs.draft._best_ai_pick(code)
				if c.is_empty() or not gs.draft._draft_pick(code, c):
					gs.draft._skip_current_pick()
			gs.finish_intake_draft()
		else:
			gs.start_next_season()
		# Read after the rollover: the log keeps the whole off-season.
		var walked := {}
		var traded := {}
		for e in gs.offseason_log:
			var kind := str(e.get("kind", ""))
			if kind == "released":
				walked[str(e["id"])] = bool(e.get("wanted", false))
			elif kind == "ai_trade" or kind == "trade":
				var ids: Array = (e.get("in", []) as Array) + (e.get("out", []) as Array)
				for id in ids:
					traded[str(id)] = true
		var kinds := {}
		for e in gs.offseason_log:
			kinds[str(e.get("kind", ""))] = int(kinds.get(str(e.get("kind", "")), 0)) + 1
		print("LOG seed %d year %d | off-season log rows %s | free agents left unsigned %d" % [
				seed, year, str(kinds), gs.free_agents.size()])
		var retired := {}
		for r in (gs.intake_summary.get("retired", []) as Array):
			retired[str(r["id"])] = true
		var drafted: Dictionary = gs.drafted_draftees
		for code in before:
			if not gs.season.lists.has(code):
				continue
			var was: Dictionary = before[code]
			var now := _ids(gs.season.lists[code])
			var a := {"delisted": 0, "walked": 0, "retired": 0, "traded_out": 0,
					"drafted": 0, "traded_in": 0, "signed": 0, "kept": 0}
			# Released into the market and back on this club's list by the
			# rollover: no change to the list, counted apart.
			for id in was:
				if walked.has(id) and now.has(id):
					a["kept"] += 1
			for id in was:
				if now.has(id):
					continue
				if retired.has(id):
					a["retired"] += 1
				elif traded.has(id) and not walked.has(id):
					a["traded_out"] += 1
				elif walked.has(id) and bool(walked[id]):
					a["walked"] += 1
				else:
					a["delisted"] += 1
			for id in now:
				if was.has(id):
					continue
				if drafted.has(id) and str(drafted[id]) == code:
					a["drafted"] += 1
				elif traded.has(id):
					a["traded_in"] += 1
				else:
					a["signed"] += 1
			var out_n: int = a["delisted"] + a["walked"] + a["retired"] + a["traded_out"]
			var in_n: int = a["drafted"] + a["traded_in"] + a["signed"]
			print("CHURN seed %d year %d club %s user %d | before %d after %d | delisted %d walked %d retired %d traded_out %d | drafted %d traded_in %d signed %d | out %d in %d | kept %d" % [
					seed, year, code, 1 if code == user else 0, was.size(), now.size(),
					a["delisted"], a["walked"], a["retired"], a["traded_out"],
					a["drafted"], a["traded_in"], a["signed"], out_n, in_n, a["kept"]])
		done += 1
	print("SUMMARY seed %d user %s offseasons %d" % [seed, user, done])
