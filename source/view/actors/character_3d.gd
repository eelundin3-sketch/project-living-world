extends Node2D
## A private transparent 3D stage projects a genuinely volumetric character into
## the 2D world. All decisions and inventory remain in the simulation.
var stage: SubViewport
var model: Node3D
var torso: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_elbow: Node3D
var right_elbow: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_knee: Node3D
var right_knee: Node3D
var carried: Node3D
var cargo_models: Dictionary = {}
var axe: Node3D
var saw: Node3D
var rifle: Node3D
var hammer: Node3D
var sprite: Sprite2D
var character_id: int
static var outline_material: ShaderMaterial

func setup(id: int, player: bool, raider: bool) -> void:
	character_id = id
	stage = SubViewport.new()
	stage.size = Vector2i(128, 144)
	stage.transparent_bg = true
	stage.msaa_3d = Viewport.MSAA_2X
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var root := Node3D.new()
	stage.add_child(root)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.position = Vector3(0, 2.3, 5)
	root.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff3d8")
	settings.ambient_light_energy = 0.9
	environment.environment = settings
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 0.65
	root.add_child(light)
	model = Node3D.new()
	root.add_child(model)
	var skin := _material([Color("f5d99b"), Color("d8a66f"), Color("b87e53")][posmod(id, 3)])
	var shirt := _material(Color("ead7a2") if player else (Color("d6ac90") if raider else [Color("e9ddb3"), Color("d9cca3"), Color("d9b694"), Color("cbd0b0")][posmod(id, 4)]))
	var vest := _material(Color("c3a571") if player else (Color("915846") if raider else [Color("b8996a"), Color("8c8964"), Color("ad835d"), Color("879080")][posmod(id, 4)]))
	var pants := _material(Color("bd9556"))
	var gaiter := _material(Color("d1ad70"))
	var boot := _material(Color("68471f"))
	var hair := _material(Color("654027"))
	var hat := _material(Color("c69449") if not raider else Color("ac764d"))
	var crown := _material(Color("d7a353") if not raider else Color("bd895d"))
	var dark := _material(Color("302014"), false)
	torso = Node3D.new()
	torso.position = Vector3(0, 0.98, 0)
	model.add_child(torso)
	_mesh(torso, _capsule(0.28, 0.67), vest, Vector3(0, 0.16, 0), Vector3(1, 1, 0.72))
	_mesh(torso, _capsule(0.035, 0.44), shirt, Vector3(0, 0.14, 0.202), Vector3(1, 1, 0.60))
	for side in [-1, 1]:
		_mesh(torso, _capsule(0.042, 0.19), vest, Vector3(side * 0.10, 0.39, 0.184), Vector3(1, 1, 0.62), Vector3(0, 0, side * -0.55))
	for y in [0.06, 0.16, 0.26]:
		_mesh(torso, _sphere(0.018), dark, Vector3(0.079, y, 0.204))
	_mesh(torso, _capsule(0.115, 0.19), skin, Vector3(0, 0.46, 0))
	# The jaw projects forward of the hair cap so the face reads as a profile when turning.
	_mesh(torso, _sphere(0.203), hair, Vector3(0, 0.654, -0.036), Vector3(1, 1.13, 0.90))
	_mesh(torso, _capsule(0.174, 0.43), skin, Vector3(0, 0.61, 0.058), Vector3(1, 1, 0.88))
	var eye_white := _material(Color("fff1cd"), false)
	var iris := _material(Color("70b8bf"), false)
	for side in [-1, 1]:
		var eye_x: float = side * 0.073
		_mesh(torso, _sphere(0.036), dark, Vector3(eye_x, 0.658, 0.196), Vector3(1, 0.60, 0.47))
		_mesh(torso, _sphere(0.026), eye_white, Vector3(eye_x, 0.658, 0.211), Vector3(1, 0.52, 0.24))
		_mesh(torso, _sphere(0.013), iris, Vector3(eye_x, 0.658, 0.217), Vector3(1, 0.87, 0.34))
		_mesh(torso, _sphere(0.007), dark, Vector3(eye_x, 0.658, 0.222))
	_mesh(torso, _sphere(0.049), dark, Vector3(0, 0.547, 0.200), Vector3(1, 0.18, 0.35))
	_mesh(torso, _cylinder(0.38, 0.035), hat, Vector3(0, 0.80, 0), Vector3(1, 1, 0.83))
	_mesh(torso, _cylinder(0.177, 0.134), crown, Vector3(0, 0.889, 0), Vector3(1, 1, 0.87))
	_mesh(torso, _cylinder(0.181, 0.030), dark, Vector3(0, 0.841, 0), Vector3(1, 1, 0.87))
	left_arm = _limb(torso, Vector3(-0.245, 0.36, 0), shirt, vest, skin)
	right_arm = _limb(torso, Vector3(0.245, 0.36, 0), shirt, vest, skin)
	left_elbow = left_arm.get_node("Elbow")
	right_elbow = right_arm.get_node("Elbow")
	left_leg = _leg(model, Vector3(-0.13, 0.84, 0), pants, gaiter, boot)
	right_leg = _leg(model, Vector3(0.13, 0.84, 0), pants, gaiter, boot)
	left_knee = left_leg.get_node("Knee")
	right_knee = right_leg.get_node("Knee")
	carried = Node3D.new(); torso.add_child(carried)
	cargo_models["log"] = _mesh(carried, _cylinder(0.09, 0.64), _material(Color("987044")), Vector3(0, 0.05, 0.28), Vector3.ONE, Vector3(0, 0, PI / 2))
	cargo_models["plank"] = _mesh(carried, _box(Vector3(0.62, 0.10, 0.20)), _material(Color("c7a66a")), Vector3(0, 0.05, 0.28))
	cargo_models["food"] = _mesh(carried, _sphere(0.17), _material(Color("bba473")), Vector3(0, 0.05, 0.28), Vector3(1.0, 0.8, 0.8))
	cargo_models["bandage"] = _mesh(carried, _box(Vector3(0.24, 0.16, 0.13)), _material(Color("e1ddc8")), Vector3(0, 0.05, 0.28))
	cargo_models["antiseptic"] = _mesh(carried, _cylinder(0.07, 0.23), _material(Color("718a76")), Vector3(0, 0.05, 0.28))
	var tool_grip := Node3D.new()
	tool_grip.position.y = 0.25
	right_elbow.add_child(tool_grip)
	axe = _tool(tool_grip, Color("8c633b"), Color("b3b3a5"), false)
	saw = _tool(tool_grip, Color("735338"), Color("9ea4a0"), true)
	hammer = _tool(tool_grip, Color("8c633b"), Color("7b7d76"), false)
	rifle = Node3D.new(); torso.add_child(rifle)
	_mesh(rifle, _box(Vector3(0.65, 0.055, 0.06)), _material(Color("7f5a35")), Vector3(0.18, 0.28, 0.24))
	_mesh(rifle, _box(Vector3(0.48, 0.025, 0.025)), dark, Vector3(0.48, 0.31, 0.24))
	sprite = Sprite2D.new()
	sprite.texture = stage.get_texture()
	sprite.position = Vector2(0, -34)
	sprite.scale = Vector2(0.76, 0.76)
	add_child(sprite)

