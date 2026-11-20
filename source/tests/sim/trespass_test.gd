extends SceneTree
## People claim their space: three warnings in someone's home, then thrown out or reported; at
## night only one warning; friends are welcome; shops are fine by day and not at night; leaving
## for a while starts over.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Trespass = preload("res://sim/law/trespass.gd")
const Society = preload("res://sim/factions/society.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _inside(s: Dictionary, building: Dictionary, skip: int = 0) -> Array:
	var f: Array = building.footprint
	var found := 0
	for y in range(f[1] + 1, f[1] + f[3] - 1):
		for x in range(f[0] + 1, f[0] + f[2] - 1):
			if World.walkable(s, [x, y]):
				if found == skip: return [x, y]
				found += 1
	return []

## A home with its owner inside, awake, at `hour`, and the player standing in it.
func _scene(hour: int) -> Array:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + hour * 600
	var home: Dictionary = {}
	var owner: Dictionary = {}
	for household in s.households.values():
		var building: Dictionary = s.entities[str(household.home)]
		if Trespass.kind_of_place(s, building) != "private": continue
		for id in household.members:
			var npc: Dictionary = s.residents.get(str(id), {})
			if not npc.is_empty() and npc.occupation not in ["Child", "Sheriff"]: owner = npc; home = building; break
		if not owner.is_empty(): break
	for npc in s.residents.values():
		npc.sleeping = {}; npc.anger = 0
		if Trespass.building_at(s, s.entities[str(npc.id)].cell).get("id", -1) == home.id and npc.id != owner.id:
			s.entities[str(npc.id)].cell = s.entities[str(s.settlements[str(npc.settlement)].warehouse)].cell.duplicate()
	s.entities[str(owner.id)].cell = _inside(s, home, 0)
	s.entities[str(s.player)].cell = _inside(s, home, 3)
	owner.goal = "rest"; owner.path = []; owner.job = 0
	return [sim, s, home, owner]

func _hold(sim: RefCounted, owner: Dictionary, cell: Array, ticks: int) -> void:
	for i in range(ticks):
		sim.state.entities[str(owner.id)].cell = cell.duplicate()   # keep the owner at home for the test
		owner.impact_until = sim.state.tick + 5                      # (their own routine paused)
		sim.step()

func _initialize() -> void:
	var scene: Array = _scene(12); var sim = scene[0]; var s: Dictionary = scene[1]; var home: Dictionary = scene[2]; var owner: Dictionary = scene[3]
	var spot: Array = s.entities[str(owner.id)].cell.duplicate()
	check(Trespass.kind_of_place(s, home) == "private", "Someone's home is private")
	_hold(sim, owner, spot, 12)
	check(int(s.player_control.get("trespass", {}).get("warnings", 0)) == 1, "Step in uninvited: a first warning")
	check(str(s.player_control.notice).ends_with("wants you out."), "...you are told (%s)" % s.player_control.notice)
	_hold(sim, owner, spot, Trespass.WARN_EVERY * 2 + 10)
	check(int(s.player_control.trespass.warnings) == 3, "Three warnings in all")
	_hold(sim, owner, spot, Trespass.WARN_EVERY + 10)
	check(not owner.get("brawl", {}).is_empty(), "Stay on and an angry householder throws you out")
	# Calmer people fetch the sheriff instead.
	scene = _scene(12); sim = scene[0]; s = scene[1]; home = scene[2]; owner = scene[3]
	spot = s.entities[str(owner.id)].cell.duplicate()
	for i in range(Trespass.WARN_EVERY * 3 + 40):
		owner.anger = 0
		s.entities[str(owner.id)].cell = spot.duplicate()
		owner.impact_until = s.tick + 5
		sim.step()
	check(bool(s.player_control.trespass.get("done", false)) and (not owner.get("reporting", {}).is_empty() or load("res://sim/law/law.gd").wanted_hours(s, int(home.settlement)) > 0), "A calm householder goes for the sheriff")
	# At night there's one warning, then it's over.
	scene = _scene(23); sim = scene[0]; s = scene[1]; home = scene[2]; owner = scene[3]
	spot = s.entities[str(owner.id)].cell.duplicate()
	_hold(sim, owner, spot, Trespass.WARN_EVERY + 20)
	check(bool(s.player_control.get("trespass", {}).get("done", false)) and int(s.player_control.trespass.warnings) == 1, "At night: one warning only")
	# A friend is welcome.
	scene = _scene(12); sim = scene[0]; s = scene[1]; home = scene[2]; owner = scene[3]
	Society.remember(s, int(owner.id), "saved_life", int(s.player), "The stranger saved my life.")
	_hold(sim, owner, s.entities[str(owner.id)].cell.duplicate(), 40)
	check(s.player_control.get("trespass", {}).is_empty(), "A friend is welcome")
	# Shops: open by day, closed at night.
	var bakery: Dictionary = World.of_kind(s, "bakery")[0]
	s.tick = 14400 + 12 * 600
	check(Trespass.kind_of_place(s, bakery) == "", "A bakery at noon is open")
	s.tick = 14400 + 22 * 600
	check(Trespass.kind_of_place(s, bakery) == "closed", "...and closed at ten at night")
	# Leave for a while and it starts over.
	scene = _scene(12); sim = scene[0]; s = scene[1]; home = scene[2]; owner = scene[3]
	spot = s.entities[str(owner.id)].cell.duplicate()
	var inside: Array = s.entities[str(s.player)].cell.duplicate()
	_hold(sim, owner, spot, 160)
	check(int(s.player_control.trespass.warnings) == 2, "Two warnings so far")
	s.entities[str(s.player)].cell = s.entities[str(s.settlements[str(home.settlement)].warehouse)].cell.duplicate()
	s.entities[str(s.player)].cell[1] += 3
	_hold(sim, owner, spot, Trespass.RETURN_TICKS + 20)
	s.entities[str(s.player)].cell = inside
	_hold(sim, owner, spot, 12)
	check(int(s.player_control.trespass.warnings) == 1, "Back after a long while: they start over")
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(100): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Trespass: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
