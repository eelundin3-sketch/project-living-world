extends CanvasLayer
## Title screen. The live world plays behind it while the camera drifts slowly over the map; the
## menu sits on a dark panel at the left. Start fades the menu out and the controller flies the
## camera down to the player. Options is a placeholder layout (nothing in it is wired up yet).
signal start_requested
signal quit_requested

const INK := Color("f3e7cc")
const MUTED := Color("b9a98a")
const ACCENT := Color("e2b55a")
const PANEL := Color(0.06, 0.05, 0.04, 0.0)

var root_control: Control
var menu_column: VBoxContainer
var options_panel: PanelContainer
var buttons: Array[Button] = []
var shade: TextureRect
var fading := false

func _ready() -> void:
	layer = 30
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	# A soft dark wash from the left edge so the menu reads over the moving map.
	shade = TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.05, 0.04, 0.03, 0.92), Color(0.05, 0.04, 0.03, 0.72), Color(0.05, 0.04, 0.03, 0.08), Color(0.05, 0.04, 0.03, 0.25)])
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	shade.texture = texture
	root_control.add_child(shade)

	menu_column = VBoxContainer.new()
	menu_column.position = Vector2(72, 0)
	menu_column.anchor_top = 0.5
	menu_column.anchor_bottom = 0.5
	menu_column.offset_top = -200
	menu_column.offset_left = 72
	menu_column.add_theme_constant_override("separation", 14)
	root_control.add_child(menu_column)
	var title := Label.new()
	title.text = "LIVING WORLD"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", INK)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 0.9
	heavy.spacing_glyph = 4
	title.add_theme_font_override("font", heavy)
	menu_column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A frontier life on the Moss Road"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", MUTED)
	menu_column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	menu_column.add_child(gap)
	for entry in [["Start Game", "start"], ["Options", "options"], ["Quit Game", "quit"]]:
		var button := _menu_button(entry[0])
		button.pressed.connect(_on_pressed.bind(entry[1]))
		menu_column.add_child(button)
		buttons.append(button)
	var footer := Label.new()
	footer.text = "Project Living World · early build"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(MUTED, 0.6))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 74
	footer.offset_top = -40
	root_control.add_child(footer)
	_build_options()

func _menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 22
		style.set_corner_radius_all(6)
		match state:
			"normal":
				style.bg_color = Color(0.1, 0.08, 0.06, 0.55)
				style.border_color = Color(1, 1, 1, 0.08)
				style.border_width_left = 3
			"hover":
				style.bg_color = Color(0.24, 0.17, 0.08, 0.85)
				style.border_color = ACCENT
				style.border_width_left = 5
				style.content_margin_left = 28
			"pressed":
				style.bg_color = Color(0.32, 0.22, 0.09, 0.95)
				style.border_color = ACCENT
				style.border_width_left = 5
				style.content_margin_left = 28
			"disabled":
				style.bg_color = Color(0.1, 0.08, 0.06, 0.3)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("ffe7b0"))
	button.add_theme_color_override("font_pressed_color", Color("ffe7b0"))
	return button

func _on_pressed(id: String) -> void:
	if fading: return
	match id:
		"start":
			fading = true
			options_panel.visible = false
			var tween := create_tween()
			tween.tween_property(root_control, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
			start_requested.emit()
		"options": options_panel.visible = not options_panel.visible
		"quit": quit_requested.emit()

## A placeholder settings screen: the layout a full options menu would have, all disabled for now.
func _build_options() -> void:
	options_panel = PanelContainer.new()
	options_panel.visible = false
	options_panel.anchor_left = 0.5
	options_panel.anchor_right = 0.5
	options_panel.anchor_top = 0.5
	options_panel.anchor_bottom = 0.5
	options_panel.offset_left = -60
	options_panel.offset_right = 520
	options_panel.offset_top = -335
	options_panel.offset_bottom = 335
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.94)
	style.border_color = Color(ACCENT, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	options_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(options_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	options_panel.add_child(column)
	var heading := Label.new()
	heading.text = "OPTIONS"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", INK)
	column.add_child(heading)
	var note := Label.new()
	note.text = "Coming soon: none of these are wired up yet."
	note.add_theme_color_override("font_color", ACCENT)
	note.add_theme_font_size_override("font_size", 13)
	column.add_child(note)
	var sections := [
		["VIDEO", [["Fullscreen", "toggle"], ["Shadow quality", "High"], ["Day length", "24 min"], ["Show name tags", "toggle"]]],
		["AUDIO", [["Master volume", "slider"], ["Music", "slider"], ["Effects", "slider"]]],
		["GAMEPLAY", [["Difficulty", "Settler"], ["Autosave", "Every in-game day"], ["Permadeath", "toggle"]]],
		["CONTROLS", [["Move · Run · Crouch", "WASD · Shift · X"], ["Inventory · Health · Map", "I · H · M"], ["Hotbar · Shove", "1-4 · Space"]]]]
	for section in sections:
		var label := Label.new()
		label.text = section[0]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED)
		column.add_child(label)
		for row in section[1]:
			var line := HBoxContainer.new()
			column.add_child(line)
			var name_label := Label.new()
			name_label.text = row[0]
			name_label.custom_minimum_size = Vector2(230, 0)
			name_label.add_theme_color_override("font_color", INK)
			line.add_child(name_label)
			var control: Control
			match row[1]:
				"toggle":
					var check := CheckButton.new()
					check.disabled = true
					control = check
				"slider":
					var slider := HSlider.new()
					slider.value = 80
					slider.editable = false
					slider.custom_minimum_size = Vector2(200, 0)
					control = slider
				_:
					var value := Label.new()
					value.text = row[1]
					value.add_theme_color_override("font_color", MUTED)
					control = value
			line.add_child(control)
	var back := _menu_button("Back")
	back.custom_minimum_size = Vector2(160, 40)
	back.add_theme_font_size_override("font_size", 17)
	back.pressed.connect(func() -> void: options_panel.visible = false)
	column.add_child(back)
