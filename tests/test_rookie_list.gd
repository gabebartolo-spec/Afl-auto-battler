extends RefCounted
## Row 88: the rookie list (RookieList). Row 64: a prospect the National
## Draft passed over gets his rookie list chance in the Rookie Draft. A seeded career
## rolls over through the National Draft, which now fills the senior list
## only; the Rookie Draft follows and fills the rookie spots. A rookie is
## upgraded to the senior list (refused while it is full), an old save loads
## with everyone on the senior list, the list screen shows both lists and
## the Rookie Draft sheet and the upgrade take real taps.
## Run through run_rookie_list_tests.gd.

const Tap := preload("res://tests/tap.gd")
const SEED := 8801
const CLUB := "ADE"

var failures: Array[String] = []
var checks := 0
var root: Window
var _tree: SceneTree
var gs


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		push_error(msg)


func _settle() -> void:
	for i in 4:
		await _tree.process_frame


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
const Ran := preload("res://tests/functions_ran.gd")
func _t(test: String, args := []) -> Variant:
	return await Ran.one(self, test, args)


func run(tree: SceneTree) -> void:
	root = tree.root
	_tree = tree
	gs = GameState
	failures.clear()
	checks = 0
	root.size = Vector2i(390, 844)
	GameState.replay_seed = SEED
	_t("_test_rollover_on")
	_t("_test_upgrade")
	_t("_test_old_save")
	_t("_test_nobody_left")
	await _t("_test_rookie_draft_tap")
	await _t("_test_list_screen_and_upgrade_tap")
	_t("_test_release_and_resign")
	_t("_test_entering_club_seat")
	_t("_test_midseason_fills_rookie_spots")
	_t("_test_midseason_pool_after_offseason")
	_t("_test_real_lists_start")
	_t("_test_real_lists_open_spots")
	_t("_test_real_lists_rookie_categories")
	_t("_test_the_44_rule")
	_t("_test_the_44_national_draft")
	_t("_test_the_44_real_lists")
	await _t("_test_three_category_b_head")
	_t("_test_youth_only_drafts")
	_t("_test_youth_only_midseason")
	await _t("_test_undrafted_chance")
	_t("_test_arrivals_need_senior_spot")
	GameState.replay_seed = 0
	print(Ran.line("Rookie list", self))


func _new_career() -> void:
	gs.reset()
	gs.start_season(CLUB, GameDB.club_list(CLUB))
	gs.set_setting("seen_weekly_loop_intro", true)
	gs.tutorials = false


## A career at the end of its first home-and-away, through the National Draft
## (every pick made the way a rival makes it) and the rollover.
func _rollover() -> Draft:
	_new_career()
	gs.season.round_index = gs.season.fixture.size()
	if not gs.begin_intake_draft():
		return null
	var draft: Draft = gs.draft
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	if not gs.finish_intake_draft():
		return null
	return draft


func _test_rollover_on() -> void:
	var draft := _rollover()
	_check(draft != null, "The rollover commits")
	if draft == null:
		return
	_check(draft.senior_cap == RookieList.SENIOR_SPOTS, "The National Draft fills the senior list (38)")
	# No club's National Draft took it past 38 seniors.
	var clubs := 0
	for code in draft.existing_sizes:
		clubs += 1
		var before := int(draft.existing_sizes[code])
		var took := draft.count_for(str(code))
		_check(took == 0 or before + took <= RookieList.SENIOR_SPOTS,
				"%s: the National Draft stops at a full senior list (%d kept + %d picks)" % [code, before, took])
	_check(clubs >= 18, "Every club was in the National Draft (%d)" % clubs)
	var rec: Dictionary = gs.rookie_draft
	_check(int(rec.get("year", 0)) == gs.season_year and gs.season_year == 2028,
			"The Rookie Draft opens after the National Draft, for the new season (%s)" % str(rec.get("year")))
	_check(gs.draft == null, "The National Draft is over when the Rookie Draft runs")
	_check(RookieList.waiting(gs), "Your first rookie pick waits for you")
	_check((rec.get("order", []) as Array).size() >= 18, "Every club is in the Rookie Draft order")
	var pool := MidseasonDraft.pool(gs)
	_check(not pool.is_empty(), "There are players left to take (%d)" % pool.size())
	if pool.is_empty():
		return
	var pid := str(pool[0]["id"])
	_check(RookieList.choose(gs, pid), "Your pick is taken")
	var mine := RookieList._find(gs.my_list, pid)
	_check(not mine.is_empty() and RookieList.is_rookie(mine), "He joins your rookie list")
	_check(int(mine.get("salary", 0)) == RookieList.wage(gs.season_year), "He is paid the rookie wage")
	_check(int(mine.get("contract_years", 0)) == RookieList.deal_years(mine)
			and int(mine.get("contract_years", 0)) in [1, 2], "A one- or two-season rookie deal")
	if RookieList.waiting(gs):
		_check(RookieList.choose(gs, ""), "A pass is taken")
	_check(not RookieList.waiting(gs) and bool(gs.rookie_draft.get("done", false)),
			"After a pass the Rookie Draft runs to its end")
	_check(RookieList.rookie_count(gs.my_list) == 1, "Your pass ended your draft at one rookie")
	var picks: Array = gs.rookie_draft.get("picks", [])
	_check(picks.size() > 1, "Rivals took rookies too (%d picks)" % picks.size())
	for code in gs.league_lists:
		var arr: Array = gs.league_lists[code]
		_check(RookieList.rookie_count(arr) <= RookieList.CAT_A_SPOTS, "%s: at most six rookies" % code)
		_check(arr.size() <= Contracts.MAX_LIST, "%s: at most 44 on both lists" % code)
	for k in picks:
		var p := RookieList._find(gs.league_lists.get(str(k["club"]), []), str(k["id"]))
		_check(RookieList.is_rookie(p) and int(p.get("salary", 0)) == RookieList.wage(gs.season_year),
				"Every Rookie Draft pick is on a rookie list on the rookie wage (%s)" % str(k["id"]))
		_check(not gs.free_agents.has(p) and not gs.draftee_pool.has(p), "A pick leaves the pool (%s)" % str(k["id"]))
	_check(gs.news.any(func(n): return str(n.get("text", "")).begins_with("Rookie Draft")),
			"The news reports the Rookie Draft")
	_check(gs.save_career() and gs.load_career() and int(gs.rookie_draft.get("year", 0)) == 2028
			and RookieList.rookie_count(gs.my_list) == 1,
			"A save and load keeps the Rookie Draft and the rookie list")
	var n := (gs.rookie_draft.get("picks", []) as Array).size()
	RookieList.open_draft(gs, gs.intake_order())
	_check((gs.rookie_draft.get("picks", []) as Array).size() == n, "The Rookie Draft opens once a season")


func _test_upgrade() -> void:
	_new_career()
	var list: Array = gs.my_list
	_check(list.size() >= RookieList.SENIOR_SPOTS, "A full list to start (%d)" % list.size())
	var rk: Dictionary = list[list.size() - 1]
	rk["rookie_list"] = "A"
	rk["salary"] = RookieList.wage(gs.season_year)
	var id := str(rk["id"])
	var senior_id := str(list[0]["id"])
	_check(RookieList.upgrade_block(gs, CLUB, senior_id) == "He is already on the senior list.",
			"A senior player cannot be upgraded")
	# Fill the senior list to 38 with stand-ins, so the upgrade has no spot.
	var n := 0
	while RookieList.senior_count(list) < RookieList.SENIOR_SPOTS:
		var extra: Dictionary = (list[0] as Dictionary).duplicate(true)
		extra["id"] = "%s_extra%d" % [str(extra["id"]), n]
		n += 1
		list.append(extra)
	_check(RookieList.upgrade_block(gs, CLUB, id).begins_with("The senior list is full"),
			"The upgrade is refused while the senior list is full")
	_check(not RookieList.upgrade(gs, CLUB, id) and RookieList.is_rookie(rk), "...and nothing moves")
	# Make room: delist seniors until one spot is free.
	while RookieList.senior_count(list) >= RookieList.SENIOR_SPOTS:
		for i in list.size():
			if not RookieList.is_rookie(list[i]):
				list.remove_at(i)
				break
	_check(RookieList.upgrade_block(gs, CLUB, id) == "", "A free senior spot allows the upgrade")
	_check(RookieList.upgrade(gs, CLUB, id), "The rookie is upgraded")
	_check(not RookieList.is_rookie(rk) and not rk.has("rookie_list"), "He is on the senior list")
	_check(int(rk["salary"]) >= RookieList.senior_wage(gs.season_year), "His wage rises to the senior minimum")
	_check(RookieList.senior_count(list) == RookieList.SENIOR_SPOTS, "He took the free senior spot")
	# A rival with a free senior spot upgrades its best rookie the same way.
	var rl: Array = gs.season.lists["GEE"]
	while RookieList.senior_count(rl) >= RookieList.SENIOR_SPOTS:
		rl.remove_at(0)
	var r1: Dictionary = rl[rl.size() - 1]
	r1["rookie_list"] = "A"
	var done := RookieList.ai_upgrades(gs)
	_check(done.any(func(d): return str(d["id"]) == str(r1["id"])) and not RookieList.is_rookie(r1),
			"A rival upgrades a rookie into a free senior spot")
	_check(not done.any(func(d): return str(d["club"]) == CLUB), "Your club is never upgraded for you")
	# A rookie who moves club lands on his new club's senior list.
	var mover: Dictionary = rl[0]
	mover["rookie_list"] = "A"
	gs._release("GEE", mover, false, false)
	gs._join("COL", mover)
	_check(not RookieList.is_rookie(mover) and str(mover["club"]) == "COL",
			"A rookie who changes club joins its senior list")


