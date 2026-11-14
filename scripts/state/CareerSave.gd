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

## Bump VERSION whenever the save layout changes, and add the step that
## lifts the previous version to upgrade(): an older career is upgraded on
## load, never dropped (T5.Q24).
##   1 -> 2: St Kilda's club code SKN became STK.
const VERSION := 2
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
		"venue", "decided_on_ladder", "extra_time", "scoring"]

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
## Called once per decoded player so a load screen keeps moving. GameState points it at
## Season.beat; naming Season here would pull the autoloads into every runner that names CareerSave.
static var beat_hook := Callable()


## A usable save at `path`, or one to recover it from.
static func exists(path := DEFAULT_PATH) -> bool:
	for p in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if bool(_checked(p)["ok"]):
			return true
	return false


## What a full decode of the file at `path` found: {"ok", "meta"}. The title
## screen asks exists() and read_meta() of the same save; decoding a big
## save is a stall on a phone, so each file is decoded once and the answer
## kept while the file is unchanged (same length and time, and no write
## through this class since).
static var _checks := {}
## Full decodes of a save file for a check (exists, read_meta): tests count them.
static var check_decodes := 0


static func _checked(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		_checks.erase(p)
		return {"ok": false, "meta": {}}
	var stamp := "%d|%d" % [FileAccess.get_modified_time(p), _length(p)]
	var had: Dictionary = _checks.get(p, {})
	if str(had.get("stamp", "")) == stamp:
		return had
	check_decodes += 1
	var blob := _blob_at(p)
	var res := {"stamp": stamp, "ok": not blob.is_empty(), "meta": blob.get("meta", {}) if not blob.is_empty() else {}}
	_checks[p] = res
	return res


static func _length(p: String) -> int:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


static func delete(path := DEFAULT_PATH) -> void:
	_checks.clear()
	for p in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	for i in range(1, HISTORY_MAX + 2):
		if FileAccess.file_exists(_history_path(path, i)):
			DirAccess.remove_absolute(_history_path(path, i))
	if FileAccess.file_exists(path + INDEX_SUFFIX):
		DirAccess.remove_absolute(path + INDEX_SUFFIX)


## Write `state` with a small readable `meta` header. Returns false (and
## leaves any previous save in place) if the file cannot be written.
## `version` is for tests only: write a save as an older build laid it out.
static func write(state: Dictionary, meta: Dictionary, path := DEFAULT_PATH, version := VERSION) -> bool:
	var enc := CareerSave.new()
	var body = enc._encode(state)
	enc._untag()
	return _write_blob({"version": version, "meta": meta, "players": enc._players, "state": body}, path)


## Write an already encoded blob through the safe swap. The save it replaces
## joins the earlier saves first (_keep_history).
static func _write_blob(blob: Dictionary, path: String) -> bool:
	_checks.clear()
	var tmp := path + TEMP_SUFFIX
	var bak := path + BACKUP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("CareerSave: cannot write %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	# The same bytes store_var writes (a 32-bit length, then the encoded
	# value), kept in hand so the check below needs no decode.
	var bytes := var_to_bytes(blob)
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, bytes.size())
	f.store_buffer(head)
	f.store_buffer(bytes)
	f.close()
	# Check it before trusting it: a short or garbled write never replaces a
	# good save. The file must be exactly what was meant to be written (its
	# length and MD5); decoding it back cost a phone seconds on every save.
	if not _wrote(tmp, head, bytes):
		push_warning("CareerSave: %s did not read back; the previous save is kept" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	if fail_at == "after_temp":
		return false
	_keep_history(path, blob.get("meta", {}))
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
	_note_current(path, blob.get("meta", {}))
	return true


static func _wrote(p: String, head: PackedByteArray, bytes: PackedByteArray) -> bool:
	if _length(p) != head.size() + bytes.size():
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(head)
	ctx.update(bytes)
	return ctx.finish().hex_encode() == FileAccess.get_md5(p)


## A pre-made history: the same blob as a save, compressed, behind a small
## header (meta) that can be read without unpacking it.
static func write_packed(state: Dictionary, meta: Dictionary, path: String) -> bool:
	var enc := CareerSave.new()
	var body = enc._encode(state)
	enc._untag()
	var bytes := var_to_bytes({"version": VERSION, "meta": meta, "players": enc._players, "state": body})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(meta)
	f.store_64(bytes.size())
	f.store_buffer(bytes.compress(FileAccess.COMPRESSION_ZSTD))
	f.close()
	return true


static func read_packed_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var meta = f.get_var()
	return meta if meta is Dictionary else {}


static func read_packed(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	f.get_var()
	var raw := f.get_64()
	var packed := f.get_buffer(f.get_length() - f.get_position())
	var blob = bytes_to_var(packed.decompress(raw, FileAccess.COMPRESSION_ZSTD))
	if not (blob is Dictionary) or int((blob as Dictionary).get("version", 0)) != VERSION:
		return {}
	var dec := CareerSave.new()
	dec._players = blob.get("players", {})
	var state = dec._decode(blob.get("state", {}))
	return state if state is Dictionary else {}


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
	# The same order as _read_blob: the newest good save's header.
	for p in [path + TEMP_SUFFIX, path, path + BACKUP_SUFFIX]:
		var c := _checked(p)
		if bool(c["ok"]):
			return (c["meta"] as Dictionary).duplicate(true)
	return {}


## Why there is no usable save at `path`: "" (a usable save, or no file at
## all), "newer" (written by a newer build) or "unreadable" (damaged).
static func problem(path := DEFAULT_PATH) -> String:
	if exists(path):
		return ""
	var found := ""
	for p in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(p):
			continue
		var v := _version_at(p)
		if v > VERSION:
			return "newer"
		found = "unreadable"
	return found


static func _version_at(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var blob = f.get_var()
	f.close()
	return int((blob as Dictionary).get("version", 0)) if blob is Dictionary else 0


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
	if not (blob is Dictionary) or not (blob as Dictionary).has("state"):
		return {}
	return upgrade(blob)


## An older save lifted step by step to VERSION, or {} if no step reaches it
## (a newer build's save, or a version this build never wrote).
static func upgrade(blob: Dictionary) -> Dictionary:
	var v := int(blob.get("version", 0))
	while v < VERSION:
		match v:
			1:
				blob = _migrate_1_to_2(blob)
			_:
				return {}
		v += 1
		blob["version"] = v
	return blob if v == VERSION else {}


## The raw blob, players table included, renamed in place (shared player
## bodies stay shared).
static func _migrate_1_to_2(blob: Dictionary) -> Dictionary:
	migrate_club_codes(blob)
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
## line read those; the ~1,100 others only drive a replay). The full-time
## review also reads the injuries (who was lost, and not "Needs a lift" for
## a man hurt early), the synergies, the key match-ups' contests and
## changes, and for the coach's report each side's plans by quarter and the
## weather (qa, 2026-10-11: they vanished after a reload). The impact ledger
## and the game-plan traits tell full time what each call was worth (row 144).
## "breeze_side" is who kicked with the breeze first, so the reviewed match's flags and
## the board's arrow point the way they did live; a save from before it has no such key
## and its flags take the default end. "weather_start" and "weather_turned_after":
## a day that turned at a break (row 160), for the report's weather line.
const REVIEW_KEYS := ["players", "roster", "team", "quarter_teams",
		"injuries", "synergies", "duels", "duel_changes", "tactics_history", "weather",
		"impact", "impact_by", "plan_traits", "breeze_side", "weather_start", "weather_turned_after"]
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
				# Loading a career decodes thousands of players: the load screen
				# keeps its ball moving between them (draws no random numbers).
				if beat_hook.is_valid():
					beat_hook.call()
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


# ---------------------------------------------------------------------------
# Earlier saves (row 57)
# ---------------------------------------------------------------------------
## How many earlier saves are kept, newest first at <path>.old1.
const HISTORY_MAX := 5
const HISTORY_SUFFIX := ".old"


static func _history_path(path: String, i: int) -> String:
	return "%s%s%d" % [path, HISTORY_SUFFIX, i]


## The headers of the save in place ("current") and of each earlier save
## ("slots", newest first), so neither autosave nor the menu decodes a whole
## career to know what is kept.
const INDEX_SUFFIX := ".old.json"


static func _index(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path + INDEX_SUFFIX)
	var d = JSON.parse_string(txt) if txt != "" else null
	if d is Dictionary and d.get("slots") is Array:
		return d
	# Lost or damaged: rebuild it from the files (slow, once).
	var slots := []
	for i in range(1, HISTORY_MAX + 1):
		var blob := _blob_at(_history_path(path, i))
		if blob.is_empty():
			break
		slots.append(blob.get("meta", {}))
	var cur := _blob_at(path)
	return {"current": cur.get("meta", {}) if not cur.is_empty() else {}, "slots": slots}


static func _save_index(path: String, idx: Dictionary) -> void:
	var f := FileAccess.open(path + INDEX_SUFFIX, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(idx))
		f.close()


## A save that is about to be replaced joins the earlier saves when it marks
## a different point in the career (a new round, stage or year) from the
## newest one kept, so saving twice in one week keeps one point, not two.
static func _keep_history(path: String, incoming: Dictionary = {}) -> void:
	if not FileAccess.file_exists(path):
		return
	var idx := _index(path)
	var cur: Dictionary = idx.get("current", {}) if idx.get("current") is Dictionary else {}
	var slots: Array = idx["slots"]
	# Saving the same point again overwrites it; only a new point keeps the old one.
	if cur.is_empty() or (not incoming.is_empty() and _point(incoming) == _point(cur)):
		return
	if not slots.is_empty() and _point(slots[0]) == _point(cur):
		# Same point: the newer copy of it replaces the older one.
		DirAccess.remove_absolute(_history_path(path, 1))
		slots.remove_at(0)
	else:
		var last := _history_path(path, HISTORY_MAX)
		if FileAccess.file_exists(last):
			DirAccess.remove_absolute(last)
		for i in range(HISTORY_MAX - 1, 0, -1):
			if FileAccess.file_exists(_history_path(path, i)):
				DirAccess.rename_absolute(_history_path(path, i), _history_path(path, i + 1))
		if slots.size() >= HISTORY_MAX:
			slots.resize(HISTORY_MAX - 1)
	if _copy_file(path, _history_path(path, 1)):
		slots.insert(0, cur)
	idx["slots"] = slots
	_save_index(path, idx)


## After a save is in place: the index learns its header.
static func _note_current(path: String, meta: Dictionary) -> void:
	var idx := _index(path)
	idx["current"] = meta
	_save_index(path, idx)


static func _point(meta: Dictionary) -> String:
	# The index is JSON, so a year read back is a float (2027.0): compare as int.
	return "%s|%d|%s" % [meta.get("club", ""), int(meta.get("year", 0)), meta.get("stage", "")]


static func _copy_file(from: String, to: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(from)
	if bytes.is_empty():
		return false
	var f := FileAccess.open(to, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


## The earlier saves that can be restored, newest first: each is its header
## (club, year, stage, saved_at) plus "slot" for restore_history().
static func history(path := DEFAULT_PATH) -> Array:
	var out := []
	var slots: Array = _index(path)["slots"]
	for i in slots.size():
		if not FileAccess.file_exists(_history_path(path, i + 1)) or not (slots[i] is Dictionary):
			continue
		var meta: Dictionary = (slots[i] as Dictionary).duplicate()
		meta["slot"] = i + 1
		out.append(meta)
	return out


## Make earlier save `slot` the career save. The save it replaces becomes the
## newest earlier save, so a restore can itself be undone.
## `before` runs once the earlier save is read and before it is written (the
## game saves the career in memory there, so that is kept too).
static func restore_history(slot: int, path := DEFAULT_PATH, before := Callable()) -> bool:
	# Read first: every write shifts the slots.
	var blob := _blob_at(_history_path(path, slot))
	if blob.is_empty():
		return false
	if before.is_valid():
		before.call()
	return _write_blob(blob, path)


# ---------------------------------------------------------------------------
# The last good save (row T7.R84)
# ---------------------------------------------------------------------------
## Is there a save from before the one in place (the backup every completed
## save leaves)? Only that the file is there: the menu asks on every visit,
## and reading it whole is a stall on a phone. backup() reads it.
static func has_backup(path := DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path + BACKUP_SUFFIX)


## The save from before the one in place: {"ok", "meta"} (club, year, stage,
## saved_at). Not ok when there is none or it cannot be read.
static func backup(path := DEFAULT_PATH) -> Dictionary:
	var c := _checked(path + BACKUP_SUFFIX)
	return {"ok": bool(c["ok"]), "meta": (c["meta"] as Dictionary).duplicate(true)}


## Make the save from before the one in place the career save. The two swap:
## the save it replaces becomes the backup, so restoring again undoes it. A
## damaged save in place is dropped instead (there is nothing in it to keep).
## False, and nothing changed, when the backup cannot be read.
static func restore_backup(path := DEFAULT_PATH) -> bool:
	var blob := _blob_at(path + BACKUP_SUFFIX)
	if blob.is_empty():
		return false
	for p in [path, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(p) and not bool(_checked(p)["ok"]):
			DirAccess.remove_absolute(p)
	return _write_blob(blob, path)


# ---------------------------------------------------------------------------
# Export and import (row 57)
# ---------------------------------------------------------------------------
## Extension of an exported career file. The file is the save itself, so a
## save copied out of user:// by hand imports just the same.
const EXPORT_EXT := "ardsave"


## The bytes of the newest good save, for a file the coach keeps; empty if
## there is no usable save.
static func export_bytes(path := DEFAULT_PATH) -> PackedByteArray:
	for p in [path + TEMP_SUFFIX, path, path + BACKUP_SUFFIX]:
		if not _blob_at(p).is_empty():
			return FileAccess.get_file_as_bytes(p)
	return PackedByteArray()


## Make `bytes` (an exported file) the career save. Returns "" on success,
## "newer" (a newer build wrote it) or "unreadable". The career it replaces
## joins the earlier saves, so an import can be undone with Restore. A bad
## file never touches the save in place.
static func import_bytes(bytes: PackedByteArray, path := DEFAULT_PATH) -> String:
	var probe := path + ".import"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return "unreadable"
	f.store_buffer(bytes)
	f.close()
	_checks.clear()
	var blob := _blob_at(probe)
	var v := _version_at(probe)
	DirAccess.remove_absolute(probe)
	if blob.is_empty():
		return "newer" if v > VERSION else "unreadable"
	return "" if _write_blob(blob, path) else "unreadable"
