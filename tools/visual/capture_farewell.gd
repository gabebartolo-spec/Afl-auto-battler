extends SceneTree
## Visual review tool for the milestone farewell (FarewellVignette, FL-007): the guard
## of honour and chaired off, on a phone. Needs a real renderer (capture.yml runs it).
##   godot --path . --script tools/visual/capture_farewell.gd -- --out /tmp/farewell
## Writes <out>_sheet.png (six beats). --movie: also <out>_fNNNN.png, the whole scene at
## 30 frames a second, which capture.yml turns into an MP4.
## --games N: his Nth game (200 by default); --farewell: his last game instead.
## --home CODE / --opp CODE: the clubs (Collingwood v Geelong by default).
## --scale N: render the same 390x844-point phone at N times the pixels (3 = a real phone's
## 1170x2532), so a review sees what the device shows, not a third of it.
## --skins: the men in the guard wear every skin tone in turn (look.skin 0, 1, 2...), to check
## the clap's hands on each.
## --layers: a layer pass - kit recolouring off, each man in the guard one distinct flat tint,
## to show whose arms are whose.
## --lens X / --horizon F: force a framing (FarewellVignette.lens / horizon_at); by default the
## screen's shape picks it (FarewellVignette.framing: phone 1.25 / 0.43, wide window 1.68 / 0.508).
## --window WxH: a desktop window of that many pixels (e.g. 1920x1080) at the Standard screen
## size, instead of the phone (--scale is ignored).
## On --scale N the screen-size setting (ScreenLayout.ui_scale) is set to N too, so the text is
## laid out for a 390-point phone at N pixels a point, as a phone's density does (without it a CI
## window counts as a 1x desktop and every caption came out a third of its size).
## --lossless: draw from the sheets' PNGs as they are, not the imported VRAM-compressed
## copies. A desktop GPU loads BPTC, which smears the mask's channels at sharp edges (sock
## tops, small hands) so the shader paints boot colour there; an Android phone loads ASTC,
## which is close to lossless. Use it to see what the phone shows.
## Prints ART lines: the figure sheet's size and, for every move the scene drew, its
## strip and the frames asked for - proof the new moves came from the sheet.

