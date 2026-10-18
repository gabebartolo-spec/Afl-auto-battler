class_name StoryEngine
extends RefCounted
## Picks the week's story cards and keeps the story's memory: what came up and
## when, the flags choices set, and the arcs those flags start. Pure rules over
## the facts GameState hands in; GameState applies the effects.
##
## The week: a due arc beat comes first (it does not wait for a busy week),
## then, in about seven weeks of ten, a new arc start or else a one-off. A big
## week (round 1, the last home-and-away round, each finals week) may bring a
## second card from another category, about a different player.
##
## Nothing repeats too soon: each card has its own cooldown, each player one
## too (no player on two cards within his card's subject cooldown), and no
## category comes up more than twice in five weeks.
##
## Arcs: a choice can set a flag on its player or on the club, stamped with
## the week. A follow-up card names the flag and a window ("after" weeks, up to
## "within"), plus live conditions, so which beat comes depends on what has
## happened since. An end beat closes the arc; an arc nobody returns to before
## its window shuts closes as lapsed. Either way it never starts again for him.
##
## Randomness: a story stream of its own, seeded from the save seed, the year
## and the week, so drawing cards never moves the match dice or the draft.

const EVENT_CHANCE := 0.7
## A big week's second card comes this often.
const SECOND_CHANCE := 0.5
const DIVERSITY_WEEKS := 5
const DIVERSITY_MAX := 2
## Weeks counted per season, finals included (24 rounds and up to 5 finals
## weeks fit inside), so a cooldown runs on across seasons.
const SEASON_WEEKS := 30
const NEVER := -99999
const TIERS := ["beat", "start", "one_off"]
## A result line may name players from a ranked list: {best3}, {worst2}.
const RANKED_TOKEN := "\\{(best|worst)([1-9])\\}"


static func week_abs(year: int, week: int) -> int:
	return (year - 2000) * SEASON_WEEKS + week


static func new_state() -> Dictionary:
	return {"flags": {}, "last": {}, "subj": {}, "cats": [], "seen": {}, "season": {}, "arcs": {}}


## An older save, or a partial one: every key present.
static func ensure(story: Dictionary) -> Dictionary:
	var fresh := new_state()
	for k in fresh:
		if not story.has(k) or typeof(story[k]) != typeof(fresh[k]):
			story[k] = fresh[k]
	return story


## A new season: the per-season counts start again; cooldowns and arcs run on.
static func new_season(story: Dictionary) -> void:
	ensure(story)
	story["season"] = {}


## The week's cards (0, 1 or 2). `ctx`: seed, year, week (1.. in season),
## phase ("regular" or "finals"), big (bool), club (club facts), players
## (one fact dict per player of yours, with "id"). Records what it picks.
static func pick_week(deck: Array, ctx: Dictionary, story: Dictionary) -> Array:
	ensure(story)
	var w := week_abs(int(ctx.get("year", 2000)), int(ctx.get("week", 0)))
	lapse_arcs(story, w)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("story|%d|%d|%d" % [int(ctx.get("seed", 0)), int(ctx.get("year", 0)), int(ctx.get("week", 0))])
	# September always has something to say (finals weeks); the rest of the year is as quiet as it was.
	var quiet := rng.randf() >= EVENT_CHANCE and str(ctx.get("phase", "regular")) != "finals"
	var out := []
	var first := _pick_one(deck, ctx, story, rng, w, quiet, "", "")
	if first.is_empty():
		return out
	out.append(first)
	_record_pick(story, first, w)
	var second_chance := 1.0 if int((ctx.get("club", {}) as Dictionary).get("finals_week", 0)) == 5 else SECOND_CHANCE
	if bool(ctx.get("big", false)) and rng.randf() < second_chance:
		var second := _pick_one(deck, ctx, story, rng, w, false, str(first["category"]), str(first.get("player_id", "")))
		if not second.is_empty():
			out.append(second)
			_record_pick(story, second, w)
	return out


static func _pick_one(deck: Array, ctx: Dictionary, story: Dictionary, rng: RandomNumberGenerator, w: int,
		quiet: bool, skip_cat: String, skip_pid: String) -> Dictionary:
	var tiers := {"beat": [], "start": [], "one_off": []}
	for t in deck:
		if str(t["category"]) == skip_cat:
			continue
		var subj := eligible_subject(t, ctx, story, w, rng, skip_pid)
		if subj.is_empty():
			continue
		tiers[tier(t)].append([t, subj])
	# A priority card (the Grand Final week's, a week off's) comes before the older ones.
	for name in TIERS:
		var first: Array = (tiers[name] as Array).filter(func(c): return bool(c[0].get("priority", false)))
		if not first.is_empty():
			tiers[name] = first
	for name in TIERS:
		if name != "beat" and quiet:
			break
		var pool: Array = tiers[name]
		if pool.is_empty():
			continue
		var total := 0
		for c in pool:
			total += maxi(1, int(c[0].get("weight", 1)))
		var roll := rng.randi_range(1, total)
		for c in pool:
			roll -= maxi(1, int(c[0].get("weight", 1)))
			if roll <= 0:
				return build(deck, c[0], c[1], ctx.get("club", {}), rng, w)
	return {}


