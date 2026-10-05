extends RefCounted
## Can training turn a player into a type his body does not fit? Every player
## on every club, on each plan his position allows, trained hard; record which
## player-type labels change and whether role / role2 ever change.

func run() -> void:
	var transitions := {}
	var role_changes := 0
	var small_kd := []
	var small_kf := []
	var trained := 0
	for club in GameDB.active_clubs(2027):
		for plan_row in GameState.TRAIN_PLANS:
			if not plan_row.has("weights"):
				continue
			GameState.reset()
			GameState.autosave_enabled = false
			GameState.start_season(str(club), GameDB.club_list(str(club)))
			var before := {}
			for p in GameState.my_list:
				if not (plan_row["roles"] as Array).has(str(p.get("role", ""))):
					continue
				before[str(p["id"])] = [PlayerProfile.player_type(p), str(p["role"]), str(p.get("role2", ""))]
				GameState.set_player_plan(str(p["id"]), str(plan_row["key"]))
			for i in range(12):
				for p in GameState.my_list:
					p["xp"] = int(p.get("xp", 0)) + 300
				GameState.apply_train_plans()
			for p in GameState.my_list:
				var id := str(p["id"])
				if not before.has(id):
					continue
				trained += 1
				var now := PlayerProfile.player_type(p)
				var was: String = before[id][0]
				if str(p["role"]) != before[id][1] or str(p.get("role2", "")) != before[id][2]:
					role_changes += 1
				if now != was:
					var k := "%s -> %s (plan %s)" % [was, now, plan_row["key"]]
					transitions[k] = int(transitions.get(k, 0)) + 1
				var h := float(p.get("height_cm", 0.0))
				if now == "Key defender" and h < PlayerProfile.KEY_DEF_CM:
					small_kd.append("%s %.0fcm" % [GameDB.player_display_name(p), h])
				if now == "Key forward" and h > 0.0 and h < 188.0:
					small_kf.append("%s %.0fcm" % [GameDB.player_display_name(p), h])
	print("TRAINED player-plan runs: %d; role/role2 changed: %d" % [trained, role_changes])
	print("UNDER-191cm typed Key defender after training: %d %s" % [small_kd.size(), str(small_kd.slice(0, 5))])
	print("UNDER-188cm typed Key forward after training: %d %s" % [small_kf.size(), str(small_kf.slice(0, 5))])
	var keys := transitions.keys()
	keys.sort_custom(func(a, b): return int(transitions[a]) > int(transitions[b]))
	for k in keys:
		print("    %4d  %s" % [int(transitions[k]), k])
	GameState.reset()
