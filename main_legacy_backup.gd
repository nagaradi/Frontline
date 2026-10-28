extends Node3D

const WORLD_SIZE := 90.0
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var hud: CanvasLayer
var status_label: Label
var health := 100
var kills := 0
var ammo := 30
var aiming := false
var fire_cooldown := 0.0
var touch_move := Vector2.ZERO
var mobile_aim := false

func _ready() -> void:
    _make_environment()
    _make_world()
    _make_player()
    _make_targets()
    _make_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        camera_pivot.rotate_y(-event.relative.x * 0.0025)
        camera.rotate_x(-event.relative.y * 0.0022)
        camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-48), deg_to_rad(35))
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            aiming = event.pressed
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _shoot()

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if touch_move.length() > 0.1:
        input_dir = touch_move
    var basis := camera_pivot.global_transform.basis
    var forward := -basis.z
    var right := basis.x
    forward.y = 0
    right.y = 0
    forward = forward.normalized()
    right = right.normalized()
    var direction := (right * input_dir.x + forward * -input_dir.y).normalized()
    var speed := 4.8
    if Input.is_key_pressed(KEY_SHIFT):
        speed = 7.2
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    if not player.is_on_floor():
        player.velocity.y -= 20.0 * delta
    elif Input.is_action_just_pressed("jump"):
        player.velocity.y = 7.0
    player.move_and_slide()
    if direction.length() > 0.1:
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
    var target_cam := Vector3(0.0, 2.2, 5.0) if not aiming else Vector3(0.7, 1.8, 2.3)
    camera.position = camera.position.lerp(target_cam, delta * 8.0)
    _update_hud()

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.sky.sky_material = ProceduralSkyMaterial.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.68, 0.76)
    environment.ambient_light_energy = 0.8
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func _add_box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    mesh_instance.position = pos
    parent.add_child(mesh_instance)
    if collision:
        var body := StaticBody3D.new()
        body.name = name + "_Collision"
        body.position = pos
        parent.add_child(body)
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        mesh_instance.position = Vector3.ZERO
        mesh_instance.reparent(body)
        mesh_instance.position = Vector3.ZERO
    return mesh_instance

func _make_world() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    add_child(ground)
    var ground_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
    ground_mesh.mesh = plane
    ground_mesh.material_override = _mat(Color(0.22, 0.34, 0.20))
    ground.add_child(ground_mesh)
    var ground_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(WORLD_SIZE, 0.5, WORLD_SIZE)
    ground_shape.shape = box
    ground_shape.position.y = -0.25
    ground.add_child(ground_shape)
    var road_mat := _mat(Color(0.18, 0.19, 0.18))
    _add_box(self, "Road", Vector3(0, 0.015, -12), Vector3(8, 0.04, 58), road_mat)
    var line_mat := _mat(Color(0.85, 0.78, 0.44))
    for z in range(-38, 16, 6):
        _add_box(self, "RoadLine", Vector3(0, 0.045, z), Vector3(0.18, 0.025, 2.6), line_mat)
    var building_mat := _mat(Color(0.48, 0.43, 0.36))
    var roof_mat := _mat(Color(0.25, 0.25, 0.24))
    for i in range(10):
        var x := -27.0 + float(i % 5) * 13.5
        var z := -27.0 + float(i / 5) * 17.0
        if absf(x) < 8.0: x += 14.0
        _building(Vector3(x, 0, z), Vector3(7.0, 4.0 + float(i % 3), 6.0), building_mat, roof_mat)
    var tree_mat := _mat(Color(0.12, 0.29, 0.12))
    var trunk_mat := _mat(Color(0.26, 0.17, 0.09))
    for i in range(34):
        var x := sin(float(i) * 17.3) * 39.0
        var z := cos(float(i) * 9.7) * 39.0
        if absf(x) < 12 and absf(z + 12) < 30: continue
        var trunk := MeshInstance3D.new()
        var tm := CylinderMesh.new()
        tm.top_radius = 0.18
        tm.bottom_radius = 0.28
        tm.height = 1.5
        trunk.mesh = tm
        trunk.material_override = trunk_mat
        trunk.position = Vector3(x, 0.75, z)
        add_child(trunk)
        var crown := MeshInstance3D.new()
        var cm := SphereMesh.new()
        cm.radius = 1.25
        cm.height = 2.4
        crown.mesh = cm
        crown.material_override = tree_mat
        crown.position = Vector3(x, 2.15, z)
        add_child(crown)

