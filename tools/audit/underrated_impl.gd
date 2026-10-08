extends RefCounted
## Who does the opening draft undersell? Every player on a 2027 list (the
## pool the career's first draft picks from): his 2026 OVR against his
## established level - the mean OVR of his rated 2024 and 2025 seasons with
## 12+ games, from the same model (data/player_history_2026.csv). A short
## 2026 season (an injury) shrinks OVR toward 40, so the 2026 games are
## printed beside every gap. Reads; changes nothing. No arguments.

const MIN_GAP := 6


func run() -> void:
	var min_gap := MIN_GAP
	GameState.reset()
	GameState.autosave_enabled = false
	var rows := []
	var with_hist := 0
	for club in GameDB.active_clubs(2027):
		for p in GameDB.club_list(str(club)):
			var est := []
			for h in p.get("history", []):
				if int(h[0]) >= 2024 and int(h[2]) >= 12:
					est.append(int(h[1]))
			if est.is_empty():
				continue
			with_hist += 1
			var level := 0.0
			for v in est:
				level += float(v)
			level /= float(est.size())
			var gap := level - float(p.get("overall", 0))
			rows.append({"p": p, "level": level, "gap": gap, "seasons": est.size()})
	rows.sort_custom(func(a, b): return float(a["gap"]) > float(b["gap"]))
	print("PLAYERS with an established 2024-25 level: %d" % with_hist)
	var short := 0
	var full := 0
	var listed := 0
	print("\nUNDERRATED BY %d+ OVR (2026 OVR vs 2024-25 level)" % min_gap)
	print("  %-24s %-3s %-4s %3s  %4s  %5s  %3s  %4s  %s" % ["player", "clb", "role", "age", "OVR", "level", "gap", "gm26", "history (year:OVR:games)"])
	for r in rows:
		if float(r["gap"]) < float(min_gap):
			break
		var p: Dictionary = r["p"]
		listed += 1
		if float(p.get("gm", 0.0)) < 14.0:
			short += 1
		else:
			full += 1
		var hs: PackedStringArray = []
		for h in p.get("history", []):
			hs.append("%d:%d:%d" % [int(h[0]), int(h[1]), int(h[2])])
		print("  %-24s %-3s %-4s %3d  %4d  %5.1f  %3.0f  %4d  %s" % [GameDB.player_display_name(p),
				str(p.get("club", "")), str(p.get("role", "")), int(p.get("age", 0)), int(p.get("overall", 0)),
				float(r["level"]), float(r["gap"]), int(p.get("gm", 0)), " ".join(hs)])
	print("\n%d players %d+ under their level: %d played under 14 games in 2026, %d a full-ish season" % [
			listed, min_gap, short, full])
	# The other way, for scale: how far the model runs above a level too.
	var over := 0
	for r in rows:
		if float(r["gap"]) <= -float(min_gap):
			over += 1
	print("%d players %d+ OVER their level (the gap runs both ways)" % [over, min_gap])
	_short_seasons()
	GameState.reset()


## The counting stats in players_2026.csv; time on ground (pctp) is a share.
const COUNTING := ["ki", "mk", "hb", "di", "gl", "bh", "ho", "tk", "rb", "if50", "cl", "cg",
		"ff", "fa", "br", "cp", "up", "cm", "mi", "onepct", "bo", "ga"]
const FULL_SEASON := 22.0


