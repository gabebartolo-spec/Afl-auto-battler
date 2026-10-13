extends RefCounted
## Fast tuning probe (no careers): generated classes aged forward with Prospects.age_player only (no training,
## no re-anchoring), mean OVR by draft range at k seasons after the draft. For choosing arms before the full
## growth_curve_impl runs. Args: classes (count) arms (comma list of night:step:gap).
##   TUNE|arm|range|k|n|mean
## godot --headless --path . --script tools/audit/run_audit.gd -- growth_tune_impl 12 1:0.7:0.7,0.86:1:1

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var classes := int(args[1]) if args.size() > 1 else 12
	var arms := str(args[2]).split(",") if args.size() > 2 else PackedStringArray(["1:0.7:0.7"])
	for arm in arms:
		var sp := arm.split(":")
		Prospects.DRAFT_NIGHT_SCALE = float(sp[0])
		Potential.YOUTH_STEP_PACE = float(sp[1])
		Potential.YOUTH_GAP_PACE = float(sp[2])
		var acc := {}
		for c in range(classes):
			var cls: Array = Prospects.generate_class(2027 + c, 700 + c)
			for p in cls:
				var r := int(p["draft_rank"])
				var band := "1-10" if r <= 10 else ("11-30" if r <= 30 else "31+")
				var q: Dictionary = p.duplicate(true)
				for k in range(0, 6):
					var key := "%s|%d" % [band, k]
					if not acc.has(key):
						acc[key] = [0, 0.0]
					acc[key][0] += 1
					acc[key][1] += float(q["overall"])
					Prospects.age_player(q, 2028 + c + k)
		for band in ["1-10", "11-30", "31+"]:
			var row := "TUNE|%s|%s" % [arm, band]
			for k in range(0, 6):
				var v: Array = acc["%s|%d" % [band, k]]
				row += "|%.1f" % (v[1] / v[0])
			print(row)