func _building(pos: Vector3, size: Vector3, wall: Material, roof: Material) -> void:
    var body := StaticBody3D.new()
    body.position = pos + Vector3(0, size.y / 2, 0)
    add_child(body)
    var mesh := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mesh.mesh = bm
    mesh.material_override = wall
    body.add_child(mesh)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    var roof_mesh := MeshInstance3D.new()
    var rm := BoxMesh.new()
    rm.size = Vector3(size.x + 0.4, 0.25, size.z + 0.4)
    roof_mesh.mesh = rm
    roof_mesh.material_override = roof
    roof_mesh.position = Vector3(0, size.y / 2 + 0.12, 0)
    body.add_child(roof_mesh)
    # Simple dark window panels
    var win_mat := _mat(Color(0.10, 0.15, 0.17), 0.35)
    for side in [-1.0, 1.0]:
        var win := MeshInstance3D.new()
        var wm := BoxMesh.new()
        wm.size = Vector3(1.1, 0.8, 0.06)
        win.mesh = wm
        win.material_override = win_mat
        win.position = Vector3(side * size.x * 0.23, 0.2, -size.z / 2 - 0.035)
        body.add_child(win)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.95, 8)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.4
    capsule.height = 1.8
    collision.shape = capsule
    player.add_child(collision)
    var visuals := Node3D.new()
    visuals.name = "Visuals"
    player.add_child(visuals)
    # Placeholder stylized soldier built from low-poly shapes.
    var uniform := _mat(Color(0.18, 0.28, 0.22))
    var vest := _mat(Color(0.12, 0.15, 0.14))
    var skin := _mat(Color(0.70, 0.49, 0.35))
    var boots := _mat(Color(0.10, 0.10, 0.09))
    _capsule_part(visuals, Vector3(0, 0.12, 0), Vector3(0.55, 0.78, 0.30), uniform)
    _capsule_part(visuals, Vector3(0, 0.2, -0.19), Vector3(0.46, 0.52, 0.13), vest)
    _sphere_part(visuals, Vector3(0, 0.72, 0), Vector3(0.23, 0.25, 0.23), skin)
    _capsule_part(visuals, Vector3(-0.17, -0.43, 0), Vector3(0.17, 0.53, 0.18), uniform)
    _capsule_part(visuals, Vector3(0.17, -0.43, 0), Vector3(0.17, 0.53, 0.18), uniform)
    _capsule_part(visuals, Vector3(-0.17, -0.72, -0.04), Vector3(0.18, 0.12, 0.30), boots)
    _capsule_part(visuals, Vector3(0.17, -0.72, -0.04), Vector3(0.18, 0.12, 0.30), boots)
    _capsule_part(visuals, Vector3(-0.36, 0.18, -0.02), Vector3(0.13, 0.48, 0.14), uniform)
    _capsule_part(visuals, Vector3(0.36, 0.18, -0.02), Vector3(0.13, 0.48, 0.14), uniform)
    _capsule_part(visuals, Vector3(0.22, 0.12, -0.35), Vector3(0.10, 0.10, 0.65), vest)
    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    camera_pivot.position.y = 1.25
    player.add_child(camera_pivot)
    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.position = Vector3(0, 2.2, 5)
    camera.current = true
    camera.fov = 75
    camera_pivot.add_child(camera)