func _test_old_save() -> void:
	_new_career()
	_check(gs.save_career(), "An old-style career saves")
	_check(gs.load_career(), "...and loads")
	_check(RookieList.rookie_count(gs.my_list) == 0 and RookieList.senior_count(gs.my_list) == gs.my_list.size(),
			"Every existing player is on the senior list")
	_check(gs.rookie_draft.is_empty() and not RookieList.waiting(gs), "No Rookie Draft waits in an old save")


## Nobody left to take: no sheet with only Pass on it (director, 2026-11-07);
## the pick passes and the news says why.
func _test_nobody_left() -> void:
	var draft := _rollover()
	_check(draft != null and RookieList.waiting(gs), "A rookie pick waits after the rollover (nobody-left test)")
	if not RookieList.waiting(gs):
		return
	gs.free_agents.clear()
	gs.draftee_pool = gs.draftee_pool.filter(func(q): return int(q.get("draft_year", gs.season_year)) >= gs.season_year)
	_check(MidseasonDraft.pool(gs).is_empty(), "Nobody left to take")
	var host := Control.new()
	root.add_child(host)
	_check(RookieDraftSheet.open(host, Callable()) == null and host.get_node_or_null(RookieDraftSheet.NAME) == null,
			"No Rookie Draft sheet opens with nobody to take")
	host.queue_free()
	_check(not RookieList.waiting(gs) and bool(gs.rookie_draft.get("done", false)), "The pick passed and the draft ended")
	_check(gs.news.any(func(n): return str(n["text"]) in [RookieList.NOBODY_LEFT_NEWS, RookieList.NOBODY_AT_ALL_NEWS]), "The news says why")
	_check(not (gs.news.any(func(n): return str(n["text"]) == "Rookie Draft: no club took a player.")
			and gs.news.any(func(n): return str(n["text"]) == RookieList.NOBODY_LEFT_NEWS)),
			"Never 'no club took a player' and 'nobody was left' side by side")


## The Rookie Draft sheet over the pre-season (or the hub): a real tap on Pick.
func _test_rookie_draft_tap() -> void:
	var draft := _rollover()
	_check(draft != null and RookieList.waiting(gs), "A rookie pick waits after the rollover")
	if not RookieList.waiting(gs):
		return
	if gs.needs_season_wrap():
		gs.begin_season_from_wrap()
	var scene_path := "res://scenes/PreSeasonScene.tscn" if gs.preseason_active() else "res://scenes/HubScene.tscn"
	var scene: Control = load(scene_path).instantiate()
	root.add_child(scene)
	await _settle()
	var sheet := scene.get_node_or_null(RookieDraftSheet.NAME)
	_check(sheet != null, "The Rookie Draft sheet opens on %s" % scene_path.get_file())
	var want: String = RookieDraftSheet.PASS_PRESEASON if gs.preseason_active() else RookieDraftSheet.PASS_HUB
	var said := sheet != null and sheet.find_children("*", "Label", true, false).any(
			func(l): return (l as Label).text.contains(want))
	_check(said, "The sheet names the action on this screen that passes: %s" % want)
	var pool := MidseasonDraft.pool(gs)
	if sheet == null or pool.is_empty():
		scene.queue_free()
		return
	var pid := str(pool[0]["id"])
	var btn := sheet.find_child("RookiePick_%s" % pid, true, false) as Button
	_check(btn != null, "The best player left has a Pick button")
	var why: String = await Tap.tap(btn)
	_check(why == "", "A real tap on Pick reaches it (%s)" % why)
	await _settle()
	_check(RookieList.is_rookie(RookieList._find(gs.my_list, pid)), "The tapped player joins your rookie list")
	# Your next round's pick opens straight away; Pass ends it.
	if RookieList.waiting(gs):
		var again := scene.get_node_or_null(RookieDraftSheet.NAME)
		var pass_btn: Button = again.find_child("RookiePass", true, false) as Button if again != null else null
		_check(pass_btn != null, "The next round's sheet opens with Pass")
		var why2: String = await Tap.tap(pass_btn)
		_check(why2 == "", "A real tap on Pass reaches it (%s)" % why2)
		await _settle()
	_check(not RookieList.waiting(gs), "Your Rookie Draft is over")
	_check(scene.get_node_or_null(RookieDraftSheet.NAME) == null, "The sheet is gone")
	scene.queue_free()
	await _settle()


## The list screen shows both lists, and a rookie's profile offers the upgrade.
func _test_list_screen_and_upgrade_tap() -> void:
	_new_career()
	var list: Array = gs.my_list
	while RookieList.senior_count(list) >= RookieList.SENIOR_SPOTS:
		list.remove_at(0)
	var rk: Dictionary = list[list.size() - 1]
	rk["rookie_list"] = "A"
	var id := str(rk["id"])
	var scene: Control = load("res://scenes/ListScene.tscn").instantiate()
	scene.set("_pane", "list")
	root.add_child(scene)
	await _settle()
	var sh := scene.find_child("SeniorListHead", true, false) as Label
	var rh := scene.find_child("RookieListHead", true, false) as Label
	_check(sh != null and sh.text.contains("/ 38"), "The senior list shows its spots (%s)" % (sh.text if sh else "none"))
	_check(rh != null and rh.text.contains("1 / 6"), "The rookie list shows its spots (%s)" % (rh.text if rh else "none"))
	scene.call("_open_profile", id)
	await _settle()
	var up := scene.find_child("Upgrade", true, false) as Button
	_check(up != null and not up.disabled, "A rookie's profile offers the upgrade")
	if up != null:
		var why: String = await Tap.tap(up)
		_check(why == "", "A real tap on the upgrade reaches it (%s)" % why)
		await _settle()
	_check(not RookieList.is_rookie(RookieList._find(gs.my_list, id)), "The tapped upgrade moves him to the senior list")
	var rh2 := scene.find_child("RookieListHead", true, false) as Label
	_check(rh2 != null and rh2.text.contains("0 / 6"), "The rookie list count drops (%s)" % (rh2.text if rh2 else "none"))
	scene.queue_free()
	await _settle()


## A delisted rookie is a free agent; whoever signs him, his old club too,
## puts him on its senior list.
func _test_release_and_resign() -> void:
	_new_career()
	var rl: Array = gs.season.lists["GEE"]
	var p: Dictionary = rl[rl.size() - 1]
	p["rookie_list"] = "A"
	var before := RookieList.rookie_count(rl)
	gs._release("GEE", p, false, false)
	_check(not RookieList.is_rookie(p) and gs.free_agents.has(p), "A delisted rookie is a free agent off the rookie list")
	gs._sign_fa(p, "GEE", RookieList.senior_wage(gs.season_year), 1)
	_check(rl.has(p) and not RookieList.is_rookie(p), "Signed back by his old club, he is on its senior list")
	_check(RookieList.rookie_count(rl) == before - 1, "The rookie list lost him (%d)" % RookieList.rookie_count(rl))


## A club on no ladder yet (in its first season) still gets a Rookie Draft
## seat, at the end of the order.
func _test_entering_club_seat() -> void:
	_new_career()
	var order: Array = gs.intake_order()
	_check(order.has("WCE") and order.size() >= 18, "(setup) WCE is on the ladder (%d clubs)" % order.size())
	order.erase("WCE")
	gs.rookie_draft = {}
	RookieList.open_draft(gs, order)
	var seats: Array = gs.rookie_draft.get("order", [])
	_check(seats.has("WCE") and str(seats[seats.size() - 1]) == "WCE",
			"A club missing from the National Draft order sits last in the Rookie Draft (%s)" % str(seats))
	_check(seats.size() == order.size() + 1, "Every other club keeps its seat once (%d)" % seats.size())
	RookieList.settle(gs)
	_check(not RookieList.waiting(gs), "(cleanup) your pick is passed")


