class_name BuildInfo
extends RefCounted
## Which build this is, for testers to quote: the version and, when the build
## was made by CI, the short commit (CI writes build_info.txt; a build from the
## editor has none and shows only the version).

const FILE := "res://build_info.txt"


static func label() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	if FileAccess.file_exists(FILE):
		var c := FileAccess.get_file_as_string(FILE).strip_edges()
		if c != "":
			return "%s (%s)" % [v, c]
	return v
