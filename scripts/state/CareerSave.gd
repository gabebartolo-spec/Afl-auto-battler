class_name CareerSave
extends RefCounted
## The career save file: one Variant blob written with FileAccess.store_var.
##
## Player dictionaries are shared by reference all over a career (the season
## lists, your list, the draft pool and picks, the prospect pool, GameDB's
## generated classes). A plain store_var would load each reference back as a
## separate copy, and training one copy would no longer touch the others. So
## every player dict is written once into a table and referenced by number;
## loading hands back one shared dict per player, exactly as it was.
##
## Arrays are saved by value. The few arrays that are themselves shared (your
## list is the season's list for your club, the league lists are the
## season's) are relinked by GameState after loading.

const VERSION := 1
const DEFAULT_PATH := "user://career.save"

## A reference to an entry in the player table.
const PLAYER_REF := "__player_ref"
## Temporary marker set on a live player dict while it is being written.
const WRITE_TAG := "__save_sid"

## Match results keep only what the ladder, the finals bracket and the season
## review read. The event log (~1,100 events a match), box score and coach
## snapshots only serve the replay of a match you have just watched.
## Derived once from raw stats when the dataset loads (Ratings.derive_all)
## and never read again, so they are not worth half of every player's bytes.
const SKIP_PLAYER_KEYS := ["rates", "norm"]
const RESULT_KEYS := ["home", "away", "score", "goals", "behinds", "quarters",
		"q_goals", "q_behinds", "winner", "margin", "round", "label", "tag",
		"venue", "decided_on_ladder", "extra_time"]

var _players := {}      # sid -> encoded player body (writing) / raw (reading)
var _next_sid := 0
var _tagged: Array = []
var _decoded := {}      # sid -> live player dict (reading)


## The previous good save, kept until the next one is safely in place.
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"
## Tests only: make write() stop at a step ("after_temp": as if the app were
## killed once the new save is written; "after_backup": once the old one has
## been moved aside; "swap": as if moving the new one into place failed).
static var fail_at := ""


## A usable save at `path`, or one to recover it from.
static func exists(path := DEFAULT_PATH) -> bool:
	for p in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if not _blob_at(p).is_empty():
			return true
	return false


