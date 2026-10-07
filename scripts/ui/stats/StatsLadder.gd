class_name StatsLadder
extends RefCounted
## Season stats > Ladder: the full ladder, then the finals once they start.


static func build(host: Control) -> Control:
	var season: Season = GameState.season
	var v := UiKit.vbox(12)
	v.name = "StatsLadder"
	var info := "Home and away complete" if season.is_regular_done() \
			else "After %d of %d rounds" % [season.round_index, Season.REGULAR_ROUNDS]
	v.add_child(UiKit.subtitle(info))
	var p := UiKit.panel(UiKit.PANEL, 12)
	v.add_child(p)
	p.add_child(UiKit.ladder_table(season.ladder_sorted(), GameState.my_club,
			host.call("content_width") - 24.0, 0, true))
	return v
