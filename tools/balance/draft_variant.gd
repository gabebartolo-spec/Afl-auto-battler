extends Draft
## Experimental career-draft models, for measurement only.
##
## A subclass of the shipped Draft: with the default model every pick is
## exactly the shipped draft's (the smoke suite pins this). Each model knob
## switches off or alters ONE draft mechanism so its share of the league's
## compression can be measured. Nothing here is used by the game.
##
## Model keys (all optional; omitted = the shipped behaviour):
##   order        "snake" (shipped) | "linear" (same order every round) |
##                "random_round" (a fresh seeded shuffle every round)
##   score        "current" (shipped: worth over replacement x need - cap
##                penalty) | "bpa" (best player available: perceived worth
##                only, minus the cap penalty if it is on)
##   need_scale   1.0 shipped. Need weights are pulled toward 1 by
##                w' = 1 - need_scale * (1 - w): 0 ignores list needs.
##   vorp_scale   1.0 shipped. Multiplies AI_VORP_WEIGHT (the replacement term).
##   cap_penalty  true shipped. false drops the soft cap mark-down.
##   budget_mult  1.0 shipped. Multiplies every club's hard cap (10 = no cap).
##   noise_sd     0 shipped. Every club misjudges every player by a fixed,
##                seeded Gaussian error (rating points) on the worth it uses.
##   noise_sd_max 0 shipped. Club drafting competence: each club gets its own
##                error SD, drawn uniformly from [0, noise_sd_max]. Replaces
##                noise_sd when set.
##   eval_sd      [lo, hi]: the range of the shipped club-specific evaluation
##                (Draft.club_eval_sd). Omitted in a non-empty model means
##                [0, 0], i.e. the draft as it was before that evaluation
##                shipped, so the draft-compression experiment
##                (docs/DRAFT_COMPRESSION.md) still reproduces. An empty model
##                is exactly the shipped draft.
## The two-ruck rule (_forced_role) and the hard budget check always apply.

var model := {}
var club_noise_sd := {}          # code -> this club's valuation error SD
var _noise := {}                 # code -> {player id -> error}


func configure(p_model: Dictionary) -> void:
	model = p_model.duplicate()
	var order := str(model.get("order", "snake"))
	if order != "snake":
		_rebuild_sequence(order)
	budget = int(round(float(budget) * float(model.get("budget_mult", 1.0))))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7717 + 13
	var sd_max := float(model.get("noise_sd_max", 0.0))
	for code in clubs:
		club_noise_sd[code] = rng.randf_range(0.0, sd_max) if sd_max > 0.0 \
				else float(model.get("noise_sd", 0.0))
	for code in clubs:
		var sd := float(club_noise_sd[code])
		var errs := {}
		if sd > 0.0:
			var r := RandomNumberGenerator.new()
			r.seed = hash("%d|%s" % [seed, code])
			for p in pool:
				errs[str(p["id"])] = r.randfn(0.0, sd)
		_noise[code] = errs


func _rebuild_sequence(order: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 104729 + 3
	pick_sequence = []
	for r in range(target_size):
		var round_order := draft_order.duplicate()
		if order == "random_round" and r > 0:
			for i in range(round_order.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = round_order[i]
				round_order[i] = round_order[j]
				round_order[j] = tmp
		for code in round_order:
			pick_sequence.append(code)
	if pick_sequence.size() > pool.size():
		pick_sequence.resize(pool.size())
	pick_index = 0


func _eval_sd_range() -> Array:
	if model.is_empty():
		return super()
	return model.get("eval_sd", [0.0, 0.0])


func _perceived(code: String, p: Dictionary) -> float:
	return _worth(p) + _eval_error(code, p) + float((_noise.get(code, {}) as Dictionary).get(str(p["id"]), 0.0))


func _ai_score(code: String, p: Dictionary) -> float:
	if model.is_empty():
		return super(code, p)
	_refresh_ai_cache()
	var penalty := _cap_penalty(code, p) if bool(model.get("cap_penalty", true)) else 0.0
	var worth := _perceived(code, p)
	if str(model.get("score", "current")) == "bpa":
		return worth - penalty
	var vorp_w := AI_VORP_WEIGHT * float(model.get("vorp_scale", 1.0))
	var best := -INF
	var roles := [[str(p["role"]), 1.0]]
	var role2 := str(p.get("role2", ""))
	if role2 != "" and role2 != str(p["role"]):
		roles.append([role2, 0.85])
	for entry in roles:
		var role: String = entry[0]
		var need := _need_weight(code, role)
		var over := minf(AI_VORP_CAP, worth - _replacement(code, role))
		var s := (worth + vorp_w * over) * need * float(entry[1])
		best = maxf(best, s)
	return best - penalty


func _need_weight(code: String, role: String) -> float:
	var w := super(code, role)
	var k := float(model.get("need_scale", 1.0))
	return 1.0 - k * (1.0 - w)
