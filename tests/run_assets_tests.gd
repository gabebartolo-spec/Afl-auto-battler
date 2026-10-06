extends SceneTree
## godot --headless --path . --script tests/run_assets_tests.gd
## The art and music the game ships, checked as files and as the game uses
## them. These checks can say an asset is whole and wired up; only a person
## can say it looks or sounds right.
##   - Figure sheets: every frame of every move in VignetteFigures.gd has a
##     figure on the sheet, and the colour masks belong to the same render as
##     the shading (a sheet rebuilt without the others shows up here).
##   - Vignettes in motion: each scene plays its moves through - no frame
##     asked for past the end of a move (it would freeze without a word).
##   - Music: every track loads and is in the playlist, nothing clips, the
##     tracks sit at one level, and the player pauses for a match, resumes,
##     moves on and honours Mute.

const SHEETS := "res://assets/vignette/figures_%s.png"
const MUSIC_DIR := "res://assets/audio/music"
## A frame with less figure than this share of its cell is empty.
const MIN_COVER := 0.01
## Same render (the art agent's rule, 2026-10-06): every guernsey-mask pixel
## (mask A >= 0.05) lies on the figure (shade A > 0.05) or within 1 px of it.
## Blender's straight alpha leaves full-strength mask on edge pixels whose
## coverage rounds to nothing - padding the shader never draws - but nothing
## further out. Backstop: at most this share of a frame's mask off the figure
## (thin side-on frames run to 7% of edge padding; a mask 16 px out is 15%+).
const MASK_ON := 0.05
const BODY_ON := 0.05
const MASK_SPILL := 0.10
const PEAK_LIMIT_DB := -1.0
const LEVEL_SPREAD_DB := 3.0
const MAX_LEAD_SILENCE := 0.5

