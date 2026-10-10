extends SceneTree
## Game feel (director, 2026-10-11): a short clip or a still of each effect on
## a real screen, for the director to judge at game speed. Needs a renderer:
##   godot --path . --write-movie /tmp/feel.avi --fixed-fps 30 \
##       --script tools/visual/capture_feel.gd -- --effect hub --out /tmp/feel
## capture.yml runs it with movie_maker=true and turns the AVI (picture and
## sound) into an MP4. Without --write-movie it just writes the stills.
##
##   --effect E   hub      arriving at the hub after a round: the club colour
##                         settling, the ladder spot counting and landing, an
##                         unanswered week question brightening (if one is up)
##                press    the same hub, then three real taps: Settings (a soft
##                         boot), a match-speed choice (a stud tick), Done
##                result   full time of the round just played: the result lands
##                draft    a League Draft pick: the pick lands with the sting
##                break    quarter time with a broken call (staged: the match
##                         ended your tag), the band settling and the call
##                         brightening twice
##                settings the Settings sheet, scrolled to the new rows (still)
##   --size WxH   default 390x844 (a phone in portrait); 1280x720 a PC
##   --secs S     how long to keep filming after the effect starts (default 3)
##   --out PATH   stills: <out>_end.png (and <out>_start.png)
## Seeded (2027): the same command films the same club and round.

const Tap := preload("res://tests/tap.gd")

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _run() -> void:
	await process_frame
	var args := _args()
	var effect := str(args.get("effect", "hub"))
	var out := str(args.get("out", "/tmp/feel"))
	var secs := float(args.get("secs", "3"))
	if args.has("size"):
		var wh := str(args["size"]).split("x")
		W = int(wh[0])
		H = int(wh[1])
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_feel.save"
	state.settings_path = "user://capture_feel_settings.cfg"
	state.set_button_sounds("normal")
	state.set_haptics_on(true)
	state.set_reduced_motion(false)
	state.set_vignettes_on(false)
	state.reset()
	state.replay_seed = 2027
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	print("FEEL effect %s at %dx%d, motion %s" % [effect, W, H, load("res://scripts/ui/UiKit.gd").motion_on()])

	match effect:
		"draft":
			state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted() + db.all_draftees_sorted(),
					db.active_clubs(2027).duplicate(), 12345)
			var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
			root.add_child(ui)
			ui.call("_on_club_chosen", "COL")
			await _wait(0.8)
			_shot(out + "_start.png")
			var pick: Button = null
			for n in ui.find_children("Pick_*", "Button", true, false):
				if not (n as Button).disabled and (n as Button).is_visible_in_tree():
					pick = n
					break
			print("FEEL tap pick: ", "missing" if pick == null else await Tap.tap(pick))
		"break":
			state.start_season("COL", db.club_list("COL"))
			state.prepare_interactive_match()
			var sim = state.pending_sim
			var mine := 0 if str(state.pending_match["home"]) == "COL" else 1
			# Staged: quarter time, and the match has just ended your tag on
			# their best midfielder (the real code path from there on).
			sim.current_quarter = 2
			var theirs: Array = sim.squads[1 - mine].ground
			sim.tag_drops.append({"side": mine, "id": str(theirs[0]["id"]), "q": 1})
			var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
			root.add_child(m)
		"settings":
			var host := Control.new()
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			root.add_child(host)
			var sheet: Control = load("res://scripts/ui/OptionsSheet.gd").open(host, true)
			await _wait(0.5)
			var row: Control = sheet.find_child("SettingsButtonSounds", true, false)
			var p := row.get_parent()
			while p != null and not (p is ScrollContainer):
				p = p.get_parent()
			if p != null:
				(p as ScrollContainer).ensure_control_visible(row)
				await _wait(0.3)
				(p as ScrollContainer).scroll_vertical += int(H * 0.25)
		_:
			state.start_season("COL", db.club_list("COL"))
			# As if you'd looked at the hub before the round: where you sat.
			var hub_script = load("res://scripts/ui/HubScene.gd")
			var before := int(state.my_position())
			for i in range(6):
				hub_script._ladder_seen = {"key": state.season.get_instance_id(), "pos": int(state.my_position())}
				before = int(state.my_position())
				state.advance()
				if int(state.my_position()) != before:
					break
			print("FEEL ladder %d -> %d" % [before, int(state.my_position())])
			if effect == "result":
				state.review_requested = true
				var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
				root.add_child(m)
			else:
				var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
				root.add_child(hub)
				if effect == "press":
					await _wait(1.0)
					for name in ["HubSettings", "SettingsMatchSpeed_2", "SettingsDone"]:
						var b: Button = root.find_child(name, true, false)
						print("FEEL tap %s: %s" % [name, "missing" if b == null else await Tap.tap(b)])
						await _wait(0.55)
	await process_frame
	await process_frame
	if effect != "settings" and effect != "draft":
		_shot(out + "_start.png")
	await _wait(secs)
	_shot(out + "_end.png")
	quit(0)