func _material(color: Color, inked: bool = true) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if inked: result.next_pass = _outline()
	return result

static func _outline() -> ShaderMaterial:
	if outline_material == null:
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, cull_front, depth_draw_opaque; void vertex() { VERTEX += NORMAL * 0.023; } void fragment() { ALBEDO = vec3(0.035, 0.021, 0.013); }"
		outline_material = ShaderMaterial.new()
		outline_material.shader = shader
	return outline_material

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2; mesh.radial_segments = 20; mesh.rings = 10; return mesh

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new(); mesh.radius = radius; mesh.height = height; mesh.radial_segments = 20; mesh.rings = 10; return mesh

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new(); mesh.size = size; return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = 28; return mesh

func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.mesh = mesh; part.material_override = material; part.position = pos; part.scale = scale_value; part.rotation = rotation_value; parent.add_child(part); return part

func _limb(parent: Node3D, pos: Vector3, sleeve: Material, cuff: Material, skin: Material) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = pos
	parent.add_child(shoulder)
	_mesh(shoulder, _capsule(0.102, 0.34), sleeve, Vector3(0, -0.12, 0))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position.y = -0.25
	shoulder.add_child(elbow)
	_mesh(elbow, _capsule(0.087, 0.27), cuff, Vector3(0, -0.10, 0))
	_mesh(elbow, _sphere(0.065), skin, Vector3(0, -0.238, 0.011), Vector3(1, 0.95, 0.85))
	return shoulder

