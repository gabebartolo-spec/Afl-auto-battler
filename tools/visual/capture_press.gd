extends SceneTree
## Visual review of the post-match press conference (MediaConferenceVignette) on a phone.
## Real renderer, e.g.:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/visual/capture_press.gd \
##       -- --out /tmp/press [--width 360] [--club COL]
## Writes <out>_<width>.png: the scene at its beats (walking in, sitting down, settled,
## answering), at the size the hub gives it. Nothing here touches a save.

const BEATS := [0.5, 1.15, 1.4, 1.7, 2.4]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/press"
	var width := 360
	var club := "COL"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--width": width = int(a[i + 1])
			"--club": club = str(a[i + 1])
	await process_frame
	var h := int(round(width * 2.2))
	root.size = Vector2i(width, h)
	DisplayServer.window_set_size(Vector2i(width, h))
	# The hub's stage: the modal's width, at most 300 px or 0.38 of the screen tall.
	var stage := Control.new()
	stage.position = Vector2.ZERO
	stage.size = Vector2(width, minf(300.0, h * 0.38))
	root.add_child(stage)
	var scene = load("res://scripts/ui/MediaConferenceVignette.gd").open(stage, club)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	scene.set_process(false)
	var r := Rect2i(Vector2i.ZERO, Vector2i(stage.size))
	var sheet := Image.create(r.size.x * BEATS.size(), r.size.y, false, Image.FORMAT_RGBA8)
	for c in range(BEATS.size()):
		scene.set("_t", float(BEATS[c]))
		scene.queue_redraw()
		for i in range(3):
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, r, Vector2i(c * r.size.x, 0))
	var path := "%s_%d.png" % [out, width]
	sheet.save_png(path)
	print("wrote ", path)
	quit()
