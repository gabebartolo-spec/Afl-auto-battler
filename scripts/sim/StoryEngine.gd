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
	var quiet := rng.randf() >= EVENT_CHANCE
	var out := []
	var first := _pick_one(deck, ctx, story, rng, w, quiet, "", "")
	if first.is_empty():
		return out
	out.append(first)
	_record_pick(story, first, w)
	if bool(ctx.get("big", false)) and rng.randf() < SECOND_CHANCE:
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
	if not (t.get("phase", ["regular"]) as Array).has(str(ctx.get("phase", "regular"))):
		return {}
	if w - int(story["last"].get(id, NEVER)) < int(t.get("cooldown", 0)):
		return {}
	var per := int(t.get("per_season", 0))
	if per > 0 and int(story["season"].get(id, 0)) >= per:
		return {}
	if category_count(story, str(t["category"]), w) >= DIVERSITY_MAX:
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
		elif str(facts.get(key, "")) != str(v):
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
		var detail := " ".join(PackedStringArray([describe(c, facts), fill(str(c.get("note", "")), facts)])).strip_edges()
		options.append({"key": str(c["key"]), "label": fill(str(c["label"]), facts), "detail": detail,
				"effects": (c.get("effects", []) as Array).duplicate(true), "result": fill(str(c.get("result", "")), facts)})
	var card := {"key": str(t["id"]), "tid": str(t["id"]), "story": true, "category": str(t["category"]),
			"default": int(t.get("default", -1)), "week": w, "facts": facts,
			"title": fill(str(titles[rng.randi_range(0, titles.size() - 1)]), facts),
			"text": fill(str(texts[rng.randi_range(0, texts.size() - 1)]), facts),
			"options": options}
	if str(t.get("stakes", "")) != "":
		card["stakes"] = fill(str(t["stakes"]), facts)
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
	return card


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
		var s := _effect_words(e, facts)
		if s != "":
			out.append(fill(s, facts))
	return " ".join(out)


static func _effect_words(e: Dictionary, facts: Dictionary) -> String:
	var d := effect_d(e, facts)
	var who := str(e.get("who", "subject"))
	match str(e.get("op", "")):
		"morale":
			var s := _morale_words(d, who)
			if str(e.get("scale", "")) == "trust" and d > 0:
				var b := str(facts.get("trust_band", "neutral"))
				if b == "close" or b == "trusts":
					s += " It means more coming from you."
				elif b == "wary" or b == "lost":
					s += " He's wary of you, so it lands softer."
			return s
		"xp":
			var size := "A big week of development" if d >= 20 else ("A solid week of development" if d >= 10 else "Some extra development")
			return "%s %s." % [size, "for him" if who == "subject" else ("for the side" if who == "side" else "for everyone")]
		"board":
			return _board_words(d)
		"trust":
			return "His trust in you rises." if d > 0 else "His trust in you takes a hit."
		"rest":
			return "He misses this week's game."
		"sore":
			return "He plays short of a gallop, and there's {sore_odds} chance he breaks down for weeks."
		"fresh":
			return "Fresher bodies: fewer injuries this week."
		"heavy_legs":
			return "Heavy legs on game day, and more soft-tissue risk."
		"expects_game":
			return "He expects a game this week; leave him out fit and it sours."
		"start_backing":
			return "He's thrilled, and expects to be picked for the next {run_games} games; leave him out fit and the promise breaks."
		"extend_early":
			return "He signs on for {more_seasons} at {early_price} a season, locked in whatever he does next."
		"promise_win":
			return "Win and the board is won over; lose and it costs you."
		"explain":
			return "{kpi_or_need} Nothing is promised."
	return ""


static func _morale_words(d: int, who: String) -> String:
	if who == "subject":
		if d >= 10:
			return "It lifts him a lot."
		if d >= 5:
			return "It lifts him."
		if d > 0:
			return "A small lift for him."
		if d <= -10:
			return "He takes it hard."
		if d <= -5:
			return "He's disappointed."
		return "It stings him a little."
	var group: String = {"side": "the side", "all": "the whole list", "others": "the rest of the group"}.get(who, "the group")
	if d > 0:
		return ("A lift for %s." if d >= 5 else "A small lift for %s.") % group
	return ("%s takes it hard." if d <= -5 else "%s is a little flat about it.") % group.capitalize()


static func _board_words(d: int) -> String:
	if d >= 6:
		return "The board is delighted."
	if d > 0:
		return "The board likes it."
	if d <= -6:
		return "The board will be furious."
	return "The board won't like it."


## What changed, for the card's result line: only the levers a player feels.
static func aftermath(applied: Dictionary) -> String:
	var out: PackedStringArray = []
	var t := int(applied.get("trust", 0))
	if t != 0:
		out.append("His trust in you rose." if t > 0 else "His trust in you fell.")
	var b := int(applied.get("board", 0))
	if b != 0:
		out.append("The board liked it." if b > 0 else "The board didn't like it.")
	return " ".join(out)