func _leg(parent: Node3D, pos: Vector3, pants: Material, gaiter: Material, boot: Material) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	_mesh(joint, _capsule(0.116, 0.39), pants, Vector3(0, -0.16, 0))
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position.y = -0.32
	joint.add_child(knee)
	_mesh(knee, _capsule(0.093, 0.38), gaiter, Vector3(0, -0.16, 0))
	_mesh(knee, _sphere(0.106), boot, Vector3(0, -0.351, 0.055), Vector3(0.89, 0.70, 1.45))
	return joint

func _tool(parent: Node3D, handle_color: Color, head_color: Color, long_blade: bool) -> Node3D:
	var tool := Node3D.new(); parent.add_child(tool)
	_mesh(tool, _box(Vector3(0.06, 0.48, 0.06)), _material(handle_color), Vector3(0, -0.53, 0.02))
	_mesh(tool, _box(Vector3(0.38 if long_blade else 0.22, 0.08, 0.09)), _material(head_color), Vector3(0.04, -0.76, 0.02))
	return tool

func set_pose(pose: Dictionary) -> void:
	position = pose.get("position", Vector2.ZERO)
	model.rotation.y = PI / 2.0 - float(pose.get("heading", PI / 2.0))
	var action: String = pose.get("action", "idle")
	var gait: float = float(pose.get("gait_phase", 0.0)) * TAU
	var swing: float = sin(gait) * (0.72 if action == "run" else 0.48) if pose.get("moving", false) else 0.0
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.8
	right_arm.rotation.x = swing * 0.8
	left_arm.rotation.z = 0.0
	right_arm.rotation.z = 0.0
	left_knee.rotation.x = 0.0
	right_knee.rotation.x = 0.0
	model.position.y = 0.0
	if action == "run" and pose.get("moving", false):
		left_leg.rotation.x = sin(gait) * 0.95
		right_leg.rotation.x = -sin(gait) * 0.95
		left_knee.rotation.x = -0.18 - maxf(0.0, -sin(gait)) * 1.0
		right_knee.rotation.x = -0.18 - maxf(0.0, sin(gait)) * 1.0
		left_arm.rotation.x = -0.35 - sin(gait) * 0.85
		right_arm.rotation.x = -0.35 + sin(gait) * 0.85
		model.position.y = 0.045 + 0.045 * cos(gait * 2.0)
	var phase: float = float(pose.get("phase", 0.0))
	torso.rotation.x = 0.20 if action == "run" and pose.get("moving", false) else 0.0
	model.rotation.z = PI / 2.0 if action == "down" else 0.0
	if action in ["pickup", "drop", "harvest"]:
		torso.rotation.x = 0.55 * sin(phase * PI)
		left_arm.rotation.x = -0.7; right_arm.rotation.x = -0.7
	elif action == "ready":
		left_arm.rotation.x = -1.15; right_arm.rotation.x = -1.15
		left_arm.rotation.z = -0.25; right_arm.rotation.z = 0.25
		torso.rotation.x = 0.08
	elif action in ["punch", "shove"]:
		var extension: float = smoothstep(0.05, 0.30, phase) * (1.0 - smoothstep(0.48, 0.95, phase))
		left_arm.rotation.x = -1.15 if action == "punch" else -1.15 - extension * 0.7
		right_arm.rotation.x = -1.15 - extension * 0.7
		torso.rotation.x = 0.12 + extension * 0.24
	elif action == "stagger":
		model.rotation.z = 0.9 * sin(phase * PI)
		torso.rotation.x = -0.4 * sin(phase * PI)
		left_arm.rotation.x = -0.8; right_arm.rotation.x = -0.8
	elif action in ["chop", "build", "melee"]:
		var strike: float = smoothstep(0.18, 0.46, phase) - smoothstep(0.55, 0.95, phase)
		right_arm.rotation.x = -2.1 + strike * 1.7
		left_arm.rotation.x = -0.55 - strike * 0.25
		torso.rotation.x = 0.1 + strike * 0.25
	elif action == "saw":
		left_arm.rotation.x = -1.05 + sin(phase * TAU) * 0.24
		right_arm.rotation.x = -1.05 + sin(phase * TAU) * 0.24
		torso.rotation.x = 0.16 + sin(phase * TAU) * 0.08
	elif action in ["aim", "shoot"]:
		left_arm.rotation.x = -1.1; right_arm.rotation.x = -1.1
	elif action == "hit": torso.rotation.x = -0.35
	elif action == "eat":
		right_arm.rotation.x = -1.75 + sin(phase * TAU) * 0.28
		torso.rotation.x = 0.10
	elif action == "rest":
		model.rotation.z = PI / 2.0
	if pose.get("ready", false) and action in ["walk", "run", "carry"]:
		left_arm.rotation.x = -1.15; right_arm.rotation.x = -1.15
		left_arm.rotation.z = -0.25; right_arm.rotation.z = 0.25
	carried.visible = int(pose.get("cargo_quantity", 0)) > 0 or (action == "drop" and int(pose.get("last_quantity", 0)) > 0) or (action == "pickup" and int(pose.get("expected_quantity", 0)) > 0)
	carried.position = Vector3(0, -0.65, 0.20) if action == "build" else Vector3.ZERO
	if action in ["pickup", "drop"]:
		var raise_amount: float = phase if action == "pickup" else 1.0 - phase
		carried.position = Vector3(0, lerpf(-0.65, 0.0, clampf(raise_amount, 0.0, 1.0)), 0.12)
	var held_item: String = str(pose.get("cargo_item", ""))
	if held_item.is_empty() and action == "drop": held_item = str(pose.get("last_item", ""))
	if held_item.is_empty() and action == "pickup": held_item = str(pose.get("expected_item", ""))
	for item in cargo_models: cargo_models[item].visible = item == held_item
	axe.visible = action == "chop"
	saw.visible = action == "saw" and not pose.get("machine_work", false)
	hammer.visible = action == "build"
	rifle.visible = action in ["aim", "shoot"]
	if carried.visible and action not in ["build", "pickup", "drop"]:
		if action not in ["punch", "shove", "stagger", "hit", "down"]:
			left_arm.rotation.x = -1.15; right_arm.rotation.x = -1.15

	# Elbows bend independently while the shoulders retain each action's swing.
	left_elbow.rotation = Vector3(-0.12, 0, 0)
	right_elbow.rotation = Vector3(-0.12, 0, 0)
	if action == "idle" and not carried.visible:
		left_arm.rotation = Vector3(-0.16, 0, -0.26)
		right_arm.rotation = Vector3(-0.16, 0, 0.26)
		left_elbow.rotation = Vector3(-0.58, 0, 1.04)
		right_elbow.rotation = Vector3(-0.58, 0, -1.04)
	elif action == "run":
		left_elbow.rotation.x = -0.68
		right_elbow.rotation.x = -0.68
	elif action == "ready" or pose.get("ready", false):
		left_elbow.rotation.x = -0.50
		right_elbow.rotation.x = -0.50
