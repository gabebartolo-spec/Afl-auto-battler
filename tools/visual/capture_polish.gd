extends SceneTree
## The hub and a player profile at phone size, for the hub/profile polish look:
##   godot --path . --script tools/visual/capture_polish.gd -- --out /tmp/polish [--club BRL] [--size 390x844]
## Writes <out>_hub.png (the top), <out>_hub_bottom.png (scrolled to the end:
## league news and the ladder) and <out>_profile.png (a forward on My list).
## Needs a real renderer (capture.yml).

var W := 390
var H := 844


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in range(10):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(path)
	print("wrote ", path)


func _lum(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


## Real size and contrast of the small type where it sits: the label's font
## size and line height in pixels, and its colour against the brightest page
## pixel in a 3 px strip above and below it (the stripes behind it).
func _measure(tag: String, want: Callable) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var seen := {}
	for n in current_scene.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "" or not want.call(l):
			continue
		var r := l.get_global_rect()
		if r.end.y > H or r.position.y < 0:
			continue
		var key := "%s|%d" % [l.text, int(l.get_theme_font_size("font_size"))]
		if seen.has(key):
			continue
		seen[key] = true
		var bg := Color.BLACK
		var best := -1.0
		for x in range(int(r.position.x), mini(int(r.end.x), W - 1), 3):
			for y in [int(r.position.y) - 3, int(r.end.y) + 2]:
				if y < 0 or y >= H:
					continue
				var c := img.get_pixel(x, y)
				if _lum(c) > best:
					best = _lum(c)
					bg = c
		var fc: Color = l.get_theme_color("font_color")
		var lf := (_lum(fc) + 0.05) / (best + 0.05) if _lum(fc) > best else (best + 0.05) / (_lum(fc) + 0.05)
		print("POLISH %s [%s] font %d px, line height %d px, text %s on brightest %s: contrast %.1f" % [
				tag, l.text.substr(0, 28), l.get_theme_font_size("font_size"),
				int(l.get_theme_font("font").get_height(l.get_theme_font_size("font_size"))),
				fc.to_html(false), bg.to_html(false), lf])


func _run() -> void:
	var out := "/tmp/polish"
	var club := "BRL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if str(a[i]) == "--out":
			out = str(a[i + 1])
		if str(a[i]) == "--club":
			club = str(a[i + 1])
		if str(a[i]) == "--size":
			var wh := str(a[i + 1]).split("x")
			W = int(wh[0])
			H = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	state.autosave_enabled = false
	state.save_path = "user://capture_polish.save"
	state.settings_path = "user://capture_polish_settings.cfg"
	state.set_vignettes_on(false)
	state.set_reduced_motion(true)   # still frames: no slide or fades
	state.reset()
	state.replay_seed = 2027
	state.set_setting("seen_weekly_loop_intro", true)
	root.size = Vector2i(W, H)
	DisplayServer.window_set_size(Vector2i(W, H))
	state.start_season(club, db.club_list(club))
	state.tutorials = false
	state.media_conference = {}
	state.backing_talk = {}
	state.advance()
	state.media_conference = {}
	state.backing_talk = {}
	root.get_node("Router").go("hub")
	for i in range(10):
		await process_frame
	await _shot(out + "_hub.png")
	_measure("top", func(l: Label) -> bool: return l.text.contains("rated") or l.text.contains("Form:") or l.text.contains("on the ladder"))
	for sc in current_scene.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		s.scroll_vertical = 100000
	await _shot(out + "_hub_bottom.png")
	_measure("bottom", func(l: Label) -> bool: return l.text.contains("rated") or l.text.contains("Form:")
			or l.text in ["Club", "W-L", "Pts", "#", "1", "10", "1-0", "0-1", "4", "0", "Crows", "Giants", "Lions"]
			or l.get_parent() is VBoxContainer and l.text.begins_with("Mark Keane"))
	root.get_node("Router").go("list")
	for i in range(8):
		await process_frame
	var fwd: Dictionary = state.my_list[0]
	for q in state.my_list:
		if str(q.get("role", "")) == "FWD":
			fwd = q
			break
	current_scene.call("_open_profile", str(fwd["id"]))
	for l in current_scene.find_children("*", "Label", true, false):
		var t := (l as Label).text
		if t.begins_with("#") or l.name == "ProfileType":
			print("POLISH label %s: [%s]" % [l.name, t])
	await _shot(out + "_profile.png")
	quit(0)
