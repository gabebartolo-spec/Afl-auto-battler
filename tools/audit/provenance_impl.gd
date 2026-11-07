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
	_plausibility()


## Entry history of generated expansion players across many careers (the
## career seed salts each foundation list): how many read implausibly - a
## Talent League (under-age) season as the record of a man of 20 or more, or
## a ranking in the entry year's draft class past draft age (over 21).
func _plausibility() -> void:
	var n := 0
	var talent_old := 0
	var ranked_old := 0
	var seasoned := 0
	var example := ""
	for spec in [["TAS", 2028], ["CANB", 2030]]:
		for s in range(200):
			var salt := "" if s == 0 else "%04d" % s
			for p in Prospects.generate_expansion_list(str(spec[0]), int(spec[1]), 36, salt):
				n += 1
				var age := float(p["age"])
				if age > Potential.MAX_PROSPECT_AGE:
					seasoned += 1
				var bad := false
				if age >= 20.0 and str(p.get("draft_league", "")) == "Talent League":
					talent_old += 1
					bad = true
				if age > Potential.MAX_PROSPECT_AGE and int(p.get("draft_rank", 0)) > 0:
					ranked_old += 1
					bad = true
				if bad and example == "":
					example = "%s age %.0f: %s / %s" % [p["id"], age, PlayerProfile.pedigree(p),
							str(PlayerProfile.production(p)["title"])]
	print("PLAUSIBILITY players=%d over21=%d talent_league_at_20plus=%d ranked_in_class_over21=%d" % [
			n, seasoned, talent_old, ranked_old])
	print("   e.g. ", example)
