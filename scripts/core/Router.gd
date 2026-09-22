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
	"training": "res://scenes/TrainingScene.tscn",
	"season_review": "res://scenes/SeasonReviewScene.tscn",
}

var stack: Array = []


func go(key: String) -> void:
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


## Clears history and returns to the main menu, resetting the season.
func to_main_menu(wipe_save := true) -> void:
	if wipe_save:
		GameState.reset()
	stack = []
	go("main")
