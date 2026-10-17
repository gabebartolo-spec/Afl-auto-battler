extends SceneTree
## League news front page and its hub card (needs a real renderer):
##   godot --path . --script tools/visual/capture_newsfront.gd -- --size 1280x720 --out PREFIX --mode r1|mid [--club MEL]
## Writes PREFIX_hub.png and PREFIX_news.png. Dark theme; a fresh career, never a real save.
## r1 is the director's Round 1 feed (15 first goals, a fine, an injury, a six-goal haul, a press quote);
## mid plays six real rounds and shows the news the game made.

var _w := 1280
var _h := 720
var _club := "MEL"


func _initialize() -> void:
	_run.call_deferred()


func _item(kind: String, text: String) -> Dictionary:
	return {"year": 2027, "when": "Round 1", "kind": kind, "text": text}


func _run() -> void:
	var out := "newsfront"
	var mode := "r1"
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		match str(a[i]):
			"--out":
				out = str(a[i + 1])
			"--mode":
				mode = str(a[i + 1])
			"--club":
				_club = str(a[i + 1])
			"--size":
				var wh := str(a[i + 1]).split("x")
				_w = int(wh[0])
				_h = int(wh[1])
	await process_frame
	var state = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var router = root.get_node("Router")
	state.autosave_enabled = false
	state.save_path = "user://capture_newsfront.save"
	state.settings_path = "user://capture_newsfront.cfg"
	state.reset()
	state.start_season(_club, db.club_list(_club))
	state.tutorials = false
	# The canvas is the size a player's screen gives the game (1280x720 on a PC, 390x844 on a
	# phone): undo this machine's display density so the layout is the real one.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(_w, _h))
	for i in range(10):
		await process_frame
	var layout = root.get_node("ScreenLayout")
	var base: float = layout.desktop_density(Vector2(root.size), DisplayServer.screen_get_scale(),
			DisplayServer.screen_get_dpi() if OS.get_name() == "Windows" else 0)
	layout.ui_scale = 1.0 / maxf(1.0, base)
	layout._update_scale()
	for i in range(10):
		await process_frame
	print("canvas ", root.get_visible_rect().size)
	if mode == "r1":
		var items := [
			_item("media", "Post-match: 'It clearly hurt us...'"),
			_item("mro", "Kane Farrell (Port Adelaide) was fined by the MRO for rough conduct."),
			_item("injury", "Josh Battle (Hawthorn) is out for 8 weeks with a hand."),
			_item("game", "Shannon Neale kicked 6 goals for Geelong against Sydney."),
		]
		var firsts := [["Jed Walter", "Gold Coast"], ["Harry Sheezel", "North Melbourne"], ["Zane Duursma", "Fremantle"],
				["Ollie Dempsey", "Essendon"], ["Cam Mackenzie", "Hawthorn"], ["Nick Daicos", "Collingwood"],
				["Finn O'Sullivan", "Carlton"], ["Max Michalanney", "Adelaide"], ["Jake Bowey", "Melbourne"],
				["Will Ashcroft", "Brisbane"], ["Elijah Tsatas", "Richmond"], ["Sam Darcy", "Western Bulldogs"],
				["Lachie Ash", "Greater Western Sydney"], ["Ryley Sanders", "Western Bulldogs"], ["Tom Green", "St Kilda"]]
		for f in firsts:
			items.append(_item("milestone", "%s kicked his first AFL goal for %s." % [f[0], f[1]]))
		state.news = items
	else:
		for i in range(6):
			state.advance()
		state.media_conference = {}  # the press conference sheet is not what is being shown
		print("NEWS_COUNT ", state.news.size())
	router.stack = []
	router.go("main")
	await _frames(8)
	router.go("hub")
	await _frames(25)
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == "Got it" and (b as Button).is_visible_in_tree():
			(b as Button).emit_signal("pressed")
	await _frames(20)
	for n in ["ThisWeek", "LadderSection", "NewsCard"]:
		var c: Control = root.find_child(n, true, false)
		print("RECT ", n, " ", c.get_global_rect() if c != null else "none")
	_save(out + "_hub.png")
	for sc in root.find_children("*", "ScrollContainer", true, false):
		if (sc as ScrollContainer).is_visible_in_tree() and (sc as ScrollContainer).size.y > 200:
			(sc as ScrollContainer).scroll_vertical = 100000
			break
	await _frames(10)
	_save(out + "_hubdown.png")
	var more: Button = root.find_child("NewsMore", true, false)
	if more != null:
		more.emit_signal("pressed")
	await _frames(25)
	_save(out + "_news.png")
	var feed: Node = root.find_child("NewsFeed", true, false)
	if feed != null:
		for sc in feed.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 100000
			break
		await _frames(10)
		_save(out + "_newsdown.png")
	quit()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _save(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
