extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Context = preload("res://sim/player/context_actions.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Invariants = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func ids(options: Array) -> Array:
	return options.map(func(o: Dictionary) -> String: return o.id)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var player: Dictionary = s.entities[str(s.player)]
	var npc: Dictionary = s.residents.values()[0]
	var tree: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "tree" and e.settlement == 1: tree = e; break
	# What the menu offers depends on the target's state.
	check(ids(Context.options(s, npc.id)).has("punch") and ids(Context.options(s, npc.id)).has("trade"), "A standing person can be talked to or punched")
	Brawl.knockdown(s, npc, s.entities[str(npc.id)].cell, "ko", [1000, 0])
	var down_options := ids(Context.options(s, npc.id))
	check(down_options.has("loot") and not down_options.has("punch"), "Someone knocked out can be searched, not punched: " + str(down_options))
	check(ids(Context.options(s, tree.id)).has("chop"), "A standing tree can be chopped")
	tree.felled = true
	check(ids(Context.options(s, tree.id)).has("gather") and not ids(Context.options(s, tree.id)).has("chop"), "A fallen tree can be gathered")
	check(ids(Context.options(s, s.player)).has("eat"), "Clicking yourself offers eat and drink")
	# Looting takes their goods and coins.
	Inventory.produce(s, npc.id, "food", 3)
	var coins_before: int = int(s.accounts[str(s.player)])
	var npc_coins: int = int(s.accounts.get(str(npc.id), 0))
	player.cell = [s.entities[str(npc.id)].cell[0] + 1, s.entities[str(npc.id)].cell[1]]
	var food_before: int = Inventory.amount(s, s.player, "food")
	sim.submit("loot_all", {"target": npc.id}); sim.submit("loot_coins", {"target": npc.id}); sim.step(); sim.step()
	check(Inventory.amount(s, s.player, "food") >= food_before + 3, "Looting moves their food to the player")
	check(int(s.accounts[str(s.player)]) == coins_before + npc_coins, "Looting takes their coins")
	check(Invariants.validate(s).is_empty(), "Invariants hold after looting: " + str(Invariants.validate(s)))
	# Far away: the player walks to the target first, then acts.
	var far := Sim.new(); far.start_game(); var f: Dictionary = far.state
	var ftree: Dictionary = {}
	var nearest := 9999.0
	for e in f.entities.values():
		if e.kind != "tree" or e.settlement != 1 or World.inside_building(f, e.cell) != 0: continue
		var distance: float = Vector2(e.cell[0] - 62, e.cell[1] - 49).length()
		if distance >= 8.0 and distance < nearest: ftree = e; nearest = distance
	var fplayer: Dictionary = f.entities[str(f.player)]
	far.submit("context_action", {"target": ftree.id, "action": "chop"}); far.step()
	check(not f.player_control.pending.is_empty() and not f.player_path.is_empty(), "A far target starts a walk with a pending action")
	var started := false
	for t in range(900):
		for key in f.jobs.keys():
			if f.jobs[key].target == ftree.id: f.jobs.erase(key)  # no villager has claimed this tree
		far.step()
		if not f.player_control.work.is_empty(): started = true; break
	check(started, "On arrival the pending action starts (chopping)")
	for t in range(60): far.step()
	check(ftree.get("felled", false), "The tree is felled by the chop")
	# Mining the big rock in Dustvale yields iron ore.
	var rock: Dictionary = {}
	for e in f.entities.values():
		if e.kind == "ore" and e.get("big", false): rock = e
	check(not rock.is_empty() and Inventory.amount(f, rock.id, "ore") >= 500, "Dustvale has a large iron rock")
	var r: Array = rock.rock_rect
	check(not World.walkable(f, [r[0] + 1, r[1] + 1]), "The big rock blocks the ground it sits on")
	fplayer.cell = [r[0] - 1, r[1] + 1]
	f.player_path = []
	var ore_before: int = Inventory.amount(f, f.player, "ore")
	far.submit("context_action", {"target": rock.id, "action": "mine"}); far.step()
	for t in range(80): far.step()
	check(Inventory.amount(f, f.player, "ore") > ore_before, "Mining the rock gives iron ore")
	# Walking by hand cancels a pending walk.
	far.submit("context_action", {"target": rock.id, "action": "mine"}); far.step()
	fplayer.cell = [100, 100]
	far.submit("move_player", {"direction": [1, 0]}); far.step()
	check(f.player_control.pending.is_empty(), "Moving by hand cancels a click-to-act walk")
	if failures == 0: print("Context actions: PASS")
	quit(failures)