static func tier(t: Dictionary) -> String:
	if not (t.get("needs", {}) as Dictionary).is_empty():
		return "beat"
	if str(t.get("arc", "")) != "":
		return "start"
	return "one_off"


## Who the card would be about this week, or {} when it cannot come up:
## {"kind": "club"} or the chosen player's facts.
static func eligible_subject(t: Dictionary, ctx: Dictionary, story: Dictionary, w: int,
		rng: RandomNumberGenerator, skip_pid := "") -> Dictionary:
	var id := str(t["id"])
	if bool(t.get("scripted", false)):
		return {}   # dealt by the game itself (the result of a role trial), never drawn
	if not (t.get("phase", ["regular"]) as Array).has(str(ctx.get("phase", "regular"))):
		return {}
	# A week off in the finals: only the cards written for it.
	if bool((ctx.get("club", {}) as Dictionary).get("finals_bye", false)) and not bool(t.get("bye", false)):
		return {}
	if w - int(story["last"].get(id, NEVER)) < int(t.get("cooldown", 0)):
		return {}
	var per := int(t.get("per_season", 0))
	if per > 0 and int(story["season"].get(id, 0)) >= per:
		return {}
	# A priority card (September's) is not held back by the mix of the last five weeks.
	if category_count(story, str(t["category"]), w) >= DIVERSITY_MAX and not bool(t.get("priority", false)):
		return {}
	var club: Dictionary = ctx.get("club", {})
	if not meets(club, t.get("when", {}), story["flags"].get("club", {})):
		return {}
	var subject: Dictionary = t.get("subject", {})
	if str(subject.get("kind", "club")) != "player":
		if not _arc_open_ok(t, story, "club", w):
			return {}
		return {"kind": "club"}
	var fits := []
	for p in ctx.get("players", []):
		var pid := str(p["id"])
		if pid == skip_pid:
			continue
		if w - int(story["subj"].get(pid, NEVER)) < int(t.get("subject_cooldown", 0)):
			continue
		if not meets(p, subject.get("where", {}), story["flags"].get(pid, {})):
			continue
		# A card that invents a private life, health of mind or misconduct is
		# never about a player shown under his real name (director, 2026-10-11).
		if bool(t.get("private", false)) and bool(p.get("real_named", false)):
			continue
		if not _arc_open_ok(t, story, pid, w):
			continue
		fits.append(p)
	return choose(fits, str(subject.get("pick", "random")), rng)


## Arc rules for one subject: a follow-up needs his flag inside its window and
## his arc still open; a start needs no earlier run of that arc for him.
static func _arc_open_ok(t: Dictionary, story: Dictionary, who: String, w: int) -> bool:
	var arc := str(t.get("arc", ""))
	var needs: Dictionary = t.get("needs", {})
	if not needs.is_empty():
		var set_at := int((story["flags"].get(who, {}) as Dictionary).get(str(needs.get("flag", "")), NEVER))
		if set_at == NEVER:
			return false
		var since := w - set_at
		if since < int(needs.get("after", 1)) or since > int(needs.get("within", 30)):
			return false
		if arc != "":
			return str((story["arcs"].get(arc + "|" + who, {}) as Dictionary).get("state", "")) == "open"
		return true
	if arc != "":
		return not story["arcs"].has(arc + "|" + who)
	return true


## Do these facts meet the conditions? `x_min`, `x_max`, `x_every` (a positive
## multiple), plain equality, and flag / no_flag against the holder's flags.
static func meets(facts: Dictionary, cond: Dictionary, flags: Dictionary) -> bool:
	for k in cond:
		var key := str(k)
		var v = cond[k]
		if key == "flag":
			if not flags.has(str(v)):
				return false
		elif key == "no_flag":
			if flags.has(str(v)):
				return false
		elif key.ends_with("_min"):
			if float(facts.get(key.trim_suffix("_min"), -INF)) < float(v):
				return false
		elif key.ends_with("_max"):
			if float(facts.get(key.trim_suffix("_max"), INF)) > float(v):
				return false
		elif key.ends_with("_every"):
			var n := int(facts.get(key.trim_suffix("_every"), 0))
			if n <= 0 or n % maxi(1, int(v)) != 0:
				return false
		else:
			# A number in a card (JSON reads 5 as 5.0) equals the same number in a fact.
			var have = facts.get(key, "")
			if (v is float or v is int) and (have is float or have is int):
				if float(have) != float(v):
					return false
			elif str(have) != str(v):
				return false
	return true


