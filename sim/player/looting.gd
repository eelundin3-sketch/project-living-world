extends RefCounted
## Searching chests and the knocked-out or sleeping: take goods, coins and worn clothes.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const Actions = preload("res://sim/player/player_actions.gd")
const Society = preload("res://sim/factions/society.gd")

## Whether the player may rummage through this target right now.
static func can_search(s: Dictionary, id: int) -> String:
	var e: Dictionary = s.entities.get(str(id), {})
	if e.is_empty(): return "There is nothing there."
	if not Actions.near(s, e): return "Too far away."
	if e.kind == "chest": return ""
	var npc: Dictionary = s.residents.get(str(id), {})
	if npc.is_empty(): return "You cannot search that."
	if Brawl.knocked(s, npc) or not npc.get("sleeping", {}).is_empty(): return ""
	return "They would not stand for it."

## Opens the loot window: `kind` "loot" for chests and people, "wardrobe" for the player's own clothes.
static func open(s: Dictionary, id: int, kind: String = "loot") -> void:
	var pc: Dictionary = s.player_control
	if kind == "loot":
		var problem := can_search(s, id)
		if not problem.is_empty():
			pc.notice = problem
			return
	pc.ui_target = id
	pc.ui_nonce += 1
	pc.ui_kind = kind

static func _victim_robbed(s: Dictionary, id: int) -> void:
	var npc: Dictionary = s.residents.get(str(id), {})
	if npc.is_empty(): return
	var asleep: bool = not npc.get("sleeping", {}).is_empty() and npc.get("knock", {}).is_empty()
	if asleep:
		# A sleeper only feels the hands in their pockets if you are not sneaking.
		if bool(s.get("player_control", {}).get("crouching", false)):
			s.player_control.notice += " They sleep on."
			return
		var Households = load("res://sim/entities/households.gd")
		var Brawl = load("res://sim/player/brawl.gd")
		Households.wake(s, npc)
		npc.anger = 75
		npc.offences = 2
		npc.last_offence = s.tick
		Brawl.engage(s, npc, "beat")
		s.player_control.notice = "%s wakes up and catches you stealing!" % s.entities[str(id)].name
		if s.has("factions"): Society.remember(s, id, "robbed", s.player, "The traveller went through my things.", -20)
		return
	npc.grudge = true   # they will remember when they come round
	if s.has("factions"): Society.remember(s, id, "robbed", s.player, "The traveller went through my things.", -20)

static func take(s: Dictionary, id: int, item: String) -> void:
	var pc: Dictionary = s.player_control
	var problem := can_search(s, id)
	if not problem.is_empty(): pc.notice = problem; return
	var amount: int = mini(Inventory.amount(s, id, item), Inventory.available(s, s.player))
	if amount <= 0: pc.notice = "Your pack is full." if Inventory.amount(s, id, item) > 0 else "It is gone."; return
	Inventory.transfer(s, id, s.player, item, amount)
	pc.notice = "Took %s." % Outfits.label(item).to_lower()
	if s.entities[str(id)].kind != "chest": _victim_robbed(s, id)

static func take_all(s: Dictionary, id: int) -> void:
	var pc: Dictionary = s.player_control
	var problem := can_search(s, id)
	if not problem.is_empty(): pc.notice = problem; return
	var moved := 0
	for item in s.inventories[str(id)].items.keys():
		var amount: int = mini(Inventory.amount(s, id, item), Inventory.available(s, s.player))
		if amount > 0 and Inventory.transfer(s, id, s.player, item, amount).ok: moved += amount
	pc.notice = "Took everything (%d items)." % moved if moved > 0 else "Nothing to take, or your pack is full."
	if moved > 0 and s.entities[str(id)].kind != "chest": _victim_robbed(s, id)

static func take_coins(s: Dictionary, id: int) -> void:
	var pc: Dictionary = s.player_control
	var problem := can_search(s, id)
	if not problem.is_empty(): pc.notice = problem; return
	var coins: int = int(s.get("accounts", {}).get(str(id), 0))
	if coins <= 0: pc.notice = "No coins."; return
	s.accounts[str(id)] -= coins
	s.accounts[str(s.player)] += coins
	pc.notice = "Took %d coins." % coins
	_victim_robbed(s, id)

## Takes a piece of clothing off someone who cannot stop you; optionally puts it on yourself at once.
static func strip(s: Dictionary, id: int, slot: String, wear_it: bool) -> void:
	var pc: Dictionary = s.player_control
	var problem := can_search(s, id)
	if not problem.is_empty(): pc.notice = problem; return
	if s.entities[str(id)].kind == "chest": return
	var item := Outfits.strip(s, id, slot, s.player)
	if item.is_empty(): pc.notice = "They are not wearing that, or your pack is full."; return
	pc.notice = "You take their %s." % Outfits.label(item).to_lower()
	_victim_robbed(s, id)
	if wear_it: wear(s, item)

static func wear(s: Dictionary, item: String) -> void:
	var pc: Dictionary = s.player_control
	var put_on := Outfits.wear(s, s.player, item)
	pc.notice = "You put on the %s." % Outfits.label(put_on).to_lower() if not put_on.is_empty() else "You cannot wear that."

static func take_off(s: Dictionary, slot: String) -> void:
	var pc: Dictionary = s.player_control
	var item := Outfits.take_off(s, s.player, slot)
	pc.notice = "You take off your %s." % Outfits.label(item).to_lower() if not item.is_empty() else "You are not wearing that."
