class_name SeasonAwards
extends RefCounted
## Read-only ceremony over the review; stored results remain authoritative.

static func open(host: Control) -> Control:
	var box := UiKit.modal_box(host, 580.0)
	var overlay: Control = box["overlay"]
	overlay.name = "SeasonAwards"
	var body: VBoxContainer = box["body"]
	var footer: VBoxContainer = box["footer"]
	var aw: Dictionary = GameState.season_awards
	var stages := [
		["Brownlow Medal", "Home-and-away votes", aw.get("brownlow", []), "votes"],
		["Coleman Medal", "Home-and-away goals", aw.get("coleman", []), "goals"],
		["All-Australian", "The season's team", aw.get("all_australian", []), ""],
		["Best and fairest", GameDB.club_name(GameState.my_club),
			(aw.get("best_and_fairest", {}) as Dictionary).get(GameState.my_club, []), "bf"],
	]
	var state := {"stage": 0, "revealed": false, "vignette": null}
	var done := func() -> void:
		GameState.season_awards["presentation_seen"] = true
		GameState.mark_dirty()
		GameState.autosave()
		overlay.queue_free()
	var skip := UiKit.btn("Skip to season review", 14)
	skip.name = "AwardsSkip"
	skip.custom_minimum_size.y = 44
	skip.pressed.connect(done)
	footer.add_child(skip)
	var next := UiKit.btn("Reveal results", UiKit.NAME, true)
	next.name = "AwardsNext"
	next.custom_minimum_size.y = 48
	footer.add_child(next)
	var build := func() -> void:
		UiKit.clear(body)
		state["vignette"] = null
		var stage: Array = stages[int(state["stage"])]
		body.add_child(UiKit.lbl(str(stage[0]), 22, UiKit.TEXT, true))
		body.add_child(_words(str(stage[1]), UiKit.MUTED))
		var rows: Array = stage[2]
		var metric := str(stage[3])
		if not bool(state["revealed"]):
			body.add_child(_words("%d season awards" % int(aw.get("year", GameState.season_year)), UiKit.MUTED))
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
					"player" if mine == 1 else "players"], UiKit.TEXT))
			for row in rows:
				var line := "%s · %s · %s" % [GameState.award_name(row),
					GameDB.club_short(str(row.get("club", ""))), str({"RUCK": "Ruck", "MID": "Midfield", "DEF": "Defence", "FWD": "Forward", "BENCH": "Interchange"}.get(str(row.get("slot", "")), ""))]
				body.add_child(_words(line, UiKit.TEXT))
		else:
			# The stored order already includes the engine's tiebreak. Do not
			# invent shared medals by looking only at a tied displayed total.
			var winner: Dictionary = rows[0]
			var code := str(winner.get("club", GameState.my_club))
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
			body.add_child(_words(GameState.award_name(winner), UiKit.TEXT, 24))
			body.add_child(_words("%s · %d %s" % [GameDB.club_name(code), int(winner.get(metric, 0)),
					"goals" if metric == "goals" else "votes"], UiKit.MUTED))
			if metric != "goals" and rows.size() > 1:
				body.add_child(_words("Final placings", UiKit.MUTED))
				for i in range(1, mini(5, rows.size())):
					var row: Dictionary = rows[i]
					body.add_child(_words("%d. %s · %d votes" % [i + 1, GameState.award_name(row),
							int(row.get(metric, 0))], UiKit.TEXT))
		var last := int(state["stage"]) == stages.size() - 1
		next.text = "Season review" if last else "Next award"
		var animation = state["vignette"]
		if is_instance_valid(animation):
			var after := next.text
			next.text = "Finish reveal"
			animation.finished.connect(func(): next.text = after)
	next.pressed.connect(func() -> void:
		if not bool(state["revealed"]):
			state["revealed"] = true
		else:
			var scene = state["vignette"]
			if is_instance_valid(scene) and not scene._done:
				scene.finish_now()
				return
			state["stage"] = int(state["stage"]) + 1
			state["revealed"] = false
			if int(state["stage"]) >= stages.size():
				done.call()
				return
		build.call())
	build.call()
	return overlay

static func _words(text: String, colour: Color, font_size := 15) -> Label:
	var label := UiKit.lbl(text, font_size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label