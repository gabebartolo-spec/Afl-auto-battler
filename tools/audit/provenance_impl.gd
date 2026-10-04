extends RefCounted

func _band(age: float) -> String:
	if age < 22.0: return "18-21"
	if age < 27.0: return "22-26"
	return "27-30"

func _summ(label: String, list: Array) -> void:
	var bands := {}
	for p in list:
		var b := _band(float(p.get("age", 18.0)))
		if not bands.has(b):
			bands[b] = {"n": 0, "ovr": 0.0, "pot": 0.0, "gap": 0.0, "pot85": 0, "maxpot": 0}
		var r: Dictionary = bands[b]
		var pot := int(p.get("potential", p["overall"]))
		r["n"] += 1
		r["ovr"] += float(p["overall"])
		r["pot"] += float(pot)
		r["gap"] += float(pot - int(p["overall"]))
		if pot >= 85: r["pot85"] += 1
		r["maxpot"] = maxi(int(r["maxpot"]), pot)
	for b in ["18-21", "22-26", "27-30"]:
		if bands.has(b):
			var r: Dictionary = bands[b]
			print("%s age %s: n=%d meanOVR=%.1f meanPOT=%.1f meanHeadroom=%.1f POT85+=%d maxPOT=%d" % [label, b, r["n"],
				r["ovr"] / r["n"], r["pot"] / r["n"], r["gap"] / r["n"], r["pot85"], r["maxpot"]])

func run() -> void:
	var db = GameDB
	# Real AFL players by age, for reference: what a 27-30 year old's POT looks like.
	_summ("REAL-2026", db.players)
	for spec in [["TAS", 2028], ["CANB", 2030]]:
		var lst: Array = Prospects.generate_expansion_list(str(spec[0]), int(spec[1]))
		for p in lst:
			Potential.assign(p)
		_summ("EXPANSION %s %d" % spec, lst)
		var worst := []
		for p in lst:
			if float(p["age"]) >= 26.0:
				worst.append("%s age %.0f OVR %d POT %d rank %d draft_year %d hist=%s" % [db.player_display_name(p),
					float(p["age"]), int(p["overall"]), int(p.get("potential", 0)), int(p["draft_rank"]),
					int(p["draft_year"]), str(p.get("history", p.get("career", "none")))])
		for w in worst.slice(0, 6):
			print("   ", w)
	var cls: Array = []
	for y in [2027, 2028, 2029]:
		var c: Array = Prospects.generate_class(y, 12345)
		for p in c:
			Potential.assign(p)
		cls.append_array(c)
	_summ("DRAFT CLASSES 27-29", cls)
