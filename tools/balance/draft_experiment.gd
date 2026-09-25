extends SceneTree
## Draft-compression experiment runner. Measurement only: see
## docs/DRAFT_COMPRESSION.md. Every variant drafts with
## tools/balance/draft_variant.gd (or the shipped Draft for "current") and
## plays through the unchanged Season -> MatchSim.
##
## Draft only (cheap: list shape and preseason strength of every club):
##   godot --headless --path . --script tools/balance/draft_experiment.gd -- \
##       --mode draft --variant need0 --policy ai --leagues 1,2,3 --out d.json
## Seasons (each league's lists replayed for --seasons seeds):
##   ... --mode season --variant need0 --policy ai --leagues 1,2 --seasons 6 --out s.json
## --variant real uses the real 2026 lists (no draft).
## Seeds: draft seed L; season s (0-based) of league L uses L * 1000 + s + 1.
## Aggregate with tools/balance/draft_experiment_report.py.

## One mechanism changed per variant (keys: tools/balance/draft_variant.gd).
## Every variant but "current" leaves out the shipped club-specific
## evaluation (eval_sd [0, 0]) unless it names one, so the documented
## experiment reproduces; "current" is the draft as shipped today.
const VARIANTS := {
	"current": {},
	# The draft before club-specific evaluation shipped, and calibration
	# candidates for its range (docs/DRAFT_EVALUATION.md)
	"eval_off": {"eval_sd": [0.0, 0.0]},
	# First round: the opinion applied in full, whatever the need.
	"eval_05_3": {"eval_sd": [0.5, 3.0], "eval_by_need": false},
	"eval_1_4": {"eval_sd": [1.0, 4.0], "eval_by_need": false},
	"eval_1_5": {"eval_sd": [1.0, 5.0], "eval_by_need": false},
	"eval_15_6": {"eval_sd": [1.5, 6.0], "eval_by_need": false},
	# Second round (shipped shape): the opinion weighted by list need.
	"evn_1_5": {"eval_sd": [1.0, 5.0]},
	"evn_15_6": {"eval_sd": [1.5, 6.0]},
	"evn_2_7": {"eval_sd": [2.0, 7.0]},
	"evn_25_8": {"eval_sd": [2.5, 8.0]},
	# Draft order, shipped AI
	"linear": {"order": "linear"},
	"random_round": {"order": "random_round"},
	# AI scoring, snake order
	"need50": {"need_scale": 0.5},
	"need0": {"need_scale": 0.0},
	"vorp0": {"vorp_scale": 0.0},
	"capsoft_off": {"cap_penalty": false},
	"cap_off": {"cap_penalty": false, "budget_mult": 10.0},
	"bpa": {"score": "bpa"},
	"bpa_cap_off": {"score": "bpa", "cap_penalty": false, "budget_mult": 10.0},
	"bpa_cap_off_linear": {"score": "bpa", "cap_penalty": false, "budget_mult": 10.0, "order": "linear"},
	# Valuation noise (every club equally fallible), snake order
	"noise2": {"noise_sd": 2.0},
	"noise4": {"noise_sd": 4.0},
	"noise8": {"noise_sd": 8.0},
	# Club drafting competence: each club's error SD drawn from [0, max]
	"comp4": {"noise_sd_max": 4.0},
	"comp8": {"noise_sd_max": 8.0},
	"comp12": {"noise_sd_max": 12.0},
	# Combinations (list construction still shipped-shaped)
	"comp8_need50": {"noise_sd_max": 8.0, "need_scale": 0.5},
	"comp8_linear": {"noise_sd_max": 8.0, "order": "linear"},
}

var LB
var _t0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var k := str(a[i])
		if k.begins_with("--"):
			var v := ""
			if i + 1 < a.size() and not str(a[i + 1]).begins_with("--"):
				v = str(a[i + 1])
				i += 1
			out[k.substr(2)] = v
		i += 1
	return out


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	LB = load("res://tools/balance/league_balance.gd").new()
	var gs = root.get_node("GameState")
	gs.autosave_enabled = false
	gs.save_path = "user://balance_probe.save"
	gs.settings_path = "user://balance_probe.cfg"
	gs.set_new_career_difficulty("normal")
	var args := _args()
	var variant := str(args.get("variant", "current"))
	if variant != "real" and not VARIANTS.has(variant):
		push_error("unknown variant %s" % variant)
		quit(1)
		return
	var mode := str(args.get("mode", "draft"))
	var policy := str(args.get("policy", "ai"))
	var top_n := int(args.get("top-n", "5"))
	var seasons := int(args.get("seasons", "1"))
	var leagues := []
	for x in str(args.get("leagues", "1")).split(",", false):
		leagues.append(int(x))
	var codes: Array = LB.clubs()
	var out := {"variant": variant, "policy": policy, "mode": mode,
			"model": VARIANTS.get(variant, {}), "leagues": [], "seasons": [],
			"args": str(OS.get_cmdline_user_args())}
	for L in leagues:
		var lists: Dictionary
		var sig := "real"
		var user := ""
		var noise_sd := {}
		var picks := []
		var undrafted := []
		if variant == "real":
			lists = LB.real_lists()
		else:
			var d = LB.make_draft(int(L), policy, top_n, VARIANTS[variant])
			lists = d.all_lists()
			sig = str(LB.league_signature(lists))
			user = str(d.user_club)
			if "club_noise_sd" in d:
				noise_sd = d.club_noise_sd
			# Draft quality: every pick against the shared (consensus) ranking
			# of the pool by worth, and each club's evaluation SD.
			var ranked: Array = d.pool.duplicate()
			ranked.sort_custom(func(a, b): return d._worth(a) > d._worth(b))
			var rank_of := {}
			for i in range(ranked.size()):
				rank_of[str(ranked[i]["id"])] = i + 1
				if not d.picked.has(str(ranked[i]["id"])):
					undrafted.append(i + 1)
			for e in d.pick_history:
				picks.append([int(e["pick"]), str(e["club"]), str(e["player_id"]), str(e["role"]),
						int(e["overall"]), int(rank_of[str(e["player_id"])])])
			if d.has_method("club_eval_sd"):
				for c in codes:
					noise_sd[str(c)] = d.club_eval_sd(str(c)) if str(c) != user else 0.0
		var units: Dictionary = LB.club_units(lists, codes)
		var league := {"league": str(L), "sig": sig, "user_club": user,
				"noise_sd": noise_sd, "units": units, "picks": picks, "undrafted": undrafted}
		out["leagues"].append(league)
		print("%s league %d drafted (%ds)" % [variant, L, _secs()])
		if mode != "season":
			continue
		for s in range(seasons):
			var seed := int(L) * 1000 + s + 1
			out["seasons"].append(LB.play_engine_season(lists, seed,
					{"variant": variant, "policy": policy, "league": str(L),
					"season_seed": seed, "sig": sig, "user_club": user}))
			print("%s league %d season %d done (%ds)" % [variant, L, s, _secs()])
	out["runtime_s"] = _secs()
	var path := str(args.get("out", "user://draft_experiment_%s.json" % variant))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote %s in %ds" % [path, _secs()])
	quit(0)


func _secs() -> int:
	return int((Time.get_ticks_msec() - _t0) / 1000)
