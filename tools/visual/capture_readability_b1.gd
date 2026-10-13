extends SceneTree
## Visual review tool for the readability roll-out, batch 1 (director, 2026-10-13: the
## design bible's second pillar): the Season stats fixture, ratings, players, awards
## and trophy room, and the season review with its awards night. Needs a real renderer;
## capture.yml runs it:
##   gh workflow run capture.yml --ref <branch> -f tool=capture_readability_b1 \
##       -f args="--clubs COL,ESS,HAW --sizes 390x844,1280x720"
## For each club (as "your club") at each size it writes
##   <out>_<club>_<WxH>_<screen>.png
## where screen is: fixture, fixture_match, ratings, players, awards, awards_awarded,
## trophies, review_awards, review, review_lower. A fresh, seeded career per club and
## size; the season is played through for the end-of-season screens. Never touches a real save.
##   --out PREFIX   --clubs A,B,C   --sizes WxH,WxH   --rounds N (before the mid-season screens)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "readability_b1"
	var clubs := ["COL", "ESS", "HAW"]
	var sizes := ["390x844", "1280x720"]
	var rounds := 10
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--clubs":
				clubs = str(a[i + 1]).split(",")
			"--sizes":
				sizes = str(a[i + 1]).split(",")
			"--rounds":
				rounds = int(str(a[i + 1]))
	await process_frame
	for club in clubs:
		for sz in sizes:
			var wh := str(sz).split("x")
			await _one(out, str(club), int(wh[0]), int(wh[1]), rounds)
	quit()


func _one(out: String, club: String, w: int, h: int, rounds: int) -> void:
	var prefix := "%s_%s_%dx%d_" % [out, club, w, h]
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var UK = load("res://scripts/ui/UiKit.gd")
	state.autosave_enabled = false
	state.save_path = "user://capture_b1.save"
	state.settings_path = "user://capture_b1.cfg"
	state.reset()
	state.career_seed = 2031
	state.replay_seed = 2031
	state.set_setting("seen_training_intro", true)
	state.set_setting("seen_season_stats_intro", true)
	state.start_season(club, db.club_list(club))
	for i in range(rounds):
		state.advance()
	UK.apply_appearance("dark")
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	await _frames(3)
	var hub = load("res://scripts/ui/StatsHubScene.gd")

	# Fixture: the round just played, a played match opened.
	var scene: Control = await _hub(hub, "fixture")
	await _tap(scene, "PrevRound")
	_save(prefix + "fixture.png")
	await _tap(scene, "Match_0")
	_save(prefix + "fixture_match.png")
	scene.queue_free()
	await _frames(2)
	for sec in ["ratings", "players", "awards"]:
		scene = await _hub(hub, sec)
		_save(prefix + sec + ".png")
		scene.queue_free()
		await _frames(2)

	# The season played out: awards presented, the honour roll holding a flag.
	var guard := 0
	while not state.season_is_over() and guard < 60:
		state.advance()
		guard += 1
	if not state.honour_roll.is_empty():
		var entry: Dictionary = state.honour_roll.back()
		entry["premier"] = club
		entry["my_position"] = 1
		entry["my_record"] = "18-5-0"
	scene = await _hub(hub, "awards")
	_save(prefix + "awards_awarded.png")
	scene.queue_free()
	await _frames(2)
	scene = await _hub(hub, "trophies")
	_save(prefix + "trophies.png")
	scene.queue_free()
	await _frames(2)

	# The season review, with its awards night over it first.
	if state.season_awards.has("presentation_seen"):
		state.season_awards["presentation_seen"] = false
	var review: Control = load("res://scenes/SeasonReviewScene.tscn").instantiate()
	root.add_child(review)
	await _frames(12)
	await _tap(review, "AwardsNext")
	await _frames(40)
	_save(prefix + "review_awards.png")
	var skip: Button = review.find_child("AwardsSkip", true, false)
	if skip != null:
		skip.emit_signal("pressed")
	await _frames(12)
	_save(prefix + "review.png")
	var sc: ScrollContainer = null
	for n in review.find_children("*", "ScrollContainer", true, false):
		sc = n
		break
	var awards: Control = review.find_child("AwardsPanel", true, false)
	if sc != null and awards != null:
		sc.scroll_vertical = int(awards.global_position.y - sc.global_position.y) + sc.scroll_vertical
		await _frames(6)
		_save(prefix + "review_lower.png")
	review.queue_free()
	await _frames(3)


func _hub(hub, section: String) -> Control:
	hub.current = section
	var scene: Control = load("res://scenes/StatsHubScene.tscn").instantiate()
	root.add_child(scene)
	await _frames(10)
	return scene


func _tap(scene: Node, node_name: String) -> void:
	var b: Button = scene.find_child(node_name, true, false)
	if b == null:
		push_error("no " + node_name)
		return
	b.emit_signal("pressed")
	await _frames(10)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(path) != OK:
		push_error("could not save " + path)
	print("wrote ", path)
