extends SceneTree
## Game feel (director, 2026-10-11): a short clip or a still of each effect on
## a real screen, for the director to judge at game speed. Needs a renderer:
##   godot --path . --write-movie /tmp/feel.avi --fixed-fps 30 \
##       --script tools/visual/capture_feel.gd -- --effect hub --out /tmp/feel
## capture.yml runs it with movie_maker=true: the tool saves every frame at the
## window's own size and the workflow joins them with the AVI's sound into an MP4. Without --write-movie it just writes the stills.
##
##   --effect E   (several, comma-separated, film one after another in one clip)
##                hub      arriving at the hub after a round: the club colour
##                         settling, the ladder spot counting and landing, an
##                         unanswered week question brightening (if one is up)
##                press    the same hub, then three real taps: Settings (a soft
##                         boot), a match-speed choice (a stud tick), Done
##                attention  the hub with an unanswered week card brightening
##                living   the hub with no card: only the club colour settling
##                result   full time of the round just played: the result lands
##                draft    a League Draft pick: the pick lands with the sting
##                break    quarter time with a broken call (staged: the match
##                         ended your tag), the band settling and the call
##                         brightening twice
##                settings the Settings sheet, scrolled to the new rows (still)
##   --size WxH   default 390x844 (a phone in portrait); 1280x720 a PC
##   --secs S     how long to keep filming after the effect starts (default 3)
##   --out PATH   stills: <out>_end.png (and <out>_start.png)
##   --club CODE  your club (default COL; a colourful club shows the living colour better)
##   --no-music   music off, so the clip holds only the feel sounds (to measure them)
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


var _film := ""   # <out>: every drawn frame is saved as <out>_fNNNN.png while filming
var _frame := 0


## Filming (run under --write-movie, which fixes the clock at 30 fps): the
## viewport itself, frame by frame, at exactly the size the game drew it.
func _save_frame() -> void:
	if _film == "":
		return
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s_f%04d.png" % [_film, _frame])
	_frame += 1

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
	# --no-music: only the game-feel sounds in the clip (to measure them).
	state.set_music_level("off" if args.has("no-music") else "normal")
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	if Engine.get_write_movie_path() != "":
		_film = out
		process_frame.connect(_save_frame)

	# One run films every effect asked for, one after another (--effect a,b,c),
	# each from a fresh career, so one capture job makes one clip.
	var effects := effect.split(",")
	for e in effects:
		var keep := root.get_children()
		state.reset()
		state.replay_seed = 2027
		# No first-visit notes over the effect being filmed.
		state.set_setting("seen_weekly_loop_intro", true)
		var tag := out if effects.size() == 1 else "%s_%s" % [out, e]
		print("FEEL effect %s at %dx%d, motion %s" % [e, W, H, load("res://scripts/ui/UiKit.gd").motion_on()])
		await _one(str(e), tag, secs, state, db, str(args.get("club", "COL")))
		_film = ""   # the clip ends on the last real frame, not the teardown's blank ones
		for c in root.get_children():
			if not keep.has(c):
				c.queue_free()
		await process_frame
		await process_frame
	var feel = load("res://scripts/ui/Feel.gd")
	print("FEEL heard %s, moved %s" % [str(feel.heard), str(feel.moved)])
	quit(0)