## A short 2026 season is rated twice over for its size: every per-game rate
## is pulled toward the league average (Ratings shrunk_rate, 5 games' worth)
## and the OVR toward 40 under 14 games (rate_overall's confidence). Re-rate
## the whole pool with each short-season player's per-game numbers held for
## 22 games: what his handful of games says he is, if they were the season.
func _short_seasons() -> void:
	var copy := []
	var short_ids := {}
	for p in GameDB.players:
		var c: Dictionary = p.duplicate(true)
		var gm := float(c.get("gm", 0.0))
		if gm >= 1.0 and gm < 14.0:
			short_ids[str(c["id"])] = true
			var f := FULL_SEASON / gm
			for k in COUNTING:
				if c.has(k):
					c[k] = float(c[k]) * f
			c["gm"] = FULL_SEASON
		copy.append(c)
	Ratings.derive_all(copy)
	var full := {}
	for c in copy:
		full[str(c["id"])] = int(c["overall"])
	# Rank in the opening pool by OVR, as the draft board sorts it.
	var pool := []
	for club in GameDB.active_clubs(2027):
		pool.append_array(GameDB.club_list(str(club)))
	var by_ov := pool.duplicate()
	by_ov.sort_custom(func(a, b): return int(a["overall"]) > int(b["overall"]))
	var rank := {}
	for i in range(by_ov.size()):
		rank[str(by_ov[i]["id"])] = i + 1
	var by_full := pool.duplicate()
	by_full.sort_custom(func(a, b): return int(full.get(str(a["id"]), a["overall"])) > int(full.get(str(b["id"]), b["overall"])))
	var rank_full := {}
	for i in range(by_full.size()):
		rank_full[str(by_full[i]["id"])] = i + 1
	var rows := []
	for p in pool:
		if short_ids.has(str(p["id"])):
			rows.append(p)
	rows.sort_custom(func(a, b): return full[str(a["id"])] - int(a["overall"]) > full[str(b["id"])] - int(b["overall"]))
	print("\nSHORT 2026 SEASONS (1-13 games): %d in the opening pool" % rows.size())
	print("  %-24s %-3s %-4s %3s %4s  %4s %5s  %4s %5s  %3s %5s  %5s %5s  %s" % ["player", "clb", "role", "age",
			"gm26", "OVR", "rank", "full", "rank", "POT", "rehab", "D/gm", "G/gm", "2024-25 (year:OVR:games)"])
	var lifted := 0
	var top100 := 0
	for p in rows:
		var id := str(p["id"])
		var gm := maxf(1.0, float(p.get("gm", 0.0)))
		var hs: PackedStringArray = []
		for h in p.get("history", []):
			if int(h[0]) >= 2024:
				hs.append("%d:%d:%d" % [int(h[0]), int(h[1]), int(h[2])])
		if int(full[id]) - int(p["overall"]) >= 10:
			lifted += 1
		if int(rank_full[id]) <= 100 and int(rank[id]) > 100:
			top100 += 1
		print("  %-24s %-3s %-4s %3d %4d  %4d %5d  %4d %5d  %3d %5s  %5.1f %5.1f  %s" % [GameDB.player_display_name(p),
				str(p.get("club", "")), str(p.get("role", "")), int(p.get("age", 0)), int(p.get("gm", 0)),
				int(p["overall"]), int(rank[id]), int(full[id]), int(rank_full[id]),
				int(p.get("potential", 0)), "yes" if bool(p.get("rehab", false)) else "-",
				float(p.get("di", 0.0)) / gm, float(p.get("gl", 0.0)) / gm, " ".join(hs)])
	print("\n%d short-season players rate 10+ higher held over a full season; %d of them move into the top 100" % [lifted, top100])
	_recent_view(pool, rank)


## Recency weights for a games-weighted look across seasons (illustration
## for the director, not the game's model).
const RECENT_W := {2026: 1.0, 2025: 0.75, 2024: 0.5}


## A short or missing 2026 says little; his 2024 and 2025 say more. Each
## season's OVR (same model) weighted by its games and recency, for every
## player under 14 games in 2026 who has a rated 2024 or 2025.
func _recent_view(pool: Array, rank: Dictionary) -> void:
	var rows := []
	for p in pool:
		var gm := float(p.get("gm", 0.0))
		if gm >= 14.0:
			continue
		var num := float(p["overall"]) * gm * float(RECENT_W[2026])
		var den := gm * float(RECENT_W[2026])
		var any := false
		for h in p.get("history", []):
			var y := int(h[0])
			if RECENT_W.has(y) and y < 2026:
				num += float(h[1]) * float(h[2]) * float(RECENT_W[y])
				den += float(h[2]) * float(RECENT_W[y])
				any = true
		if not any or den <= 0.0:
			continue
		rows.append({"p": p, "view": num / den})
	var by_view := []
	for p in pool:
		by_view.append(p)
	var vmap := {}
	for r in rows:
		vmap[str(r["p"]["id"])] = float(r["view"])
	by_view.sort_custom(func(a, b): return float(vmap.get(str(a["id"]), a["overall"])) > float(vmap.get(str(b["id"]), b["overall"])))
	var vrank := {}
	for i in range(by_view.size()):
		vrank[str(by_view[i]["id"])] = i + 1
	rows.sort_custom(func(a, b): return float(a["view"]) - float(a["p"]["overall"]) > float(b["view"]) - float(b["p"]["overall"]))
	print("\nUNDER 14 GAMES IN 2026, WITH A RATED 2024 OR 2025: %d (incl. %d with no 2026 game)" % [rows.size(),
			rows.filter(func(r): return float(r["p"].get("gm", 0.0)) < 1.0).size()])
	print("  2026, 2025 and 2024 OVRs weighted by games x 1.0 / 0.75 / 0.5")
	print("  %-24s %-3s %3s %4s  %4s %5s  %5s %5s  %3s %5s" % ["player", "clb", "age", "gm26", "OVR", "rank",
			"view", "rank", "POT", "rehab"])
	var big := 0
	for r in rows:
		var p: Dictionary = r["p"]
		var d := float(r["view"]) - float(p["overall"])
		if d >= 8.0:
			big += 1
		if d < 5.0:
			continue
		var id := str(p["id"])
		print("  %-24s %-3s %3d %4d  %4d %5d  %5.0f %5d  %3d %5s" % [GameDB.player_display_name(p),
				str(p.get("club", "")), int(p.get("age", 0)), int(p.get("gm", 0)), int(p["overall"]),
				int(rank[id]), float(r["view"]), int(vrank[id]), int(p.get("potential", 0)),
				"yes" if bool(p.get("rehab", false)) else "-"])
	print("\n%d players read 8+ higher on the two-season view" % big)