var W := 390
var H := 844
const BEATS := [0.4, 1.4, 2.6, 3.6, 4.6, 5.8]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/farewell"
	var a := OS.get_cmdline_user_args()
	var movie := a.has("--movie")
	var me := "COL"
	var opp := "GEE"
	var games := 200
	var scale := 1
	var lens := 0.0
	var horizon := 0.0
	var desk := false
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--home":
			me = str(a[i + 1])
		if str(a[i]) == "--opp":
			opp = str(a[i + 1])
		if str(a[i]) == "--games":
			games = int(a[i + 1])
		if str(a[i]) == "--horizon":
			horizon = float(a[i + 1])
		if str(a[i]) == "--lens":
			lens = float(a[i + 1])
		if str(a[i]) == "--window":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
			desk = true
		if str(a[i]) == "--scale":
			scale = maxi(1, int(a[i + 1]))
	if a.has("--lossless"):
		# The vignette scripts preload the sheets as soon as they're parsed, so swap the data
		# under the loaded textures' RIDs instead; the format printed is the proof.
		var paths := ["figures_shade", "figures_mask", "figures_design"]
		for f in DirAccess.get_files_at("res://assets/vignette"):
			if f.begins_with("hair_") and f.ends_with(".png"):
				paths.append(f.get_basename())
		for p in paths:
			var path := "res://assets/vignette/%s.png" % p
			var tex: Texture2D = load(path)
			var was: int = tex.get_image().get_format()
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			img.convert(Image.FORMAT_RGBA8)
			RenderingServer.texture_replace(tex.get_rid(), RenderingServer.texture_2d_create(img))
			print("ART lossless %s: format %d -> %d" % [p, was, tex.get_image().get_format()])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture.save"
	state.settings_path = "user://capture_settings.cfg"
	state.reset()
	state.start_season(me, db.club_list(me))
	if desk:
		scale = 1
	root.get_node("ScreenLayout").ui_scale = float(scale)
	root.size = Vector2i(W * scale, H * scale)
	DisplayServer.window_set_size(Vector2i(W * scale, H * scale))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(W, H)
	var mine: Array = state.my_squad().ground + state.my_squad().bench
	var osq = load("res://scripts/sim/Squad.gd").new(opp, state.season.lists[opp], false, opp)
	var theirs: Array = osq.ground + osq.bench
	var man: Dictionary = mine[0]
	var name: String = db.player_display_name(man)
	var ms := {"player": name.split(" ")[-1], "name": name, "id": str(man.get("id", "")),
			"games": "farewell" if a.has("--farewell") else games}
	var Farewell = load("res://scripts/ui/match/FarewellVignette.gd")
	if lens > 0.0:
		Farewell.lens = lens
	if horizon > 0.0:
		Farewell.horizon_at = horizon
	print("ART framing ", Farewell.framing(Vector2(W, H)), " (lens, horizon)")
	print("ART sheet ", load("res://scripts/ui/match/VignetteFigures.gd").SHEET_SIZE, " caption: ", Farewell.caption(ms))
	var Stoppage = load("res://scripts/ui/match/StoppageVignette.gd")
	Stoppage.log_frames = true
	Stoppage.frame_log.clear()
	var vig = Farewell.open(root, ms, man, me, opp, mine, theirs, "Full time")
	vig.set_process(false)
	if a.has("--skins"):
		var tones: int = load("res://scripts/core/Appearance.gd").SKIN.size()
		for t in vig.tokens:
			var look: Dictionary = (t["look"] as Dictionary).duplicate()
			look["skin"] = int(t["k"]) % tones
			t["look"] = look
		print("ART skins: each line's men wear tones 0..%d in order from the camera" % (tones - 1))
	if a.has("--layers"):
		# One flat colour per man over the sheet's coverage, the hue hashed from his draw
		# colour (kit, skin, hair): give each man his own skin and hair so each differs.
		var flat := ShaderMaterial.new()
		flat.shader = Shader.new()
		flat.shader.code = """shader_type canvas_item;
varying vec4 looks;
void vertex() {
	looks = COLOR;
}
void fragment() {
	float a = texture(TEXTURE, UV).a;
	float h = fract(looks.g * 5.31 + looks.b * 2.17 + looks.r * 0.73);
	vec3 c = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.15), c, 0.85), a * looks.a);
}"""
		vig.material = flat
		for t in vig.tokens:
			var look: Dictionary = (t["look"] as Dictionary).duplicate()
			look["skin"] = (int(t["k"]) * 3 + (0 if int(t["line"]) < 0 else 5)) % 8
			look["hair"] = (int(t["k"]) * 5 + 2) % 8
			t["look"] = look
		print("ART layers: kit shader off, one flat colour per man")
	var shots := []
	for t in BEATS:
		vig.set("_t", t)
		vig.queue_redraw()
		for i in range(3):
			await process_frame
		shots.append(root.get_viewport().get_texture().get_image())
	var sw := W * scale
	var shh := H * scale
	var sheet := Image.create(sw * 3, shh * 2, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, sw, shh), Vector2i((i % 3) * sw, (i / 3) * shh))
	sheet.save_png(out + "_sheet.png")
	print("wrote ", out + "_sheet.png")
	# Every move it drew, from the sheet: the strip's frame count and the frames wanted.
	var seen := {}
	for e in Stoppage.frame_log:
		var k := "%s/%s" % [e["anim"], e["facing"]]
		if not seen.has(k):
			seen[k] = {"frames": int(e["frames"]), "max_wanted": 0}
		seen[k]["max_wanted"] = maxi(int(seen[k]["max_wanted"]), int(e["wanted"]))
	for k in seen:
		print("ART ", k, " frames ", seen[k]["frames"], " max wanted ", seen[k]["max_wanted"])
	if movie:
		var n := 0
		var t := 0.0
		while t < Farewell.END:
			vig.set("_t", t)
			vig.queue_redraw()
			for i in range(2):
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			img.save_png("%s_f%04d.png" % [out, n])
			n += 1
			t += 1.0 / 30.0
		print("filmed ", n)
	quit(0)
