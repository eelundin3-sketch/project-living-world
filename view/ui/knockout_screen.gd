extends CanvasLayer
## When the player is knocked out, everything goes black except a soft stage light on their body,
## with a message and a button to skip time until they come round. When the player dies the same
## darkness stays, with the choices Load last save / New game / Quit to title.
signal skip_requested
signal wait_requested
signal load_requested
signal new_game_requested
signal quit_to_title_requested

const SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 120.0;
uniform float strength = 1.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 pixel = UV / SCREEN_PIXEL_SIZE;
	vec2 offset = (pixel - center) / vec2(1.0, 0.62);   // a pool of light on the ground: wider than tall
	float d = length(offset) / (radius * (1.0 + pulse * 0.03));
	float dark = smoothstep(0.35, 1.25, d);
	float vignette = mix(0.80, 1.0, smoothstep(0.0, 1.0, d * 0.5));
	vec3 tint = mix(vec3(1.0, 0.92, 0.75) * 0.10, vec3(0.0), dark);   // faint warm light inside the pool
	COLOR = vec4(tint, clamp(dark * 0.985 * vignette, 0.0, 1.0) * strength + (1.0 - dark) * 0.0);
}
"""

var strength := 0.0
var target := 0.0
var dead := false
var center := Vector2(640, 360)
var clock := 0.0
var rect: ColorRect
var material: ShaderMaterial
var title: Label
var subtitle: Label
var skip_button: Button
var death_row: HBoxContainer
var column: VBoxContainer
var panel_root: Control
var jail_layer: CanvasLayer
var jail_label: Label
var jail_button: Button
var booking_card: PanelContainer
var booking_title: Label
var booking_body: Label
var flash_layer: CanvasLayer
var flash_rect: ColorRect

func _ready() -> void:
	layer = 11
	panel_root = Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_root)
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	panel_root.add_child(rect)
	column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_top = -190
	column.offset_bottom = -60
	column.offset_left = -240
	column.offset_right = 240
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_END
	panel_root.add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("efe3c6"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	column.add_child(title)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("a99c7e"))
	column.add_child(subtitle)
	skip_button = _button("Skip ahead until you wake  ▸▸")
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	column.add_child(skip_button)
	death_row = HBoxContainer.new()
	death_row.alignment = BoxContainer.ALIGNMENT_CENTER
	death_row.add_theme_constant_override("separation", 12)
	column.add_child(death_row)
	for entry in [["Load last save", "load"], ["New game", "new"], ["Quit to title", "title"]]:
		var button := _button(entry[0])
		button.custom_minimum_size = Vector2(150, 44)
		var which: String = entry[1]
		button.pressed.connect(func() -> void: _death_choice(which))
		death_row.add_child(button)
	visible = false
	# In jail: a small banner at the top with the time left and a way to wait it out.
	jail_layer = CanvasLayer.new()
	jail_layer.layer = 9
	add_sibling.call_deferred(jail_layer)
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 14
	bar.offset_left = -230
	bar.offset_right = 230
	bar.offset_bottom = 70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.92)
	style.border_color = Color("8a8c90")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 16
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", style)
	jail_layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	jail_label = Label.new()
	jail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jail_label.add_theme_color_override("font_color", Color("efe3c6"))
	row.add_child(jail_label)
	jail_button = _button("Wait it out ▸▸")
	jail_button.custom_minimum_size = Vector2(150, 36)
	jail_button.add_theme_font_size_override("font_size", 14)
	jail_button.pressed.connect(func() -> void: wait_requested.emit())
	row.add_child(jail_button)
	jail_layer.visible = false
	# The booking card: what the sheriff writes down at the desk.
	booking_card = PanelContainer.new()
	booking_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	booking_card.offset_top = 84
	booking_card.offset_left = 24
	booking_card.offset_right = 364
	booking_card.offset_bottom = 190
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("e6dcc0")
	card_style.border_color = Color("6a5a3e")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	booking_card.add_theme_stylebox_override("panel", card_style)
	var card_column := VBoxContainer.new()
	card_column.add_theme_constant_override("separation", 3)
	booking_card.add_child(card_column)
	booking_title = Label.new()
	booking_title.add_theme_font_size_override("font_size", 16)
	booking_title.add_theme_color_override("font_color", Color("3b2f1f"))
	card_column.add_child(booking_title)
	booking_body = Label.new()
	booking_body.add_theme_font_size_override("font_size", 13)
	booking_body.add_theme_color_override("font_color", Color("5a4a33"))
	card_column.add_child(booking_body)
	jail_layer.add_child(booking_card)
	booking_card.visible = false
	# The mugshot flash.
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 12
	add_sibling.call_deferred(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash_rect)

func _death_choice(which: String) -> void:
	if which == "load": load_requested.emit()
	elif which == "new": new_game_requested.emit()
	else: quit_to_title_requested.emit()

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(300, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(1)
		style.border_color = Color("e2b55a", 0.5)
		style.bg_color = {"normal": Color(0.09, 0.08, 0.06, 0.92), "hover": Color(0.26, 0.19, 0.09, 0.96), "pressed": Color(0.34, 0.24, 0.1, 1.0)}[state]
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("f3e7cc"))
	return button

## Called every frame by the controller with the simulation state and the body's screen position.
func update_state(s: Dictionary, screen_position: Vector2, delta: float) -> void:
	var control: Dictionary = s.get("player_control", {})
	var jail: Dictionary = control.get("jail", {})
	var booking: Dictionary = control.get("booking", {})
	if jail_layer != null:
		var releasing: bool = not jail.is_empty() and bool(jail.get("releasing", false))
		jail_layer.visible = not jail.is_empty() or not booking.is_empty()
		if jail_layer.visible:
			var crimes: Array = jail.get("crimes", [])
			var left: int = maxi(0, int(jail.get("until", 0)) - int(s.tick))
			var stage_label := ""
			if not booking.is_empty():
				stage_label = "Booking · " + {"search": "being searched", "property": "belongings into the locker", "photo": "mugshot"}.get(str(booking.get("step", "")), "processing")
			elif releasing:
				stage_label = "Release · the sheriff is seeing you out"
			else:
				stage_label = "In jail for %s · %d h %02d min left" % [", ".join(crimes.map(func(c): return str(c).replace("_", " "))), left / 600, (left % 600) / 10]
			jail_label.text = stage_label
		# The booking card, while the sheriff is at the desk.
		var wanted_crimes: Array = []
		for record in s.get("law", {}).get("wanted", {}).values(): wanted_crimes.append_array(record.get("crimes", []))
		booking_card.visible = not booking.is_empty()
		if booking_card.visible:
			var name_text: String = str(s.entities[str(s.player)].get("name", "Prisoner"))
			booking_title.text = "BOOKING · " + name_text
			var held: int = 0
			for quantity in control.get("property", {}).get("items", {}).values(): held += int(quantity)
			booking_body.text = "Charge: %s\nProperty held: %d item%s, %d coins\nIssue: prison uniform" % [", ".join(wanted_crimes.map(func(c): return str(c).replace("_", " "))) if not wanted_crimes.is_empty() else "see record", held, "" if held == 1 else "s", int(control.get("property", {}).get("coins", 0))]
		# The flash when the photo is taken, fading quickly.
		if flash_rect != null:
			var since_flash: int = int(s.tick) - int(booking.get("flash", -1000))
			flash_rect.color.a = clampf(1.0 - float(since_flash) / 6.0, 0.0, 1.0) * 0.85 if since_flash >= 0 and since_flash < 6 else 0.0
	var knock: Dictionary = s.get("player_control", {}).get("knock", {})
	dead = bool(s.get("player_control", {}).get("dead", false))
	var out_cold: bool = not knock.is_empty() and str(knock.get("kind", "")) in ["ko", "dead"] and s.tick >= int(knock.start) + 4 and (dead or s.tick < int(knock.down_until))
	target = 1.0 if out_cold else 0.0
	strength = move_toward(strength, target, delta * (1.6 if target > strength else 1.1))
	visible = strength > 0.001
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP if strength > 0.4 else Control.MOUSE_FILTER_IGNORE
	if not visible: return
	clock += delta
	center = screen_position
	material.set_shader_parameter("center", center)
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("radius", 130.0 + 12.0 * sin(clock * 1.7))
	material.set_shader_parameter("pulse", sin(clock * 1.3))
	var shown: bool = strength > 0.55
	title.text = "You have died" if dead else "You have been knocked out"
	title.add_theme_color_override("font_color", Color("e0766c") if dead else Color("efe3c6"))
	subtitle.text = "Your health reached zero." if dead else "You will come round in about %d seconds." % maxi(1, (int(knock.down_until) - int(s.tick)) / 10)
	title.modulate.a = strength if shown else 0.0
	subtitle.modulate.a = strength if shown else 0.0
	skip_button.visible = shown and not dead
	death_row.visible = shown and dead
