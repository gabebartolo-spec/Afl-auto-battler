extends RefCounted
## Match-day weather against the evidence (ARD-M4-016, measurement only).
## Drafted leagues, one home-and-away season each; every match is played four
## times on the same seed - a perfect day, wet, windy, hot - so each condition's
## change is paired. Per side-match: the box score, accuracy and the change
## against a perfect day, beside docs/research/WEATHER_EVIDENCE.md's targets.
## Env: WX_DRAFTS (default 21,22).

const STATS := ["score", "goals", "behinds", "disposals", "kicks", "handballs", "marks",
		"contested_marks", "tackles", "clangers", "intercepts", "inside50", "clearances",
		"one_percenters", "metres_gained"]
## The evidence's change against a dry day, where it names one (wet: ABC 2022-25).
const TARGET := {"wet": {"marks": -13.0, "tackles": 12.0, "clangers": 9.0, "one_percenters": 15.0,
		"score": -5.0}}


func run() -> void:
	var lb = load("res://tools/balance/league_balance.gd").new()
	var codes: Array = lb.clubs()
	var drafts := [21, 22]
	if OS.get_environment("WX_DRAFTS") != "":
		drafts = []
		for s in OS.get_environment("WX_DRAFTS").split(","):
			drafts.append(int(s))
	var sums := {}
	var n := 0
	# WX_HOME_PLAN: the home side plays this plan in every match, for the plan
	# by condition matrix (compare its home margins with a run without it).
	var plan := OS.get_environment("WX_HOME_PLAN")
	var margin := {}
	for c in Weather.CONDITIONS:
		sums[c] = {}
	for d in drafts:
		var lists: Dictionary = lb.drafted_lists(int(d))["lists"]
		var season := Season.new(codes, lists, int(d) * 7 + 1)
		for ri in range(season.fixture.size()):
			var mi := 0
			for m in season.fixture[ri]:
				mi += 1
				var match_seed := int(d) * 100000 + ri * 100 + mi
				for c in Weather.CONDITIONS:
					var sim := season.match_sim(str(m["home"]), str(m["away"]), match_seed,
							[true, false], false, c)
					if plan != "":
						sim.set_tactics(0, {"gameplan": plan})
					var res := sim.run()
					margin[c] = float(margin.get(c, 0.0)) + float(res["score"][0]) - float(res["score"][1])
					for side in range(2):
						var t: Dictionary = res["team"][side]
						var row: Dictionary = sums[c]
						for k in STATS:
							var v := float(res["score"][side]) if k == "score" else float(t.get(k, 0.0))
							row[k] = float(row.get(k, 0.0)) + v
				n += 2
	print("weather_impl: %d side-matches per condition (drafts %s)" % [n, str(drafts)])
	var base: Dictionary = sums["perfect"]
	var header := "%-16s" % "per side-match"
	for c in Weather.CONDITIONS:
		header += "%12s" % c
	print(header)
	for k in STATS:
		var line := "%-16s" % k
		for c in Weather.CONDITIONS:
			var v := float((sums[c] as Dictionary).get(k, 0.0)) / float(maxi(1, n))
			var b := float(base.get(k, 0.0)) / float(maxi(1, n))
			line += "%12s" % ("%.1f" % v if c == "perfect" else "%.1f %+.0f%%" % [v, (v / maxf(0.001, b) - 1.0) * 100.0])
		print(line)
	var acc := "%-16s" % "accuracy"
	for c in Weather.CONDITIONS:
		var g := float((sums[c] as Dictionary).get("goals", 0.0))
		var b2 := float((sums[c] as Dictionary).get("behinds", 0.0))
		acc += "%12s" % ("%.1f%%" % (100.0 * g / maxf(1.0, g + b2)))
	print(acc)
	var mg := "%-16s" % ("home margin" + ("" if plan == "" else " (" + plan + ")"))
	for c in Weather.CONDITIONS:
		mg += "%12s" % ("%+.2f" % (float(margin.get(c, 0.0)) / float(maxi(1, n / 2))))
	print(mg)
	print("evidence (wet vs dry): ", TARGET["wet"], "; accuracy -1 to -2 points; windy (20 km/h+) about -5 points a game combined.")
