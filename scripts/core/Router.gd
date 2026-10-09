extends Node
## Router (autoload) - scene navigation with a back stack, so the back button
## works the same on desktop and mobile.

const SCENES := {
	"main": "res://scenes/Main.tscn",
	"draft": "res://scenes/DraftScene.tscn",
	"hub": "res://scenes/HubScene.tscn",
	"match": "res://scenes/MatchScene.tscn",
	"stats": "res://scenes/StatsHubScene.tscn",
	"list": "res://scenes/ListScene.tscn",
	"selection": "res://scenes/SelectionScene.tscn",
	"offseason": "res://scenes/OffseasonScene.tscn",
	"training": "res://scenes/TrainingScene.tscn",
	"staff": "res://scenes/StaffScene.tscn",
	"coaching": "res://scenes/CoachingScene.tscn",
	"season_review": "res://scenes/SeasonReviewScene.tscn",
	"forge": "res://scenes/ClubForgeScene.tscn",
}

var stack: Array = []


func go(key: String) -> void:
	# Every screen change is a safe point to save (GameState skips it while a
	# live match is half played).
	GameState.autosave_if_dirty()
	var path := str(SCENES.get(key, key))
	if not ResourceLoader.exists(path):
		push_error("Router: scene not found for '%s' (%s)" % [key, path])
		return
	stack.append(key)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router: change_scene_to_file failed (%d) for %s" % [err, path])
		return
	MusicManager.set_context(key)
	_ease_in()


## The new screen eases in rather than cutting (director, 2026-10-08: motion).
func _ease_in() -> void:
	if not UiKit.motion_on():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene as CanvasItem
	if scene == null:
		return
	scene.modulate.a = 0.0
	scene.create_tween().tween_property(scene, "modulate:a", 1.0, 0.18)


## Replace the current entry instead of pushing - used for boot -> menu.
func replace(key: String) -> void:
	if not stack.is_empty():
		stack.pop_back()
	go(key)


func back() -> void:
	if stack.size() <= 1:
		# Nothing behind this screen (the menu is the boot scene and was never
		# pushed, so Club Forge's back found an empty history): go to the menu.
		if current() != "" and current() != "main":
			to_main_menu(false)
		return
	# Take both this screen and the one we return to off the stack: go()
	# pushes the target again. Leaving it on made it appear twice, so every
	# later back landed on the same screen.
	stack.pop_back()
	go(str(stack.pop_back()))


func current() -> String:
	return str(stack[stack.size() - 1]) if not stack.is_empty() else ""


func can_go_back() -> bool:
	return stack.size() > 1


# ---------------------------------------------------------------------------
# Back button (Android back gesture, Escape on desktop)
# ---------------------------------------------------------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back(false)


## The current scene gets first say through an optional handle_back() -> bool
## (close a popup, refuse to leave a live match). Otherwise step back one
## screen. Only the OS back button on the main menu leaves the app; Escape on
## desktop never quits.
func handle_back(from_os := false) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("handle_back") and bool(scene.call("handle_back")):
		return
	match current():
		"main", "":
			if from_os:
				get_tree().quit()
		"hub":
			to_main_menu(false)
		"draft":
			replace("main")
		_:
			if can_go_back():
				back()
			else:
				to_main_menu(false)


## Clears history and returns to the main menu, resetting the season.
## The career stays on disk: the main menu offers Continue Career.
func to_main_menu(wipe_save := true) -> void:
	if wipe_save:
		GameState.autosave()
		GameState.reset()
	stack = []
	go("main")


## Open New career setup from inside a career without deleting the existing
## save. The normal New career confirmation remains the destructive gate.
func to_new_career_setup() -> void:
	GameState.autosave()
	GameState.reset()
	GameState.new_career_setup_requested = true
	stack = []
	go("main")
