extends RefCounted
## Click-to-interact: what the player can do to whatever they click, and the doing of it.
## `options` lists the actions for a menu; `request` performs one, first walking to the target
## if it is out of reach; `update` finishes a pending walk-then-act.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Actions = preload("res://sim/player/player_actions.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const Unarmed = preload("res://sim/player/unarmed.gd")
const Households = preload("res://sim/entities/households.gd")
const Needs = preload("res://sim/entities/needs.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Society = preload("res://sim/factions/society.gd")
const Looting = preload("res://sim/player/looting.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const ITEM_NAMES := {"log": "logs", "plank": "planks", "food": "food", "rye": "rye", "bandage": "bandages", "antiseptic": "antiseptic", "shell": "shells", "shotgun": "shotgun", "tool": "iron tools", "ore": "iron ore"}

static func _opt(id: String, label: String, icon: String, enabled: bool = true, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "icon": icon, "enabled": enabled, "reason": reason}

static func _items(s: Dictionary, id: int) -> Dictionary:
	return s.inventories.get(str(id), {}).get("items", {})

## Menu entries for a target. `icon` names a pictogram drawn by the menu.
static func options(s: Dictionary, id: int) -> Array:
	var result: Array = []
	if not s.entities.has(str(id)): return result
	var e: Dictionary = s.entities[str(id)]
	if id == s.player:
		result.append(_opt("eat", "Eat", "food", Inventory.amount(s, s.player, "food") > 0, "No food"))
		result.append(_opt("drink", "Drink", "drop", Needs.near_water(s), "Stand by a well"))
		result.append(_opt("wardrobe", "Clothing", "shirt"))
		result.append(_opt("inventory", "Inventory", "bag"))
		result.append(_opt("health", "Check wounds", "heart"))
		return result
	match e.get("kind", ""):
		"resident":
			var npc: Dictionary = s.residents.get(str(id), {})
			var down: bool = Brawl.knocked(s, npc) if not npc.is_empty() else false
			var asleep: bool = not npc.get("sleeping", {}).is_empty()
			if down or asleep:
				result.append(_opt("loot", "Search & loot", "hand"))
				if asleep: result.append(_opt("wake", "Wake up", "sun"))
				elif npc.get("knock", {}).get("kind", "") == "fall": result.append(_opt("help_up", "Help up", "hand"))
				else: result.append(_opt("help_up", "Help up", "hand", false, "Unconscious"))
			else:
				result.append(_opt("trade", "Talk / trade", "talk"))
				result.append(_opt("punch", "Punch", "fist"))
				result.append(_opt("shove", "Shove", "fist"))
			if not npc.is_empty() and int(npc.get("bleeding_until", 0)) > s.tick:
				result.append(_opt("bandage", "Bandage wound", "heart", Inventory.amount(s, s.player, "bandage") > 0, "No bandages"))
			result.append(_opt("examine", "Look at", "eye"))
		"tree":
			var logs: int = int(_items(s, id).get("log", 0))
			if logs == 0: result.append(_opt("examine", "Only a stump", "eye"))
			elif e.get("felled", false):
				result.append(_opt("gather", "Gather wood", "log"))
				result.append(_opt("examine", "Look at", "eye"))
			else:
				result.append(_opt("chop", "Chop down", "axe"))
				result.append(_opt("examine", "Look at", "eye"))
		"farm":
			result.append(_opt("harvest", "Harvest", "hand"))
			result.append(_opt("examine", "Check the crop", "eye"))
		"ore":
			var ore: int = int(_items(s, id).get("ore", 0))
			result.append(_opt("mine", "Mine iron ore", "pick", ore > 0, "Nothing left to mine"))
			result.append(_opt("examine", "Look at", "eye"))
		"chest":
			var stored: int = 0
			for count in _items(s, id).values(): stored += int(count)
			result.append(_opt("loot", "Open chest", "chest"))
			result.append(_opt("examine", "Look at", "eye"))
		"stash":
			var items: Dictionary = _items(s, id)
			result.append(_opt("pickup_all", "Pick up everything", "hand", not items.is_empty(), "Nothing here"))
			for item in items:
				if int(items[item]) > 0: result.append(_opt("pickup:" + item, "Pick up %d %s" % [items[item], ITEM_NAMES.get(item, item)], "hand"))
		"warehouse", "market":
			result.append(_opt("trade", "Trade / take supplies", "talk"))
			result.append(_opt("examine", "Look at", "eye"))
		"market_stall":
			result.append(_opt("trade", "Trade", "talk"))
		"office":
			var has_gun: bool = Inventory.amount(s, s.player, "shotgun") > 0
			result.append(_opt("rack", "Return the shotgun" if has_gun else "Take a shotgun", "gun", has_gun or Inventory.amount(s, id, "shotgun") > 0, "The rack is empty"))
			result.append(_opt("examine", "Look at", "eye"))
		"sawmill", "bakery", "forge":
			result.append(_opt("operate", "Use / collect", "hand"))
			result.append(_opt("examine", "Look at", "eye"))
		_:
			result.append(_opt("examine", "Look at", "eye"))
	return result

## One short line under the menu title.
static func subtitle(s: Dictionary, id: int) -> String:
	var e: Dictionary = s.entities.get(str(id), {})
	match e.get("kind", ""):
		"resident":
			var npc: Dictionary = s.residents.get(str(id), {})
			var state := ""
			if Brawl.knocked(s, npc): state = " · knocked down" if npc.get("knock", {}).get("kind", "") == "fall" else " · unconscious"
			elif not npc.get("sleeping", {}).is_empty(): state = " · asleep"
			elif not npc.get("brawl", {}).is_empty(): state = " · angry"
			return String(npc.get("occupation", "Villager")) + state
		"tree":
			var logs: int = int(_items(s, id).get("log", 0))
			return "Stump" if logs == 0 else ("Fallen · %d logs" % logs if e.get("felled", false) else "Standing tree")
		"ore": return "%d iron ore left" % int(_items(s, id).get("ore", 0))
		"stash": return "Dropped items"
	return ""

static func describe(s: Dictionary, id: int) -> String:
	var e: Dictionary = s.entities.get(str(id), {})
	if e.is_empty(): return ""
	match e.get("kind", ""):
		"resident":
			var npc: Dictionary = s.residents.get(str(id), {})
			var mood: String = "calm" if int(npc.get("anger", 0)) < 30 else "angry"
			return "%s, a %s. %s. They look %s. Wearing %s." % [e.name, String(npc.get("occupation", "villager")).to_lower(), npc.get("status", "Resting"), mood, Outfits.describe(s, id)]
		"tree":
			var logs: int = int(_items(s, id).get("log", 0))
			return "%s: %s." % [e.name, "only a stump" if logs == 0 else ("fallen, %d logs to gather" % logs if e.get("felled", false) else "standing, about %d logs of timber" % logs)]
		"ore":
			return "%s: %d iron ore left." % [e.name, int(_items(s, id).get("ore", 0))]
		"farm":
			return "%s." % e.name
	return String(e.name)

## Adjacent cells from which `e` can be worked.
static func _stand_cells(s: Dictionary, e: Dictionary) -> Array:
	var cells: Array = []
	if e.has("rock_rect"):
		var r: Array = e.rock_rect
		for y in range(r[1] - 1, r[1] + r[3] + 1):
			for x in range(r[0] - 1, r[0] + r[2] + 1):
				if x < r[0] or x >= r[0] + r[2] or y < r[1] or y >= r[1] + r[3]: cells.append([x, y])
	elif not e.get("fixtures", []).is_empty():
		cells.append(World.Fixtures.interaction_cell(s, e.id))
	else:
		for offset in [[0, 1], [0, -1], [1, 0], [-1, 0]]: cells.append([e.cell[0] + offset[0], e.cell[1] + offset[1]])
	return cells

## Perform now when in reach, otherwise walk there and perform on arrival.
static func request(sim: RefCounted, id: int, action: String) -> void:
	var s: Dictionary = sim.state
	var pc: Dictionary = s.player_control
	if not s.entities.has(str(id)): return
	var e: Dictionary = s.entities[str(id)]
	pc.pending = {}
	if id == s.player or action in ["examine", "inventory", "health", "wardrobe"] or Actions.near(s, e):
		perform(sim, id, action)
		return
	var from: Array = s.entities[str(s.player)].cell
	var best: Array = []
	var best_distance := 9999
	for cell in _stand_cells(s, e):
		if not World.walkable(s, cell): continue
		var distance: int = absi(cell[0] - from[0]) + absi(cell[1] - from[1])
		if distance < best_distance:
			var route := Nav.request_path(s, from, cell)
			if route.ok:
				best = route.path
				best_distance = distance
				s.player_travel_goal = cell.duplicate()
	if best.is_empty() and best_distance == 9999:
		pc.notice = "You cannot reach %s." % e.name
		return
	s.player_path = best
	pc.pending = {"target": id, "action": action, "since": s.tick, "repath": s.tick + 12}
	pc.notice = "Walking to %s…" % e.name

## Finishes a pending walk-then-act, re-aiming at targets that move.
static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	var pending: Dictionary = s.get("player_control", {}).get("pending", {})
	if pending.is_empty(): return
	var pc: Dictionary = s.player_control
	var id: int = int(pending.target)
	if not s.entities.has(str(id)) or s.tick - int(pending.since) > 900:
		pc.pending = {}
		return
	var e: Dictionary = s.entities[str(id)]
	if Actions.near(s, e):
		s.player_path = []
		pc.pending = {}
		perform(sim, id, str(pending.action))
	elif s.player_path.is_empty() or s.tick >= int(pending.repath):
		pending.repath = s.tick + (5 if pc.get("travel_run", false) else 10)
		var from: Array = s.entities[str(s.player)].cell
		var best: Array = []
		var best_distance := 9999
		for cell in _stand_cells(s, e):
			if not World.walkable(s, cell): continue
			var distance: int = absi(cell[0] - from[0]) + absi(cell[1] - from[1])
			if distance < best_distance:
				var route := Nav.request_path(s, from, cell)
				if route.ok:
					best = route.path
					best_distance = distance
		if best.is_empty() and s.player_path.is_empty(): pc.pending = {}
		elif not best.is_empty(): s.player_path = best

static func perform(sim: RefCounted, id: int, action: String) -> void:
	var s: Dictionary = sim.state
	var pc: Dictionary = s.player_control
	var e: Dictionary = s.entities.get(str(id), {})
	if e.is_empty(): return
	if action.begins_with("pickup:"):
		var item: String = action.substr(7)
		var moved := Inventory.transfer(s, id, s.player, item, mini(Inventory.amount(s, id, item), Inventory.available(s, s.player)))
		pc.notice = "Picked up the %s." % ITEM_NAMES.get(item, item) if moved.ok else "Your pack is full."
		return
	match action:
		"examine": pc.notice = describe(s, id)
		"eat": pc.notice = Needs.eat(s)
		"drink": pc.notice = Needs.drink(s)
		"inventory", "health": pass   # opened by the interface
		"wardrobe": Looting.open(s, s.player, "wardrobe")
		"pickup_all": _take_everything(sim, id)
		"trade", "chop", "gather", "harvest", "mine", "operate", "rack": Actions.interact(sim, id)
		"loot": Looting.open(s, id)
		"help_up":
			var npc: Dictionary = s.residents.get(str(id), {})
			if not npc.is_empty(): Brawl.help_up(s, npc)
			pc.notice = "You help %s to their feet." % e.name
		"wake":
			var sleeper: Dictionary = s.residents.get(str(id), {})
			if not sleeper.is_empty():
				Households.wake(s, sleeper)
				sleeper.anger = mini(100, int(sleeper.get("anger", 0)) + 6)
			pc.notice = "%s wakes up, grumbling." % e.name
		"bandage":
			var patient: Dictionary = s.residents.get(str(id), {})
			if not patient.is_empty() and int(patient.get("bleeding_until", 0)) > s.tick and Inventory.consume(s, s.player, "bandage", 1):
				patient.bleeding_until = 0
				pc.notice = "You bind %s's wound. The bleeding stops." % e.name
			else: pc.notice = "There is nothing to bandage."
		"punch", "shove":
			var from: Array = s.entities[str(s.player)].cell
			var direction: Array = [signi(e.cell[0] - from[0]) * 1000, signi(e.cell[1] - from[1]) * 1000]
			if direction == [0, 0]: direction = [1000, 0]
			Unarmed.begin(s, action, direction)

static func _take_everything(sim: RefCounted, id: int) -> void:
	var s: Dictionary = sim.state
	var pc: Dictionary = s.player_control
	var e: Dictionary = s.entities[str(id)]
	var taken: Array = []
	var items: Dictionary = _items(s, id).duplicate()
	for item in items:
		var amount: int = mini(int(items[item]), Inventory.available(s, s.player))
		if amount > 0 and Inventory.transfer(s, id, s.player, item, amount).ok: taken.append("%d %s" % [amount, ITEM_NAMES.get(item, item)])
	var coins: int = int(s.get("accounts", {}).get(str(id), 0))
	if coins > 0 and s.get("accounts", {}).has(str(s.player)):
		s.accounts[str(id)] -= coins
		s.accounts[str(s.player)] += coins
		taken.append("%d coins" % coins)
	if e.get("kind", "") == "resident" and s.has("factions") and not taken.is_empty(): Society.remember(s, id, "robbed", s.player, "The traveller went through my pockets.", -20)
	pc.notice = ("You take " + ", ".join(taken) + ".") if not taken.is_empty() else "There is nothing to take."
