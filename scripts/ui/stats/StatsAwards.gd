class_name StatsAwards
extends RefCounted
## Season stats > Awards: the races as they stand (provisional until the
## season's awards are presented).


static func build(_host: Control) -> Control:
	var v := UiKit.vbox(14)
	v.name = "StatsAwards"
	var coleman := race("Coleman Medal", "Coleman", GameState.coleman_leaders(10), "goals", "Goals")
	if coleman != null:
		v.add_child(coleman)
	var coaches := race("Coaches Award", "CoachesAward", GameState.coaches_award_leaders(10), "votes", "Votes")
	if coaches != null:
		v.add_child(coaches)
	return v


## One race: rank, player, club, count. Null before anyone has a count.
static func race(title: String, node: String, leaders: Array, key: String, head: String) -> Control:
	if leaders.is_empty() or int(leaders[0][key]) <= 0:
		return null
	var v := UiKit.vbox(4)
	v.name = node + "Leaders"
	v.add_child(UiKit.section(title))
	var header := UiKit.hbox(10)
	for column in [["Rank", 32], ["Player", 0], ["Club", 72], [head, 48]]:
		var label := UiKit.line(str(column[0]), 12, UiKit.MUTED)
		label.custom_minimum_size.x = float(column[1])
		if column[0] == "Player":
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif column[0] == head:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(label)
	v.add_child(header)
	var rank := 0
	for i in range(leaders.size()):
		var r: Dictionary = leaders[i]
		if int(r[key]) <= 0:
			break
		# Level on the count, level in the race.
		if i == 0 or int(r[key]) != int(leaders[i - 1][key]):
			rank = i + 1
		var h := UiKit.hbox(10)
		h.name = "%s_%d" % [node, i + 1]
		var n := UiKit.line(str(rank), UiKit.BODY, UiKit.MUTED)
		n.custom_minimum_size.x = 32
		h.add_child(n)
		var who := UiKit.ellipsis(GameState.award_name(r), UiKit.NAME, UiKit.TEXT, str(r["club"]) == GameState.my_club)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(who)
		var club := UiKit.ellipsis(GameDB.club_short(str(r["club"])), 14, UiKit.MUTED)
		club.custom_minimum_size.x = 72
		h.add_child(club)
		var c := UiKit.line(str(int(r[key])), 17, UiKit.TEXT, true)
		c.custom_minimum_size.x = 48
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(c)
		v.add_child(h)
	return v