## The mid-season rookie draft fills rookie spots: a club with six rookies is
## left out, a club with a free rookie spot is in, and every pick is a rookie.
func _test_midseason_fills_rookie_spots() -> void:
	_new_career()
	var year: int = gs.season_year
	var cls: Array = gs.draftee_pool.filter(func(q): return int(q.get("draft_year", year)) == year)
	_check(cls.size() >= 30, "(setup) a class to pass over (%d)" % cls.size())
	for i in mini(30, cls.size()):
		(cls[i] as Dictionary)["draft_year"] = year - 1
	var full: Array = gs.season.lists["GEE"]
	for i in RookieList.CAT_A_SPOTS:
		(full[full.size() - 1 - i] as Dictionary)["rookie_list"] = "A"
	var open: Array = gs.season.lists["COL"]
	while open.size() >= Contracts.MAX_LIST:
		open.pop_back()
	_check(RookieList.rookie_spot_free(open) and not RookieList.rookie_spot_free(full),
			"(setup) COL has a rookie spot, GEE has none")
	MidseasonDraft._record(gs)
	MidseasonDraft._open_draft(gs)
	var order: Array = gs.midseason.get("order", [])
	_check(not order.has("GEE"), "A club with six rookies is out of the mid-season draft")
	_check(order.has("COL"), "A club with a free rookie spot is in it")
	# Your pick is passed; the rivals' picks run to the end.
	MidseasonDraft.settle(gs)
	_check(not MidseasonDraft.waiting(gs), "Your pick is passed and the draft ends")
	var picks: Array = gs.midseason.get("picks", [])
	_check(not picks.is_empty(), "Rivals took players (%d)" % picks.size())
	for k in picks:
		var p := RookieList._find(gs.season.lists.get(str(k["club"]), []), str(k["id"]))
		_check(RookieList.is_rookie(p), "A mid-season pick lands on the rookie list (%s)" % str(k["id"]))


## The director (2026-11-11): the mid-season draft had nobody to take. After
## an off-season the young unsigned free agents are still in the pool, rivals
## leave rookie spots open, and the mid-season draft has players and takers.
func _test_midseason_pool_after_offseason() -> void:
	_new_career()
	# Who stays when free agency closes: the young, the best of them first.
	var model: Dictionary = (gs.season.lists["COL"] as Array)[0]
	var made := []
	for i in 16:
		var fa: Dictionary = model.duplicate(true)
		fa["id"] = "T_FA_%02d" % i
		fa["age"] = 20.0 + float(i % 4)
		fa["overall"] = 40 + i
		fa.erase("retiring")
		made.append(fa)
	(made[13] as Dictionary)["age"] = 26.0
	(made[14] as Dictionary)["age"] = 31.0
	(made[15] as Dictionary)["retiring"] = gs.season_year + 1
	var was: Array = gs.free_agents
	gs.free_agents = made.duplicate()
	var stay: Array = gs._fa_staying()
	gs.free_agents = was
	var stay_ids := stay.map(func(p): return str(p["id"]))
	_check(stay.size() == gs.FA_STAYS_MAX and str(stay[0]["id"]) == "T_FA_12" and not stay_ids.has("T_FA_00"),
			"The best twelve young free agents stay, best first (%s)" % str(stay_ids))
	_check(not stay_ids.has("T_FA_13") and not stay_ids.has("T_FA_14") and not stay_ids.has("T_FA_15"),
			"Nobody 26 or older stays, and nobody who is retiring (%s)" % str(stay_ids))
	gs.season.round_index = gs.season.fixture.size()
	_check(gs.begin_intake_draft(), "(setup) the National Draft opens")
	var draft: Draft = gs.draft
	if draft == null:
		return
	# Free agency has closed: who stayed in the pool.
	var kept: Array = gs.free_agents.duplicate()
	# Two more who stayed: one every club wants, one nobody does.
	var star: Dictionary = made[0]
	star["overall"] = 99
	var spare: Dictionary = made[1]
	spare["overall"] = 26
	for p in [star, spare]:
		p["age"] = 22.0
		p["fa_kept"] = gs.season_year
		p["contract_years"] = 0
		p["released_by"] = "COL"
		p.erase("rookie_list")
		gs.free_agents.append(p)
	var young := true
	for p in kept:
		young = young and float(p.get("age", 99.0)) < gs.FA_STAYS_UNDER and int(p.get("fa_kept", 0)) == gs.season_year
	_check(young and kept.size() <= gs.FA_STAYS_MAX,
			"Only young unsigned free agents stay when free agency closes (%d)" % kept.size())
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(gs.finish_intake_draft(), "(setup) the rollover commits")
	RookieList.settle(gs)
	_check(bool(gs.rookie_draft.get("done", false)), "(setup) the Rookie Draft is over")
	var held := 0
	for code in gs.season.lists:
		if str(code) != gs.my_club and RookieList.rookie_spot_free(gs.season.lists[code]):
			held += 1
	_check(held >= 10, "Most rivals have a rookie spot for the mid-season draft (%d)" % held)
	var rookie_picks: Array = gs.rookie_draft.get("picks", [])
	var pool := MidseasonDraft.pool(gs)
	_check(not pool.is_empty(), "After an off-season the mid-season draft pool is not empty (%d)" % pool.size())
	_check(pool.size() == RookieList.AI_LEAVES and rookie_picks.size() > 1,
			"Rivals took rookies and left their last picks unused: %d taken, %d still there" % [rookie_picks.size(), pool.size()])
	var on_list := {}
	for code in gs.season.lists:
		for q in gs.season.lists[code]:
			if str(q["id"]) == "T_FA_00":
				on_list = q
	_check(not on_list.is_empty() and RookieList.is_rookie(on_list) and not on_list.has("fa_kept")
			and float(on_list["age"]) == 23.0,
			"A free agent who stayed is taken in the Rookie Draft, a year older (%s)" % str(on_list.get("club", "")))
	_check(pool.has(spare) and gs.free_agents.has(spare) and float(spare["age"]) == 23.0,
			"One nobody took is still there to take mid-season, a year older")
	for p in gs.free_agents:
		_check(p.has("fa_kept") and float(p.get("age", 99.0)) < gs.FA_STAYS_UNDER + 1.0,
				"A free agent still in the pool is one who stayed (%s)" % str(p.get("id", "")))
	# The mid-season draft itself: rivals take players, and one is there for you.
	MidseasonDraft._record(gs)
	MidseasonDraft._open_draft(gs)
	var mid_picks: Array = gs.midseason.get("picks", [])
	_check(MidseasonDraft.waiting(gs) or not mid_picks.is_empty(),
			"The mid-season draft has someone to take (%d picks before yours, %d left)" % [mid_picks.size(), MidseasonDraft.pool(gs).size()])
	_check(not gs.news.any(func(n): return str(n.get("text", "")) == MidseasonDraft.NOBODY_AT_ALL_NEWS),
			"The mid-season draft does not report nobody to take")
	MidseasonDraft.settle(gs)
	# The next off-season: a free agent nobody took in his extra year is gone.
	var left: Array = gs.free_agents.filter(func(p): return p.has("fa_kept"))
	gs.season.round_index = gs.season.fixture.size()
	gs.open_offseason()
	_check(gs.offseason_year == gs.season_year, "(setup) the next off-season opens")
	for p in left:
		_check(not gs.free_agents.has(p) and gs.departed_names.has(str(p["id"])),
				"A free agent nobody took in his extra year leaves the game (%s)" % str(p["id"]))


## A real-lists career: the starting lists split into
## senior and rookie lists, the opening National Draft fills the senior list
## and the Rookie Draft follows it.
func _test_real_lists_start() -> void:
	gs.reset()
	gs.begin_real_lists()
	var draft: Draft = gs.draft
	_check(draft != null and draft.senior_cap == RookieList.SENIOR_SPOTS,
			"The opening National Draft fills the senior list (38)")
	if draft == null:
		return
	var clubs := 0
	var marked := 0
	for code in gs.league_lists:
		clubs += 1
		var arr: Array = gs.league_lists[code]
		var real_rookies := RookieList.rookies(arr).filter(func(p): return str(p.get("list_type", "")) != "")
		_check(RookieList.rookie_count(arr) <= maxi(RookieList.CAT_A_SPOTS, real_rookies.size()),
				"%s starts with at most six rookies, or its real rookie list" % code)
		_check(RookieList.rookie_count(arr) == RookieList.CAT_A_SPOTS or RookieList.senior_count(arr) <= RookieList.SENIOR_SPOTS,
				"%s: over 38 seniors only once its rookie list is full" % code)
		_check(int(draft.existing_sizes.get(code, -1)) == RookieList.senior_count(arr),
				"%s: the draft counts the senior list" % code)
		for p in arr:
			if str(p.get("list_type", "")) == "rookie" and RookieList.is_rookie(p):
				marked += 1
	_check(clubs >= 18, "Every club has a list (%d)" % clubs)
	_check(marked > 0, "The club lists' rookies start on the rookie list (%d)" % marked)
	var rookies_before := {}
	for code in gs.league_lists:
		rookies_before[code] = RookieList.cat_a_count(gs.league_lists[code])
	gs.choose_real_club(CLUB)
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	for code in draft.existing_sizes:
		var before := int(draft.existing_sizes[code])
		var took := draft.count_for(str(code))
		_check(took == 0 or before + took <= RookieList.SENIOR_SPOTS,
				"%s: the opening draft stops at a full senior list (%d kept + %d picks)" % [code, before, took])
	_check(gs.finish_intake_draft(), "The opening National Draft commits")
	_check(int(gs.rookie_draft.get("year", 0)) == GameDB.START_YEAR and gs.season_year == GameDB.START_YEAR,
			"The Rookie Draft follows the opening National Draft (%s)" % str(gs.rookie_draft.get("year")))
	_check((gs.rookie_draft.get("order", []) as Array).size() >= 18, "Every club has a Rookie Draft seat")
	RookieList.settle(gs)
	_check(bool(gs.rookie_draft.get("done", false)), "Passing ends your Rookie Draft and it runs to its end")
	for code in gs.season.lists:
		_check(RookieList.cat_a_count(gs.season.lists[code]) <= maxi(RookieList.CAT_A_SPOTS, int(rookies_before.get(code, 0))),
				"%s: at most six Category A rookies after it, or no more than its real rookie list" % code)


