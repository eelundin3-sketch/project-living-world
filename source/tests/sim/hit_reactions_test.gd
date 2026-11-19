extends SceneTree
## Hit reactions: a blow knocks what you hold out of your hands (it stays in your pack), and a
## hurt arm opens up the shotgun's pattern.
const Sim = preload("res://sim/core/simulation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const BodyHealth = preload("res://sim/combat/body_health.gd")
const PlayerActions = preload("res://sim/player/player_actions.gd")
const Shotgun = preload("res://sim/combat/shotgun.gd")
const Limbs = preload("res://sim/combat/limbs.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

## The widest pellet angle (radians from the aim) of one blast fired east.
func _widest(hurt_arm: bool) -> float:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	if hurt_arm:
		BodyHealth.injure(s, "right_forearm", 30, "bruise")
		Limbs.refresh(s, int(s.player))
	check(Limbs.arms_ok(s, int(s.player)) == 2, "The arm is hurt but still usable")
	s.shotgun.equipped = true; s.shotgun.loaded = 5; s.shotgun.last_shot = -1000; s.shotgun.bloom = 0
	s.shotgun.pellets = []
	check(Shotgun.fire(sim, [1000, 0]), "The gun fires")
	var widest := 0.0
	for pellet in s.shotgun.pellets: widest = maxf(widest, absf(atan2(float(pellet.dy), float(pellet.dx))))
	return widest

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	Inventory.produce(s, s.player, "log", 2)
	PlayerActions.hold(s, "log")
	check(s.player_control.held_item == "log", "Holding logs")
	BodyHealth.injure(s, "left_thigh", 10, "bruise")
	check(s.player_control.held_item == "" and int(s.player_control.held_quantity) == 0, "A blow knocks them out of your hands")
	check(Inventory.amount(s, s.player, "log") == 2, "...and they are still in your pack, nothing lost")
	var steady: float = _widest(false)
	var shaky: float = _widest(true)
	check(shaky > steady * 1.2, "A hurt arm widens the pattern (%.3f against %.3f)" % [shaky, steady])
	print("Hit reactions: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
