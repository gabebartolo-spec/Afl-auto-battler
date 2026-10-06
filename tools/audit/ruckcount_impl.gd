extends "res://tools/audit/career_impl.gd"
## Ruck supply across a long career: after every season, the fewest players
## listed as RUCK at any club and how many clubs have fewer than two (every
## list needs two). Plays an autopilot career exactly as career_impl does, so
## the same args apply: policy seed club seasons (e.g. `ai 1 MEL 16`). Compare
## the same seeds on two branches.

func _ledger_update() -> void:
	super._ledger_update()
	var fewest := 999
	var under := 0
	var total := 0
	for code in GameState.season.lists:
		var n := 0
		for p in GameState.season.lists[code]:
			if str(p.get("role", "")) == "RUCK":
				n += 1
		fewest = mini(fewest, n)
		total += n
		if n < 2:
			under += 1
	print("RUCKS seed %d %d | fewest at any club %d | clubs under two %d | league total %d | free agent rucks %d" % [
		seed_n, GameState.season_year, fewest, under, total, _free_agent_rucks()])

func _free_agent_rucks() -> int:
	var n := 0
	for p in GameState.free_agents:
		if str(p.get("role", "")) == "RUCK":
			n += 1
	return n
