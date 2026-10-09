class_name PlanTiles
extends RefCounted
## The six game plans as tiles, each with the List profile strength it runs on
## and your list's word for it (director, 2026-10-09: "each strength profile
## marries to a gameplan"). Coaching and the plan chooser on team selection
## show the same tiles. Facts only: nothing says which plan to pick.

## plan -> the List profile strength it runs on (PlanFit.NEEDS = ListProfile's
## Contest, Running power, Pressure and Control). Through stars runs on the
## side's best three; Balanced on nothing in particular.
const PLAN_STRENGTH := {"contest": "contest", "attacking": "running", "defensive": "pressure",
		"controlled": "control"}


## The words of your side as picked, by strength (ListProfile, against the league).
static func words(profile: Array) -> Dictionary:
	var out := {}
	for row in profile:
		out[str(row["dim"])] = str(row["word"])
	return out


static func strength_line(key: String, words_by_dim: Dictionary, ground: Array) -> String:
	if PLAN_STRENGTH.has(key):
		var dim := str(PLAN_STRENGTH[key])
		return "%s · %s" % [ListProfile.LABEL[dim], str(words_by_dim.get(dim, ""))]
	if key == "through_stars":
		var e := PlanFit.edge(ground, "through_stars")
		var w := "Elite" if e >= 1.2 else ("Strong" if e >= 0.4 else ("Average" if e > -0.4 else "Weak"))
		return "Best three · %s" % w
	return "Plays it straight"


## A grid named "ClubPlan" of tiles "ClubPlan_<key>" (the plan, then its
## strength). A tap makes that plan the club's and calls on_pick(key).
static func grid(columns: int, ground: Array, profile: Array, on_pick: Callable = Callable()) -> GridContainer:
	var g := GridContainer.new()
	g.name = "ClubPlan"
	g.columns = columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var by_dim := words(profile)
	var tiles := {}
	var paint := func() -> void:
		var ink := UiKit.ink_on(UiKit.team_colour())
		for k in tiles:
			var on: bool = str(k) == GameState.club_plan
			var t: Button = tiles[k]
			UiKit.paint_choice(t, on)
			(t.find_child("Plan", true, false) as Label).add_theme_color_override("font_color", ink if on else UiKit.TEXT)
			(t.find_child("Strength", true, false) as Label).add_theme_color_override("font_color",
					Color(ink, 0.85) if on else UiKit.MUTED)
	for key in GameState.CLUB_PLANS:
		var k := str(key)
		var t := Button.new()
		t.name = "ClubPlan_%s" % k
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0, 56)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.tooltip_text = CoachReport.plan_label(k)
		var face := UiKit.vbox(0)
		face.alignment = BoxContainer.ALIGNMENT_CENTER
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := UiKit.ellipsis(CoachReport.plan_label(k), 14, UiKit.TEXT, true)
		name_l.name = "Plan"
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(name_l)
		var str_l := UiKit.ellipsis(strength_line(k, by_dim, ground), 12, UiKit.MUTED)
		str_l.name = "Strength"
		str_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		str_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(str_l)
		t.add_child(face)
		t.pressed.connect(func():
			GameState.set_club_plan(k)
			paint.call()
			if on_pick.is_valid():
				on_pick.call(k))
		tiles[k] = t
		g.add_child(t)
	paint.call()
	return g