## Director's bug, 2026-11-12: as Melbourne in a real-lists career "I entered
## the draft with just 1 draft pick available". The 2026 lists' rookies were
## counted as seniors, so most clubs' senior lists were full. Each club now
## starts with its real rookie list (data/list_types_2026.csv and the list
## additions, from DraftGuru's 2026 lists) and its real 2026 departures and
## moves, so it reaches the National Draft with the open spots it really had.
## The bound: before the 2025 National Draft every club had 1 to 7 open
## primary-list spots (ZeroHanger's club-by-club table,
## zerohanger.com/afl-draft-the-amount-of-open-list-spots-each-team-has-170528);
## DraftGuru's 2026 lists less the 2026 departures give 2 (West Coast) to 7
## (Melbourne, Carlton, Fremantle). So every club has 1 to 8 open senior spots
## and can use at least one pick, and Melbourne can use every pick it holds.
## West Coast is the exception (the checker on #1443, 2026-11-12): its real
## 43 of the 44 and one tied prospect leave no room, so its picks pass.
const AT_THE_44 := ["WCE"]


func _test_real_lists_open_spots() -> void:
	gs.reset()
	gs.begin_real_lists()
	var draft: Draft = gs.draft
	_check(draft != null, "A real-lists career opens on the National Draft")
	if draft == null:
		return
	var usable := 0
	var held := 0
	var bad := PackedStringArray()
	for code in draft.draft_order:
		var arr: Array = gs.league_lists[code]
		var open := draft.open_spots(str(code))
		var plan := draft.spots_plan(str(code))
		var picks: Array = draft.upcoming_picks(str(code), 0)
		held += picks.size()
		usable += (plan["usable"] as Array).size()
		if AT_THE_44.has(str(code)):
			# The one club that starts at the 44: it adds nobody (RookieList.add_block),
			# so every pick it holds passes.
			if open != 0 or not (plan["usable"] as Array).is_empty() or RookieList.list_size(arr) < Contracts.MAX_LIST:
				bad.append("%s at the 44 has %d open, %d usable" % [code, open, (plan["usable"] as Array).size()])
		elif open < 1 or open > 8 or (plan["usable"] as Array).is_empty():
			bad.append("%s %d open, %d of %d picks usable" % [code, open, (plan["usable"] as Array).size(), picks.size()])
		for p in arr:
			var kind := str(p.get("list_type", ""))
			if kind in ["rookie", "cat_b"] and not RookieList.is_rookie(p):
				bad.append("%s: %s (%s) is on the senior list" % [code, str(p.get("real_name", "?")), kind])
	_check(bad.is_empty(), "Every club reaches the 2026 draft with 1 to 8 open senior spots, a usable pick and its real rookies on the rookie list; West Coast, at the 44, passes (%s)" % ", ".join(bad))
	_check(usable >= 2 * draft.draft_order.size(), "The clubs can use most of the picks they hold (%d of %d)" % [usable, held])
	var mel: Dictionary = draft.spots_plan("MEL")
	_check((mel["passing"] as Array).is_empty() and (mel["usable"] as Array).size() >= 3 and draft.open_spots("MEL") >= 6,
			"Melbourne can use all its picks (%s usable, %d open spots)" % [str(mel["usable"]), draft.open_spots("MEL")])
	var mentha := ""
	for p in gs.league_lists["MEL"]:
		if str(p.get("real_name", "")) == "Ricky Mentha":
			mentha = str(p.get("rookie_list", ""))
	_check(mentha == "B", "A Category B rookie (Ricky Mentha) starts on the rookie list as one (%s)" % mentha)


## The checker's fault on #1443: Category B rookies took Category A spots, so
## Essendon (5 A + 2 B), Fremantle and Melbourne (6 A + 1 B each) started at
## "7 / 6" and had no Rookie Draft or mid-season rookie pick. The AFL's rule:
## up to six Category A rookies, and up to two Category B in their own spots,
## outside the 44 (senior and Category A lists). Every club starts within
## both, except where the real 2026 list was over (DraftGuru's 2026 lists,
## less the 2026 departures): West Coast's ten Category A rookies (injury
## replacements signed in 2026) and GWS's three Category B rookies.
const CAT_A_OVER := {"WCE": 10}
const CAT_B_OVER := {"GWS": 3}


func _test_real_lists_rookie_categories() -> void:
	gs.reset()
	gs.begin_real_lists()
	var bad := PackedStringArray()
	for code in gs.league_lists:
		var arr: Array = gs.league_lists[code]
		var a := RookieList.cat_a_count(arr)
		var b := RookieList.cat_b_count(arr)
		if a > int(CAT_A_OVER.get(code, RookieList.CAT_A_SPOTS)):
			bad.append("%s %d Category A" % [code, a])
		if b > int(CAT_B_OVER.get(code, RookieList.CAT_B_SPOTS)):
			bad.append("%s %d Category B" % [code, b])
	_check(bad.is_empty(), "Every club starts with at most 6 Category A and 2 Category B rookies, or its real 2026 list (%s)" % ", ".join(bad))
	for code in CAT_A_OVER:
		_check(RookieList.cat_a_count(gs.league_lists[code]) > RookieList.CAT_A_SPOTS,
				"%s's named exception is still real (%d Category A)" % [code, RookieList.cat_a_count(gs.league_lists[code])])
	for code in CAT_B_OVER:
		_check(RookieList.cat_b_count(gs.league_lists[code]) > RookieList.CAT_B_SPOTS,
				"%s's named exception is still real (%d Category B)" % [code, RookieList.cat_b_count(gs.league_lists[code])])
	var ess: Array = gs.league_lists["ESS"]
	_check(RookieList.cat_a_count(ess) == 5 and RookieList.cat_b_count(ess) == 2 and RookieList.rookie_spot_free(ess),
			"Essendon's two Category B rookies leave it a Category A spot (%d A, %d B)" % [RookieList.cat_a_count(ess), RookieList.cat_b_count(ess)])
	# West Coast as DraftGuru's 2027 list has it after the 2026 list period
	# (checked 2026-11-12): 51 on the 2026 list, less Cripps (retired) and seven
	# delistings, plus Trent Rivers and Jack Viney from Melbourne = 45: 33
	# senior, 10 Category A, 2 Category B, so 43 of the 44. The game also lists
	# its tied 2026 prospects before the draft (Harper Banfield, father-son;
	# Lachlan McGlade and Garrison Kenh, Next Generation Academy), as it does
	# for every club: they are the senior spots past the real 33.
	var wce: Array = gs.league_lists["WCE"]
	var tied: int = gs.intake_assignments.filter(func(a): return str(a["club"]) == "WCE").size()
	_check(RookieList.senior_count(wce) - tied == 33 and RookieList.cat_a_count(wce) == 10
			and RookieList.cat_b_count(wce) == 2 and RookieList.list_size(wce) - tied == 43,
			"West Coast starts as its real list: 33 senior, 10 Category A, 2 Category B, 43 of 44, plus %d tied prospects (%d, %d, %d, %d)" % [
				tied, RookieList.senior_count(wce), RookieList.cat_a_count(wce), RookieList.cat_b_count(wce), RookieList.list_size(wce)])
	var mel: Array = gs.league_lists["MEL"]
	_check(RookieList.cat_a_count(mel) == 6 and RookieList.cat_b_count(mel) == 1 and RookieList.list_size(mel) == mel.size() - 1,
			"Melbourne: six Category A, Ricky Mentha in a Category B spot outside the 44 (%d A, %d B, %d of 44)" % [
				RookieList.cat_a_count(mel), RookieList.cat_b_count(mel), RookieList.list_size(mel)])
	# A signing the data names as Category B joins as one (Isaac Keeler, Port
	# Adelaide's pre-draft selection, DraftGuru's 2027 list).
	var keeler := ""
	for p in gs.league_lists["PAD"]:
		if str(p.get("real_name", "")) == "Isaac Keeler":
			keeler = str(p.get("rookie_list", "?"))
	_check(keeler == "B", "Isaac Keeler joins Port Adelaide as a Category B rookie (%s)" % keeler)


