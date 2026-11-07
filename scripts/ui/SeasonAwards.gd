class_name SeasonAwards
extends RefCounted
## Read-only ceremony over the review; stored results remain authoritative.
##
## Awards night (T5.Q23b): when the season's votes were recorded round by round
## (AwardsCount), the Brownlow is counted round by round, watched live or a
## round at a time, with the Coleman Medal named before it and the Rising Star
## presented at the halfway mark; then the Golden Fist and the All-Australian
## team; then your club's best and fairest, counted game by game with its
## finals. Each count ends on the stored winner. A season without the whole
## record (a save from before it existed, or one loaded part way through)
## keeps the winner-by-winner reveal. Presentation only: nothing here touches
## a vote.

static func open(host: Control) -> Control:
	var aw: Dictionary = GameState.season_awards
	var year := int(aw.get("year", GameState.season_year))
	var season: Season = GameState.season
	var rounds := season.fixture.size() if season != null and not season.fixture.is_empty() else Season.REGULAR_ROUNDS
	var record: Dictionary = GameState.award_counts
	var counted := AwardsCount.complete(record, year, GameState.my_club, rounds)
	# A count fills the screen's height, so the controls never jump as the
	# board grows round by round.
	var box := UiKit.modal_box(host, 580.0, 0.0, UiKit.AUTO_COLOUR, false, counted)
	var overlay: Control = box["overlay"]
	overlay.name = "SeasonAwards"
	UiKit.close_on_outside_tap(box)
	var body: VBoxContainer = box["body"]
	var footer: VBoxContainer = box["footer"]
	var club_award := BestAndFairest.award_name(GameState.my_club)
	var club_rows: Array = (aw.get("best_and_fairest", {}) as Dictionary).get(GameState.my_club, [])
	# [title, subtitle, rows, metric, count]: count is "votes" or "bf" for a
	# stage counted round by round.
	var stages := []
	if counted:
		stages = [
			["Brownlow Medal", "Home-and-away votes", aw.get("brownlow", []), "votes", "votes"],
			[Awards.GOLDEN_FIST, "Best defender, finals included", aw.get("golden_fist", []), "fist", ""],
			["All-Australian", "The season's team", aw.get("all_australian", []), "", ""],
			[club_award, GameDB.club_name(GameState.my_club), club_rows, "bf", "bf"],
		]
	else:
		stages = [
			["Brownlow Medal", "Home-and-away votes", aw.get("brownlow", []), "votes", ""],
			["Coleman Medal", "Home-and-away goals", aw.get("coleman", []), "goals", ""],
			# The best defender, lockdown or intercept, each judged against his own kind;
			# the winner's line shows which. Absent in a season played before it existed.
			[Awards.GOLDEN_FIST, "Best defender, finals included", aw.get("golden_fist", []), "fist", ""],
			["All-Australian", "The season's team", aw.get("all_australian", []), "", ""],
			[club_award, GameDB.club_name(GameState.my_club), club_rows, "bf", ""],
		]
	stages = stages.filter(func(st): return str(st[3]) != "fist" or not (st[2] as Array).is_empty())
	# A replay starts again from Round 1; a night left part way resumes where
	# it was left (season_awards["count_at"]).
	var replay := bool(aw.get("presentation_seen", false))
	var at: Dictionary = {} if replay or not counted else aw.get("count_at", {})
	var state := {"stage": clampi(int(at.get("stage", 0)), 0, stages.size() - 1),
			"revealed": bool(at.get("revealed", false)), "vignette": null, "view": null,
			"resume": at, "paused": false}
	var keep := func() -> void:
		if not counted or replay:
			return
		var pos := {"stage": int(state["stage"]), "revealed": bool(state["revealed"])}
		var view = state["view"]
		if is_instance_valid(view):
			pos.merge((view as AwardsCountView).position())
		GameState.season_awards["count_at"] = pos
		GameState.mark_dirty()
	var done := func() -> void:
		GameState.season_awards["presentation_seen"] = true
		GameState.season_awards.erase("count_at")
		GameState.mark_dirty()
		GameState.autosave()
		overlay.queue_free()
	var next := UiKit.btn("Reveal results", UiKit.NAME, true)
	next.name = "AwardsNext"
	next.custom_minimum_size.y = 48
	# The count's controls: Watch or Pause, Skip round, Skip to the result, and
	# the next round as the main action (director rulings 121 and 3.57).
	var watch := UiKit.btn("Watch", UiKit.NAME)
	watch.name = "CountWatch"
	var skip_round := UiKit.btn("Skip round", UiKit.NAME)
	skip_round.name = "CountSkipRound"
	var skip_all := UiKit.btn("Skip to the result", UiKit.NAME)
	skip_all.name = "CountSkipAll"
	if counted:
		var skip := UiKit.text_action("Skip to season review", UiKit.SECONDARY)
		skip.name = "AwardsSkip"
		skip.custom_minimum_size.y = 48
		skip.add_theme_color_override("font_color", UiKit.MUTED)
		skip.pressed.connect(done)
		footer.add_child(skip)
		var controls := UiKit.vbox(6)
		controls.name = "CountControls"
		var top := UiKit.hbox(6)
		var bottom := UiKit.hbox(6)
		controls.add_child(top)
		controls.add_child(bottom)
		for pair in [[top, watch], [top, skip_round], [bottom, skip_all], [bottom, next]]:
			var b: Button = pair[1]
			b.custom_minimum_size.y = 48
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			(pair[0] as HBoxContainer).add_child(b)
		footer.add_child(controls)
	else:
		var skip := UiKit.btn("Skip to season review", 14)
		skip.name = "AwardsSkip"
		skip.custom_minimum_size.y = 44
		skip.pressed.connect(done)
		footer.add_child(skip)
		footer.add_child(next)
	# The buttons say what the count can do from where it stands.
	var sync := func() -> void:
		if not counted:
			return
		var view = state["view"]
		var counting: bool = is_instance_valid(view) and not (view as AwardsCountView).done()
		watch.get_parent().visible = counting
		watch.visible = counting
		skip_all.visible = counting
		# Your club's count reads a game a round: Next game does what Skip round would.
		skip_round.visible = counting and (view as AwardsCountView).kind == "votes"
		if not counting:
			if is_instance_valid(view):
				next.text = "Reveal winner"
			return
		var v: AwardsCountView = view
		watch.text = "Pause" if v.live else ("Resume" if bool(state["paused"]) else "Watch")
		next.text = "Next round" if v.kind == "votes" else "Next game"
	var build := func() -> void:
		UiKit.clear(body)
		state["vignette"] = null
		state["view"] = null
		var stage: Array = stages[int(state["stage"])]
		var count := str(stage[4])
		if count != "" and not bool(state["revealed"]):
			var view := _count_view(count, stage, aw, record)
			view.name = "AwardsCount"
			view.restore(state["resume"] as Dictionary)
			state["resume"] = {}
			body.add_child(view)
			view.render()
			state["view"] = view
			view.moved.connect(func() -> void:
				sync.call()
				keep.call())
			sync.call()
			return
		sync.call()
		body.add_child(UiKit.lbl(str(stage[0]), 22, StatsSide.mine_ink(), true))
		body.add_child(_words(str(stage[1]), UiKit.MUTED))
		var rows: Array = stage[2]
		var metric := str(stage[3])
		if not bool(state["revealed"]):
			body.add_child(_words("%d season awards" % year, UiKit.MUTED))
			next.text = "Reveal team" if metric == "" else "Reveal winner"
			return
		if rows.is_empty():
			body.add_child(_words("No result recorded.", UiKit.MUTED))
		elif metric == "":
			var mine := 0
			for row in rows:
				if str(row.get("club", "")) == GameState.my_club:
					mine += 1
			body.add_child(_words("%d %s %s selected." % [mine, GameDB.club_name(GameState.my_club),
					"player" if mine == 1 else "players"], StatsSide.mine_ink(), 15, true))
			for row in rows:
				var line := "%s · %s · %s" % [GameState.award_name(row),
					GameDB.club_short(str(row.get("club", ""))), str({"RUCK": "Ruck", "MID": "Midfield", "DEF": "Defence", "FWD": "Forward", "BENCH": "Interchange"}.get(str(row.get("slot", "")), ""))]
				# Each in his club's colour where it reads; yours in bold.
				var club_code := str(row.get("club", ""))
				body.add_child(_words(line, StatsSide.ink(club_code), 15, club_code == GameState.my_club))
		else:
			# The stored order already includes the engine's tiebreak. Do not
			# invent shared medals by looking only at a tied displayed total.
			var winner: Dictionary = rows[0]
			# The Brownlow goes to the first eligible player (Awards'
			# brownlow_winner), the medallist every other screen names.
			if metric == "votes" and not (aw.get("brownlow_winner", {}) as Dictionary).is_empty():
				winner = aw["brownlow_winner"]
			var code := str(winner.get("club", GameState.my_club))
			# Vignettes off (Settings): the winner without the stage.
			if GameState.vignettes_on():
				var scene := AwardWinnerVignette.new()
				scene.name = "AwardWinner"
				scene.custom_minimum_size = Vector2(0, 240)   # the stage and the room in front of it
				body.add_child(scene)
				var jumper := 0
				for p in GameState.season.lists.get(code, []) if GameState.season != null else []:
					if str(p.get("id", "")) == str(winner.get("id", "")):
						jumper = int(p.get("num", 0))
				scene.setup_winner(code, jumper, str(winner.get("id", "")))
				state["vignette"] = scene
			# The winner leads, in his club's colour where it reads.
			body.add_child(_words(GameState.award_name(winner), StatsSide.ink(code), 24, true))
			body.add_child(_words("%s · %s" % [GameDB.club_name(code), _figure(winner, metric)], UiKit.TEXT))
			# A counted award has just shown its final count; the placings
			# follow only the winner-by-winner reveal.
			if metric != "goals" and rows.size() > 1 and count == "":
				body.add_child(_words("Final placings", UiKit.TEXT, 15, true))
				# The Golden Fist names its top three, each with his own counts.
				var others := rows.filter(func(r): return str(r.get("id", "")) != str(winner.get("id", "")))
				for i in range(mini(2 if metric == "fist" else 4, others.size())):
					var row: Dictionary = others[i]
					var rc := str(row.get("club", ""))
					body.add_child(_words("%d. %s · %s%s" % [i + 2, GameState.award_name(row),
							_figure(row, metric),
							# Brownlow eligibility only: a suspension never touches the club B&F.
							" (ineligible)" if metric == "votes" and not bool(row.get("brownlow_eligible", true)) else ""],
							StatsSide.ink(rc), 15, rc == GameState.my_club))
		var last := int(state["stage"]) == stages.size() - 1
		next.text = "Season review" if last else "Next award"
		var animation = state["vignette"]
		if is_instance_valid(animation):
			var after := next.text
			next.text = "Finish reveal"
			animation.finished.connect(func(): next.text = after)
	watch.pressed.connect(func() -> void:
		var view = state["view"]
		if is_instance_valid(view):
			state["paused"] = (view as AwardsCountView).live
			(view as AwardsCountView).watch())
	skip_round.pressed.connect(func() -> void:
		var view = state["view"]
		if is_instance_valid(view):
			(view as AwardsCountView).skip_round())
	skip_all.pressed.connect(func() -> void:
		var view = state["view"]
		if is_instance_valid(view):
			(view as AwardsCountView).skip_all())
	next.pressed.connect(func() -> void:
		var view = state["view"]
		if is_instance_valid(view) and not (view as AwardsCountView).done():
			if (view as AwardsCountView).live:
				state["paused"] = true
			(view as AwardsCountView).next_round()
			return
		if not bool(state["revealed"]):
			state["revealed"] = true
		else:
			var scene = state["vignette"]
			if is_instance_valid(scene) and not scene._done:
				scene.finish_now()
				return
			state["stage"] = int(state["stage"]) + 1
			state["revealed"] = false
			state["paused"] = false
			if int(state["stage"]) >= stages.size():
				done.call()
				return
		build.call()
		keep.call())
	build.call()
	# Without a count its controls never join the page. They go with the
	# overlay, not before: the lambdas above hold them, and a lambda whose
	# captured node was freed fails on every call.
	if not counted:
		overlay.tree_exited.connect(func() -> void:
			for b in [watch, skip_round, skip_all]:
				if is_instance_valid(b):
					b.free())
	return overlay


