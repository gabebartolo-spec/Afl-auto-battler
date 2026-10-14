class_name StatGuide
extends RefCounted
## The in-game stat guide: one short line per rated stat (what it is and what
## it changes in a match), grouped, plus a few lines on how ratings fit
## together. Kept short on purpose (director, 2026-10-14: "condense it, keep
## only the essential info"). Detail that changes with the engine lives in
## the screens that show it, not here.

## key -> [one line]
const STATS := {
	"disposal": ["Gets the ball in open play. A midfield of good users wins more of the contest."],
	"contested": ["Wins the clearance and holds the ball in a tackle. Your inside mids win or lose the stoppages."],
	"ruck": ["Wins the hit-outs at the bounce and stoppages. Your starting ruck matters."],
	"carry": ["Runs the ball forward. Good carriers through the middle feed your attack."],
	"marking": ["Takes the marks, most of all in contests inside 50. Forwards and key defenders need it."],
	"creating": ["Sets up goals for team-mates and makes better shots for the whole forward line."],
	"goalkicking": ["Gets the shots inside 50 and kicks the goals. The biggest part of your scoring."],
	"accuracy": ["Turns shots into goals instead of behinds."],
	"pressure": ["Tackles and hurries the opposition. The biggest part of your defence."],
	"intercept": ["Reads the play, takes marks in defence and spoils forward entries."],
	"discipline": ["Fewer clangers and free kicks against. Higher is cleaner."],
	"durability": ["Stays on the park. Durable players get hurt less often."],
	"star": ["Match-winning class. Lifts your side at the stoppages and drives a player's overall."],
}

## [heading, [stat keys]] in the order they read.
const GROUPS := [
	["Ball winning", ["disposal", "contested", "ruck"]],
	["Ball use", ["carry", "marking", "creating"]],
	["Scoring", ["goalkicking", "accuracy"]],
	["Defence", ["pressure", "intercept"]],
	["Body and class", ["discipline", "durability", "star"]],
]

const TOPICS := [
	["Overall (OVR)", "A player's rating, mostly the stats his position relies on. It decides selection and draft price."],
	["Potential (POT)", "Where he is projected to peak. A projection, not a limit; growth slows as he nears it."],
	["Team strengths", "Contest is your stoppages, attack your forwards and carry, defence your pressure and intercept."],
	["Traits and synergies", "A standout stat earns a trait. The right mix in a line switches on a synergy; the Team screen shows yours, and says when one is a single player short (\"Lockdown unit: 1 lockdown player short\")."],
	["Injuries and legs", "Every player risks injury each game, less with durability. Tired players win less ball, so rotate in the coach box."],
	["XP and training", "Players earn XP every game and a training plan spends it. A stat costs more the higher it already is, and much more past POT."],
	["Contracts", "After the Grand Final, re-sign or release players, sign free agents and trade."],
]


static func short(key: String) -> String:
	return str((STATS.get(key, [""]) as Array)[0])


static func _label_for(key: String) -> String:
	for row in GameState.TRAIN_STATS:
		if str(row[0]) == key:
			return str(row[1])
	return key


## Open the guide as a modal over `parent`. Returns the overlay so the scene
## can close it from the back button. On a wide screen the groups sit in three
## columns so it fits about one screen; on a phone it is one short scroll.
static func show(parent: Control) -> Control:
	# Columns follow the layout width: a PC window is often only ~570 units
	# wide after the canvas scale, so two columns from 520, three from 760.
	var vw := UiKit.view_width(parent)
	var landscape := not ScreenLayout.is_phone() and vw > UiKit.view_height(parent) * 1.2
	var cols_n := 3 if (landscape and vw >= 760.0) else (2 if (landscape and vw >= 520.0) else 1)
	var wide := cols_n > 1
	var box := UiKit.modal_box(parent, 1100.0 if wide else 720.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "StatGuide"
	UiKit.close_on_outside_tap(box)
	var v: VBoxContainer = box["body"]
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiKit.heading("Stat guide", UiKit.H1))
	var sections: Array = []
	for g in GROUPS:
		var sec := UiKit.vbox(4)
		sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sec.add_child(UiKit.lbl(str(g[0]), UiKit.H2, UiKit.EMPH, true))
		for key in g[1]:
			var item := UiKit.vbox(0)
			item.name = "Guide_" + str(key)
			item.add_child(UiKit.lbl(_label_for(str(key)), UiKit.NAME, UiKit.EMPH, true))
			item.add_child(_para(short(str(key)), 12, UiKit.TEXT))
			sec.add_child(item)
		sections.append(sec)
	var rest := UiKit.vbox(4)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.add_child(UiKit.lbl("How it fits together", UiKit.H2, UiKit.EMPH, true))
	for topic in TOPICS:
		var item := UiKit.vbox(0)
		item.add_child(UiKit.lbl(str(topic[0]), UiKit.NAME, UiKit.EMPH, true))
		item.add_child(_para(str(topic[1]), 12, UiKit.TEXT))
		rest.add_child(item)
	sections.append(rest)
	if wide:
		# Which groups sit in which column (sections 0-4 are the stat groups,
		# 5 is "How it fits together"); the columns come out about as tall.
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 20)
		var layout := [[0, 1], [2, 3, 4], [5]] if cols_n == 3 else [[0, 1, 2, 3], [4, 5]]
		for col in layout:
			var c := UiKit.vbox(8)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in col:
				c.add_child(sections[i])
			cols.add_child(c)
		v.add_child(cols)
	else:
		for s in sections:
			v.add_child(s)
	var ok := UiKit.btn("Got it", UiKit.NAME, true)
	ok.name = "CloseStatGuide"
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(ok)
	return overlay


static func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
