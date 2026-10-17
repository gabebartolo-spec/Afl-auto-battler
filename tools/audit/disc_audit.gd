extends SceneTree
## godot --headless --path . --script tools/audit/disc_audit.gd
## Every home/away pairing of the 18 clubs: how different the two discs are before
## clash selection (the away side in its own kit) and after, and the strip used.
## Prints a markdown table, then the 10 closest pairs after.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	print("start")
	var PV = load("res://scripts/ui/PitchView.gd")
	var gdb = root.get_node("GameDB")
	var order: Array = gdb.CLUB_ORDER.slice(0, 18)
	var rows := []
	for h in order:
		for a in order:
			if h == a:
				continue
			var hk: Dictionary = PV.with_trim(str(h), gdb.club_guernsey(str(h)))
			var ak: Dictionary = PV.with_trim(str(a), gdb.club_guernsey(str(a)))
			var before: float = PV.disc_distance(hk, ak)
			var k: Array = PV.kits_for(str(h), str(a))
			var after: float = PV.disc_distance(k[0], k[1])
			var used := "home kit"
			if bool(k[1].get("clash", false)):
				used = "clash: %s body" % k[1]["base"].to_html(false)
			rows.append([str(h), str(a), before, after, used])
	if "--table" in OS.get_cmdline_user_args():
		print("| Home v away | Before | After | Away strip |\n|---|---|---|---|")
		for r in rows:
			print("| %s v %s | %.0f | %.0f | %s |" % [r[0], r[1], r[2], r[3], r[4]])
	rows.sort_custom(func(x, y): return x[3] < y[3])
	print("CLOSEST 10 AFTER:")
	for i in range(10):
		print("%s v %s before %.1f after %.1f %s" % [rows[i][0], rows[i][1], rows[i][2], rows[i][3], rows[i][4]])
	var swaps := 0
	for r in rows:
		if str(r[4]) != "home kit":
			swaps += 1
	print("pairs %d, clash strips %d, min after %.1f" % [rows.size(), swaps, rows[0][3]])
	quit(0)