## The card's player among those who fit: "random", "highest:<fact>",
## "lowest:<fact>" or "random_top:<n>:<fact>" (one of the top n). {} for none.
static func choose(fits: Array, pick: String, rng: RandomNumberGenerator) -> Dictionary:
	if fits.is_empty():
		return {}
	var parts := pick.split(":")
	if parts[0] == "random":
		return fits[rng.randi_range(0, fits.size() - 1)]
	var fact := parts[parts.size() - 1]
	var sorted := fits.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get(fact, 0)) > float(b.get(fact, 0)) \
			or (float(a.get(fact, 0)) == float(b.get(fact, 0)) and str(a["id"]) < str(b["id"])))
	if parts[0] == "lowest":
		return sorted[sorted.size() - 1]
	if parts[0] == "random_top":
		var n := mini(int(parts[1]), sorted.size())
		return sorted[rng.randi_range(0, n - 1)]
	return sorted[0]


static func category_count(story: Dictionary, cat: String, w: int) -> int:
	var n := 0
	for row in story["cats"]:
		if str(row[1]) == cat and w - int(row[0]) < DIVERSITY_WEEKS:
			n += 1
	return n


static func _record_pick(story: Dictionary, card: Dictionary, w: int) -> void:
	var id := str(card["tid"])
	story["last"][id] = w
	story["seen"][id] = int(story["seen"].get(id, 0)) + 1
	story["season"][id] = int(story["season"].get(id, 0)) + 1
	var pid := str(card.get("player_id", ""))
	if pid != "":
		story["subj"][pid] = w
	(story["cats"] as Array).append([w, str(card["category"])])
	while (story["cats"] as Array).size() > 10:
		(story["cats"] as Array).pop_front()


## The card as the hub shows it, with what each choice does already worded
## (so the hint is generated from the very effects that will apply).
static func build(deck: Array, t: Dictionary, subj: Dictionary, club: Dictionary, rng: RandomNumberGenerator, w: int) -> Dictionary:
	var player := str(subj.get("kind", "")) != "club"
	var facts: Dictionary = club.duplicate()
	if player:
		facts.merge(subj, true)
	var titles: Array = t["title"]
	var texts: Array = t["text"]
	var options := []
	for c in t["choices"]:
		if not meets(facts, c.get("when", {}), {}):
			continue
		var detail := " ".join(PackedStringArray([describe(c, facts), fill(str(c.get("note", "")), facts)])).strip_edges()
		options.append({"key": str(c["key"]), "label": fill(str(c["label"]), facts), "detail": detail,
				"rule": fill(str(c.get("rule", "")), facts),
				"effects": (c.get("effects", []) as Array).duplicate(true), "result": fill(str(c.get("result", "")), facts)})
	var card := {"key": str(t["id"]), "tid": str(t["id"]), "story": true, "category": str(t["category"]),
			"default": int(t.get("default", -1)), "week": w, "facts": facts,
			"title": variant(titles, facts, rng),
			"text": variant(texts, facts, rng),
			"options": options}
	if str(t.get("stakes", "")) != "":
		card["stakes"] = fill(str(t["stakes"]), facts)
	if bool(t.get("choice_notes", false)):
		card["choice_notes"] = true
	if player:
		card["player_id"] = str(subj["id"])
	if str(t.get("arc", "")) != "":
		card["arc"] = str(t["arc"])
		card["beat"] = str(t.get("beat", ""))
		card["window"] = arc_window(deck, str(t["arc"]), t)
	var un: Dictionary = t.get("unanswered", {})
	var cost := int(un.get("board", 0))
	if cost != 0:
		card["unanswered"] = {"board": cost, "text": fill(str(un.get("text", "")), facts),
				"hint": "Say nothing: %s" % _board_words(cost).to_lower()}
	# Saying nothing can cost the player's trust instead (a card about what he asked for).
	var trust_cost := int(un.get("trust", 0))
	if trust_cost != 0 and player:
		card["unanswered"] = {"trust": trust_cost, "why": fill(str(un.get("why", "")), facts),
				"text": fill(str(un.get("text", "")), facts),
				"hint": "Say nothing: %s" % _lower_first(_trust_words(trust_cost))}
	return card


