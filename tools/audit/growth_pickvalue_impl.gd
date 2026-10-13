extends RefCounted
## Side-effect probe for the draft-night scale: what a club thinks a draft pick is worth (TradeValue.pick_value)
## and the draftee's Draft-AI worth (0.35 OVR + 0.65 POT), per scale, averaged over generated classes.
##   PICKV|scale|pick|phase|value|draft_night_ovr|pot|worth
## godot --headless --path . --script tools/audit/run_audit.gd -- growth_pickvalue_impl 12 1,0.78,0.71,0.67

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var classes := int(args[1]) if args.size() > 1 else 12
	for sc in str(args[2]).split(","):
		Prospects.DRAFT_NIGHT_SCALE = float(sc)
		for pick in [1, 5, 10, 20, 30, 45]:
			for phase in ["rebuilding", "contending"]:
				var v := 0.0
				var ov := 0.0
				var pot := 0.0
				for c in range(classes):
					var ranked: Array = TradeValue.rank_prospects(Prospects.generate_class(2027 + c, 700 + c))
					v += TradeValue.pick_value([[pick, 1.0]], ranked, phase)
					ov += float(ranked[pick - 1]["overall"])
					pot += float(ranked[pick - 1]["potential"])
				v /= classes
				ov /= classes
				pot /= classes
				print("PICKV|%s|%d|%s|%.1f|%.1f|%.1f|%.1f" % [sc, pick, phase, v, ov, pot, ov * 0.35 + pot * 0.65])