## Row 114: Youth only binds your club in every draft. The National Draft
## refuses a player over 24 and says why; the Rookie Draft and the mid-season
## draft refuse him too, and a 24-year-old goes through.
func _test_youth_only_drafts() -> void:
	_new_career()
	gs.challenge = {"kind": "youth"}
	gs.season.round_index = gs.season.fixture.size()
	# Room on the list, so the picks below are made: a full list passes them.
	gs.my_list.resize(gs.my_list.size() - 3)
	_check(gs.begin_intake_draft(), "(setup) the National Draft opens")
	var draft: Draft = gs.draft
	if draft == null:
		return
	_check(draft.user_max_age == Challenge.MAX_AGE, "Youth only: the National Draft carries the age line (%d)" % draft.user_max_age)
	var old := {"id": "youth_test_old", "age": 25.4, "value": 0, "overall": 99}
	_check(draft.too_old_for_user(old) and not draft.can_pick_player(old),
			"Youth only: a 25-year-old cannot be drafted")
	_check(draft.pick_block_reason(old).contains(" is 25, and you cannot"),
			"Youth only: the board says why (%s)" % draft.pick_block_reason(old))
	# The reason names the player the card shows: his real surname, never the
	# generated label underneath.
	var named := {"id": "youth_test_named", "age": 29.0, "name": "Tom Penhall", "real_name": "Flynn Perez"}
	var why := Challenge.block_reason(gs, named)
	_check(why.contains("Perez is 29") and not why.contains("Penhall"),
			"Youth only: the reason names the player shown on the card (%s)" % why)
	_check(not draft.too_old_for_user({"id": "youth_test_ok", "age": 24.9}), "Youth only: a 24-year-old can be drafted")
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	var mine: Array = draft.club_lists.get(CLUB, [])
	var too_old := mine.filter(func(q): return int(floor(float(q.get("age", 0)))) > Challenge.MAX_AGE)
	_check(not mine.is_empty() and too_old.is_empty(),
			"Youth only: every pick made for your club is 24 or under (%d picks, %d over)" % [mine.size(), too_old.size()])
	_check(gs.finish_intake_draft(), "(setup) the rollover commits")
	_check(RookieList.waiting(gs), "(setup) a Rookie Draft pick waits")
	if not RookieList.waiting(gs):
		return
	var left := MidseasonDraft.pool(gs)
	_check(not left.is_empty(), "(setup) a Rookie Draft pool")
	if left.is_empty():
		return
	var him: Dictionary = left[0]
	var age_was = him.get("age", 20)
	him["age"] = 25
	_check(not RookieList.choose(gs, str(him["id"])) and RookieList.waiting(gs),
			"Youth only: the Rookie Draft refuses a 25-year-old and your pick still waits")
	him["age"] = 22
	_check(RookieList.choose(gs, str(him["id"])), "Youth only: a 22-year-old can be taken in the Rookie Draft")
	var p := RookieList._find(gs.season.lists[CLUB], str(him["id"]))
	_check(not p.is_empty() and str(p.get("drafted_club", "")) == CLUB,
			"A Rookie Draft pick is home-grown: first drafted by your club (%s)" % str(p.get("drafted_club", "")))
	him["age"] = age_was
	gs.challenge = {}


func _test_youth_only_midseason() -> void:
	_new_career()
	gs.challenge = {"kind": "youth"}
	var year: int = gs.season_year
	var cls: Array = gs.draftee_pool.filter(func(q): return int(q.get("draft_year", year)) == year)
	for i in mini(30, cls.size()):
		(cls[i] as Dictionary)["draft_year"] = year - 1
	var mine: Array = gs.season.lists[CLUB]
	while mine.size() >= Contracts.MAX_LIST:
		mine.pop_back()
	MidseasonDraft._record(gs)
	MidseasonDraft._open_draft(gs)
	_check(MidseasonDraft.waiting(gs), "(setup) your mid-season pick waits")
	if not MidseasonDraft.waiting(gs):
		return
	var left := MidseasonDraft.pool(gs)
	_check(left.size() >= 2, "(setup) a mid-season pool")
	if left.size() < 2:
		return
	var old: Dictionary = left[0]
	var young: Dictionary = left[1]
	old["age"] = 25
	young["age"] = 24
	_check(not MidseasonDraft.choose(gs, str(old["id"])) and MidseasonDraft.waiting(gs),
			"Youth only: the mid-season draft refuses a 25-year-old")
	_check(Challenge.block_reason(gs, old).contains(" is 25, and you cannot"),
			"Youth only: the reason is said in words (%s)" % Challenge.block_reason(gs, old))
	_check(MidseasonDraft.choose(gs, str(young["id"])), "Youth only: a 24-year-old can be taken mid-season")
	gs.challenge = {}


## Row 64 (director, 2026-11-06): an undrafted prospect gets a rookie list
## chance. Every prospect the National Draft just passed over (and still
## young enough to stay in the pool) is in the Rookie Draft that follows it;
## you offer one a spot with a real tap, rivals take them by the same rule,
## the list limits hold, and a save and load keeps it all.
func _test_undrafted_chance() -> void:
	_new_career()
	gs.season.round_index = gs.season.fixture.size()
	var year: int = gs.season_year
	_check(gs.begin_intake_draft(), "(setup) the National Draft opens")
	var draft: Draft = gs.draft
	if draft == null:
		return
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	var taken := {}
	for code in draft.club_lists:
		for q in (draft.club_lists[code] as Array):
			taken[str(q["id"])] = true
	# The prospects this National Draft passed over (its own class).
	var undrafted := {}
	for q in gs.draftee_pool:
		if int(q.get("draft_year", 0)) == year and not taken.has(str(q["id"])) \
				and not gs.drafted_draftees.has(str(q["id"])):
			undrafted[str(q["id"])] = q
	_check(undrafted.size() > 0, "(setup) the National Draft passed over prospects (%d)" % undrafted.size())
	_check(gs.finish_intake_draft(), "The National Draft commits")
	_check(RookieList.waiting(gs), "The Rookie Draft follows and waits on your pick")
	if not RookieList.waiting(gs):
		return
	# Every one of them is in the Rookie Draft, unless he aged out (22).
	var ids := {}
	for q in MidseasonDraft.pool(gs):
		ids[str(q["id"])] = true
	for k in (gs.rookie_draft.get("picks", []) as Array):
		ids[str(k["id"])] = true
	var missing := []
	for id in undrafted:
		if float((undrafted[id] as Dictionary).get("age", 0.0)) < 22.0 and not ids.has(id):
			missing.append(id)
	_check(missing.is_empty(), "Every prospect the National Draft passed over is in the Rookie Draft (%s)" % str(missing))
	# Your path: offer one of them a spot with a real tap on the sheet.
	if gs.needs_season_wrap():
		gs.begin_season_from_wrap()
	var scene_path := "res://scenes/PreSeasonScene.tscn" if gs.preseason_active() else "res://scenes/HubScene.tscn"
	var scene: Control = load(scene_path).instantiate()
	root.add_child(scene)
	await _settle()
	var sheet := scene.get_node_or_null(RookieDraftSheet.NAME)
	_check(sheet != null, "The Rookie Draft sheet opens")
	var pid := ""
	for q in MidseasonDraft.pool(gs).slice(0, RookieDraftSheet.SHOWN):
		if undrafted.has(str(q["id"])):
			pid = str(q["id"])
			break
	_check(pid != "", "A prospect passed over in this National Draft is on the sheet")
	if sheet == null or pid == "":
		scene.queue_free()
		return
	var from_line := "passed over in %d" % year
	var who := GameDB.player_display_name(undrafted[pid])
	var said := sheet.find_children("*", "Label", true, false).any(
			func(l): return (l as Label).text.contains(who) and (l as Label).text.contains(from_line))
	_check(said, "The sheet says he was %s" % from_line)
	var rookies_before := RookieList.rookie_count(gs.my_list)
	var btn := sheet.find_child("RookiePick_%s" % pid, true, false) as Button
	_check(btn != null and not btn.disabled, "He has a Pick button")
	var why: String = await Tap.tap(btn)
	_check(why == "", "A real tap on Pick reaches it (%s)" % why)
	await _settle()
	var mine := RookieList._find(gs.my_list, pid)
	_check(not mine.is_empty() and RookieList.is_rookie(mine), "He joins your rookie list")
	_check(RookieList.rookie_count(gs.my_list) == rookies_before + 1, "He takes one rookie spot")
	_check(int(mine.get("salary", 0)) == RookieList.wage(gs.season_year), "He is on the rookie wage")
	_check(int(mine.get("contract_years", 0)) == RookieList.deal_years(mine),
			"He is on a rookie deal (%d)" % int(mine.get("contract_years", 0)))
	_check(str(gs.drafted_draftees.get(pid, "")) == CLUB and not gs.draftee_pool.has(mine),
			"He leaves the prospect pool as your pick")
	# Pass the rest; the rivals finish the draft by the same rule.
	var guard := 0
	while RookieList.waiting(gs) and guard < 10:
		guard += 1
		var again := scene.get_node_or_null(RookieDraftSheet.NAME)
		var pass_btn: Button = again.find_child("RookiePass", true, false) as Button if again != null else null
		if pass_btn == null:
			RookieList.choose(gs, "")
			break
		await Tap.tap(pass_btn)
		await _settle()
	scene.queue_free()
	await _settle()
	_check(bool(gs.rookie_draft.get("done", false)), "The Rookie Draft runs to its end")
	# AI path: rivals pick up prospects the National Draft passed over.
	var rival_undrafted := (gs.rookie_draft.get("picks", []) as Array).filter(
			func(k): return str(k["club"]) != CLUB and undrafted.has(str(k["id"])))
	_check(rival_undrafted.size() > 0, "Rivals give undrafted prospects a rookie spot too (%d)" % rival_undrafted.size())
	for k in rival_undrafted:
		var q := RookieList._find(gs.league_lists.get(str(k["club"]), []), str(k["id"]))
		_check(RookieList.is_rookie(q) and int(q.get("salary", 0)) == RookieList.wage(gs.season_year)
				and str(gs.drafted_draftees.get(str(k["id"]), "")) == str(k["club"]),
				"%s: a rival's undrafted pick is on its rookie list on the rookie wage" % str(k["id"]))
		_check(str(k["from"]).begins_with(from_line), "A rival's pick says he was %s (%s)" % [from_line, str(k["from"])])
	# The rookie list limits hold for every club.
	for code in gs.league_lists:
		var arr: Array = gs.league_lists[code]
		_check(RookieList.rookie_count(arr) <= RookieList.CAT_A_SPOTS and arr.size() <= Contracts.MAX_LIST,
				"%s: six rookies and 44 players at most (%d, %d)" % [code, RookieList.rookie_count(arr), arr.size()])
	# Save and load: your undrafted rookie stays yours.
	_check(gs.save_career() and gs.load_career(), "The career saves and loads")
	var back := RookieList._find(gs.my_list, pid)
	_check(not back.is_empty() and RookieList.is_rookie(back)
			and int(back.get("salary", 0)) == RookieList.wage(gs.season_year),
			"After a load he is still on your rookie list on the rookie wage")
	_check(not MidseasonDraft.pool(gs).any(func(q): return str(q["id"]) == pid), "...and out of the pool")
	_check((gs.rookie_draft.get("picks", []) as Array).any(
			func(k): return str(k["id"]) == pid and str(k["club"]) == CLUB),
			"...and the Rookie Draft record keeps your pick")