## One of a card's title or text variants. A variant may be a case,
## {"when": {facts}, "text": "..."}: the first case whose facts hold is the one
## (the card says what is true this week); else one plain line, chosen by the
## story stream as it always was.
static func variant(list: Array, facts: Dictionary, rng: RandomNumberGenerator) -> String:
	var pick := rng.randi_range(0, list.size() - 1)
	for v in list:
		if v is Dictionary and meets(facts, (v as Dictionary).get("when", {}), {}):
			return fill(str((v as Dictionary).get("text", "")), facts)
	var plain := list.filter(func(v): return not (v is Dictionary))
	if plain.is_empty():
		return ""
	return fill(str(list[pick] if not (list[pick] is Dictionary) else plain[0]), facts)


## A small chance that was written on a card, rolled once from the save's
## seed, the year, the week and the card, so the same save gives the same
## answer however often it is reloaded.
static func risk_hit(seed: int, year: int, week: int, key: String, chance: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("risk|%d|%d|%d|%s" % [seed, year, week, key])
	return rng.randi_range(1, 100) <= chance


## How long an arc waits for its next beat: the longest window of its
## follow-ups (a card may carry "_window" to say so itself, as tests do).
static func arc_window(deck: Array, arc: String, t: Dictionary = {}) -> int:
	if t.has("_window"):
		return int(t["_window"])
	var most := 0
	for c in deck:
		if str(c.get("arc", "")) == arc:
			most = maxi(most, int((c.get("needs", {}) as Dictionary).get("within", 0)))
	return maxi(most, 1)


## After a card is answered (or settles by default): flags its choice sets,
## and the arc it belongs to opens, moves on or ends.
static func record_choice(story: Dictionary, card: Dictionary, choice: int, w: int) -> void:
	ensure(story)
	var opts: Array = card.get("options", [])
	var pid := str(card.get("player_id", ""))
	var set_any := false
	if choice >= 0 and choice < opts.size():
		for e in (opts[choice] as Dictionary).get("effects", []):
			if str(e.get("op", "")) != "flag":
				continue
			var who := "club" if str(e.get("on", "subject")) == "club" or pid == "" else pid
			if not story["flags"].has(who):
				story["flags"][who] = {}
			story["flags"][who][str(e.get("name", ""))] = w
			set_any = true
	var arc := str(card.get("arc", ""))
	if arc == "":
		return
	var key := arc + "|" + (pid if pid != "" else "club")
	var beat := str(card.get("beat", ""))
	if beat == "end":
		if story["arcs"].has(key):
			story["arcs"][key]["state"] = "done"
			story["arcs"][key]["ended"] = w
		return
	if beat == "start" and not set_any:
		return   # a start whose choice sets nothing never began
	var rec: Dictionary = story["arcs"].get(key, {"start": w, "state": "open"})
	rec["until"] = w + int(card.get("window", 1))
	story["arcs"][key] = rec


## Arcs nobody came back to inside their window close as lapsed.
static func lapse_arcs(story: Dictionary, w: int) -> void:
	for key in story["arcs"]:
		var rec: Dictionary = story["arcs"][key]
		if str(rec.get("state", "")) == "open" and w > int(rec.get("until", w)):
			rec["state"] = "lapsed"
			rec["ended"] = w


## A lever's size after trust: an effect marked "scale": "trust" lands harder
## with a player who trusts you (Trust.scaled). Used for the hint and the apply.
static func effect_d(e: Dictionary, facts: Dictionary) -> int:
	var d := int(e.get("d", 0))
	if str(e.get("scale", "")) == "trust":
		return Trust.scaled(d, int(facts.get("trust", 0)))
	return d


static func fill(s: String, facts: Dictionary) -> String:
	return s.format(facts) if s.contains("{") else s


## Names from a ranked list of players, in a card's result line: {best3} is
## the three at the top, {worst2} the two at the bottom (never the same player
## as one of the best). `rows` are {"name": String} already best first, so the
## caller decides what "best" means (a time trial ranks running fitness).
## Without enough names a token says "nobody" rather than leave braces.
static func fill_ranked(s: String, rows: Array) -> String:
	if not s.contains("{"):
		return s
	var re := RegEx.create_from_string(RANKED_TOKEN)
	var best_n := 0
	for m in re.search_all(s):
		if m.get_string(1) == "best":
			best_n = maxi(best_n, int(m.get_string(2)))
	var out := s
	for m in re.search_all(s):
		var n := int(m.get_string(2))
		var picked: Array
		if m.get_string(1) == "best":
			picked = rows.slice(0, n)
		else:
			picked = rows.slice(maxi(best_n, rows.size() - n), rows.size())
			picked.reverse()
		var names: Array = picked.map(func(r): return str(r["name"]))
		out = out.replace(m.get_string(), name_list(names))
	return out


## "A", "A and B", "A, B and C".
static func name_list(names: Array) -> String:
	if names.is_empty():
		return "nobody"
	if names.size() == 1:
		return str(names[0])
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, names.size() - 1))), str(names[names.size() - 1])]


