extends RefCounted
## The third settlement: Dustvale, a dry-country town to the south with few, mostly dead trees.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Residents = preload("res://sim/entities/residents.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Market = preload("res://sim/economy/market.gd")
const Crops = preload("res://sim/farming/crops.gd")
const STORE: Array = [122, 128]

static func install(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if s.settlements.has("3"): return
	var store := World.add_entity(sim, "warehouse", "Dustvale exchange", STORE, 3)
	Inventory.create(s, store, 3000)
	Inventory.produce(s, store, "food", 300)
	# No woodland nearby, so the town starts with a stock of timber for its first houses.
	Inventory.produce(s, store, "plank", 120)
	Inventory.produce(s, store, "log", 40)
	var home := World.add_entity(sim, "home", "Dustvale lodge", [104, 122], 3)
	var farm := World.add_entity(sim, "farm", "Dustvale fields", [141, 142], 3)
	Inventory.create(s, farm, 1200)
	Inventory.produce(s, farm, "food", 300)
	Crops.add_plot(s, "field", [135, 139, 12, 6], 3, farm, 0, 15000)
	s.settlements["3"] = {"id": 3, "name": "Dustvale", "warehouse": store, "home": home, "housing": 12,
		"population": 5, "policy": "Balanced", "demand": {}, "fidelity": "coarse", "faction": 3}
	Residents.spawn(sim, 5, 3, [120, 131])
	# The big iron-bearing rock east of the town: the place to mine iron ore. It blocks its cells.
	var rock := World.add_entity(sim, "ore", "Iron-bearing rock", [171, 131], 3)
	Inventory.create(s, rock, 800)
	Inventory.produce(s, rock, "ore", 600)
	s.entities[str(rock)].big = true
	s.entities[str(rock)].pick_radius = 70.0
	s.entities[str(rock)].rock_rect = [169, 129, 5, 4]
	for y in range(129, 133):
		for x in range(169, 174): World.apply_mutation(s, [x, y], true)
	Recipes.add_workshop(sim, 3, [156, 127], store, "forge")
	Recipes.add_workshop(sim, 3, [139, 127], store, "bakery")
	World.populate_forest(sim, 3, 16, STORE)
	Market.add_market(s, 3)
