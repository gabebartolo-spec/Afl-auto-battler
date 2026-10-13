extends RefCounted
## Draft-night examples as the draft screen shows them (age, scouted OVR and POT ranges), by readiness, and
## the readiness mix of a class and of its top 10. Args: classes scale.
##   MIX|scale|share ready/typical/project of class|of top 10
##   EX|scale|label|pick|age|height|role|OVR range|POT range|(true OVR/POT)
## godot --headless --path . --script tools/audit/run_audit.gd -- growth_examples_impl 30 0.78

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var classes := int(args[1]) if args.size() > 1 else 30
	for sc in str(args[2]).split(","):
		Prospects.DRAFT_NIGHT_SCALE = float(sc)
		Prospects.DRAFT_READINESS = true
		var cnt := {"ready": 0, "typical": 0, "project": 0}
		var top := {"ready": 0, "typical": 0, "project": 0}
		var n := 0
		var ex := {"ready": [], "typical": [], "project": []}
		for c in range(classes):
			for p in Prospects.generate_class(2027 + c, 700 + c):
				var lab: String = str(p["readiness"])
				cnt[lab] += 1
				n += 1
				if int(p["draft_rank"]) <= 10:
					top[lab] += 1
					if c == 3 and ex[lab].size() < 3:
						ex[lab].append(p)
		print("MIX|%s|%.0f/%.0f/%.0f|%.0f/%.0f/%.0f" % [sc, 100.0 * cnt["ready"] / n, 100.0 * cnt["typical"] / n, 100.0 * cnt["project"] / n,
				10.0 * top["ready"] / classes, 10.0 * top["typical"] / classes, 10.0 * top["project"] / classes])
		for lab in ex:
			for p in ex[lab]:
				var pr := DraftScouting.projection(p, "MEL", 1)
				print("EX|%s|%s|%d|%d|%d cm|%s|%s-%s|%s-%s|(%d/%d)" % [sc, lab, int(p["draft_rank"]), int(float(p["age"])), int(p["height_cm"]),
						p["role"], pr["overall"][0], pr["overall"][1], pr["potential"][0], pr["potential"][1], int(p["overall"]), int(p["potential"])])