## What a choice does, in a coach's words, from its effects.
static func describe(c: Dictionary, facts: Dictionary) -> String:
	var out: PackedStringArray = []
	for e in c.get("effects", []):
		var s := _trial_words(e) if str(e.get("op", "")) == "role_trial" else _effect_words(e, facts)
		if s != "":
			out.append(fill(s, facts))
	return " ".join(out)


## What a choice does, as the coach weighs it: what he gains, then what it
## costs, each its own short line behind a plain marker, from the very effects
## that will apply, so the line cannot drift from the mechanic and a new card
## gets it for free. Every line carries its size, in percentages a coach reads
## the way he reads a ladder (director, 2026-10-18: "his morale up 15%",
## "about 20% of the time"): morale and board confidence run 0 to 100 and trust
## and togetherness -100 to 100, so one step is 1%. A dice roll says its chance.
## A cost that only happens if the coach later breaks a promise or the dice
## fall wrong says so. The game never says which choice is better. Effects that
## change nothing the coach feels (a flag, a note) show nothing; no lines at all
## when a choice does nothing mechanical.
const GAIN_MARK := "Gain: "
const COST_MARK := "Cost: "
## What the lines quote, from the rules they describe (tests/test_story.gd pins
## each against the rule's own constant, so a retune cannot leave a line behind).
## A full senior game's development (GameState.XP_SENIOR_GAME).
const SENIOR_GAME_XP := 37
## His legs at the first bounce after a heavy week (MatchSim._start_energy).
const HEAVY_LEGS_START := 88
## An early extension's premium over today's price (ClubLife.early_price) and
## the lift signing gives him (ClubStories._extend).
const EARLY_PREMIUM_PCT := 15
const EXTEND_MORALE := 8
## What a promise to the board moves on top of the result (GameState._board_after_round).
const PROMISE_WIN_UP := 8
const PROMISE_WIN_DOWN := 10
## What a broken promise costs the group's togetherness (GameState._board_after_round).
const BROKEN_TOGETHER := 2
## Trust lost when a promise made on a card is broken after the match: a game, a run.
const BROKEN_PROMISE_TRUST := -8
const BROKEN_RUN_TRUST := -10


static func stakes_lines(effects: Array, facts: Dictionary) -> PackedStringArray:
	var gains: PackedStringArray = []
	var costs: PackedStringArray = []
	var notes: PackedStringArray = []
	for e in effects:
		for part in _effect_parts(e, facts):
			var s := fill(str(part[1]), facts)
			var into: PackedStringArray = notes if str(part[0]) == "note" else (gains if str(part[0]) == "gain" else costs)
			if not into.has(s):
				into.append(s)
	var out: PackedStringArray = []
	if not notes.is_empty():
		out.append(" ".join(notes))
	if not gains.is_empty():
		out.append(GAIN_MARK + " ".join(gains))
	if not costs.is_empty():
		out.append(COST_MARK + " ".join(costs))
	return out


## What happens if the coach leaves the card when the week is played, in one
## line under the text, from the card's own data: the choice it settles as (its
## gain and cost sit under that choice's button, so they are not said twice) or
## the price of saying nothing. "" when leaving it changes nothing.
static func silence_line(card: Dictionary) -> String:
	var un: Dictionary = card.get("unanswered", {})
	if str(un.get("hint", "")) != "":
		return str(un["hint"])
	var d := int(card.get("default", -1))
	var opts: Array = card.get("options", [])
	if d < 0 or d >= opts.size():
		return ""
	return "If you leave this, it goes as \"%s\"." % str((opts[d] as Dictionary).get("label", ""))


