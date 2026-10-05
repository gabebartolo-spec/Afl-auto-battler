extends SceneTree
## Visual review tool for the broadcast close-ups (BroadcastVignette): every kind
## at its beats, on a phone. Needs a real renderer, so run it under a virtual
## display, e.g.:
##   xvfb-run -a -s "-screen 0 1280x900x24" godot --path . --rendering-driver opengl3 \
##       --script tools/visual/capture_broadcast.gd -- --out /tmp/broadcast [--width 360] [--scale 0.5]
## Writes <out>_<width>.png: one row per kind (speccy front, side, defensive,
## after the siren, goal-line crumb, boundary snap), one column per beat, each
## cell the whole portrait screen at --scale. Collingwood (your side, a real
## player featured) against Carlton; nothing here touches a save.
## --film KIND: instead writes <out>_KIND_NNN.png, the whole of that kind at 12
## frames a second, for checking motion.

const KINDS := ["speccy_front", "speccy_side", "speccy_defensive", "after_siren", "goal_line", "boundary_snap"]
## Seconds into each kind worth a still: wind-up, the moment, the ball's flight.
const BEATS := {
	"speccy_front": [0.3, 0.9, 1.3, 1.6, 2.1, 3.0],
	"speccy_side": [0.3, 0.9, 1.3, 1.6, 2.1, 3.0],
	"speccy_defensive": [0.3, 0.9, 1.3, 1.6, 2.1, 3.0],
	"after_siren": [1.0, 2.2, 2.85, 3.02, 3.3, 4.6],
	"goal_line": [0.5, 0.9, 1.3, 1.6, 1.9, 2.8],
	"boundary_snap": [0.3, 0.8, 1.15, 1.35, 1.6, 3.0],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/broadcast"
	var width := 360
	var scale := 0.5
	var film := ""
	var a := OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		match str(a[i]):
			"--out": out = str(a[i + 1])
			"--width": width = int(a[i + 1])
			"--scale": scale = float(a[i + 1])
			"--film": film = str(a[i + 1])
	await process_frame
	var db = root.get_node("GameDB")
	var w := width
	var h := int(round(width * 2.2))       # a tall phone in portrait
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var star: Dictionary = db.club_list("COL")[0]
	var cw := int(w * scale)
	var ch := int(h * scale)
	var sheet := Image.create(cw * 6, ch * KINDS.size(), false, Image.FORMAT_RGBA8)
	for r in range(KINDS.size()):
		var kind: String = KINDS[r]
		var ev := {"kind": "goal", "side": 0, "num": int(star.get("num", 7)), "player_id": str(star["id"]),
				"club": "COL", "q": 4, "set_shot": kind == "after_siren", "crumb": kind == "goal_line"}
		if kind.begins_with("speccy"):
			ev["kind"] = "mark"
		var vig = load("res://scripts/ui/match/BroadcastVignette.gd").new()
		root.add_child(vig)
		vig.size = Vector2(w, h)
		vig.setup(kind, ev, {}, {"home": "COL", "away": "CAR"})
		vig.set_process(false)
		var beats: Array = BEATS[kind]
		if film != "":
			if kind != film:
				vig.queue_free()
				continue
			beats = []
			var ft := 0.0
			while ft < vig.duration_for(kind):
				beats.append(ft)
				ft += 1.0 / 12.0
		for c in range(beats.size()):
			vig.set("_t", float(beats[c]))
			vig.modulate.a = 1.0
			vig.queue_redraw()
			for i in range(3):
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			if film != "":
				img.save_png("%s_%s_%03d.png" % [out, kind, c])
				continue
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i(c * cw, r * ch))
		vig.queue_free()
		await process_frame
	if film != "":
		print("filmed ", film)
		quit(0)
		return
	var path := "%s_%d.png" % [out, width]
	sheet.save_png(path)
	print("wrote ", path)
	quit(0)
