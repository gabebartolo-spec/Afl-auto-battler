extends Node
## Router (autoload) - scene navigation with a back stack, so the back button
## works the same on desktop and mobile.

const SCENES := {
	"main": "res://scenes/Main.tscn",
	"draft": "res://scenes/DraftScene.tscn",
	"hub": "res://scenes/HubScene.tscn",
	"match": "res://scenes/MatchScene.tscn",
	"ladder": "res://scenes/LadderScene.tscn",
	"list": "res://scenes/ListScene.tscn",
	"selection": "res://scenes/SelectionScene.tscn",
	"training": "res://scenes/TrainingScene.tscn",
	"season_review": "res://scenes/SeasonReviewScene.tscn",
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


## Replace the current entry instead of pushing - used for boot -> menu.
func replace(key: String) -> void:
	if not stack.is_empty():
		stack.pop_back()
	go(key)


func back() -> void:
	if stack.size() <= 1:
		return
	stack.pop_back()
	go(stack[stack.size() - 1])


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
