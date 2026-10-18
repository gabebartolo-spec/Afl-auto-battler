extends SceneTree
## SCRATCH for the CI preflight proof (PR 816): names a class that is not declared.

var vignette: NoSuchClassAtCompileTime = null


func _initialize() -> void:
	quit(0)
