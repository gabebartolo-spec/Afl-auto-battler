extends RefCounted
## Career-stage OVR economy (ROADMAP "Director follow-up - career-stage OVR
## economy", ARD-M5-010; BALANCE-GATED): measurement only, no tuning.
##  1. OVR/POT by career stage and role, real 2026 lists at the start of a
##     career: young (under 50 AFL games), established (24-28, 50+ games),
##     veteran (29+, 50+ games).
##  2. Draft classes by pick band: the real 2026 class and generated classes.
##  3. How often a new draftee outranks proven regulars before any development:
##     the share of established regulars (50+ games, 15+ games in 2026) of his
##     role rated below him, and per club, how many of the club's own
##     best-22 established players a top-10 pick would outrank.
##  4. Compression: does OVR follow demonstrated production among established
##     regulars (Spearman of OVR against a per-game production index), and
##     how wide is their OVR range compared with the draftees'.
## Env: OVR_YEARS (generated class years, default 2028..2032), OVR_SEED
## (career seed for the class tiers, default 4242).
## godot --headless --path . --script tools/audit/run_audit.gd -- ovr_economy_impl

const ROLES := ["MID", "FWD", "DEF", "RUCK"]
const BANDS := [[1, 5, "picks 1-5"], [6, 20, "picks 6-20"], [21, 40, "picks 21-40"], [41, 999, "picks 41+"]]


static func _env_ints(key: String, fallback: Array) -> Array:
	var v := OS.get_environment(key)
	if v == "":
		return fallback
	var out := []
	for part in v.split(","):
		out.append(int(part))
	return out


static func _career_games(p: Dictionary) -> int:
	var n := 0
	for h in p.get("history", []):
		if h is Array and (h as Array).size() >= 3:
			n += int(h[2])
	# The 2026 season itself, when the history stops at 2025.
	var last_year := 0
	for h in p.get("history", []):
		if h is Array and (h as Array).size() >= 1:
			last_year = maxi(last_year, int(h[0]))
	if last_year < 2026:
		n += int(float(p.get("gm", 0.0)))
	return n


static func _q(xs: Array, f: float) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[clampi(int(f * (s.size() - 1) + 0.5), 0, s.size() - 1)])


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / xs.size()


static func _ranks(xs: Array) -> Array:
	var idx := range(xs.size())
	idx.sort_custom(func(a, b): return xs[a] < xs[b])
	var r := []
	r.resize(xs.size())
	for k in range(idx.size()):
		r[idx[k]] = float(k)
	return r


static func _pearson(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 3:
		return 0.0
	var mx := _mean(xs)
	var my := _mean(ys)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(n):
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(1e-9, sxx * syy))


## Per-game production from the 2026 season line: what a coach sees.
static func _production(p: Dictionary) -> float:
	var gm := float(p.get("gm", 0.0))
	if gm <= 0.0:
		return 0.0
	var t := float(p.get("di", 0.0)) + 4.0 * float(p.get("gl", 0.0)) + 2.0 * float(p.get("mk", 0.0)) \
			+ 2.0 * float(p.get("tk", 0.0)) + float(p.get("ho", 0.0)) * 0.5 + 2.0 * float(p.get("cl", 0.0)) \
			+ 2.0 * float(p.get("if50", 0.0)) + 2.0 * float(p.get("rb", 0.0)) + float(p.get("cp", 0.0))
	return t / gm


static func _line(label: String, xs: Array) -> String:
	return "%-34s n %3d  OVR p10 %4.1f  p50 %4.1f  p90 %4.1f" % [label, xs.size(), _q(xs, 0.1), _q(xs, 0.5), _q(xs, 0.9)]