func _one(effect: String, out: String, secs: float, state, db, club: String) -> void:
	match effect:
		"draft":
			state.draft = load("res://scripts/sim/Draft.gd").new(db.all_players_sorted() + db.all_draftees_sorted(),
					db.active_clubs(2027).duplicate(), 12345)
			var ui: Control = load("res://scenes/DraftScene.tscn").instantiate()
			root.add_child(ui)
			ui.call("_on_club_chosen", club)
			await _wait(0.8)
			_shot(out + "_start.png")
			var pick: Button = null
			for n in ui.find_children("Pick_*", "Button", true, false):
				if not (n as Button).disabled and (n as Button).is_visible_in_tree():
					pick = n
					break
			print("FEEL tap pick: ", "missing" if pick == null else await Tap.tap(pick))
		"break":
			state.start_season(club, db.club_list(club))
			state.prepare_interactive_match()
			var sim = state.pending_sim
			var mine := 0 if str(state.pending_match["home"]) == club else 1
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
			# A phone shows the Vibration row; a PC has nothing to buzz.
			load("res://scripts/ui/Feel.gd").force_phone = W < 600
			var sheet: Control = load("res://scripts/ui/OptionsSheet.gd").open(host, true)
			await _wait(0.5)
			for n in ["SettingsButtonSounds", "SettingsReducedMotion"]:
				var row: Control = sheet.find_child(n, true, false)
				var p := row.get_parent()
				while p != null and not (p is ScrollContainer):
					p = p.get_parent()
				if p != null:
					(p as ScrollContainer).ensure_control_visible(row)
					await _wait(0.3)
					(p as ScrollContainer).scroll_vertical += int(H * 0.25)
					await _wait(0.3)
				_shot("%s_%s.png" % [out, n])
		_:
			state.start_season(club, db.club_list(club))
			state.tutorials = false
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
			# Nothing over the hub while filming it: this week's press and sit-down wait.
			state.media_conference = {}
			state.backing_talk = {}
			if effect == "living":
				load("res://scripts/ui/ClubBackdrop.gd").trace = true
				state.week_events = []   # only the colour settling, no card
				# And no ladder count-up either: the stripe layer alone.
				hub_script._ladder_seen = {"key": state.season.get_instance_id(), "pos": int(state.my_position())}
			if effect == "result":
				state.review_requested = true
				var m: Control = load("res://scenes/MatchScene.tscn").instantiate()
				root.add_child(m)
			else:
				var hub: Control = load("res://scenes/HubScene.tscn").instantiate()
				root.add_child(hub)
				if effect == "press":
					await _wait(1.0)
					for name in ["HubSettings", "SettingsSpeed_2", "SettingsDone"]:
						var b: Button = root.find_child(name, true, false)
						print("FEEL tap %s: %s" % [name, "missing" if b == null else await Tap.tap(b)])
						await _wait(0.55)
						if name == "SettingsSpeed_2":
							_shot(out + "_peak.png")   # the sheet open, a choice just ticked
	await process_frame
	await process_frame
	if effect != "settings" and effect != "draft":
		_shot(out + "_start.png")
	if effect == "living":
		# The slide's value at every frame it drew (from the very first).
		var trl: Array = load("res://scripts/ui/ClubBackdrop.gd").trail.duplicate()
		print("FEEL slide per drawn frame: %s" % str(trl.slice(0, 24)))
		var bdn = root.find_child("ClubBackdrop", true, false)
		var draws := [0]
		bdn.draw.connect(func() -> void: draws[0] += 1)
		var d0: float = bdn._drift
		await _wait(1.0)
		print("FEEL drift: %.2f px in 1 s (at ~1.6 s), stripe updates %d, _draw redraws %d" % [
				bdn._drift - d0, load("res://scripts/ui/ClubBackdrop.gd").trail.size() - trl.size(), draws[0]])
	var peak_at := {"result": 0.0, "attention": 0.85, "living": secs * 0.5, "press": 0.0, "hub": 0.85}
	if effect == "result":
		# Prove the landing ran: follow the Verdict's scale from when full time
		# is on screen (the sheet is built before the effect timer starts).
		var v: Control = null
		var waited := 0
		while v == null and waited < 120:
			v = root.find_child("Verdict", true, false) as Control
			await process_frame
			waited += 1
		var best := 1.0
		var first := -1.0
		var t := 0.0
		var peak_done := false
		var prev := 1.0
		for i in range(60):
			await process_frame
			if not is_instance_valid(v):
				break
			var sc := v.scale.x
			if first < 0.0:
				first = sc
			if sc > best:
				best = sc
			if peak_done == false and best > 1.1 and sc < prev:
				_shot(out + "_peak.png")
				peak_done = true
			prev = sc
		print("FEEL verdict scale first %.2f peak %.2f final %.2f (frames waited %d)" % [first, best, v.scale.x if is_instance_valid(v) else -1.0, waited])
		if not peak_done:
			_shot(out + "_peak.png")
		await _wait(maxf(0.0, secs - 2.0))
	else:
		var pk: float = minf(float(peak_at.get(effect, 0.8)), secs)
		if effect != "press" and effect != "draft" and effect != "settings":
			await _wait(pk)
			_shot(out + "_peak.png")
			await _wait(secs - pk)
		else:
			await _wait(secs)
	_shot(out + "_end.png")