## Bug-bash 1 (2026-11-10): a signing or a trade lands a player on the senior
## list, so it needs a senior spot (38), not a spot anywhere on the 44. A club
## with 38 seniors and a free rookie spot cannot sign a free agent or take more
## seniors than it gives in a trade; every club, rivals too.
func _set_seniors(code: String, n: int) -> Array:
	var list: Array = gs.season.lists[code]
	var donors: Array = gs.season.lists["STK" if code != "STK" else "GEE"]
	while RookieList.rookie_count(list) >= RookieList.CAT_A_SPOTS:
		for q in list:
			if RookieList.is_rookie(q):
				list.erase(q)
				break
	while RookieList.senior_count(list) > n:
		for q in list:
			if not RookieList.is_rookie(q):
				list.erase(q)
				break
	while RookieList.senior_count(list) < n:
		var q: Dictionary = donors.pop_back()
		q.erase("rookie_list")
		q["club"] = code
		list.append(q)
	return list


func _test_arrivals_need_senior_spot() -> void:
	_new_career()
	gs.season.round_index = gs.season.fixture.size()
	gs.offseason_year = gs.season_year
	_check(gs.offseason_open(), "(setup) the off-season is open")
	gs.salary_cap += 50000000
	var mine := _set_seniors(CLUB, RookieList.SENIOR_SPOTS)
	_check(mine.size() < Contracts.MAX_LIST and RookieList.senior_count(mine) == RookieList.SENIOR_SPOTS,
			"(setup) your senior list is full (%d), your list is not (%d)" % [RookieList.senior_count(mine), mine.size()])
	var gee: Array = gs.season.lists["GEE"]
	var fa: Dictionary = gee[gee.size() - 1]
	gs._release("GEE", fa, false, false)
	_check(gs.free_agents.has(fa), "(setup) a free agent")
	var r: Dictionary = gs.offer_free_agent(str(fa["id"]), Contracts.asking_salary(fa), 2)
	_check(not bool(r["ok"]) and str(r["reason"]).contains("senior list is full"),
			"Free agency: no offer with 38 seniors (%s)" % str(r.get("reason", "")))
	# He decides: your standing offer cannot be honoured; the rival's can.
	var rival := "MEL"
	_set_seniors(rival, RookieList.SENIOR_SPOTS - 1)
	fa["offers"] = [{"club": CLUB, "salary": Contracts.SENIOR_MIN_2027 * 3, "years": 2, "role": "ground", "finish_t": 0.5},
			{"club": rival, "salary": Contracts.SENIOR_MIN_2027, "years": 1, "role": "depth", "finish_t": 0.5}]
	var went: String = gs._decide_fa(fa)
	_check(went == rival and RookieList.senior_count(mine) == RookieList.SENIOR_SPOTS,
			"Free agency: he cannot sign onto your full senior list (went to %s)" % went)
	# A rival with 38 seniors and a free rookie spot is out of the market too.
	var full_rival := _set_seniors(rival, RookieList.SENIOR_SPOTS)
	var fa2: Dictionary = gee[gee.size() - 1]
	gs._release("GEE", fa2, false, false)
	fa2["offers"] = [{"club": rival, "salary": Contracts.SENIOR_MIN_2027, "years": 1, "role": "depth", "finish_t": 0.5}]
	_check(gs._decide_fa(fa2) == "" and RookieList.senior_count(full_rival) == RookieList.SENIOR_SPOTS,
			"Free agency: a rival with 38 seniors cannot sign him either")
	# Trades: two of theirs for one of your rookies takes your seniors past 38.
	var rk := {}
	for q in mine:
		if RookieList.is_rookie(q):
			rk = q
			break
	if rk.is_empty():
		rk = mine[mine.size() - 1]
		rk["rookie_list"] = "A"
		mine.erase(rk)
		mine.append(rk)
		_set_seniors(CLUB, RookieList.SENIOR_SPOTS)
	gee = _set_seniors("GEE", 36)
	var two := [gee[0], gee[1]]
	var v := Contracts.evaluate_trade(gee, two, [rk], 1 << 40, mine, 1 << 40, 0.0, {"name": "Geelong"})
	_check(not bool(v["ok"]) and str(v["code"]) == "trade_senior_over",
			"Trades: two seniors in for a rookie past 38 seniors is refused (%s)" % str(v.get("code", "")))
	var sen := {}
	for q in mine:
		if not RookieList.is_rookie(q):
			sen = q
			break
	var v2 := Contracts.evaluate_trade(gee, [gee[0]], [sen], 1 << 40, mine, 1 << 40, 0.0, {"name": "Geelong"})
	_check(str(v2["code"]) != "trade_senior_over", "Trades: a senior for a senior at 38 is not blocked by the senior list")
	# A list over the 44 (West Coast's start: its real 43 on the senior and
	# Category A lists plus three tied prospects, 46) can still trade one for one, never take on more; a
	# Category B rookie is outside the 44.
	var over: Array = []
	for i in 46:
		var q: Dictionary = (gee[i % gee.size()] as Dictionary).duplicate(true)
		q["id"] = "over_%d" % i
		if i >= 36:
			q["rookie_list"] = "A"
		else:
			q.erase("rookie_list")
		over.append(q)
	var one := Contracts.evaluate_trade(over, [over[0]], [sen], 1 << 40, mine, 1 << 40, 0.0, {"name": "West Coast"})
	_check(str(one["code"]) != "trade_list_over",
			"Trades: a club over the 44 can still trade one for one (%s)" % str(one.get("code", "")))
	var grow := Contracts.evaluate_trade(over, [over[0]], [sen, mine.filter(func(q): return q != sen)[0]], 1 << 40, mine, 1 << 40, 0.0, {"name": "West Coast"})
	_check(str(grow["code"]) == "trade_list_over",
			"Trades: a club over the 44 cannot take on more players (%s)" % str(grow.get("code", "")))
	# 36 seniors and seven rookies, two of them Category B: five Category A,
	# 41 of the 44, so a Category A spot is free.
	var mixed: Array = over.slice(0, 43)
	for i in 2:
		(mixed[36 + i] as Dictionary)["rookie_list"] = "B"
	_check(RookieList.list_size(mixed) == 41 and RookieList.cat_a_count(mixed) == 5 and RookieList.rookie_spot_free(mixed),
			"Two Category B rookies sit outside the 44 and take no Category A spot (%d of 44)" % RookieList.list_size(mixed))


## The checker's faults on #1443 (2026-11-12): only the senior spots were
## checked, so a club over the 44 could still draft, sign and upgrade its way
## further over. One rule now (RookieList.add_block): a club at or over the 44
## (senior and Category A lists together) adds nobody unless the same move
## takes a player off. `code`'s list is rebuilt as `s` seniors, `a` Category A
## and `b` Category B rookies.
func _shape(code: String, s: int, a: int, b: int) -> Array:
	var list: Array = gs.season.lists[code]
	var model: Array = list.duplicate()
	list.clear()
	for i in s + a + b:
		var q: Dictionary = model[i] if i < model.size() else (model[i % model.size()] as Dictionary).duplicate(true)
		if i >= model.size():
			q["id"] = "%s_shape%d" % [str(q["id"]), i]
		q.erase("rookie_list")
		if i >= s:
			q["rookie_list"] = "A" if i < s + a else "B"
		q["club"] = code
		q["contract_years"] = 3
		list.append(q)
	return list


