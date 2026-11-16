extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Motion = preload("res://view/world/fixture_director.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	for entity in s.entities.values():
		for fixture in entity.get("fixtures",[]):
			check(World.walkable(s,fixture.stance),"Operator stance is free")
			var approach_cell: Array = entity.cell if entity.kind != "market_stall" else [entity.cell[0], entity.cell[1] + 2]
			check(Nav.request_path(s, approach_cell, fixture.stance).ok,"Operator or customer stance is reachable")
			var r: Array = fixture.rect
			for y in range(r[1],r[1]+r[3]):
				for x in range(r[0],r[0]+r[2]): check(not World.walkable(s,[x,y]),"Machine and pile occupy solid cells")
	var home: Dictionary = s.entities[str(s.home)]
	for furniture in home.furniture:
		check(not World.walkable(s, [furniture.rect[0], furniture.rect[1]]), "Furniture occupies its real footprint")
	var mill: Dictionary = s.entities[str(s.workshops.values()[0].id)]
	check(mill.fixtures.size() == 2 and mill.fixtures[1].kind == "workshop_storage", "Workshop has a separate material rack")
	var store_fixture: Dictionary = s.entities[str(s.warehouse)].fixtures[0]
	var r: Array = store_fixture.rect
	var approach: Array = [r[0],r[1]+r[3]]
	s.entities[str(s.player)].cell=approach.duplicate()
	sim.submit("move_player",{"direction":[0,-1]})
	sim.step()
	check(s.entities[str(s.player)].cell==approach,"Player movement cannot enter a stockpile")
	s.entities[str(s.player)].cell=[62,49]
	var director := Motion.new()
	director.update(s,0,false,1)
	check(director.flights.is_empty(),"No historic transfers on load")
	var store: Dictionary = s.entities[str(s.warehouse)]
	var npc: Dictionary = s.residents.values()[0]
	s.entities[str(npc.id)].cell=store.fixtures[0].stance.duplicate()
	Inventory.produce(s,npc.id,"log",5)
	var before: int = Inventory.amount(s,s.warehouse,"log")
	check(Inventory.transfer(s,npc.id,s.warehouse,"log",5).ok,"Real deposit succeeds")
	director.update(s,0.016,false,1)
	check(Inventory.amount(s,s.warehouse,"log")==before+5 and Inventory.amount(s,npc.id,"log")==0,"Goods belong to the rack's building")
	check(director.flights.size()==1,"One deposit motion for committed transfer")
	var hash_before: String = sim.state_hash()
	var age: float = director.flights[0].age
	director.update(s,1,true,4)
	check(director.flights[0].age==age and sim.state_hash()==hash_before,"Paused machine/item presentation cannot mutate inventory")
	director.update(s,0.016,false,1)
	check(director.flights.size()==1,"Transfer cannot replay")
	var legacy: Dictionary = sim.snapshot()
	legacy.world.erase("fixture_version")
	legacy.world.erase("fixture_cells")
	var goods: Dictionary = legacy.inventories.duplicate(true)
	for entity in legacy.entities.values(): entity.erase("fixtures")
	var restored := Sim.new()
	restored.restore(legacy)
	check(restored.state.inventories==goods,"Legacy fixture upgrade preserves goods")
	var upgraded: String = restored.state_hash()
	restored.restore(restored.snapshot())
	check(restored.state_hash()==upgraded,"Fixture upgrade happens once")
	var worked: bool = false
	var spun: bool = false
	for tick in range(3000):
		sim.step()
		for worker in s.residents.values():
			check(World.walkable(s,s.entities[str(worker.id)].cell),"Worker never stands in a machine or pile")
		for workshop in s.workshops.values():
			if workshop.progress>0:
				worked=true
				var old_phase: float = director.phases.get(str(workshop.id),0)
				director.update(s,0.05,false,1)
				if director.phases.get(str(workshop.id),0)>old_phase: spun=true
	check(worked,"Physical workstation still produces")
	check(spun,"Machine itself animates during attended production")
	var phases: Dictionary = director.phases.duplicate()
	director.update(s,1,true,4)
	check(phases==director.phases,"Machine freezes on pause")
	for workshop in s.workshops.values(): workshop.enabled=false
	director.update(s,0.1,false,1)
	check(phases==director.phases,"Disabled machine stops independently of worker pose")
	print("Fixtures: %s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
