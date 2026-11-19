extends Control
## The pointer shown while a mouse button is held.
##   "fist"  the plain reticle (left button held, ready to punch)
##   "look"  an eye with a fan of chevrons: leaning out of cover to look, no weapon
##   "aim"   a crosshair whose gap opens with the gun's bloom, plus an aim line from the muzzle that
##           stops at the first wall or tree
var active: bool = false
var mode: String = "fist"
var bloom: float = 0.0               # 0..1, how open the crosshair is
var muzzle: Vector2 = Vector2.ZERO   # screen position the aim line starts from
var line_end: Vector2 = Vector2.ZERO # screen position the aim line stops at (the mouse, or a blocker)
var blocked: bool = false
var peeking: bool = false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if not active: return
	var p: Vector2 = get_local_mouse_position()
	var ink := Color("25291f")
	var light := Color("f6e9bd")
	match mode:
		"aim": _draw_aim(p, ink, light)
		"look": _draw_look(p, ink, light)
		_: _draw_fist(p, ink, light)
func _draw_fist(p: Vector2, ink: Color, light: Color) -> void:
	draw_arc(p, 10, 0, TAU, 28, ink, 3.0, true)
	draw_arc(p, 10, 0, TAU, 28, light, 1.5, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(p + direction * 5, p + direction * 15, ink, 4.0, true)
		draw_line(p + direction * 5, p + direction * 15, light, 1.5, true)
func _draw_aim(p: Vector2, ink: Color, light: Color) -> void:
	# The aim line: dotted from the muzzle, red where something solid stops it.
	var to: Vector2 = line_end if blocked else p
	var along := to - muzzle
	var length := along.length()
	if length > 6.0:
		var step := along / length
		var d := 8.0
		while d < length:
			draw_circle(muzzle + step * d, 1.6, ink)
			draw_circle(muzzle + step * d, 0.9, light)
			d += 10.0
	var gap: float = 6.0 + 16.0 * bloom
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(p + direction * gap, p + direction * (gap + 9.0), ink, 4.0, true)
		draw_line(p + direction * gap, p + direction * (gap + 9.0), light, 1.5, true)
	draw_circle(p, 1.8, ink)
	draw_circle(p, 1.0, Color("e8573f") if blocked else light)
	if blocked: draw_circle(line_end, 3.0, Color("e8573f"))
func _draw_look(p: Vector2, ink: Color, light: Color) -> void:
	# An open eye: two arcs and a pupil, with chevrons fanning away from the player.
	var points_top := PackedVector2Array()
	var points_bottom := PackedVector2Array()
	for index in range(0, 13):
		var t := float(index) / 12.0
		var x := lerpf(-13.0, 13.0, t)
		var h := sin(t * PI) * 7.0
		points_top.append(p + Vector2(x, -h))
		points_bottom.append(p + Vector2(x, h))
	draw_polyline(points_top, ink, 4.0, true)
	draw_polyline(points_bottom, ink, 4.0, true)
	draw_polyline(points_top, light, 1.6, true)
	draw_polyline(points_bottom, light, 1.6, true)
	draw_circle(p, 4.2, ink)
	draw_circle(p, 3.0, light if peeking else Color("b8b29a"))
	draw_circle(p, 1.4, ink)
	var away := (p - muzzle).normalized() if muzzle != Vector2.ZERO and p.distance_to(muzzle) > 4.0 else Vector2.UP
	for index in range(3):
		var tip := p + away * (20.0 + index * 7.0)
		var across := Vector2(-away.y, away.x)
		var wide := 5.0 + index * 2.0
		draw_polyline(PackedVector2Array([tip - away * 4.0 + across * wide, tip, tip - away * 4.0 - across * wide]), ink, 3.2, true)
		draw_polyline(PackedVector2Array([tip - away * 4.0 + across * wide, tip, tip - away * 4.0 - across * wide]), light, 1.3, true)