func run() -> void:
	var years := _env_ints("OVR_YEARS", [2028, 2029, 2030, 2031, 2032])
	var seed := int(OS.get_environment("OVR_SEED")) if OS.get_environment("OVR_SEED") != "" else 4242

	# --- 1. Career stages, real lists --------------------------------------
	var stage := {}        # "stage|role" -> [ovr]
	var stage_pot := {}    # "stage|role" -> [pot]
	var regulars := {}     # role -> [ovr] (established, 15+ games in 2026)
	var reg_players := []
	for p in GameDB.players:
		var role := str(p.get("role", ""))
		if not ROLES.has(role):
			continue
		var games := _career_games(p)
		var age := float(p.get("age", 0.0))
		var st := "young (<50 games)"
		if games >= 50:
			if age >= 29.0:
				st = "veteran (29+, 50+ games)"
			elif age >= 24.0:
				st = "established (24-28, 50+ games)"
			else:
				st = "early pro (<24, 50+ games)"
		for key in [st + "|" + role, st + "|ALL"]:
			if not stage.has(key):
				stage[key] = []
				stage_pot[key] = []
			stage[key].append(int(p.get("overall", 0)))
			stage_pot[key].append(int(p.get("potential", 0)))
		if games >= 50 and age >= 24.0 and float(p.get("gm", 0.0)) >= 15.0:
			if not regulars.has(role):
				regulars[role] = []
			regulars[role].append(int(p.get("overall", 0)))
			reg_players.append(p)
	print("## 1. Real lists at the start, OVR by career stage")
	for st in ["young (<50 games)", "early pro (<24, 50+ games)", "established (24-28, 50+ games)", "veteran (29+, 50+ games)"]:
		var all: Array = stage.get(st + "|ALL", [])
		print(_line(st, all) + "  POT p50 %4.1f" % _q(stage_pot.get(st + "|ALL", []), 0.5))
		for role in ROLES:
			print("  " + _line(role, stage.get(st + "|" + role, [])))

	# --- 2. Draft classes ---------------------------------------------------
	var classes := {"real 2026": GameDB.draftees.duplicate()}
	for y in years:
		classes["generated %d" % y] = Prospects.generate_class(y, seed)
	print("")
	print("## 2. Draft classes by pick band (draft_rank), OVR and POT p50")
	var band_ovr := {}   # band label -> [ovr] over the generated classes
	var top10 := []      # [player, class label]
	for label in classes:
		var cls: Array = classes[label]
		var parts := PackedStringArray()
		for b in BANDS:
			var o := []
			var pt := []
			for p in cls:
				var r := int(p.get("draft_rank", 999))
				if r >= int(b[0]) and r <= int(b[1]):
					o.append(int(p.get("overall", 0)))
					pt.append(int(p.get("potential", 0)))
					if str(label).begins_with("generated"):
						if not band_ovr.has(b[2]):
							band_ovr[b[2]] = []
						band_ovr[b[2]].append(int(p.get("overall", 0)))
			parts.append("%s %d/%d" % [b[2], int(_q(o, 0.5)), int(_q(pt, 0.5))])
		for p in cls:
			if int(p.get("draft_rank", 999)) <= 10:
				top10.append([p, label])
		print("%-15s %s" % [label, "  ".join(parts)])
	var ready := 0
	var top_n := 0
	var est_all: Array = stage.get("established (24-28, 50+ games)|ALL", [])
	var est_p50 := _q(est_all, 0.5)
	for e in top10:
		top_n += 1
		if int((e[0] as Dictionary).get("overall", 0)) >= est_p50:
			ready += 1
	print("top-10 picks rated at or above the median established player (%.0f): %d of %d" % [est_p50, ready, top_n])

	# --- 3. Outranking proven regulars --------------------------------------
	print("")
	print("## 3. A top-10 pick against established regulars of his role (before any development)")
	var shares := []
	var majority := 0
	for e in top10:
		var p: Dictionary = e[0]
		var regs: Array = regulars.get(str(p.get("role", "")), [])
		if regs.is_empty():
			continue
		var below := 0
		for o in regs:
			if int(o) < int(p.get("overall", 0)):
				below += 1
		var share := float(below) / regs.size()
		shares.append(share)
		if share >= 0.5:
			majority += 1
	print("share of same-role established regulars rated below a top-10 pick: mean %.0f%%, p90 %.0f%%; picks above half of them: %d of %d" % [
			100.0 * _mean(shares), 100.0 * _q(shares, 0.9), majority, shares.size()])
	# Per club: a top-10 pick dropped into each club's list - how many of that
	# club's best-22 established players is he rated above?
	var outrank := []
	for code in GameDB.clubs:
		var lst: Array = GameDB.club_list(str(code)).duplicate()
		lst.sort_custom(func(a, b): return int(a.get("overall", 0)) > int(b.get("overall", 0)))
		var best22 := lst.slice(0, 22).filter(func(q): return _career_games(q) >= 50 and float(q.get("age", 0.0)) >= 24.0)
		for e in top10:
			var n := 0
			for q in best22:
				if int((e[0] as Dictionary).get("overall", 0)) > int(q.get("overall", 0)):
					n += 1
			outrank.append(n)
	print("a top-10 pick is rated above this many of a club's best-22 established players: p50 %d, p90 %d (of about %d)" % [
			int(_q(outrank, 0.5)), int(_q(outrank, 0.9)), 14])

	# --- 4. Compression -----------------------------------------------------
	print("")
	print("## 4. Do established regulars' ratings follow their production?")
	for role in ROLES:
		var o := []
		var pr := []
		for p in reg_players:
			if str(p.get("role", "")) == role:
				o.append(float(p.get("overall", 0)))
				pr.append(_production(p))
		print("%-5s n %3d  OVR p10-p90 %4.1f-%4.1f  Spearman(OVR, production a game) %.2f" % [
				role, o.size(), _q(o, 0.1), _q(o, 0.9), _pearson(_ranks(o), _ranks(pr))])
	print("generated picks 1-5 OVR p10-p90 %.0f-%.0f, picks 6-20 %.0f-%.0f" % [
			_q(band_ovr.get("picks 1-5", []), 0.1), _q(band_ovr.get("picks 1-5", []), 0.9),
			_q(band_ovr.get("picks 6-20", []), 0.1), _q(band_ovr.get("picks 6-20", []), 0.9)])
