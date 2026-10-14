extends RefCounted
## Role audit (docs/research/ROLE_AUDIT_2026-10-14.md): one CSV row per player
## on every 2027 list - listed position, the game's first position and
## identity, and the per-game numbers the identity should agree with. Reads;
## changes nothing. No arguments. Rows start with "ROW,".


func run() -> void:
	GameState.reset()
	GameState.autosave_enabled = false
	print("ROW,club,name,listed,role,role2,label,gm,cl,cp,di,ho,rb,mk,if50,tk,gl,onepct,cm,height")
	for club in GameDB.active_clubs(2027):
		for p in GameDB.club_list(str(club)):
			var g := maxf(1.0, float(p.get("gm", 0.0)))
			print("ROW,%s,%s,%s,%s,%s,%s,%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.0f" % [
					str(club), str(p.get("real_name", GameDB.player_display_name(p))),
					str(p.get("real_pos", "")), str(p.get("role", "")), str(p.get("role2", "")),
					Roles.label(p), int(p.get("gm", 0)),
					float(p.get("cl", 0.0)) / g, float(p.get("cp", 0.0)) / g, float(p.get("di", 0.0)) / g,
					float(p.get("ho", 0.0)) / g, float(p.get("rb", 0.0)) / g, float(p.get("mk", 0.0)) / g,
					float(p.get("if50", 0.0)) / g, float(p.get("tk", 0.0)) / g, float(p.get("gl", 0.0)) / g,
					float(p.get("onepct", 0.0)) / g, float(p.get("cm", 0.0)) / g, float(p.get("height_cm", 0.0))])
	GameState.reset()