## The lines under one choice on a card (the hub shows these). Every choice
## carries a gain and a cost (bible §4): a choice whose own effects gain nothing
## states, as its gain, the other choices' costs it does not carry, from their
## effects (no slow-start chance, no promise to keep, the board untouched).
static func card_lines(card: Dictionary, i: int) -> PackedStringArray:
	var opts: Array = card.get("options", [])
	var facts: Dictionary = card.get("facts", {})
	var mine: Array = (opts[i] as Dictionary).get("effects", [])
	var lines := stakes_lines(mine, facts)
	for l in lines:
		if l.begins_with(GAIN_MARK):
			return lines
	var own := {}
	for e in mine:
		own[str(e.get("op", ""))] = true
	var spared: PackedStringArray = []
	for j in range(opts.size()):
		if j == i:
			continue
		for e in (opts[j] as Dictionary).get("effects", []):
			if own.has(str(e.get("op", ""))):
				continue
			var s := fill(_spared_words(e, facts), facts)
			if s != "" and not spared.has(s):
				spared.append(s)
	if spared.is_empty():
		return lines
	var out: PackedStringArray = []
	var placed := false
	for l in lines:
		if not placed and l.begins_with(COST_MARK):
			out.append(GAIN_MARK + " ".join(spared))
			placed = true
		out.append(l)
	if not placed:
		out.append(GAIN_MARK + " ".join(spared))
	return out


## What a choice spares him that another choice on the card would cost, in the
## same sizes; "" for a cost that is not spared by not choosing it (a mood).
static func _spared_words(e: Dictionary, facts: Dictionary) -> String:
	match str(e.get("op", "")):
		"slow_start":
			return "No %s chance of a slow start." % _pct(int(e.get("chance", 0)))
		"expects_game", "start_backing":
			return "No promise to keep: he is not owed a game."
		"back_kid":
			return "No promise to keep: {kid_name} is not owed a game."
		"promise_win":
			return "No promise to the board: a loss or draw costs %s less than a broken promise would." % _pct(PROMISE_WIN_DOWN)
		"board":
			var d := effect_d(e, facts)
			return "Board confidence stays where it is (the other choice costs it %s)." % _pct(absi(d)) if d < 0 else ""
		"role_trial":
			return "He stays in his usual spot as a {trial_home}."
		"heavy_legs":
			return "No heavy legs on game day."
		"rest":
			return "He is free to play this week."
	return ""


