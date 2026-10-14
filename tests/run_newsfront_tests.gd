extends SceneTree
## godot --headless --path . --script tests/run_newsfront_tests.gd
## League news as a front page (director, 2026-10-14): the round's items become a
## lead story, a few secondary stories and grouped briefs. Every item stays on
## the page exactly once, repeats are grouped, the lead follows a fixed rule,
## the hub's small front page sits under the ladder, and a real tap opens it.

const Tap := preload("res://tests/tap.gd")

var _state: Node
var _router: Node
var _db: Node
var _nf: GDScript
var _ui: GDScript
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _settle(n := 6) -> void:
	for i in range(n):
		await process_frame


func _item(kind: String, text: String, when := "Round 1", year := 2027) -> Dictionary:
	return {"year": year, "when": when, "kind": kind, "text": text}


## A round like the director's screenshot, newest first.
func _round_one() -> Array:
	var a: String = _db.club_name("GEE")
	var b: String = _db.club_name("SYD")
	var c: String = _db.club_name("HAW")
	var d: String = _db.club_name("PAD")
	var items := [
		_item("media", "Post-match: 'It clearly hurt us...'"),
		_item("mro", "Kane Farrell (%s) was fined by the MRO for rough conduct." % d),
		_item("injury", "Josh Battle (%s) is out for 8 weeks with a hand." % c),
		_item("game", "Shannon Neale kicked 6 goals for %s against %s." % [a, b]),
	]
	for i in range(15):
		items.append(_item("milestone", "Debutant%d Kicker kicked his first AFL goal for %s." % [i, [a, b, c, d][i % 4]]))
	return items


func _texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_texts(c, out)


