extends RefCounted
## Played-out sample of generated player-facing text, for the FL-001 copy
## review: plays an autopilot career with career_impl, then prints the league
## news (every kind, deduplicated by wording) and the match-note lines for the
## final round's results. Args after the impl name: policy seed club seasons
## (same as career_impl). Prints only; changes nothing.

func run() -> void:
	var career = load("res://tools/audit/career_impl.gd").new()
	career.run()
	var by_kind := {}
	for n in GameState.news:
		var k := str(n.get("kind", ""))
		if not by_kind.has(k):
			by_kind[k] = []
		(by_kind[k] as Array).append("%s %s | %s" % [str(n.get("year", "")), str(n.get("when", "")), str(n.get("text", ""))])
	for k in by_kind:
		var rows: Array = by_kind[k]
		print("NEWS kind %s: %d lines" % [k, rows.size()])
		var seen := {}
		for r in rows:
			var shape := _shape(str(r))
			if seen.has(shape):
				continue
			seen[shape] = true
			if seen.size() <= 12:
				print("NEWS   " + str(r))
	var shown := 0
	for res in GameState.last_results:
		if shown >= 3:
			break
		shown += 1
		var home := str(res["home"])
		var away := str(res["away"])
		for ev in res.get("events", []):
			var line := MatchNotes.feed_line(ev, home, away)
			if line.is_empty() or str(ev.get("kind", "")) == "goal" or str(ev.get("kind", "")) == "behind":
				continue
			print("FEED %s v %s | %s" % [home, away, str(line["text"])])
		for q in range(1, 5):
			for side in [0, 1]:
				for f in MatchNotes.quarter_facts(res, side, q):
					print("QTR %s v %s q%d side%d | %s" % [home, away, q, side, str(f)])

## The wording with digits and capitalised words blanked, so one template
## prints once however many clubs and players fill it.
func _shape(s: String) -> String:
	var rx := RegEx.new()
	rx.compile("[0-9]+|[A-Z][a-z']+")
	return rx.sub(s, "_", true)
