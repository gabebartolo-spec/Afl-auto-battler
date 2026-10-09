extends RefCounted
## RPG-007: sets RecruitMeeting.SPLIT_GAP and checks how often the fit lines
## are true. For the opening National Draft class, read by every club under
## SEEDS draft seeds (args: seeds, default 40):
##   GAP   the share of tested prospects whose largest scouts-vs-Combine gap
##         (DraftScouting.combine_seen against Combine.measured, on movement,
##         repeat effort and aerial) reaches 10 to 30 points
##   STYLE per plan, the share of the class whose football is at least an
##         average AFL carrier's (RecruitMeeting.style_line)
## Measurement only.


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[1]) if args.size() > 1 else 40
	var pool: Array = GameDB.all_draftees_sorted()
	var bars := [10.0, 15.0, 16.0, 17.0, 18.0, 20.0, 25.0, 30.0]
	var hits := [0, 0, 0, 0, 0, 0, 0, 0]
	var n := 0
	for s in range(1, seeds + 1):
		for club in GameDB.active_clubs(2026):
			for p in pool:
				if not Combine.tested(p, s):
					continue
				var seen := DraftScouting.combine_seen(p, str(club), s)
				var gap := 0.0
				for k in seen:
					var m := Combine.measured(p, str(k), s)
					if m >= 0.0:
						gap = maxf(gap, absf(float(seen[k]) - m))
				n += 1
				for i in range(bars.size()):
					if gap >= float(bars[i]):
						hits[i] += 1
	var parts := []
	for i in range(bars.size()):
		parts.append("%d: %.1f%%" % [int(bars[i]), 100.0 * hits[i] / maxf(1.0, n)])
	print("GAP class %d prospects, %d reads | gap at least %s" % [pool.size(), n, ", ".join(parts)])
	for plan in RecruitMeeting.STYLE_WORD:
		var yes := 0
		for p in pool:
			if RecruitMeeting.style_line(p, str(plan)) != "":
				yes += 1
		print("STYLE %s: %d of %d prospects (%.1f%%)" % [plan, yes, pool.size(), 100.0 * yes / maxf(1.0, pool.size())])