func _run() -> void:
	await process_frame
	_nf = load("res://scripts/ui/NewsFront.gd")
	_ui = load("res://scripts/ui/UiKit.gd")
	_state = root.get_node("GameState")
	_router = root.get_node("Router")
	_db = root.get_node("GameDB")
	_state.autosave_enabled = false
	_state.save_path = "user://test_newsfront.save"
	_state.settings_path = "user://test_newsfront.cfg"
	_state.delete_saved_career()
	_pure("MEL")
	await _page()
	await _hub(Vector2i(1280, 720), true)
	await _hub(Vector2i(390, 844), false)
	print("Newsfront tests: %d checks, %d failures" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL: " + f)
	quit(1 if not _failures.is_empty() else 0)


func _pure(me: String) -> void:
	var items := _round_one()
	var page = _nf.build(items, me)
	var all = _nf.all_stories(page)
	_check(all.size() == items.size(), "Every item of the round is on the page (%d of %d)" % [all.size(), items.size()])
	var texts := {}
	for st in all:
		texts[str(st["text"])] = int(texts.get(str(st["text"]), 0)) + 1
	var each_once := true
	for it in items:
		if int(texts.get(str(it["text"]), 0)) != 1:
			each_once = false
	_check(each_once, "No item is lost or repeated")
	_check(str(page["lead"]["name"]) == "Shannon Neale" and str(page["lead"]["headline"]).contains("six"),
			"A six-goal haul leads the round (%s)" % str(page["lead"]["headline"]))
	_check(str(page["lead"]["club"]) == "GEE", "The lead story belongs to the club involved")
	var firsts: Dictionary = {}
	for b in page["briefs"]:
		if b["key"] == "first_goals":
			firsts = b
	_check(not firsts.is_empty() and firsts["entries"].size() == 15, "The 15 first goals are one block")
	_check(str(firsts.get("title", "")) == "First AFL goals", "That block is called First AFL goals")
	var repeats := 0
	for st in [page["lead"]] + page["secondary"]:
		if str(st["text"]).contains("first AFL goal"):
			repeats += 1
	_check(repeats == 0, "First goals are never a headline of their own")
	_check(page["secondary"].size() >= 2 and page["secondary"].size() <= 3, "Two or three secondary stories (%d)" % page["secondary"].size())
	_check(page["dateline"] == "2027  Round 1", "The round and year are the dateline (%s)" % page["dateline"])
	var yours := 0
	for st in all:
		if bool(st["mine"]):
			yours += 1
	_check(yours == 1, "Only your press quote is marked as yours (%d)" % yours)
	var again = _nf.build(items.duplicate(), me)
	_check(again["lead"]["text"] == page["lead"]["text"] and again["secondary"].size() == page["secondary"].size(), "The same round always gives the same page")
	var big_injury := _item("injury", "Big Name (%s) is out for 16 weeks with a knee." % _db.club_name("GEE"))
	var p2 = _nf.build([big_injury, items[3]], me)
	_check(str(p2["lead"]["name"]) == "Big Name", "A 16-week injury to a star outranks a six-goal haul (%s)" % p2["lead"]["headline"])
	var prem = _nf.build([items[3], _item("premiers", "%s are the 2027 premiers." % _db.club_name("MEL"))], me)
	_check(prem["lead"]["kind"] == "premiers", "The premiership leads")
	var tie_a := _item("trade", "Trade: one.")
	var tie_b := _item("trade", "Trade: two.")
	_check(_nf.build([tie_a, tie_b], me)["lead"]["text"] == "Trade: one.", "Equal weight keeps the feed's order")
	var old := _item("game", "Old Hand kicked 7 goals for %s against %s." % [_db.club_name("GEE"), _db.club_name("SYD")], "Round 0")
	var two := items + [old]
	_check(_nf.rounds(two).size() == 2 and _nf.latest_round(two).size() == items.size(), "The page is the newest round; older ones are earlier")
	_check(_nf.build([], me)["count"] == 0, "An empty feed makes an empty page")


func _page() -> void:
	_state.reset()
	_state.start_season("MEL", _db.club_list("MEL"))
	_state.tutorials = false
	var old := _item("game", "Old Hand kicked 7 goals for %s against %s." % [_db.club_name("GEE"), _db.club_name("SYD")], "Pre-season")
	var items := _round_one() + [old]
	root.size = Vector2i(1280, 720)
	await _settle()
	var body := VBoxContainer.new()
	root.add_child(body)
	_nf.fill(body, items, "MEL", true)
	await _settle()
	var texts: Array = []
	_texts(body, texts)
	var blob := "\n".join(texts)
	_check(not blob.contains("Difficulty"), "The front page does not carry the difficulty")
	_check(blob.contains("2027  Round 1"), "The dateline reads the round and year")
	var present := true
	for it in items:
		var s = _nf.story(it, "MEL")
		var needle := str(s["name"]) if str(s["name"]) != "" else str(s["text"])
		if str(s["kind"]) == "media":
			needle = "It clearly hurt us"
		if not blob.contains(needle):
			present = false
			push_error("missing on page: " + needle)
	_check(present, "Every item of the feed is on the page (round and earlier)")
	_check(blob.contains("Your club"), "Your own item is marked as yours")
	_check(body.find_child("LeadStory", true, false) != null and body.find_child("SecondaryStories", true, false) != null, "Lead and secondary stories are there")
	var firsts := 0
	for t in texts:
		if str(t).contains("first AFL goal"):
			firsts += 1
	_check(firsts == 0, "No 'first AFL goal' line repeats on the page")
	var head: Label = body.find_child("Headline", true, false)
	_check(head != null and head.get_theme_color("font_color") != _ui.TEXT, "The lead headline is in the club's colour")
	body.queue_free()


func _hub(size: Vector2i, wide: bool) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	_state.reset()
	_state.start_season("MEL", _db.club_list("MEL"))
	_state.tutorials = false
	_state.news = _round_one()
	root.size = size
	_router.stack = []
	_router.go("main")
	await _settle()
	_router.go("hub")
	await _settle(10)
	var hub: Node = current_scene
	var card: Control = hub.find_child("NewsCard", true, false)
	var lad: Control = hub.find_child("LadderSection", true, false)
	_check(card != null and lad != null, "%s: the hub has the news card and the ladder" % tag)
	if card == null or lad == null:
		return
	if wide:
		var lr := lad.get_global_rect()
		var cr := card.get_global_rect()
		_check(absf(cr.position.y - lr.position.y) < 30.0 and cr.position.x >= lr.end.x - 1.0,
				"%s: the front page stands beside the ladder (%s beside %s)" % [tag, cr, lr])
		var view := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 70))
		_check(view.encloses(cr) and view.encloses(lr), "%s: ladder and front page are both in view without scrolling (%s, %s)" % [tag, cr, lr])
	var texts: Array = []
	_texts(card, texts)
	var blob := "\n".join(texts)
	_check(blob.contains("Shannon Neale") and blob.contains("bags six"), "%s: the card leads with the round's big story" % tag)
	var more: Button = hub.find_child("NewsMore", true, false)
	var why: String = await Tap.tap(more) if more != null else "missing"
	await _settle(8)
	_check(why == "" and hub.find_child("NewsFeed", true, false) != null, "%s: a real tap on the card opens the front page (%s)" % [tag, why])
	var feed: Control = hub.find_child("NewsFeed", true, false)
	if feed != null:
		var top := feed.find_child("LeadStory", true, false)
		_check(top != null and Rect2(Vector2.ZERO, Vector2(size)).encloses(top.get_global_rect()), "%s: the lead story is on screen" % tag)
		var close: Button = null
		for b in feed.find_children("*", "Button", true, false):
			if (b as Button).text == "Close":
				close = b
		var closed: String = await Tap.tap(close) if close != null else "missing"
		await _settle(4)
		_check(closed == "" and hub.find_child("NewsFeed", true, false) == null, "%s: Close closes it" % tag)