## The count for a stage: the Brownlow's rounds, or your club's games.
static func _count_view(count: String, stage: Array, aw: Dictionary, record: Dictionary) -> AwardsCountView:
	var view := AwardsCountView.new()
	view.kind = count
	view.title = str(stage[0])
	view.subtitle = str(stage[1])
	view.year = int(aw.get("year", GameState.season_year))
	for row in stage[2]:
		view.order.append(str(row.get("id", "")))
	if count == "votes":
		view.steps = AwardsCount.brownlow_steps(record)
		view.art = "league_bnf_medal"
		view.opening = ["The umpires' votes, read game by game from Round 1."]
		var coleman: Array = aw.get("coleman", [])
		if not coleman.is_empty():
			var c: Dictionary = coleman[0]
			view.opening.append("%s kicked %d goals for %s to win the Coleman Medal." % [
					GameState.award_name(c), int(c.get("goals", 0)), GameDB.club_name(str(c.get("club", "")))])
		# The Rising Star is presented half way through the count.
		var rising: Array = aw.get("rising_star", [])
		if not rising.is_empty():
			view.rising = rising[0]
			view.break_after = view.steps.size() / 2
			for n in GameState.rising_star_noms.get("rounds", []):
				if str(n.get("id", "")) == str(view.rising.get("id", "")):
					view.rising_round = int(n.get("round", 0))
	else:
		view.steps = AwardsCount.club_steps(record)
		view.art = "club_bnf"
		view.opening = ["Votes from every game, finals included, read one game at a time."]
	return view


## A row's figure: "56 votes", "71 goals", or a defender's counts.
static func _figure(row: Dictionary, metric: String) -> String:
	if metric == "fist":
		return Awards.golden_fist_line(row)
	return "%d %s" % [int(row.get(metric, 0)), "goals" if metric == "goals" else "votes"]


static func _words(text: String, colour: Color, font_size := 15, bold := false) -> Label:
	var label := UiKit.lbl(text, font_size, colour, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
