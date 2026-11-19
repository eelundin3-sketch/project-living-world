extends RefCounted
## Lookups that would otherwise walk every entity in the world (about 6,400 of them, nearly all
## trees). Everything here is derived from the state on demand; nothing is saved, and every
## answer is the same as a full scan in entity-table order (ascending id).
const World = preload("res://sim/world/world_db.gd")
const ACTOR_KINDS: Array[String] = ["resident", "player", "raider"]

## Keys of everyone who can walk: the player, every resident and any raiders, ascending by id.
static func actor_keys(s: Dictionary) -> Array:
	var ids: Array = []
	if s.has("player"): ids.append(int(s.player))
	for key in s.get("residents", {}): ids.append(int(key))
	for key in s.get("local_combat", {}).get("fighters", {}):
		if not s.get("residents", {}).has(key): ids.append(int(key))
	ids.sort()
	var keys: Array = []
	var last: int = -1
	for id in ids:
		if id != last: keys.append(str(id))
		last = id
	return keys

## Ids of actors standing on `cell`, ascending.
static func actors_at(s: Dictionary, cell: Array) -> Array:
	var found: Array = []
	for key in actor_keys(s):
		var entity: Dictionary = s.entities.get(key, {})
		if not entity.is_empty() and entity.get("kind", "") in ACTOR_KINDS and entity.get("cell", []) == cell: found.append(int(entity.id))
	return found