## The one effect-phrase function: [kind, words] for each thing an effect does
## ("gain", "cost" or "note"); an effect that moves nothing the coach feels gives none.
static func _effect_parts(e: Dictionary, facts: Dictionary) -> Array:
	var op := str(e.get("op", ""))
	var d := effect_d(e, facts)
	var who := str(e.get("who", "subject"))
	if str(e.get("line", "")) != "":
		# A card may word an effect itself; it is still a gain or a cost by its sign.
		var k := "gain" if d > 0 or op in ["xp", "fresh"] else "cost"
		return [[k, str(e["line"])]]
	match op:
		"delegate":
			# Left to the captain: where the group stands now, then what each
			# outcome does, each under its own gain or cost.
			var parts: Array = [["note", _standing_words(facts)]]
			for pair in [["held", "If the group listens, "], ["failed", "If it doesn't, "]]:
				for ne in e.get(pair[0], []):
					for np in _effect_parts(ne, facts):
						parts.append([np[0], pair[1] + _lower_first(str(np[1]))])
			return parts
		"morale":
			if d == 0:
				return []
			var s := _morale_words(d, who)
			if str(e.get("scale", "")) == "trust" and d > 0:
				var b := str(facts.get("trust_band", "neutral"))
				if b == "close" or b == "trusts":
					s += " It counts for more because he trusts you."
				elif b == "wary" or b == "lost":
					s += " It counts for less because he's wary of you."
			return [["gain" if d > 0 else "cost", s]]
		"board":
			return [] if d == 0 else [["gain" if d > 0 else "cost", _board_words(d)]]
		"trust":
			return [] if d == 0 else [["gain" if d > 0 else "cost", _trust_words(d)]]
		"xp":
			return [["gain", "Development worth %s of a senior game %s." % [xp_share(d),
					"for him" if who == "subject" else ("for each player in the side" if who == "side" else ("for each of the others" if who == "others" else "for everyone"))]]]
		"fresh":
			return [["gain", "Fresh legs: %d%% less likely to be injured this week." % roundi((1.0 - ClubLife.FRESH_RISK) * 100.0)]]
		"rest":
			# He cannot be hurt in a game he does not play: the chance he is spared
			# (playing sore, on the cards that say so).
			var risk := "{sore_pct}" if str(e.get("spares", "")) == "sore" else "{injury_pct}"
			var spare := ("He can't get hurt this week: playing, he would carry %s chance of an injury." % risk) 					if facts.has("injury_pct") else "He can't get hurt in this week's game."
			return [["gain", spare], ["cost", "He misses this week's game."]]
		"sore":
			return [["cost", "He plays sore: %s chance he is injured (%s), and he starts %s short of fresh legs." % [
					_sore_chance(facts), _injury_length_words(), _pct(100 - roundi(ClubLife.SORE_LEGS))]]]
		"heavy_legs":
			var rise := roundi((ClubLife.HEAVY_RISK - 1.0) * 100.0)
			var short := 100 - HEAVY_LEGS_START
			if who == "subject":
				return [["cost", "Heavy legs on game day: he starts %d%% short of fresh and is %d%% more likely to be injured." % [short, rise]]]
			return [["cost", "Heavy legs across the %s on game day: each player starts %d%% short of fresh and is %d%% more likely to be injured." % [
					"side" if who == "side" else "whole list", short, rise]]]
		"expects_game":
			return [["cost", "He expects a game this week, and Auto-pick names him. Leave him out fit and the promise breaks: %s" % _broken_words(int(e.get("sting", 12)), absi(BROKEN_PROMISE_TRUST))]]
		"start_backing":
			return [["gain", _morale_words(Backing.THRILL, "subject")],
					["cost", "He expects to be picked for the next {run_games} games, and Auto-pick names him. Leave him out fit and the promise breaks: %s" % _broken_words(Backing.STING, absi(BROKEN_RUN_TRUST))]]
		"back_kid":
			return [["gain", "{kid_name}'s morale up %s." % _pct(Backing.THRILL)],
					["cost", "{kid_name} is promised the next {run_games} games, and Auto-pick names him. Leave him out fit and the promise breaks: %s" % _broken_words(Backing.STING, absi(BROKEN_RUN_TRUST))]]
		"extend_early":
			return [["gain", "He signs on for {more_seasons}, and his morale goes up %s." % _pct(EXTEND_MORALE)],
					["cost", "Locked in at {early_price} a season, %s over what he is worth today, whatever he does next." % _pct(EARLY_PREMIUM_PCT)]]
		"promise_win":
			return [["gain", "Win and board confidence goes up %s more than a win alone." % _pct(PROMISE_WIN_UP)],
					["cost", "Lose or draw and board confidence falls %s more than a loss alone." % _pct(PROMISE_WIN_DOWN)]]
		"captaincy_swap":
			return [["gain", "{vice_name} takes the armband; {name} stays in the leadership group."],
					["cost", "Taking it off {name} mid-season: his morale falls %s and he trusts you %s less. It uses your one change this season." % [
						_pct(absi(Captaincy.STRIPPED_MORALE)), _pct(absi(Captaincy.STRIPPED_TRUST))]]]
		"rush_back":
			return [["gain", "He is cleared to play, and you name him."],
					["cost", "He plays sore: %s chance he is hurt again (any injury, not only this one; %s), and he starts %s short of fresh legs." % [
						_sore_chance(facts), _injury_length_words(), _pct(100 - roundi(ClubLife.SORE_LEGS))]]]
		"slow_start":
			return [["cost", _slow_words(e)]]
		"loss_sting":
			return [["cost", "If you lose that final, about a %s chance the side's morale also falls %s." % [
					_pct(int(e.get("chance", 0))), _pct(absi(int(e.get("d", 0))))]]]
		"role_trial":
			return [["gain", _trial_words(e)], ["cost", _trial_cost_words(e, facts)]]
	return []


## The words for one effect, gains and costs together (a choice's detail and a
## captain's outcome read this).
static func _effect_words(e: Dictionary, facts: Dictionary) -> String:
	if str(e.get("op", "")) == "explain":
		return "{kpi_or_need} Nothing is promised."
	var out: PackedStringArray = []
	for part in _effect_parts(e, facts):
		if str(part[0]) != "note":
			out.append(str(part[1]))
	if str(e.get("op", "")) == "delegate":
		return _delegate_words(e, facts)
	return " ".join(out)


## "8%".
static func _pct(n: int) -> String:
	return "%d%%" % n


## Development as a share of a senior game's: "16%".
static func xp_share(d: int) -> String:
	return _pct(maxi(1, roundi(float(d) * 100.0 / float(SENIOR_GAME_XP))))


## His chance of an injury playing sore, as a percentage ("about 20%"); an
## older card that only carried the "1 in N" odds keeps them.
static func _sore_chance(facts: Dictionary) -> String:
	return "{sore_pct}" if facts.has("sore_pct") else "{sore_odds}"


## How long an injury keeps him out, from the injury table: "66% of injuries
## are two weeks or less".
static func _injury_length_words() -> String:
	var short := 0.0
	for row in Injuries.SEVERITY:
		if int(row[1]) <= 2:
			short += float(row[2])
	return "%s of injuries are two weeks or less" % _pct(roundi(short * 100.0))