func _test_the_44_rule() -> void:
	_new_career()
	var over := _shape("GEE", 36, 10, 2)
	var under_s := _shape("COL", 37, 6, 2)
	var under_r := _shape("MEL", 38, 5, 0)
	_check(RookieList.list_size(over) == 46 and RookieList.list_size(under_s) == 43 and RookieList.list_size(under_r) == 43,
			"(setup) clubs at 46, 43 and 43 of the 44 (%d, %d, %d)" % [
				RookieList.list_size(over), RookieList.list_size(under_s), RookieList.list_size(under_r)])
	_check(RookieList.add_block(over, "senior") == "list" and RookieList.add_block(over, "A") == "list"
			and not RookieList.senior_spot_free(over) and not RookieList.rookie_spot_free(over),
			"A club at 46 has no senior spot and no rookie spot, though only 36 of its 38 senior spots are taken")
	_check(RookieList.add_block(under_s, "senior") == "" and RookieList.senior_spot_free(under_s),
			"A club at 43 with a free senior spot can add a senior")
	_check(RookieList.add_block(under_r, "A") == "" and RookieList.rookie_spot_free(under_r),
			"A club at 43 with a free Category A spot can add a rookie")
	var at := _shape("SYD", 36, 8, 0)
	_check(RookieList.add_block(at, "senior") == "list" and RookieList.add_block(at, "senior", "", [at[0]]) == "",
			"A club at exactly 44 adds nobody, unless the same move takes a player off")
	_check(RookieList.block_words(over, "list").contains("holds 46") and RookieList.block_words(over, "list").contains("limit is 44"),
			"The coach is told the count and the limit (%s)" % RookieList.block_words(over, "list"))

	# Upgrades. A Category B rookie joins the 44 when he is upgraded; a
	# Category A rookie is in it already (the same move takes him off the
	# rookie list).
	var b_over: Dictionary = over[47]
	var a_over: Dictionary = over[40]
	_check(RookieList.upgrade_block(gs, "GEE", str(b_over["id"])).contains("limit is 44")
			and not RookieList.upgrade(gs, "GEE", str(b_over["id"])) and RookieList.is_cat_b(b_over),
			"At 46 a Category B rookie cannot be upgraded (%s)" % RookieList.upgrade_block(gs, "GEE", str(b_over["id"])))
	_check(RookieList.upgrade_block(gs, "GEE", str(a_over["id"])) == "",
			"At 46 a Category A rookie can be upgraded: the list is no bigger for it")
	var b_under: Dictionary = under_s[44]
	_check(RookieList.upgrade(gs, "COL", str(b_under["id"])) and RookieList.list_size(under_s) == 44,
			"At 43 a Category B rookie is upgraded, and the club is then at 44 (%d)" % RookieList.list_size(under_s))
	_shape("COL", 37, 6, 2)
	_shape("SYD", 36, 8, 0)
	# Rivals: none upgrades its way past the 44, and no Category B moves up at 46.
	_shape("GEE", 36, 10, 2)
	RookieList.ai_upgrades(gs)
	var geelong: Array = gs.season.lists["GEE"]
	_check(RookieList.list_size(geelong) == 46 and RookieList.cat_b_count(geelong) == 2
			and RookieList.senior_count(geelong) == RookieList.SENIOR_SPOTS,
			"A rival at 46 upgrades Category A rookies into its senior spots and stays at 46 (%d of 44, %d seniors, %d Category B)" % [
				RookieList.list_size(geelong), RookieList.senior_count(geelong), RookieList.cat_b_count(geelong)])
	var bad := PackedStringArray()
	for code in gs.season.lists:
		if RookieList.list_size(gs.season.lists[code]) > maxi(Contracts.MAX_LIST, 46 if str(code) == "GEE" else 0):
			bad.append("%s %d" % [code, RookieList.list_size(gs.season.lists[code])])
	_check(bad.is_empty(), "No rival's upgrades take it past the 44 (%s)" % ", ".join(bad))

	# Rookie Draft and mid-season draft: a seat only with room in the 44.
	_shape("GEE", 36, 5, 0)
	_shape("COL", 38, 5, 0)
	_shape("SYD", 39, 5, 0)
	_check(RookieList.rookie_spot_free(gs.season.lists["COL"]) and RookieList.rookie_spot_free(gs.season.lists["GEE"])
			and not RookieList.rookie_spot_free(gs.season.lists["SYD"]),
			"Rookie Draft: a pick at 41 and at 43, none at 44 with a free Category A spot")
	_shape("GEE", 36, 10, 2)
	_shape(CLUB, 36, 10, 0)
	var year: int = gs.season_year
	var cls: Array = gs.draftee_pool.filter(func(q): return int(q.get("draft_year", year)) == year)
	for i in mini(30, cls.size()):
		(cls[i] as Dictionary)["draft_year"] = year - 1
	MidseasonDraft._record(gs)
	MidseasonDraft._open_draft(gs)
	var order: Array = gs.midseason.get("order", [])
	_check(not order.has("GEE") and not order.has("SYD") and not order.has(CLUB) and order.has("COL"),
			"Mid-season draft: clubs at 46 and 44 have no pick, a club at 43 has one (%s)" % str(order))
	MidseasonDraft.settle(gs)
	_check(RookieList.list_size(gs.season.lists["GEE"]) == 46 and RookieList.list_size(gs.season.lists["COL"]) <= 44,
			"...and after it the 46 is still 46 and the 43 is no more than 44")

	# Free agency: you at 46 cannot offer; he cannot sign with a rival at 46,
	# and can with one at 43.
	gs.season.round_index = gs.season.fixture.size()
	gs.offseason_year = gs.season_year
	gs.salary_cap += 50000000
	var mine := _shape(CLUB, 36, 10, 0)
	_shape("GEE", 36, 10, 2)
	_shape("COL", 37, 6, 2)
	var stk: Array = gs.season.lists["STK"]
	var fa: Dictionary = stk[stk.size() - 1]
	gs._release("STK", fa, false, false)
	var r: Dictionary = gs.offer_free_agent(str(fa["id"]), Contracts.asking_salary(fa), 2)
	_check(not bool(r["ok"]) and str(r["reason"]).contains("holds 46") and str(r["reason"]).contains("limit is 44"),
			"Free agency: no offer from a list of 46, and the reason says so (%s)" % str(r.get("reason", "")))
	fa["offers"] = [{"club": CLUB, "salary": Contracts.SENIOR_MIN_2027 * 3, "years": 2, "role": "ground", "finish_t": 0.5},
			{"club": "GEE", "salary": Contracts.SENIOR_MIN_2027 * 2, "years": 2, "role": "ground", "finish_t": 0.5}]
	_check(gs._decide_fa(fa) == "" and RookieList.list_size(mine) == 46 and RookieList.list_size(gs.season.lists["GEE"]) == 46,
			"Free agency: he signs with neither club at 46")
	fa["offers"] = [{"club": "COL", "salary": Contracts.SENIOR_MIN_2027, "years": 1, "role": "depth", "finish_t": 0.5}]
	_check(gs._decide_fa(fa) == "COL" and RookieList.list_size(gs.season.lists["COL"]) == 44,
			"Free agency: a club at 43 signs him and is then at 44")

	# Trades: one for one still stands at 46, two for one does not.
	var sen: Dictionary = mine[0]
	var gee: Array = gs.season.lists["GEE"]
	var one := Contracts.evaluate_trade(gee, [gee[0]], [sen], 1 << 40, mine, 1 << 40, 0.0, {"name": "Geelong"})
	_check(not str(one["code"]) in ["trade_list_over", "trade_senior_over"],
			"Trades: two clubs at 46 can still trade one for one (%s)" % str(one["code"]))
	var grow := Contracts.evaluate_trade(gee, [gee[0], gee[1]], [sen], 1 << 40, mine, 1 << 40, 0.0, {"name": "Geelong"})
	_check(str(grow["code"]) == "trade_list_over", "Trades: a club at 46 cannot take two for one (%s)" % str(grow["code"]))
	var col: Array = _shape("COL", 37, 6, 0)
	var fit := Contracts.evaluate_trade(col, [col[0]], [mine[0], mine[1]], 1 << 40, mine, 1 << 40, 0.0, {"name": "Collingwood"})
	_check(not str(fit["code"]) in ["trade_list_over", "trade_senior_over"],
			"Trades: a club at 43 can take two for one (%s)" % str(fit["code"]))


