extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int=0
func check(value: bool,label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)
func command(sim: RefCounted,kind: String,payload: Dictionary = {}) -> void: sim.submit(kind,payload); sim.step()
func _initialize() -> void:
	var sim:=Sim.new(); sim.start_game()
	var s: Dictionary=sim.state
	check(s.player_control.held_quantity==0,"Backpack contents do not automatically occupy hands")
	command(sim,"hold_item",{"item":"food"})
	check(s.player_control.held_quantity==4,"Inventory selects held stack")
	command(sim,"interact")
	check(s.player_control.held_quantity==0 and Inventory.amount(s,s.player,"food")==0,"F puts held goods down")
	command(sim,"interact")
	check(s.player_control.held_quantity==4 and Inventory.amount(s,s.player,"food")==4,"F picks the dropped goods up once")
	command(sim,"hold_item",{"item":""})
	check(s.player_control.held_quantity==0 and Inventory.amount(s,s.player,"food")==4,"Stowing preserves ownership")
	var npc: Dictionary=s.residents.values()[-1]
	s.entities[str(s.player)].cell=s.entities[str(npc.id)].cell.duplicate()
	command(sim,"interact",{"target":npc.id})
	check(s.player_control.ui_target==npc.id,"F opens person interaction")
	var money: int=s.accounts[str(s.player)]
	command(sim,"person_trade",{"target":npc.id,"item":"food","buy":false})
	check(s.accounts[str(s.player)]>money and Inventory.amount(s,npc.id,"food")==1,"Personal trade moves goods and real money")
	var machine_sim:=Sim.new(); machine_sim.start_game()
	var m: Dictionary=machine_sim.state
	for resident in m.residents.values(): m.entities[str(resident.id)].cell=[5+resident.id%10,5]
	var workshop: Dictionary=m.workshops.values()[0]
	m.entities[str(m.player)].cell=World.Fixtures.interaction_cell(m,workshop.id).duplicate()
	Inventory.produce(m,m.player,"log",2)
	command(machine_sim,"hold_item",{"item":"log"})
	command(machine_sim,"interact",{"target":workshop.id})
	check(Inventory.amount(m,workshop.id,"log")==2,"F loads held inputs into machine inventory")
	command(machine_sim,"interact",{"target":workshop.id})
	check(workshop.get("player_operator",0)==m.player,"F starts manual machine operation")
	for tick in range(50): machine_sim.step()
	check(workshop.completed==1 and Inventory.amount(m,workshop.id,"plank")==6,"Manual work commits actual recipe once")
	command(machine_sim,"interact",{"target":workshop.id})
	check(m.player_control.held_item=="plank" and Inventory.amount(m,m.player,"plank")==5,"F collects finished products")
	check(Checks.validate(s).is_empty() and Checks.validate(m).is_empty(),"Interactions conserve materials and currency")
	print("Player interactions: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
