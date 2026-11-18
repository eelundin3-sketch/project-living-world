extends SceneTree
## A top-down plan of each town's roads, lots and buildings for several seeds (no rendering needed).
const Sim = preload("res://sim/core/simulation.gd")
const TL = preload("res://sim/world/town_layout.gd")
const World = preload("res://sim/world/world_db.gd")
const K := 4   # pixels per cell
const W := 150
const H := 112
func plot(img: Image, origin: Vector2i, cell: Vector2, color: Color) -> void:
	var p := Vector2i((cell - Vector2(origin)) * K)
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() - 1 and p.y < img.get_height() - 1:
		for dy in range(2):
			for dx in range(2): img.set_pixel(p.x + dx, p.y + dy, color)
func rect(img: Image, origin: Vector2i, r: Rect2i, color: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i((x - origin.x) * K, (y - origin.y) * K)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() - K and p.y < img.get_height() - K: img.fill_rect(Rect2i(p, Vector2i(K, K)), color)
func _initialize() -> void:
	var seeds: Array = OS.get_environment("SEEDS").split(",") if OS.get_environment("SEEDS") != "" else ["741", "5", "99"]
	for seed_text in seeds:
		var sim := Sim.new(int(seed_text)); sim.start_game(12)
		var s: Dictionary = sim.state
		var img := Image.create(W * K * 3, H * K, false, Image.FORMAT_RGB8)
		img.fill(Color("1d3524"))
		for t in range(3):
			var key := str(t + 1)
			var centre: Array = s.world.layout[key].centre
			var origin := Vector2i(int(centre[0]) - W / 2, int(centre[1]) - 20)
			var sub := Image.create(W * K, H * K, false, Image.FORMAT_RGB8)
			sub.fill(Color("33503a"))
			for cell_key in TL.road_cells(s):
				var parts: PackedStringArray = cell_key.split(",")
				rect(sub, origin, Rect2i(int(parts[0]), int(parts[1]), 1, 1), Color("4a4636"))
			for segment in TL.segments(s):
				for point in segment.points: plot(sub, origin, Vector2(float(point[0]), float(point[1])), Color("e0c98a"))
			for lot in TL.lots(s, t + 1): plot(sub, origin, Vector2(lot.door[0], lot.door[1]), Color("5ab0d8"))
			for entity in s.entities.values():
				if entity.has("footprint"):
					var r := World.building_rect(entity)
					var color := Color("b87b43") if entity.kind != "home" else Color("d9a35a")
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							if World.building_contains(entity, [x, y]): rect(sub, origin, Rect2i(x, y, 1, 1), color)
					plot(sub, origin, Vector2(entity.cell[0], entity.cell[1]), Color("ff4040"))
			img.blit_rect(sub, Rect2i(0, 0, W * K, H * K), Vector2i(t * W * K, 0))
		img.save_png("res://docs/screenshots/layout-seed-%s.png" % seed_text)
	quit()
