extends SceneTree
## godot --headless --path . --script tests/run_training_tests.gd
## Run a headless editor import first on a fresh clone to register global classes.

const Tap := preload("res://tests/tap.gd")

var _checks := 0
var _failures: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_isolate_saves()
	# A suite that fails to compile must fail the run, not hang it.
	var script = load("res://tests/test_training.gd")
	if script == null or not script.can_instantiate():
		push_error("Could not load res://tests/test_training.gd")
		quit(1)
		return
	var suite = script.new()
	suite.run()
	_checks = suite.checks
	_failures.append_array(suite.failures)
	await _training_hero()
	print("Training tests: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The training gear on the Training screen (director, 2026-10-14): the real
## picture in the club's wash beside the week's news, never red, no word cut
## short, and a player still opens on a real tap. Without the file the news
## has the panel to itself.
func _training_hero() -> void:
	var gs = root.get_node("GameState")
	var db = root.get_node("GameDB")
	var art = load("res://scripts/ui/UiArt.gd")
	var culture = load("res://scripts/ui/CultureSheet.gd")
	for club in ["FRE", "MEL"]:
		for sz in [Vector2i(390, 844), Vector2i(1280, 720)]:
			var tag := "%s %dx%d" % [club, sz.x, sz.y]
			gs.reset()
			gs.set_setting("seen_training_intro", true)
			gs.start_season(club, db.club_list(club))
			root.size = sz
			var scene: Control = load("res://scenes/TrainingScene.tscn").instantiate()
			root.add_child(scene)
			await _settle()
			var hero: TextureRect = scene.find_child("TrainingHero", true, false)
			var tex: Texture2D = hero.texture if hero != null else null
			_check(tex != null and tex.resource_path == "res://assets/ui/models/training_set.png"
					and float(tex.get_height()) >= 2.0 * hero.size.y and hero.size.y >= 72.0,
					"%s: Training shows the training gear's own picture, sharp at this size (%s)" % [tag, tex.resource_path if tex != null else "missing"])
			if hero == null:
				scene.queue_free()
				await _settle()
				continue
			var tint: Color = hero.modulate
			_check(tint.is_equal_approx(culture.emblem_tint(club)) and tint.v > 0.75 and (tint.s < 0.08 or (tint.h > 0.08 and tint.h < 0.92)),
					"%s: the gear carries the club's wash and is never red (%s)" % [tag, tint.to_html(false)])
			var panel: Control = hero.get_parent().get_parent()
			var whole := panel.get_global_rect().grow(0.5).encloses(hero.get_global_rect()) and hero.mouse_filter == Control.MOUSE_FILTER_IGNORE
			var words := 0
			for l in panel.find_children("*", "Label", true, false):
				var lab := l as Label
				if not lab.is_visible_in_tree() or lab.text == "":
					continue
				words += 1
				if lab.size.y + 1.0 < lab.get_combined_minimum_size().y or lab.get_global_rect().intersects(hero.get_global_rect()) 						or not panel.get_global_rect().grow(0.5).encloses(lab.get_global_rect()):
					whole = false
			_check(whole and words > 0, "%s: the gear stands inside the news panel, takes no tap, and no word beside it is cut short or covered" % tag)
			var row: Button = null
			for b in scene.find_children("Trainee_*", "Button", true, false):
				row = b
				break
			_check(row != null and row.size.y >= 44.0, "%s: a player's row is still a thumb tall (%d)" % [tag, int(row.size.y) if row != null else 0])
			if sz.x < 600 and club == "FRE":
				var why: String = await Tap.tap(row)
				await _settle()
				_check(why == "" and bool(scene.get("_showing_detail")), "%s: a real tap still opens a player (%s)" % [tag, why])
			scene.queue_free()
			await _settle()
	art.dir = "res://assets/ui/no_such_folder"
	root.size = Vector2i(390, 844)
	var plain: Control = load("res://scenes/TrainingScene.tscn").instantiate()
	root.add_child(plain)
	await _settle()
	_check(plain.find_child("TrainingHero", true, false) == null and not plain.find_children("Trainee_*", "Button", true, false).is_empty(),
			"Without the picture Training opens as it did, the list under the news")
	plain.queue_free()
	await _settle()
	art.dir = "res://assets/ui/models"


func _settle() -> void:
	for i in range(6):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


## Never touch a real career save or settings file from a test run.
func _isolate_saves() -> void:
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://test_career.save"
	gs.settings_path = "user://test_settings.cfg"
	gs.show_real_names = false
