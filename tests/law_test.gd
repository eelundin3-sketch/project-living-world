extends SceneTree
## The sheriff's office and cell, arrests after a crime (chase, tackle, cuffs, escort, jail),
## being recognised later (gun drawn), surrendering, and running from a standoff.
const Sim = preload("res://sim/core/simulation.gd")
const Law = preload("res://sim/settlement/law.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const Households = preload("res://sim/entities/households.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func setup() -> Array:
	var sim := Sim.new(); sim.start_game()
	var s: Dictionary = sim.state
	s.tick = 14400 + 5400   # mid-morning: everyone is up
	var sheriff: Dictionary = Law.sheriffs(s, 1)[0]
	for npc in s.residents.values():
		npc.sleeping = {}
		npc.goal = ""
		npc.path = []
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	s.entities[str(sheriff.id)].cell = [store[0], store[1] + 5]
	s.entities[str(s.player)].cell = [store[0] + 1, store[1] + 5]
	return [sim, s, sheriff]
func run_until(sim: RefCounted, limit: int, done: Callable) -> int:
	for t in range(limit):
		sim.step()
		if done.call(): return t
	return -1
func _initialize() -> void:
	var made := setup(); var sim: RefCounted = made[0]; var s: Dictionary = made[1]; var sheriff: Dictionary = made[2]
	# The office: a cell with a cot, and a bed for the sheriff.
	var office: Dictionary = Law.office_of(s, 1)
	check(not office.is_empty(), "Every town has a sheriff's office")
	var beds: Array = office.furniture.filter(func(f): return f.kind == "bed")
	check(beds.any(func(f): return f.get("for", "") == "prisoner") and beds.any(func(f): return f.get("for", "") == "sheriff"), "The office has a prisoner's cot and the sheriff's bed")
	check(Households.bed_info(s, sheriff).get("rect", []) == beds.filter(func(f): return f.get("for", "") == "sheriff")[0].rect, "The sheriff sleeps in his office bed")
	for town in ["2", "3"]: check(not Law.office_of(s, int(town)).is_empty(), "Office in town " + town)
	var bed_cells: Dictionary = {}
	for f in office.furniture: bed_cells[f.kind] = true
	check(bed_cells.has("booking_desk") and bed_cells.has("locker") and bed_cells.has("toilet"), "The office has a booking desk, a locker and a toilet")
	check(not Law.in_custody(s) and Law.stage(s) == "", "Free before any arrest")
	# What the player owns before the arrest: it must all come back at release.
	Inventory.produce(s, s.player, "food", 3)
	Inventory.produce(s, s.player, "bandage", 2)
	s.accounts[str(s.player)] = int(s.accounts.get(str(s.player), 0)) + 37
	s.money_initial += 37
	var owned_items: Dictionary = s.inventories[str(s.player)].items.duplicate()
	var owned_coins: int = int(s.accounts[str(s.player)])
	var owned_outfit: Dictionary = Outfits.worn(s, s.player).duplicate()
	# Shove the sheriff: he gives chase, tackles, cuffs and walks the player to the cell.
	sim.submit("player_strike", {"kind": "shove", "direction": [-1000, 0]})
	for t in range(10): sim.step()
	check(Law.wanted_hours(s, 1) >= Law.SENTENCE.assault_sheriff, "Shoving the sheriff is a crime (%d h)" % Law.wanted_hours(s, 1))
	check(str(sheriff.get("arrest", {}).get("phase", "")) == "pursue", "The sheriff comes after you")
	var cuffed := run_until(sim, 900, func(): return Law.restrained(s))
	check(cuffed >= 0, "He catches you and cuffs you")
	var escorted := run_until(sim, 400, func(): return str(sheriff.get("arrest", {}).get("phase", "")) == "escort")
	check(escorted >= 0 and str(sheriff.arrest.dest) == "desk", "Then walks you to the booking desk")
	var booked := run_until(sim, 1500, func(): return str(sheriff.get("arrest", {}).get("phase", "")) == "book")
	check(booked >= 0 and s.entities[str(s.player)].cell == Law.desk_stance(office), "You are standing at the booking desk")
	check(Law.stage(s) == "booking", "The jail reports a booking")
	var searched := run_until(sim, 200, func(): return s.player_control.has("property"))
	check(searched >= 0, "The search empties your pockets")
	check(s.inventories[str(s.player)].items.is_empty() and int(s.accounts[str(s.player)]) == 0, "Items and coins are in the office's keeping")
	check(Checks.validate(s).is_empty(), "Invariants hold during booking: " + str(Checks.validate(s)))
	var dressed := run_until(sim, 200, func(): return Outfits.worn(s, s.player).shirt == Outfits.PRISONER.shirt)
	check(dressed >= 0 and Outfits.worn(s, s.player).hat == "", "The prison uniform goes on")
	var mid := Sim.new(); mid.restore(sim.snapshot())
	check(mid.state_hash() == sim.state_hash(), "Booking survives a reload")
	var walking := run_until(sim, 400, func(): return str(sheriff.get("arrest", {}).get("phase", "")) == "escort")
	check(walking >= 0 and str(sheriff.arrest.dest) == "cell" and bool(office.get("cell_open", false)), "Then to the cell, whose door stands open")
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "An arrest in progress survives a reload")
	var jailed := run_until(sim, 3000, func(): return Law.jailed(s))
	check(jailed >= 0, "You end up in jail")
	check(Law.inside_cell(s, s.entities[str(s.player)].cell), "Inside the cell")
	check(Law.wanted_hours(s, 1) == 0 and not Law.restrained(s), "The slate is wiped and the cuffs come off")
	check(not bool(office.get("cell_open", false)) and Law.stage(s) == "cell", "The cell door is shut")
	var hours: int = int(s.player_control.jail.hours)
	check(hours >= Law.SENTENCE.assault_sheriff, "The sentence fits the crime (%d h)" % hours)
	var here: Array = s.entities[str(s.player)].cell.duplicate()
	var r: Array = s.player_control.jail.rect
	s.entities[str(s.player)].cell = [r[0] + r[2] - 1, r[1] + 7]
	sim.submit("move_player", {"direction": [1, 0]}); sim.step()
	check(Law.inside_cell(s, s.entities[str(s.player)].cell), "The cell door holds")
	var held_hunger: int = int(s.player_needs.hunger)
	for t in range(1500): sim.step()
	check(int(s.player_needs.hunger) == held_hunger, "Hunger holds while jailed (meals provided)")
	s.player_control.jail.until = s.tick + 2
	for t in range(4): sim.step()
	check(not Law.jailed(s), "The sentence runs out")
	var freed := run_until(sim, 4000, func(): return not Law.in_custody(s) and not Law.restrained(s))
	check(freed >= 0, "The sheriff lets you out")
	check(s.inventories[str(s.player)].items == owned_items, "Your belongings are returned: " + str(s.inventories[str(s.player)].items))
	check(int(s.accounts[str(s.player)]) == owned_coins, "Your coins are returned")
	check(Outfits.worn(s, s.player) == owned_outfit, "Your own clothes are back on")
	check(not s.player_control.has("property") and not bool(office.get("cell_open", false)), "The locker is empty and the door is shut")
	check(Checks.validate(s).is_empty(), "Invariants hold: " + str(Checks.validate(s)))
	# Recognised later: the gun comes out; surrender and he walks up and arrests you.
	var made2 := setup(); var sim2: RefCounted = made2[0]; var s2: Dictionary = made2[1]; var sheriff2: Dictionary = made2[2]
	var away2: Array = s2.entities[str(sheriff2.id)].cell
	s2.entities[str(s2.player)].cell = [away2[0] + 40, away2[1]]
	Law.crime(s2, 1, "theft", 0)   # reported, not witnessed: wanted, no chase yet
	check(Law.wanted_hours(s2, 1) > 0 and sheriff2.get("arrest", {}).is_empty(), "A reported crime makes you wanted")
	var cell2: Array = s2.entities[str(sheriff2.id)].cell
	s2.entities[str(s2.player)].cell = [cell2[0] + 6, cell2[1]]
	sim2.step()
	check(str(sheriff2.get("arrest", {}).get("phase", "")) == "standoff", "When he sees you he draws his gun")
	sim2.submit("surrender"); sim2.step()
	check(bool(s2.player_control.get("surrender", false)), "F raises your hands")
	sim2.step()
	check(str(sheriff2.arrest.phase) == "approach", "He walks up to you")
	var cuffed2 := run_until(sim2, 400, func(): return Law.restrained(s2))
	check(cuffed2 >= 0 and not Brawl.player_down(s2), "You are cuffed standing, without a tackle")
	# Run instead and he gives chase.
	var made3 := setup(); var sim3: RefCounted = made3[0]; var s3: Dictionary = made3[1]; var sheriff3: Dictionary = made3[2]
	var away3: Array = s3.entities[str(sheriff3.id)].cell
	s3.entities[str(s3.player)].cell = [away3[0] + 40, away3[1]]
	Law.crime(s3, 1, "theft", 0)
	var cell3: Array = s3.entities[str(sheriff3.id)].cell
	s3.entities[str(s3.player)].cell = [cell3[0] + 6, cell3[1]]
	sim3.step()
	s3.entities[str(s3.player)].cell = [cell3[0] + 30, cell3[1]]
	sim3.step(); sim3.step()
	check(str(sheriff3.arrest.phase) == "pursue", "Running from a standoff makes him chase you")
	print("Law: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
