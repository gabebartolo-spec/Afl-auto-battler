extends RefCounted
## The 2026 list additions' rating, role and POT (one ADD line each), with the
## season they were rated on ("-" for a prospect). Reads; changes nothing.

func run() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	print("ADD,club,name,role,ovr,pot,gm,src,height")
	for p in GameDB.list_additions:
		print("ADD,%s,%s,%s,%d,%d,%d,%s,%.0f" % [str(p.get("club", "")), str(p.get("real_name", "")),
				str(p.get("role", "")), int(p.get("overall", 0)), int(p.get("potential", 0)),
				int(p.get("gm", 0)), str(p.get("stats_year", "-")), float(p.get("height_cm", 0.0))])
	GameState.reset()