static func delete(path := DEFAULT_PATH) -> void:
	for p in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Write `state` with a small readable `meta` header. Returns false (and
## leaves any previous save in place) if the file cannot be written.
static func write(state: Dictionary, meta: Dictionary, path := DEFAULT_PATH) -> bool:
	var enc := CareerSave.new()
	var body = enc._encode(state)
	enc._untag()
	var blob := {"version": VERSION, "meta": meta, "players": enc._players, "state": body}
	var tmp := path + TEMP_SUFFIX
	var bak := path + BACKUP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("CareerSave: cannot write %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(blob)
	f.close()
	# Read it back before trusting it: a short or garbled write never replaces
	# a good save.
	if _blob_at(tmp).is_empty():
		push_warning("CareerSave: %s did not read back; the previous save is kept" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	if fail_at == "after_temp":
		return false
	# Swap: the previous save steps aside as the backup (never deleted first),
	# the new one moves in, and only then is the old backup let go. A failure
	# at any step leaves a good save to read (read() falls back in order).
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var moved := DirAccess.rename_absolute(path, bak)
		if moved != OK:
			push_warning("CareerSave: cannot set the previous save aside (%d); it is kept" % moved)
			DirAccess.remove_absolute(tmp)
			return false
	if fail_at == "after_backup":
		return false
	var err := DirAccess.rename_absolute(tmp, path) if fail_at != "swap" else ERR_CANT_CREATE
	if err != OK:
		push_warning("CareerSave: cannot move %s into place (%d); restoring the previous save" % [tmp, err])
		if FileAccess.file_exists(bak) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(bak, path)
		return false
	return true


## The decoded state, or {} if there is no usable save.
static func read(path := DEFAULT_PATH) -> Dictionary:
	var blob := _read_blob(path)
	if blob.is_empty():
		return {}
	var dec := CareerSave.new()
	dec._players = blob.get("players", {})
	var state = dec._decode(blob.get("state", {}))
	return state if state is Dictionary else {}


## Just the header (club, year, phase) for the main menu.
static func read_meta(path := DEFAULT_PATH) -> Dictionary:
	var blob := _read_blob(path)
	return migrate_club_codes(blob.get("meta", {})) if not blob.is_empty() else {}


## The newest good save. A checked save still waiting in the temp file is
## newer than the file itself (every completed save moves it away), so it
## comes first; then the file; then the previous good save.
static func _read_blob(path: String) -> Dictionary:
	for p in [path + TEMP_SUFFIX, path, path + BACKUP_SUFFIX]:
		var blob := _blob_at(p)
		if not blob.is_empty():
			if p != path:
				push_warning("CareerSave: recovered the career from %s" % p)
			return blob
	return {}


static func _blob_at(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var blob = f.get_var()
	f.close()
	if not (blob is Dictionary) or int((blob as Dictionary).get("version", 0)) != VERSION:
		return {}
	return blob


## Slim copies of match results for the save. Accepts a result, or arrays of
## results nested to any depth (season rounds, finals weeks). `with_box`
## keeps each match's stat lines, packed (StatBook.pack), so every game of
## the season can be opened again after a reload (the Stats patch); a result
## that is already slim keeps the box it has.
static func slim_results(v, with_box := false):
	if v is Array:
		var out := []
		for x in v:
			out.append(slim_results(x, with_box))
		return out
	if v is Dictionary:
		var out := {}
		for k in RESULT_KEYS:
			if (v as Dictionary).has(k):
				out[k] = v[k]
		if with_box:
			if (v as Dictionary).has("players"):
				out["box"] = StatBook.pack(v)
			elif (v as Dictionary).has("box"):
				out["box"] = v["box"]
		return out
	return v


## Your most recent match, kept whole enough to review after a reload: the
## result, both box scores, the rosters, team stats and quarter snapshots,
## and just the scoring and break events (the feed and the "run of goals"
## line read those; the ~1,100 others only drive a replay).
const REVIEW_KEYS := ["players", "roster", "team", "quarter_teams"]
const REVIEW_EVENT_KINDS := ["goal", "behind", "quarter", "final"]


static func review_result(res: Dictionary) -> Dictionary:
	if res.is_empty():
		return {}
	var out: Dictionary = slim_results(res)
	for k in REVIEW_KEYS:
		if res.has(k):
			out[k] = res[k]
	var evs := []
	for e in res.get("events", []):
		if REVIEW_EVENT_KINDS.has(str((e as Dictionary).get("kind", ""))):
			evs.append(e)
	out["events"] = evs
	return out


## Script variables of a RefCounted (Season, Draft) as plain data.
static func object_vars(o: Object) -> Dictionary:
	var out := {}
	for prop in o.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[str(prop["name"])] = o.get(str(prop["name"]))
	return out


static func apply_vars(o: Object, vars: Dictionary) -> void:
	for prop in o.get_property_list():
		var key := str(prop["name"])
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and vars.has(key):
			o.set(key, vars[key])


static func _is_player(d: Dictionary) -> bool:
	return d.has("id") and d.has("attr") and d.has("role")


func _encode(v):
	if v is Dictionary:
		var d: Dictionary = v
		if _is_player(d):
			if not d.has(WRITE_TAG):
				var sid := _next_sid
				_next_sid += 1
				d[WRITE_TAG] = sid
				_tagged.append(d)
				var body := {}
				for k in d:
					if k != WRITE_TAG and not SKIP_PLAYER_KEYS.has(k):
						var x = d[k]
						body[k] = _encode(x) if _is_container(x) else x
				_players[sid] = body
			return {PLAYER_REF: int(d[WRITE_TAG])}
		var out := {}
		for k in d:
			var x = d[k]
			out[k] = _encode(x) if _is_container(x) else x
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_encode(x) if _is_container(x) else x)
		return out
	return v


## Most values are numbers and strings; only containers need the recursion.
static func _is_container(x) -> bool:
	var t := typeof(x)
	return t == TYPE_DICTIONARY or t == TYPE_ARRAY


func _untag() -> void:
	for d in _tagged:
		(d as Dictionary).erase(WRITE_TAG)
	_tagged = []


func _decode(v):
	if v is Dictionary:
		var d: Dictionary = v
		if d.size() == 1 and d.has(PLAYER_REF):
			var sid := int(d[PLAYER_REF])
			if not _decoded.has(sid):
				var live := {}
				_decoded[sid] = live
				var raw: Dictionary = _players.get(sid, {})
				for k in raw:
					var x = raw[k]
					live[k] = _decode(x) if _is_container(x) else x
			return _decoded[sid]
		var out := {}
		for k in d:
			var x = d[k]
			out[k] = _decode(x) if _is_container(x) else x
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_decode(x) if _is_container(x) else x)
		return out
	return v


## Club codes that changed after saves were written: old -> new. Every
## standalone occurrence in a save - club keys, club fields and the ids
## built from them ("SKN_13") - moves to the new code on load, so an old
## career keeps the same club, lists, history, fixtures and records.
const RENAMED_CLUBS := {"SKN": "STK"}
static var _code_res: Array = []


static func migrate_club_codes(v: Variant) -> Variant:
	if _code_res.is_empty():
		for old in RENAMED_CLUBS:
			var re := RegEx.new()
			re.compile("(?<![A-Za-z])%s(?![A-Za-z])" % old)
			_code_res.append([re, RENAMED_CLUBS[old]])
	if v is String:
		return _renamed(v)
	# In place: a save shares one player dict between lists, the draft and
	# GameDB, and that sharing must survive. Renaming is idempotent, so a
	# shared dict visited twice is harmless.
	_migrate_in_place(v)
	return v


static func _renamed(s: String) -> String:
	for pair in _code_res:
		s = (pair[0] as RegEx).sub(s, str(pair[1]), true)
	return s


## Packed string arrays (club pairs) are values, so they're replaced, not
## edited in place.
static func _renamed_all(v: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for x in v:
		out.append(_renamed(x))
	return out


static func _migrate_in_place(v: Variant) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		for k in d.keys():
			var val = d[k]
			if val is String:
				d[k] = _renamed(val)
			elif val is PackedStringArray:
				d[k] = _renamed_all(val)
			else:
				_migrate_in_place(val)
			if k is String:
				var nk := _renamed(k)
				if nk != k:
					d[nk] = d[k]
					d.erase(k)
	elif v is Array:
		var a: Array = v
		for idx in range(a.size()):
			if a[idx] is String:
				a[idx] = _renamed(a[idx])
			elif a[idx] is PackedStringArray:
				a[idx] = _renamed_all(a[idx])
			else:
				_migrate_in_place(a[idx])
