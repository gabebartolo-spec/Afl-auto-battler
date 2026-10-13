extends SceneTree
## One story card on the hub (data/stories), on a phone, for the director's
## look: the card as it asks, then after its first answer. Seeded; never
## touches a real save.
##   godot --path . --script tools/visual/capture_story_card.gd -- --out PREFIX \
##       [--cards training_kid_pushing,health_pulled_up_sore] [--club COL] [--seed 2031] [--size 390x844] [--choice 0]
## Writes <prefix>_<card>_card.png and <prefix>_<card>_answered<choice>.png for each card.

var W := 390
var H := 844
var CHOICE := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	var out := "story"
	var ids := "training_kid_pushing"
	var club := "COL"
	var seed := 2031
	var cli := OS.get_cmdline_user_args()
	for i in range(cli.size() - 1):
		match str(cli[i]):
			"--out": out = str(cli[i + 1])
			"--cards": ids = str(cli[i + 1])
			"--club": club = str(cli[i + 1])
			"--seed": seed = int(cli[i + 1])
			"--choice": CHOICE = int(cli[i + 1])
			"--size":
				var wh := str(cli[i + 1]).split("x")
				W = int(wh[0])
				H = int(wh[1])
	await process_frame
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	gs.autosave_enabled = false
	gs.save_path = "user://capture_story.save"
	gs.settings_path = "user://capture_story.cfg"
	gs.show_real_names = false
	seed(seed)
	gs.reset()
	gs.career_seed = seed
	gs.replay_seed = seed
	gs.set_setting("seen_training_intro", true)
	gs.set_setting("seen_season_stats_intro", true)
	gs.set_setting("seen_weekly_loop_intro", true)
	gs.start_season(club, db.club_list(club))
	for i in range(3):
		gs.advance()
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	for tid in ids.split(","):
		gs.media_conference = {}
		# A player card is about a player who fits it: the youngest for a kid's
		# card, else a senior player; a club card is about nobody.
		var Deck = load("res://scripts/sim/StoryDeck.gd")
		var t: Dictionary = Deck.by_id(Deck.all(), str(tid))
		var who := {}
		if str((t.get("subject", {}) as Dictionary).get("kind", "club")) != "club":
			who = gs.my_list[0]
			for q in gs.my_list:
				if str(tid).contains("kid") and float(q.get("age", 30.0)) < float(who.get("age", 30.0)):
					who = q
			# A role card is about a player who has a second position.
			if str(tid) == "media_papers_again":
				for q in gs.my_list:
					if load("res://scripts/state/ClubStories.gd").trial_role(q) != "":
						who = q
						break
		var e: Dictionary = gs.story_card(str(tid), who)
		if e.is_empty():
			push_error("capture_story_card: no card %s for this career" % tid)
			continue
		gs.week_events = [e]
		var scene: Control = load("res://scenes/HubScene.tscn").instantiate()
		root.add_child(scene)
		await _frames(8)
		await _show_card(scene)
		root.get_viewport().get_texture().get_image().save_png("%s_%s_card.png" % [out, tid])
		var b = scene.find_child("Event_%d" % CHOICE, true, false)
		if b != null:
			b.emit_signal("pressed")
		await _frames(8)
		await _show_card(scene)
		root.get_viewport().get_texture().get_image().save_png("%s_%s_answered%d.png" % [out, tid, CHOICE])
		scene.queue_free()
		await _frames(2)
	quit()


func _show_card(scene: Control) -> void:
	var card = scene.find_child("WeekEvent", true, false)
	if card == null:
		return
	var n: Node = card.get_parent()
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(card)
	await _frames(6)