## A broken promise's price, in the order it lands.
static func _broken_words(sting: int, trust: int) -> String:
	return "his morale falls up to %s, he trusts you %s less and the group's togetherness drops %s." % [
			_pct(sting), _pct(trust), _pct(BROKEN_TOGETHER)]


## A slow start: the chance, the match it is for and what it costs at the first bounce.
static func _slow_words(e: Dictionary) -> String:
	var who := str(e.get("who", "subject"))
	# "on": "week" is this week's game (a card in the season), "grand_final" is
	# Saturday; a finals card's chance is for the next final.
	var when := "his next final" if who == "subject" else "its next final"
	if str(e.get("on", "")) == "grand_final":
		when = "Saturday"
	elif str(e.get("on", "")) == "week":
		when = "this week's game"
	var legs := _pct(100 - roundi(ClubLife.SLOW_LEGS))
	var chance := _pct(int(e.get("chance", 0)))
	if who == "subject":
		return "About a %s chance he starts %s slowly, %s short of fresh legs at the first bounce." % [chance, when, legs]
	return "About a %s chance %s starts %s slowly, every one of them %s short of fresh legs at the first bounce." % [
			chance, "the side" if who == "side" else "the whole list", when, legs]


## A role trial: where he plays and for how long.
static func _trial_words(e: Dictionary) -> String:
	var n := int(e.get("weeks", 3))
	return "He plays as a {trial_word} for the next %s %s, then goes back to being a {trial_home}." % [_count(n), "game" if n == 1 else "games"]


## What a role trial costs the side: those games away from his usual spot, and
## how he rates there against where he plays now.
static func _trial_cost_words(e: Dictionary, facts: Dictionary) -> String:
	var n := int(e.get("weeks", 3))
	var head := "%s %s away from his usual spot" % [_count(n).capitalize(), "game" if n == 1 else "games"]
	if not facts.has("trial_ovr"):
		return head + "."
	return "%s: he rates {trial_ovr} as a {trial_word}, against {overall} as a {trial_home}." % head


static func _count(n: int) -> String:
	return (["one", "two", "three", "four", "five", "six"][clampi(n, 1, 6) - 1]) as String


## Left to the captain: what happens if the group listens and what if it doesn't,
## worded from the choice's own held / failed effects, and which way it stands now.
static func _standing_words(facts: Dictionary) -> String:
	if bool(facts.get("delegate_holds", false)):
		return "As it stands the group would listen to {name}."
	return "As it stands the group wouldn't listen to {name}."


static func _delegate_words(e: Dictionary, facts: Dictionary) -> String:
	var held := _lower_first(_outcome_words(e.get("held", []), facts))
	var failed := _lower_first(_outcome_words(e.get("failed", []), facts))
	if bool(facts.get("delegate_holds", false)):
		return "As it stands the group would listen to {name}: %s If they didn't, %s" % [held, failed]
	return "As it stands the group wouldn't listen to {name}: %s If they did, %s" % [failed, held]


static func _outcome_words(effects: Array, facts: Dictionary) -> String:
	var out: PackedStringArray = []
	for ne in effects:
		var w := _effect_words(ne, facts)
		if w != "":
			out.append(w)
	return " ".join(out) if not out.is_empty() else "nothing changes."


static func _lower_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)


## Every phrase names the thing that moves (morale, trust, board confidence),
## its direction and its size, in the names the game shows the player.
static func _morale_words(d: int, who: String) -> String:
	var move := "%s %s" % ["up" if d > 0 else "down", _pct(absi(d))]
	if who == "subject":
		return "His morale %s." % move
	var group: String = {"side": "across the side", "all": "across the whole list", "others": "in the rest of the group"}.get(who, "in the group")
	return "Morale %s %s." % [move, group]


static func _board_words(d: int) -> String:
	return "Board confidence %s %s." % ["up" if d > 0 else "down", _pct(absi(d))]


static func _trust_words(d: int) -> String:
	return "He trusts you %s %s." % [_pct(absi(d)), "more" if d > 0 else "less"]


## What changed, for the card's result line: only the levers a player feels.
static func aftermath(applied: Dictionary) -> String:
	var out: PackedStringArray = []
	var t := int(applied.get("trust", 0))
	if t != 0:
		out.append("He trusts you more." if t > 0 else "He trusts you less.")
	var b := int(applied.get("board", 0))
	if b != 0:
		out.append("Board confidence went up." if b > 0 else "Board confidence went down.")
	return " ".join(out)
