class_name TrainingReport
extends RefCounted
## The monthly training report (director, 2026-10-14: "A report every 4
## rounds"). Behind Features "training_report". After rounds 4, 8, 12 and so
## on it says who improved most, with the stats that rose and by how much,
## who went backwards, how the reserves did, and who can learn a new position.
## It reads ratings only; nothing here touches the sim.
##
## gs.training_block   the ratings when the block began:
##     {"year", "from" (first round), "players": {id: {"ovr", "attr", "jobs"}},
##      "res": {id: reserves XP}}
## gs.training_report  the latest report built:
##     {"year", "from", "to", "label", "risers", "fallers", "reserves",
##      "new_retrain", "dismissed"}

const BLOCK := 4
const MAX_RISERS := 8
const MAX_FALLERS := 5
const MAX_STATS := 4


static func before_game(gs) -> void:
	if gs.season == null or gs.my_list.is_empty():
		return
	var b: Dictionary = gs.training_block
	if not b.is_empty() and int(b.get("year", -1)) == gs.season_year:
		return
	var players := {}
	for p in gs.my_list:
		players[str(p["id"])] = _snap(gs, p)
	gs.training_block = {"year": gs.season_year, "from": gs.season.round_index,
			"players": players, "res": {}}


static func _snap(gs, p: Dictionary) -> Dictionary:
	var attr := {}
	for row in GameState.TRAIN_STATS:
		attr[str(row[0])] = int(round(float((p.get("attr", {}) as Dictionary).get(str(row[0]), 0))))
	return {"ovr": int(p.get("overall", 0)), "attr": attr, "jobs": gs.open_jobs(p)}


static func after_game(gs) -> void:
	var b: Dictionary = gs.training_block
	if b.is_empty() or gs.season == null:
		return
	for row in gs.last_training_report.get("rows", []):
		if bool(row.get("reserves", false)):
			var id := str(row.get("id", ""))
			(b["res"] as Dictionary)[id] = int((b["res"] as Dictionary).get(id, 0)) + int(row.get("xp", 0))
	var done: int = gs.season.round_index
	if gs.last_phase != "regular" or done <= 0 or done % BLOCK != 0:
		return
	if int(gs.training_report.get("year", -1)) == gs.season_year and int(gs.training_report.get("to", 0)) == done:
		return
	gs.training_report = build(gs, b, done)
	gs.training_block = {}


## "Rounds 1-4".
static func label(from: int, to: int) -> String:
	return "Round %d" % to if from >= to else "Rounds %d-%d" % [from, to]


## The report for a block ending after round `to`.
static func build(gs, b: Dictionary, to: int) -> Dictionary:
	var risers := []
	var fallers := []
	var new_retrain := []
	var players: Dictionary = b.get("players", {})
	for p in gs.my_list:
		var id := str(p["id"])
		if not players.has(id):
			continue
		var was: Dictionary = players[id]
		var rose := []
		var fell := []
		var up := 0
		for row in GameState.TRAIN_STATS:
			var k := str(row[0])
			var before := int((was["attr"] as Dictionary).get(k, 0))
			var after := int(round(float((p.get("attr", {}) as Dictionary).get(k, 0))))
			if after > before:
				rose.append([str(row[1]), before, after])
				up += after - before
			elif after < before:
				fell.append([str(row[1]), before, after])
		var ovr0 := int(was.get("ovr", 0))
		var ovr1 := int(p.get("overall", 0))
		rose.sort_custom(func(a, c): return (int(a[2]) - int(a[1])) > (int(c[2]) - int(c[1])))
		if not rose.is_empty():
			risers.append({"id": id, "ovr0": ovr0, "ovr1": ovr1, "points": up,
					"stats": rose.slice(0, MAX_STATS)})
		if not fell.is_empty() or ovr1 < ovr0:
			fallers.append({"id": id, "ovr0": ovr0, "ovr1": ovr1, "stats": fell.slice(0, MAX_STATS)})
		if (was.get("jobs", []) as Array).is_empty() and not gs.open_jobs(p).is_empty():
			new_retrain.append(id)
	risers.sort_custom(func(a, c):
		if int(a["ovr1"]) - int(a["ovr0"]) != int(c["ovr1"]) - int(c["ovr0"]):
			return int(a["ovr1"]) - int(a["ovr0"]) > int(c["ovr1"]) - int(c["ovr0"])
		return int(a["points"]) > int(c["points"]))
	var res: Dictionary = b.get("res", {})
	var total := 0
	for id in res:
		total += int(res[id])
	var res_row := {}
	if not res.is_empty() and total > 0:
		res_row = {"count": res.size(), "each": int(round(float(total) / float(res.size())))}
	return {"year": gs.season_year, "from": int(b.get("from", 1)), "to": to,
			"label": label(int(b.get("from", 1)), to),
			"risers": risers.slice(0, MAX_RISERS), "fallers": fallers.slice(0, MAX_FALLERS),
			"reserves": res_row, "new_retrain": new_retrain, "dismissed": false}


## Is there a report to show (the switch is on and one has been built)?
static func current(gs) -> Dictionary:
	if not Features.on("training_report"):
		return {}
	return gs.training_report


## The hub card shows until it is dismissed.
static func hub_due(gs) -> bool:
	var r := current(gs)
	return not r.is_empty() and not bool(r.get("dismissed", false))


static func dismiss(gs) -> void:
	if not gs.training_report.is_empty():
		gs.training_report["dismissed"] = true
		gs.mark_dirty()


## "Rounds 1 to 4" for the one-line link.
static func link_text(r: Dictionary) -> String:
	return "Training report, " + str(r.get("label", "")).replace("-", " to ").to_lower() + "  ›"


## Who can learn a new position now, by the rule the Training menu uses
## (GameState.learnable_jobs; the club's two-project limit aside, which only
## decides whether the menu offers it today). Those who became available this
## month come first. [{"id", "jobs": ["key forward"], "new": bool}]
static func retrain_list(gs, r: Dictionary) -> Dictionary:
	var fresh: Array = r.get("new_retrain", [])
	var out := []
	for p in gs.my_list:
		var jobs: Array = gs.open_jobs(p)
		if jobs.is_empty():
			continue
		var words := []
		for j in jobs:
			words.append(str(GameState.LEARN_JOBS[j]["word"]))
		out.append({"id": str(p["id"]), "jobs": words, "new": fresh.has(str(p["id"])),
				"pot": int(p.get("potential", 0))})
	out.sort_custom(func(a, c):
		if bool(a["new"]) != bool(c["new"]):
			return bool(a["new"])
		return int(a["pot"]) > int(c["pot"]))
	return {"entries": out, "full": gs.active_projects() >= GameState.PROJECT_MAX}