## The National Draft under the same rule: a club at 46 passes every pick (the
## coach is told why, in his own club's case), a club at 43 takes one, and a
## father-son or academy player is listed only where the 44 has room.
func _test_the_44_national_draft() -> void:
	_new_career()
	gs.season.round_index = gs.season.fixture.size()
	var year: int = gs.season_year
	_shape(CLUB, 36, 10, 2)
	_shape("GEE", 36, 10, 0)
	_shape("COL", 37, 6, 2)
	# Two prospects tied to clubs: Geelong (46) has no spot for its one,
	# Collingwood (43) lists its one and is then at 44.
	var open_class: Array = gs.draftee_pool.filter(func(q):
		return int(q.get("draft_year", 0)) == year and str(q.get("tied_club", "")) == "")
	_check(open_class.size() >= 4, "(setup) a class to draft (%d)" % open_class.size())
	if open_class.size() < 4:
		return
	var gee_tie: Dictionary = open_class[open_class.size() - 1]
	var col_tie: Dictionary = open_class[open_class.size() - 2]
	var my_tie: Dictionary = open_class[open_class.size() - 3]
	gee_tie["tied_club"] = "GEE"
	gee_tie["tied_type"] = "father_son"
	col_tie["tied_club"] = "COL"
	col_tie["tied_type"] = "father_son"
	my_tie["tied_club"] = CLUB
	my_tie["tied_type"] = "father_son"
	var before: Dictionary = gs.draft_list_spots()
	_check(int(before["open"]) == 0 and bool(before["by_44"]) and int(before["list"]) == 46 and int(before["ties"]) == 0,
			"Before the draft your club at 46 is shown no open spot, by the 44 (%s)" % str(before))
	_check(gs.draft_spots_line().contains("46 of 44"), "...and the brief says which count it is (%s)" % gs.draft_spots_line())
	var sheet := ""
	for line in DraftSpotsSheet.lines(before):
		sheet += str(line[0]) + " "
	_check(sheet.contains("will hold 46 of 44") and sheet.contains("44 on its senior and Category A rookie lists together"),
			"...and so does the sheet before the draft (%s)" % sheet)
	_check(gs.begin_intake_draft(), "(setup) the National Draft opens")
	var draft: Draft = gs.draft
	if draft == null:
		return
	_check(not gs.drafted_draftees.has(str(gee_tie["id"])) and draft.pool.any(func(q): return str(q["id"]) == str(gee_tie["id"])),
			"A club at 46 lists no father-son player: he is in the open draft")
	_check(str(gs.drafted_draftees.get(str(col_tie["id"]), "")) == "COL" and RookieList.list_size(gs.league_lists["COL"]) == 44,
			"A club at 43 lists its father-son player and is then at 44")
	_check(gs.ties_without_a_spot(CLUB).size() == 1 and gs.news.any(func(n): return str(n.get("text", n)).contains("No list spot for")),
			"Your own tied player with no spot is named in the news (%s)" % str(gs.ties_without_a_spot(CLUB)))
	_check(draft.open_spots("GEE") == 0 and draft.open_spots(CLUB) == 0 and draft.open_spots("COL") == 0,
			"Clubs at 46, 46 and 44 have no open spot (%d, %d, %d)" % [draft.open_spots("GEE"), draft.open_spots(CLUB), draft.open_spots("COL")])
	_check(draft.full_at_44(CLUB) and draft.full_words(CLUB).contains("holds 46") and draft.full_words(CLUB).contains("limit is 44"),
			"Your club is told why its picks pass (%s)" % draft.full_words(CLUB))
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.count_for("GEE") == 0 and draft.count_for(CLUB) == 0 and draft.count_for("COL") == 0,
			"No club at or over the 44 made a pick (%d, %d, %d)" % [draft.count_for("GEE"), draft.count_for(CLUB), draft.count_for("COL")])
	var took := 0
	for code in draft.draft_order:
		took += draft.count_for(str(code))
	_check(took > 0, "The clubs with room made their picks (%d)" % took)
	var bad := PackedStringArray()
	for code in draft.list_44:
		if draft.count_for(str(code)) > 0 and draft.list_now(str(code)) > Contracts.MAX_LIST:
			bad.append("%s %d" % [code, draft.list_now(str(code))])
	_check(bad.is_empty(), "No club drafted past the 44 (%s)" % ", ".join(bad))
	if not draft.user_passed.is_empty():
		_check(draft.user_passed_line().contains("limit is 44"), "Your passed picks say why (%s)" % draft.user_passed_line())
	else:
		_check(draft.upcoming_picks(CLUB, 0).is_empty(), "Your club had no pick left to pass")


## A real-lists career under the rule: after the opening National Draft and
## the Rookie Draft no club has grown past the 44, the clubs that started at
## it took nobody, and every club can still pick 22 and a bench.
func _test_the_44_real_lists() -> void:
	gs.reset()
	gs.begin_real_lists()
	var draft: Draft = gs.draft
	_check(draft != null, "A real-lists career opens on the National Draft")
	if draft == null:
		return
	var start := {}
	for code in gs.league_lists:
		start[code] = RookieList.list_size(gs.league_lists[code])
	var wce: Array = gs.league_lists["WCE"]
	var wce_ties: Array = gs.intake_assignments.filter(func(a): return str(a["club"]) == "WCE")
	_check(int(start["WCE"]) == 44 and wce_ties.size() == 1 and draft.open_spots("WCE") == 0,
			"West Coast: its real 43 and the one tied prospect the 44 has room for (%d of 44, %d tied, %d open)" % [
				int(start["WCE"]), wce_ties.size(), draft.open_spots("WCE")])
	_check(gs.ties_without_a_spot("WCE").size() == 2,
			"...and its other two tied prospects are in the open draft (%s)" % str(gs.ties_without_a_spot("WCE")))
	_check(draft.full_at_44("WCE") and draft.full_words("WCE").contains("44"),
			"West Coast's coach is told the 44 is why (%s)" % draft.full_words("WCE"))
	gs.choose_real_club("WCE")
	_check(gs.news.any(func(n): return str(n.get("text", n)).contains("No list spot for")),
			"Taking West Coast, the news names the tied players it had no spot for")
	while not draft.is_finished():
		var candidate := draft._best_ai_pick(draft.current_club())
		if candidate.is_empty() or not draft._draft_pick(draft.current_club(), candidate):
			draft._skip_current_pick()
	_check(draft.count_for("WCE") == 0 and draft.user_passed_line().contains("44"),
			"West Coast's picks pass, and the line says why (%s)" % draft.user_passed_line())
	_check(gs.finish_intake_draft(), "The opening National Draft commits")
	RookieList.settle(gs)
	var bad := PackedStringArray()
	var short := PackedStringArray()
	for code in gs.season.lists:
		var list: Array = gs.season.lists[code]
		if RookieList.list_size(list) > maxi(Contracts.MAX_LIST, int(start.get(code, 0))):
			bad.append("%s %d (started %d)" % [code, RookieList.list_size(list), int(start.get(code, 0))])
		var roles := {"RUCK": 0, "MID": 0, "DEF": 0, "FWD": 0}
		for p in list:
			if roles.has(str(p["role"])):
				roles[str(p["role"])] = int(roles[str(p["role"])]) + 1
		if list.size() < Contracts.min_list() or int(roles["RUCK"]) < 1 or int(roles["MID"]) < 6 \
				or int(roles["DEF"]) < 6 or int(roles["FWD"]) < 6:
			short.append("%s %d %s" % [code, list.size(), str(roles)])
	_check(bad.is_empty(), "No club grew past the 44 through the opening drafts (%s)" % ", ".join(bad))
	_check(short.is_empty(), "Every club can pick 22 and a bench: at least 32 listed, a ruck and six in each line (%s)" % ", ".join(short))


## GWS's real 2026 list has three Category B rookies (Delana, Hamilton,
## Madden: DraftGuru's 2026 and 2027 GWS lists, checked 2026-11-12) against
## the usual two spots. The list screen says so, never "3 / 2" with no reason;
## a club within its two spots still shows them as spots.
func _test_three_category_b_head() -> void:
	_new_career()
	_shape(CLUB, 34, 5, 3)
	var scene: Control = load("res://scenes/ListScene.tscn").instantiate()
	scene.set("_pane", "list")
	root.add_child(scene)
	await _settle()
	var bh := scene.find_child("CatBListHead", true, false) as Label
	var why := scene.find_child("CatBListWhy", true, false) as Label
	_check(bh != null and bh.text.strip_edges().ends_with("rookies  3") and not bh.text.contains("/"),
			"Three Category B rookies show as a count, not as 3 / 2 (%s)" % (bh.text if bh else "none"))
	_check(why != null and why.text.contains("real 2026 list had 3") and why.text.contains("usually has 2"),
			"...and the line under it says why (%s)" % (why.text if why else "none"))
	scene.queue_free()
	await _settle()
	_shape(CLUB, 34, 5, 2)
	scene = load("res://scenes/ListScene.tscn").instantiate()
	scene.set("_pane", "list")
	root.add_child(scene)
	await _settle()
	bh = scene.find_child("CatBListHead", true, false) as Label
	_check(bh != null and bh.text.contains("2 / 2"), "Two Category B rookies show their two spots (%s)" % (bh.text if bh else "none"))
	scene.queue_free()
	await _settle()
