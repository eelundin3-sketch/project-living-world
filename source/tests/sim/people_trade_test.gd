extends SceneTree
## Trading with people: a keeper who is away from their tent hurries over when the player comes to
## it, trade waits for them, quantities and haggling work; families keep a purse, earn wages, shop
## for food and eat at home.
const Sim = preload("res://sim/core/simulation.gd")
const Stalls = preload("res://sim/economy/stall_service.gd")
const Family = preload("res://sim/entities/family_economy.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 10 * 600   # ten in the morning: everyone is up
	# A tent whose keeper is away.
	var tent: Dictionary = {}
	for e in World.of_kind(s, "market_stall"):
		if e.has("keeper") and int(e.settlement) == 1: tent = e; break
	check(not tent.is_empty(), "Alder Hollow has a keeper's tent")
	var keeper: Dictionary = s.residents[str(tent.keeper)]
	keeper.sleeping = {}
	s.entities[str(keeper.id)].cell = [tent.cell[0] + 14, tent.cell[1] + 6]
	var stance: Array = World.Fixtures.interaction_cell(s, tent.id)
	s.entities[str(s.player)].cell = stance.duplicate()
	sim.submit("interact", {"target": tent.id}); sim.step()
	check(int(s.player_control.get("awaiting", {}).get("keeper", 0)) == int(keeper.id), "The player waits for the keeper: " + str(s.player_control.notice))
	check(not Stalls.staffed(s, tent), "Nobody is behind the counter yet")
	var item: String = tent.sale_items[0]
	var coins: int = int(s.accounts[str(s.player)])
	sim.submit("person_trade", {"target": tent.id, "item": item, "buy": true, "quantity": 1}); sim.step()
	check(int(s.accounts[str(s.player)]) == coins, "No trade before the keeper arrives")
	var ran := false
	var ticks := 0
	for i in range(200):
		sim.step()
		ticks += 1
		if int(keeper.get("running_tick", -1)) == s.tick: ran = true
		if Stalls.staffed(s, tent): break
	check(Stalls.staffed(s, tent), "The keeper reaches the counter")
	check(ran and ticks <= 30, "...hurrying, at a run (%d ticks for about 15 cells)" % ticks)
	check(s.player_control.get("ui_kind", "") == "trade" and int(s.player_control.ui_target) == int(tent.id), "Trading opens when they arrive")
	Inventory.produce(s, tent.id, item, 10) if Inventory.amount(s, tent.id, item) < 6 else null
	var before: int = Inventory.amount(s, s.player, item)
	sim.submit("person_trade", {"target": tent.id, "item": item, "buy": true, "quantity": 5}); sim.step()
	check(Inventory.amount(s, s.player, item) == before + 5, "Buy 5 buys five: " + str(s.player_control.notice))
	# Haggling, once a visit.
	sim.submit("haggle", {"target": tent.id}); sim.step()
	var terms: Dictionary = s.player_control.get("trade_terms", {})
	check(bool(terms.get("haggled", false)) and int(terms.get("pct", 0)) != 0, "Haggling changes the terms: " + str(s.player_control.notice))
	var pct: int = int(terms.pct)
	sim.submit("haggle", {"target": tent.id}); sim.step()
	check(int(s.player_control.trade_terms.pct) == pct, "Only one haggle a visit")
	# Walking away sends the keeper back to work.
	s.entities[str(s.player)].cell = [stance[0] + 30, stance[1]]
	for i in range(100): sim.step()
	check(keeper.get("serving", {}).is_empty(), "The keeper goes back to work when the customer leaves")
	# An asleep keeper cannot come.
	keeper.sleeping = {"lie": [0, 0], "approach": [0, 0], "rot": 0, "bed_rect": [], "night": true, "since": s.tick}
	s.entities[str(s.player)].cell = stance.duplicate()
	sim.submit("interact", {"target": tent.id}); sim.step()
	check(String(s.player_control.notice).contains("asleep"), "A sleeping keeper is not fetched: " + str(s.player_control.notice))
	keeper.sleeping = {}
	# Families: one purse, one surname, wages and shopping.
	var family: Dictionary = {}
	var family_key := ""
	var keys: Array = s.households.keys()
	keys.sort()
	for key in keys:
		if s.households[key].members.size() >= 2: family = s.households[key]; family_key = key; break
	check(not family.is_empty(), "There are families")
	check(s.accounts.has(Family.purse_key(family_key)), "Each family keeps a purse")
	var surname: String = Family.family_name(s, family)
	var shared := 0
	for id in family.members: if String(s.entities[str(id)].name).ends_with(" " + surname): shared += 1
	check(shared >= 2, "Family members share the %s name" % surname)
	var worker: Dictionary = s.residents[str(family.members[0])]
	worker.work_done = 3
	var purse_before: int = Family.purse(s, family_key)
	Family.payday(sim)
	check(Family.purse(s, family_key) >= purse_before + 3 * Family.WAGE, "A day's work is paid into the family purse")
	# An empty pantry: someone goes shopping in the morning and brings food home.
	var home: int = int(family.home)
	s.inventories[str(home)].items.erase("food")
	s.accounts[Family.purse_key(family_key)] = int(s.accounts[Family.purse_key(family_key)]) + 200
	s.accounts[str(s.settlements["1"].warehouse)] = int(s.accounts[str(s.settlements["1"].warehouse)]) - 200
	for npc_id in family.members:
		var npc: Dictionary = s.residents[str(npc_id)]
		npc.job = 0 if npc.job == 0 else npc.job
	while s.tick % 14400 != Family.SHOPPING_TICK - 1: sim.step()
	var stocked := false
	for i in range(2500):
		sim.step()
		if Inventory.amount(s, home, "food") > 0: stocked = true; break
	check(stocked, "The family buys food and stocks the pantry")
	check(Checks.validate(s).is_empty(), "Money and goods are conserved: " + str(Checks.validate(s)))
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(100): sim.step(); copy.step()
	check(copy.state_hash() == sim.state_hash(), "Families and keepers survive a reload")
	print("People and trade: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