## Loaded at run time: the vignettes need the autoloads, which a script
## compiled before they exist can't name.
var SV: GDScript
var _state: Node
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_state = root.get_node("GameState")
	_state.autosave_enabled = false
	_state.save_path = "user://test_career.save"
	_state.settings_path = "user://test_settings.cfg"
	_state.show_real_names = false
	_state.replay_seed = 2027
	SV = load("res://scripts/ui/match/StoppageVignette.gd")
	_figure_sheets()
	await _vignettes_play_through()
	_music_files()
	_music_player()
	_banners()
	print("Assets tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)


# ---------------------------------------------------------------------------
# Figure sheets
# ---------------------------------------------------------------------------
func _figure_sheets() -> void:
	var shade := _source_image("shade")
	var mask := _source_image("mask")
	var design := _source_image("design")
	_check(shade != null and mask != null and design != null and _source_image("digits") != null,
			"The four figure sheets are in the project")
	if shade == null or mask == null or design == null:
		return
	_check(shade.get_size() == VignetteFigures.SHEET_SIZE and mask.get_size() == VignetteFigures.SHEET_SIZE
			and design.get_size() == VignetteFigures.SHEET_SIZE / 2,
			"The sheets are the size the layout says (%s, %s, %s)" % [shade.get_size(), mask.get_size(), design.get_size()])
	var cells := {}
	var empty := []
	var clash := []
	var outside := []
	var spill := []
	var strips := 0
	for body in VignetteFigures.BODIES:
		var anims: Dictionary = VignetteFigures.BODIES[body]["anims"]
		for anim in anims:
			for facing in anims[anim]:
				strips += 1
				var s := VignetteFigures.strip(body, anim, facing)
				for i in int(s["frames"]):
					var r := Rect2i(VignetteFigures.source(s, i))
					var where := "%s %s %s #%d" % [body, anim, facing, i]
					if not Rect2i(Vector2i.ZERO, VignetteFigures.SHEET_SIZE).encloses(r):
						outside.append(where)
						continue
					var key := r.position
					if cells.has(key) and cells[key] != "%s %s" % [anim, facing]:
						clash.append("%s / %s" % [where, cells[key]])
					cells[key] = "%s %s" % [anim, facing]
					var c := _coverage(shade, mask, r)
					if c[0] < MIN_COVER:
						empty.append(where)
					elif int(c[2]) > 0 or float(c[1]) > MASK_SPILL:
						spill.append("%s: %d px beyond the edge, %.1f%% off" % [where, int(c[2]), float(c[1]) * 100.0])
	_check(strips > 0, "The layout lists the moves (%d strips)" % strips)
	_check(outside.is_empty(), "Every frame sits inside the sheet: %s" % str(outside.slice(0, 5)))
	_check(clash.is_empty(), "No two moves share a frame: %s" % str(clash.slice(0, 5)))
	_check(empty.is_empty(), "Every frame of every move has a figure in it (%d empty: %s)"
			% [empty.size(), str(empty.slice(0, 5))])
	_check(spill.is_empty(), "The colour mask lies on the figure, to the pixel, in every frame (same render): %s"
			% str(spill.slice(0, 5)))
	# The club-design sheet is half size: its guernsey must sit on the figure too.
	var off := 0
	var on := 0
	for key in cells:
		var r := Rect2i(key, Vector2i(VignetteFigures.FRAME))
		for y in range(r.position.y, r.end.y, 4):
			for x in range(r.position.x, r.end.x, 4):
				if design.get_pixel(x / 2, y / 2).a > 0.5:
					on += 1
					if shade.get_pixel(x, y).a < 0.05:
						off += 1
	_check(on > 0 and float(off) / on < 0.02,
			"The club-design sheet matches the figures (%d of %d samples off the body)" % [off, on])
	# The tool itself: a blank frame and a mask from another frame must fail.
	var blank := Image.create(VignetteFigures.SHEET_SIZE.x, VignetteFigures.SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	var any_cell: Rect2i = Rect2i(cells.keys()[0], Vector2i(VignetteFigures.FRAME))
	_check(_coverage(blank, mask, any_cell)[0] < MIN_COVER, "A blank frame counts as empty")
	var step := 16 if any_cell.end.x + 16 <= VignetteFigures.SHEET_SIZE.x else -16
	var shifted := Rect2i(any_cell.position + Vector2i(step, 0), any_cell.size)
	var moved := Image.create(VignetteFigures.SHEET_SIZE.x, VignetteFigures.SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	moved.blit_rect(mask, shifted, any_cell.position)
	_check(int(_coverage(shade, moved, any_cell)[2]) > 0, "A mask 16 px out of register counts as a mismatch")


## [share of the cell with figure, share of the mask off the figure, mask
## samples more than 1 px from the figure] (every second pixel each way; the
## 1 px test looks at the 3x3 around each sample).
func _coverage(shade: Image, mask: Image, r: Rect2i) -> Array:
	var cover := 0
	var masked := 0
	var off := 0
	var far := 0
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			n += 1
			var body := shade.get_pixel(x, y).a > BODY_ON
			if body:
				cover += 1
			# A is the guernsey alone (R/G/B are padded past the edges).
			if mask.get_pixel(x, y).a >= MASK_ON:
				masked += 1
				if not body:
					off += 1
					if not _body_near(shade, x, y, r):
						far += 1
	return [float(cover) / maxi(1, n), float(off) / maxi(1, masked), far]


func _body_near(shade: Image, x: int, y: int, r: Rect2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := Vector2i(x + dx, y + dy)
			if r.has_point(p) and shade.get_pixelv(p).a > BODY_ON:
				return true
	return false


func _source_image(which: String) -> Image:
	var path := ProjectSettings.globalize_path(SHEETS % which)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


# ---------------------------------------------------------------------------
# Vignettes in motion
# ---------------------------------------------------------------------------
func _vignettes_play_through() -> void:
	root.size = Vector2i(390, 844)
	SV.log_frames = true
	# The tool itself: a frame past the end of a move is caught.
	SV.frame_log.clear()
	var probe := VignetteFigures.strip("average", "idle", "front")
	var held: int = SV.figure_frame(probe, int(probe["frames"]) + 3, "idle", "front")
	_check(held == int(probe["frames"]) - 1 and _overruns().size() == 1,
			"A frame past the end of a move is held on the last and noticed")
	var db = root.get_node("GameDB")
	var star: Dictionary = db.club_list("COL")[0]
	for kind in ["speccy_front", "speccy_side", "speccy_defensive", "after_siren", "goal_line", "boundary_snap"]:
		var ev := {"kind": "mark" if kind.begins_with("speccy") else "goal", "side": 0,
				"num": int(star.get("num", 7)), "player_id": str(star["id"]), "club": "COL", "q": 4,
				"set_shot": kind == "after_siren", "crumb": kind == "goal_line"}
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = Vector2(390, 844)
		vig.setup(kind, ev, {}, {"home": "COL", "away": "CAR"})
		await _play(vig, "broadcast " + kind, 6.0)
	var press = load("res://scripts/ui/MediaConferenceVignette.gd").new()
	press.club = "COL"
	root.add_child(press)
	press.size = Vector2(390, 300)
	await _play(press, "press conference", 3.0)
	_state.reset()
	_state.start_season("COL", db.club_list("COL"))
	if _state.prepare_interactive_match():
		var bounce = load("res://scripts/ui/match/StoppageVignette.gd").new()
		root.add_child(bounce)
		bounce.size = Vector2(390, 844)
		bounce.setup(_state.pending_sim, 0, "Centre bounce")
		await _play(bounce, "centre bounce", 6.0)
	else:
		_check(false, "A match is ready for the centre-bounce scene")
	SV.log_frames = false


## Run a vignette for `seconds` of its own time, drawing every step, and check
## its figures: they were drawn, no move ran past its end, and every move with
## several frames showed more than one.
func _play(vig: Control, what: String, seconds: float) -> void:
	SV.frame_log.clear()
	vig.set_process(false)
	var t := 0.0
	while t <= seconds:
		vig.set("_t", t)
		vig.queue_redraw()
		await process_frame
		t += 1.0 / 30.0
	vig.queue_free()
	await process_frame
	var log: Array = SV.frame_log
	_check(not log.is_empty(), "The %s draws its footballers" % what)
	var over := _overruns()
	_check(over.is_empty(), "The %s never asks for a frame past the end of a move: %s" % [what, str(over.slice(0, 4))])
	var seen := {}
	for e in log:
		var k := "%s %s" % [e["anim"], e["facing"]]
		if int(e["frames"]) > 1:
			if not seen.has(k):
				seen[k] = {}
			seen[k][int(e["wanted"])] = true
	var frozen := []
	for k in seen:
		if (seen[k] as Dictionary).size() < 2:
			frozen.append(k)
	_check(frozen.is_empty(), "Every move in the %s plays, none stuck on one frame: %s" % [what, str(frozen)])


func _overruns() -> Array:
	var out := []
	for e in SV.frame_log:
		if int(e["wanted"]) < 0 or int(e["wanted"]) >= int(e["frames"]):
			out.append("%s %s %d/%d" % [e["anim"], e["facing"], int(e["wanted"]), int(e["frames"])])
	return out


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------
func _music_files() -> void:
	var mm = root.get_node("MusicManager")
	var listed: Array = mm.TRACK_PATHS
	var files := []
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.get_extension() in ["wav", "ogg", "mp3"]:
			files.append("%s/%s" % [MUSIC_DIR, f])
	var unlisted := files.filter(func(f): return not listed.has(f))
	var missing := listed.filter(func(p): return not ResourceLoader.exists(p))
	_check(missing.is_empty(), "Every track in the playlist is in the game: %s" % str(missing))
	_check(unlisted.is_empty(), "Every music file is in the playlist: %s" % str(unlisted))
	_check((mm.get("_tracks") as Array).size() == listed.size(),
			"Every track loads - none dropped without a word (%d of %d)" % [(mm.get("_tracks") as Array).size(), listed.size()])
	var levels := []
	for p in listed:
		var w := _wav_levels(p)
		if w.is_empty():
			_check(false, "%s reads as a 16-bit WAV" % p.get_file())
			continue
		levels.append(float(w["rms"]))
		_check(float(w["peak"]) <= PEAK_LIMIT_DB, "%s doesn't clip (peak %.1f dBFS)" % [p.get_file(), w["peak"]])
		_check(float(w["lead"]) <= MAX_LEAD_SILENCE, "%s starts without a gap (%.2f s)" % [p.get_file(), w["lead"]])
		_check(float(w["seconds"]) >= 20.0, "%s is a track, not a sting (%.0f s)" % [p.get_file(), w["seconds"]])
	if levels.size() > 1:
		_check(levels.max() - levels.min() <= LEVEL_SPREAD_DB,
				"The tracks sit at one level (%.1f dB apart)" % (levels.max() - levels.min()))
	# The tool itself: a clipped, late-starting tone fails.
	var bad := PackedByteArray()
	bad.resize(2 * 11025)
	for i in range(11025):
		var v := 0 if i < 8000 else (32767 if i % 2 == 0 else -32768)
		bad.encode_s16(i * 2, v)
	var bw := _levels_of(bad, 11025, 1)
	_check(float(bw["peak"]) > PEAK_LIMIT_DB and float(bw["lead"]) > MAX_LEAD_SILENCE,
			"A clipped track with a gap at the start is caught")


## Peak and RMS (dBFS), leading silence and length of a 16-bit PCM WAV, read
## from the source file (what the importer was given).
func _wav_levels(res_path: String) -> Dictionary:
	var f := FileAccess.open(ProjectSettings.globalize_path(res_path), FileAccess.READ)
	if f == null:
		return {}
	var b := f.get_buffer(f.get_length())
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return {}
	var at := 12
	var rate := 0
	var channels := 0
	var bits := 0
	while at + 8 <= b.size():
		var id := b.slice(at, at + 4).get_string_from_ascii()
		var n := b.decode_u32(at + 4)
		if id == "fmt ":
			channels = b.decode_u16(at + 10)
			rate = b.decode_u32(at + 12)
			bits = b.decode_u16(at + 22)
		elif id == "data":
			if bits != 16 or rate == 0:
				return {}
			return _levels_of(b.slice(at + 8, at + 8 + n), rate, channels)
		at += 8 + n + (n % 2)
	return {}


func _levels_of(pcm: PackedByteArray, rate: int, channels: int) -> Dictionary:
	var count := pcm.size() / 2
	var peak := 1
	var sum := 0.0
	var lead := -1
	var quiet := int(32768.0 * pow(10.0, -50.0 / 20.0))
	for i in range(count):
		var v := absi(pcm.decode_s16(i * 2))
		peak = maxi(peak, v)
		sum += float(v) * v
		if lead < 0 and v > quiet:
			lead = i
	var rms := sqrt(sum / maxi(1, count))
	return {"peak": 20.0 * log(peak / 32768.0) / log(10.0),
			"rms": 20.0 * log(maxf(rms, 1.0) / 32768.0) / log(10.0),
			"lead": float(maxi(lead, 0)) / (rate * channels),
			"seconds": float(count) / (rate * channels)}


func _music_player() -> void:
	var mm = root.get_node("MusicManager")
	var player: AudioStreamPlayer = mm.find_child("BackgroundMusic", true, false)
	_check(player != null and player.volume_db < -6.0, "Menu music plays quietly")
	if player == null:
		return
	mm.set_context("hub")
	var first := player.stream
	mm.set_context("match")
	_check(player.stream_paused or not player.playing, "The music stops for a match")
	mm.set_context("hub")
	_check(player.stream == first and not player.stream_paused, "After the match the same track carries on")
	player.emit_signal("finished")
	_check(player.stream != first or (mm.get("_tracks") as Array).size() == 1, "When a track ends the next one starts")
	_state.set_sounds_muted(true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Mute silences the music")
	_state.set_sounds_muted(false)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Sound back on brings it back")


# ---------------------------------------------------------------------------
# Run-through banners (data/banners.json, Banners.pick)
# ---------------------------------------------------------------------------
## The longest fill-ins: a nickname, a 12-letter surname, a 300-game
## milestone and a year.
const BANNER_LONGEST := {"{us}": "Kangaroos", "{them}": "Kangaroos", "{player}": "Wwwwwwwwwwww",
		"{games}": "300", "{year}": "2031"}


func _banners() -> void:
	var B: GDScript = load("res://scripts/core/Banners.gd")
	var d: Dictionary = B.data()
	_check(not d.is_empty(), "The banner rhymes load")
	if d.is_empty():
		return
	# Every text in the file, wherever it sits.
	var all := []
	for k in d:
		var v = d[k]
		if v is Array:
			for x in v:
				if x is String:
					all.append(x)
				elif x is Dictionary:
					all.append_array(x.get("texts", []))
		elif v is Dictionary:
			for kk in v:
				all.append_array(v[kk])
	var bad_lines := []
	var too_long := []
	var unknown := []
	var re := RegEx.new()
	re.compile("\\{[a-z_]+\\}")
	for t in all:
		var lines := str(t).split("\n")
		if lines.size() < 2 or lines.size() > 4:
			bad_lines.append(t)
		for m in re.search_all(str(t)):
			if not BANNER_LONGEST.has(m.get_string()):
				unknown.append(m.get_string())
		var filled := str(t)
		for ph in BANNER_LONGEST:
			filled = filled.replace(ph, BANNER_LONGEST[ph])
		for line in filled.split("\n"):
			if line.length() > 28:
				too_long.append(line)
	_check(all.size() >= 140, "The banner file holds its rhymes (%d)" % all.size())
	_check(bad_lines.is_empty(), "Every banner is 2 to 4 lines (%s)" % str(bad_lines.slice(0, 3)))
	_check(too_long.is_empty(), "Every line fits 28 characters with the longest names filled in (%s)" % str(too_long.slice(0, 3)))
	_check(unknown.is_empty(), "Banners use only the known fill-ins (%s)" % str(unknown))
	var missing := []
	for code in root.get_node("GameDB").clubs:
		if not (d.get("club", {}) as Dictionary).has(code) or (d["club"][code] as Array).is_empty():
			missing.append(code)
	for r in d.get("rivalry", []):
		if (r.get("pair", []) as Array).size() != 2 or (r.get("texts", []) as Array).is_empty():
			missing.append(str(r.get("pair", [])))
	for week in ["wildcard", "elimination", "qualifying", "semi", "preliminary", "grand"]:
		if (d.get("final", {}) as Dictionary).get(week, []).is_empty():
			missing.append(week)
	for key in ["debut", "50", "100", "150", "200", "250", "300", "350", "farewell"]:
		if (d.get("milestone", {}) as Dictionary).get(key, []).is_empty():
			missing.append(key)
	for t in MarqueeGames.TRADITIONS:
		if B._marquee(d, str(t["name"])).is_empty():
			missing.append(str(t["name"]))
	_check(missing.is_empty(), "Every club, rivalry, final week, milestone and marquee game has its banners (%s)" % str(missing))
	# The days of remembrance honour the day: no taunt at the opponent.
	var taunts := []
	for name in B.RESPECTFUL:
		for t in B._marquee(d, name):
			if str(t).contains("{them}"):
				taunts.append(t)
	_check(taunts.is_empty(), "ANZAC and Dreamtime banners name no opponent to taunt (%s)" % str(taunts))
	# Which set, in order: each occasion beats everything below it.
	var full := {"home": "TAS", "away": "NTH", "round": "Round 1", "final": "grand", "must_win": true,
			"spoon": true, "first_game": "TAS", "premiers": "NTH", "milestone": {"player": "Smith", "games": 100},
			"year": 2028, "seed": 7}
	var order := []
	var ctx := full.duplicate(true)
	for drop in ["first_game", "milestone", "final", "must_win", "premiers", "spoon"]:
		order.append(str(B.texts_for(ctx)[0]))
		ctx.erase(drop)
	order.append(str(B.texts_for(ctx)[0]))
	_check(order == ["first_game", "milestone", "final", "must_win", "premiers_opposition", "spoon", "club"],
			"Banners follow the occasion's priority (%s)" % str(order))
	var riv := {"home": "CAR", "away": "COL", "round": "Round 3", "seed": 3}
	_check(str(B.texts_for(riv)[0]) == "rivalry" and str(B.texts_for({"home": "COL", "away": "CAR", "seed": 3})[0]) == "rivalry",
			"A rivalry is a rivalry in either order")
	_check(str(B.texts_for({"home": "HAW", "away": "GEE", "us": "GEE"})[0]) == "marquee",
			"A marquee game gets its own banner")
	var anzac := {"home": "ESS", "away": "COL", "round": "Round 7", "must_win": true, "premiers": "COL",
			"milestone": {"player": "Smith", "games": 200}, "seed": 1}
	var anzac_texts: Array = B._marquee(d, "ANZAC Day")
	_check(anzac_texts.has(str(B.texts_for(anzac)[1][0])) and str(B.texts_for(anzac)[0]) == "marquee",
			"ANZAC Day only ever gets its own banner")
	var a: String = B.pick(riv)
	_check(a != "" and a == B.pick(riv), "The same match always gets the same banner")
	var ms: String = B.pick({"home": "COL", "away": "ESS", "milestone": {"player": "Smith", "games": 100}, "seed": 2})
	_check(not ms.contains("{") and ms.split("\n").size() >= 2, "A picked banner is filled in, in lines (%s)" % ms)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)
