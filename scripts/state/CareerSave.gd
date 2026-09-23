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
		"neutral", "decided_on_ladder", "extra_time"]

var _players := {}      # sid -> encoded player body (writing) / raw (reading)
var _next_sid := 0
var _tagged: Array = []
var _decoded := {}      # sid -> live player dict (reading)


static func exists(path := DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete(path := DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Write `state` with a small readable `meta` header. Returns false (and
## leaves any previous save in place) if the file cannot be written.
static func write(state: Dictionary, meta: Dictionary, path := DEFAULT_PATH) -> bool:
	var enc := CareerSave.new()
	var body = enc._encode(state)
	enc._untag()
	var blob := {"version": VERSION, "meta": meta, "players": enc._players, "state": body}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("CareerSave: cannot write %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(blob)
	f.close()
	# Write-then-swap, so a crash mid-write never leaves a half-written save.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("CareerSave: cannot move %s into place (%d)" % [tmp, err])
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
	return blob.get("meta", {}) if not blob.is_empty() else {}


static func _read_blob(path: String) -> Dictionary:
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
## results nested to any depth (season rounds, finals weeks).
static func slim_results(v):
	if v is Array:
		var out := []
		for x in v:
			out.append(slim_results(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in RESULT_KEYS:
			if (v as Dictionary).has(k):
				out[k] = v[k]
		return out
	return v


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