func _capsule_part(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = minf(size.x, size.z) * 0.5
    mesh.height = maxf(size.y, mesh.radius * 2.0)
    part.mesh = mesh
    part.material_override = material
    part.position = pos
    parent.add_child(part)

func _sphere_part(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    part.mesh = mesh
    part.scale = size
    part.material_override = material
    part.position = pos
    parent.add_child(part)

func _make_targets() -> void:
    for i in range(7):
        var target := StaticBody3D.new()
        target.name = "Target_%02d" % i
        target.position = Vector3(-18 + i * 6, 1.0, -22 - (i % 2) * 5)
        add_child(target)
        var body := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.38
        mesh.height = 1.9
        body.mesh = mesh
        body.material_override = _mat(Color(0.52, 0.16, 0.13))
        target.add_child(body)
        var shape_node := CollisionShape3D.new()
        var shape := CapsuleShape3D.new()
        shape.radius = 0.4
        shape.height = 1.9
        shape_node.shape = shape
        target.add_child(shape_node)
        target.set_meta("is_target", true)

func _make_hud() -> void:
    hud = CanvasLayer.new()
    hud.name = "HUD"
    add_child(hud)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 16)
    panel.custom_minimum_size = Vector2(245, 98)
    hud.add_child(panel)
    var labels := VBoxContainer.new()
    panel.add_child(labels)
    status_label = Label.new()
    status_label.text = "FRONTLINE  |  TRAINING"
    status_label.add_theme_font_size_override("font_size", 17)
    labels.add_child(status_label)
    var info := Label.new()
    info.name = "Info"
    info.text = "HP 100   AMMO 30/30   KILLS 0"
    labels.add_child(info)
    var hint := Label.new()
    hint.text = "WASD move  |  Shift sprint  |  Space jump"
    hint.add_theme_font_size_override("font_size", 12)
    labels.add_child(hint)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-8, -15)
    cross.add_theme_font_size_override("font_size", 26)
    hud.add_child(cross)
    _make_mobile_button("FIRE", Vector2(-140, -120), Vector2(112, 76), Callable(self, "_mobile_fire"))
    _make_mobile_button("AIM", Vector2(-260, -120), Vector2(100, 76), Callable(self, "_mobile_aim"))
    _make_mobile_button("JUMP", Vector2(-140, -32), Vector2(112, 64), Callable(self, "_mobile_jump"))
    var move_pad := Control.new()
    move_pad.name = "TouchMovementHint"
    move_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    move_pad.position = Vector2(28, -150)
    move_pad.custom_minimum_size = Vector2(180, 120)
    hud.add_child(move_pad)
    var pad := Label.new()
    pad.text = "◀   MOVE   ▶\n▲             ▼"
    pad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    pad.size = Vector2(180, 120)
    pad.add_theme_font_size_override("font_size", 18)
    move_pad.add_child(pad)
    var help := Label.new()
    help.text = "Touch buttons shown for mobile prototype"
    help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    help.position.y = -22
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_font_size_override("font_size", 12)
    hud.add_child(help)

func _make_mobile_button(text_value: String, offset: Vector2, size_value: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = size_value
    button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    button.position = offset
    button.pressed.connect(callback)
    hud.add_child(button)

func _mobile_fire() -> void:
    _shoot()

func _mobile_aim() -> void:
    aiming = not aiming
    camera.position = Vector3(0.7, 1.8, 2.3) if aiming else Vector3(0, 2.2, 5)

func _mobile_jump() -> void:
    if player and player.is_on_floor():
        player.velocity.y = 7.0

func _shoot() -> void:
    if fire_cooldown > 0 or ammo <= 0:
        return
    fire_cooldown = 0.22
    ammo -= 1
    var from := camera.global_position
    var to := from + -camera.global_transform.basis.z * 65.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player]
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    if result and result.collider and result.collider.has_meta("is_target"):
        result.collider.queue_free()
        kills += 1
    if ammo <= 0:
        ammo = 30

func _update_hud() -> void:
    var info := hud.get_node_or_null("PanelContainer/VBoxContainer/Info")
    if info:
        info.text = "HP %d   AMMO %02d/30   KILLS %d" % [health, ammo, kills]
    if status_label:
        status_label.text = "FRONTLINE  |  TRAINING ZONE"
