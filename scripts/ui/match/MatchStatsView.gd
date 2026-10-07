class_name MatchStatsView
extends VBoxContainer
## The match in numbers, one design for every break and full time (director's
## PC playtest, 2026-10-07: the old page spread three columns across the whole
## screen and made you scroll through the team totals to reach the players).
## Team stats and player stats are a tab apart; the team numbers sit in small
## groups with each value beside its label, as many groups across as the
## width holds. A scope picks the match so far or any single quarter played.
## Reads a match result (finished or at a break); changes nothing.

## Team comparison groups: [title, [[stat key, label], ...]].
const GROUPS := [
	["Possession", [["disposals", "Disposals"], ["kicks", "Kicks"], ["handballs", "Handballs"],
			["marks", "Marks"], ["chains", "Possession chains"]]],
	["Stoppages", [["clearances", "Clearances"], ["hitouts", "Hit-outs"],
			["hitouts_adv", "Hit-outs to advantage"]]],
	["Territory", [["inside50", "Inside 50s"], ["rebounds", "Rebound 50s"]]],
	["Pressure", [["pressure_acts", "Pressure acts"], ["pressure_rating", "Pressure rating"],
			["tackles", "Tackles"], ["one_percenters", "One percenters"]]],
	["Discipline", [["frees_for", "Frees for"], ["frees_against", "Frees against"],
			["clangers", "Clangers"]]],
]
const GROUP_W := 300.0

var _res: Dictionary
var _me := 0
var _view := "team"
var _scope := "all"      # "all" or the quarter number as a string
var _live := false        # at a break: the match so far


func setup(res: Dictionary, my_side: int, live := false) -> MatchStatsView:
	_res = res
	_me = my_side
	_live = live
	add_theme_constant_override("separation", 8)
	_build()
	return self


func _quarters() -> Array:
	return _res.get("quarter_teams", [])


func _build() -> void:
	UiKit.clear(self)
	# Scope: the match so far, or one quarter on its own. Offered once a
	# second quarter exists to tell apart.
	var qs := _quarters()
	if qs.size() >= 2:
		var opts := [["all", "So far" if _live else "Whole match"]]
		for i in range(qs.size()):
			opts.append([str(i + 1), "Q%d" % (i + 1) if i < 4 else "ET"])
		var scope := UiKit.choice_grid("StatsScope", opts, _scope, opts.size(), func(k):
			_scope = str(k)
			_build.call_deferred())
		add_child(scope)
	var tabs := UiKit.hbox(2)
	tabs.name = "StatsViews"
	add_child(tabs)
	for t in [["team", "Team stats"], ["players", "Player stats"]]:
		var key := str(t[0])
		var b := UiKit.tab(str(t[1]), key == _view)
		b.name = "StatsView_" + key
		b.custom_minimum_size.y = 44
		b.pressed.connect(func():
			_view = key
			_build.call_deferred())
		tabs.add_child(b)
	var res := scoped(_res, _scope)
	if _view == "team":
		add_child(_team(res))
	else:
		add_child(PlayerStatsTable.new().setup(res, _me, UiKit.view_width(self) >= 900.0))


## The result as one quarter saw it: the team and player numbers between the
## end of the quarter before and the end of this one. "all" is the result.
static func scoped(res: Dictionary, scope: String) -> Dictionary:
	var qs: Array = res.get("quarter_teams", [])
	if scope == "all" or not scope.is_valid_int():
		return res
	var i := int(scope) - 1
	if i < 0 or i >= qs.size():
		return res
	var cur: Dictionary = qs[i]
	var prev: Dictionary = qs[i - 1] if i > 0 else {}
	var out := res.duplicate(false)
	var team := []
	for side in [0, 1]:
		team.append(_minus((cur["team"] as Array)[side],
				(prev["team"] as Array)[side] if not prev.is_empty() else {}))
	out["team"] = team
	var players := {}
	var before: Dictionary = prev.get("players", {})
	for id in cur.get("players", {}):
		players[id] = _minus(cur["players"][id], before.get(id, {}))
	out["players"] = players
	return out


static func _minus(now: Dictionary, was: Dictionary) -> Dictionary:
	var out := {}
	for k in now:
		var v = now[k]
		if v is float or v is int:
			out[k] = float(v) - float(was.get(k, 0.0))
		else:
			out[k] = v
	return out


func _team(res: Dictionary) -> Control:
	var codes := [str(res["home"]), str(res["away"])]
	var t: Array = res["team"]
	var cols := clampi(int(UiKit.view_width(self) / (GROUP_W + 40.0)), 1, GROUPS.size())
	var grid := GridContainer.new()
	grid.name = "TeamStats"
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 14)
	for g in GROUPS:
		var box := UiKit.vbox(2)
		box.name = "Group_" + str(g[0])
		box.custom_minimum_size.x = GROUP_W if cols > 1 else 0.0
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL if cols == 1 else Control.SIZE_FILL
		# Your club on the left, every group, so you never have to look up
		# which column is yours.
		var head := UiKit.hbox(4)
		head.add_child(_cell(GameDB.club_short(codes[_me]), 56, UiKit.TEXT, UiKit.SMALL, true))
		var title := UiKit.ellipsis(str(g[0]), UiKit.SMALL, UiKit.MUTED, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(_cell(GameDB.club_short(codes[1 - _me]), 56, UiKit.TEXT, UiKit.SMALL, true))
		box.add_child(head)
		box.add_child(UiKit.rule())
		for row in g[1]:
			var key := str(row[0])
			var a: int
			var b: int
			if key == "pressure_rating":
				a = MatchSim.pressure_rating(t[_me], t[1 - _me])
				b = MatchSim.pressure_rating(t[1 - _me], t[_me])
			else:
				a = int(round(float(t[_me].get(key, 0.0))))
				b = int(round(float(t[1 - _me].get(key, 0.0))))
			var h := UiKit.hbox(4)
			h.name = "TeamRow_" + key
			# The bigger number in bold: more is not always better (clangers,
			# frees against), so no good/bad colour.
			h.add_child(_cell(str(a), 56, UiKit.TEXT, UiKit.BODY, a > b))
			var lab := UiKit.ellipsis(str(row[1]), UiKit.SMALL, UiKit.MUTED)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lab)
			h.add_child(_cell(str(b), 56, UiKit.TEXT, UiKit.BODY, b > a))
			box.add_child(h)
		grid.add_child(box)
	return grid


func _cell(text: String, w: int, col: Color, fs: int, bold := false) -> Label:
	var l := UiKit.line(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
