extends SceneTree
## Travel to a town from the map: the player walks there by themself along the roads, arrives on
## the street in front of the storehouse, and any step of their own takes over again.
const Sim = preload("res://sim/core/simulation.gd")
const TownLayout = preload("res://sim/world/town_layout.gd")
const Law = preload("res://sim/law/law.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var reedbank: Dictionary = s.settlements["2"]
	var store: Array = s.entities[str(reedbank.warehouse)].cell
	sim.submit("travel", {"town": 2}); sim.step()
	check(int(s.player_control.get("travelling", 0)) == 2 and not s.player_path.is_empty(), "Travel to Reedbank sets off: " + str(s.player_control.notice))
	var route: Array = s.player_path.duplicate()
	var on_road := 0
	for cell in route: if TownLayout.on_road(s, cell): on_road += 1
	check(on_road * 100 >= route.size() * 80, "The way there keeps to the roads (%d of %d cells)" % [on_road, route.size()])
	# Save and load halfway: the walk continues exactly.
	for i in range(300): sim.step()
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(200): sim.step(); copy.step()
	check(copy.state_hash() == sim.state_hash(), "A travel survives a reload")
	for i in range(3000):
		sim.step()
		if int(s.player_control.get("travelling", 0)) == 0: break
	var here: Array = s.entities[str(s.player)].cell
	check(absi(here[0] - store[0]) <= 3 and absi(here[1] - (store[1] + 2)) <= 3, "The player arrives in front of Reedbank's storehouse (%s)" % str(here))
	check(String(s.player_control.notice).contains("arrive"), "Arriving says so: " + str(s.player_control.notice))
	# A step of your own takes over.
	sim.submit("travel", {"town": 1}); sim.step()
	for i in range(20): sim.step()
	check(int(s.player_control.travelling) == 1, "Travelling back to Alder Hollow")
	sim.submit("move_player", {"direction": [0, 1]}); sim.step()
	check(int(s.player_control.travelling) == 0 and s.player_path.is_empty(), "Moving by hand ends the travel")
	# Locked up: no travel.
	var office: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "office": office = e; break
	s.player_control.jail = {"office": office.id, "until": s.tick + 6000, "hours": 10, "rect": Law.cell_rect(office), "sheriff": 0, "town": 1, "crimes": []}
	sim.submit("travel", {"town": 3}); sim.step()
	check(int(s.player_control.get("travelling", 0)) == 0 and s.player_path.is_empty(), "A prisoner cannot travel")
	print("Auto travel: %s; %d cells to Reedbank" % ["PASS" if failures == 0 else "FAIL", route.size()])
	quit(failures)
