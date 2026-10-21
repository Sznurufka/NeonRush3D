extends Node3D

const LANES := [-2.3, 0.0, 2.3]
const SEGMENT_LENGTH := 18.0
const TRACK_WIDTH := 8.0
const SAVE_PATH := "user://neon_rush_save.json"

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var player_visual: Node3D
var camera: Camera3D
var world_environment: WorldEnvironment
var ui: CanvasLayer
var hud_label: Label
var coin_label: Label
var message_label: Label
var shop_panel: PanelContainer
var shop_text: Label
var buttons := {}
var touch_start := Vector2.ZERO

var lane := 1
var vertical_velocity := 0.0
var run_speed := 12.0
var distance := 0.0
var coins_run := 0
var total_coins := 0
var best_distance := 0.0
var level := 1
var game_active := true
var shield_time := 0.0
var magnet_time := 0.0
var boost_time := 0.0
var spawn_distance := 0.0
var objects: Array[Node3D] = []
var ground_segments: Array[Node3D] = []
var shop_open := false
var upgrades := {"speed": 0, "magnet": 0, "shield": 0}
var purchased_skins := ["cyan"]
var skin := "cyan"
var skin_colors := {"cyan": Color(0.12,0.95,1.0), "pink": Color(1.0,0.18,0.62), "gold": Color(1.0,0.72,0.12)}
var level_target := 250.0

func _ready() -> void:
    rng.randomize()
    _load_save()
    _build_world()
    _build_player()
    _build_ui()
    _start_level()
    _show_message("NEON RUSH 3D  •  Swipe / tap arrows to move")

func _process(delta: float) -> void:
    if game_active and not shop_open:
        distance += run_speed * delta
        spawn_distance += run_speed * delta
        shield_time = maxf(0.0, shield_time - delta)
        magnet_time = maxf(0.0, magnet_time - delta)
        boost_time = maxf(0.0, boost_time - delta)
        run_speed = 12.0 + float(upgrades.speed) * 0.7 + minf(distance / 450.0, 5.0)
        if boost_time > 0.0:
            run_speed += 6.0
        _move_world(delta)
        _spawn_logic()
        _update_player(delta)
        _check_level_progress()
    _update_camera(delta)
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left"):
        _change_lane(-1)
    elif event.is_action_pressed("move_right"):
        _change_lane(1)
    elif event.is_action_pressed("jump"):
        _jump()
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
        elif game_active and not shop_open:
            var delta := event.position - touch_start
            if delta.length() < 30.0:
                if event.position.x < get_viewport().get_visible_rect().size.x * 0.33:
                    _change_lane(-1)
                elif event.position.x > get_viewport().get_visible_rect().size.x * 0.67:
                    _change_lane(1)
                else:
                    _jump()
            elif absf(delta.x) > absf(delta.y):
                _change_lane(1 if delta.x > 0 else -1)
            elif delta.y < 0:
                _jump()

func _build_world() -> void:
    world_environment = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.035, 0.09)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.42, 0.8)
    env.ambient_light_energy = 0.7
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = env
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_color = Color(0.55, 0.72, 1.0)
    sun.light_energy = 1.4
    add_child(sun)

    for i in range(7):
        var seg := Node3D.new()
        seg.position.z = -float(i) * SEGMENT_LENGTH
        _make_track_segment(seg)
        add_child(seg)
        ground_segments.append(seg)

    for i in range(22):
        var side := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.5, rng.randf_range(2.0, 8.0), rng.randf_range(0.5, 1.6))
        side.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.04,0.08,0.2)
        mat.emission_enabled = true
        mat.emission = Color(0.05,0.2,0.8)
        mat.emission_energy_multiplier = 1.2
        side.material_override = mat
        side.position = Vector3(-6.5 if i % 2 == 0 else 6.5, box.size.y/2.0, -float(i)*9.0)
        add_child(side)

func _make_track_segment(parent: Node3D) -> void:
    var floor := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(TRACK_WIDTH, 0.3, SEGMENT_LENGTH)
    floor.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.035,0.045,0.11)
    mat.metallic = 0.35
    mat.roughness = 0.28
    floor.material_override = mat
    floor.position.y = -0.2
    parent.add_child(floor)
    for x in [-1.15, 1.15]:
        var stripe := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.035,0.025,SEGMENT_LENGTH)
        stripe.mesh = sm
        var lm := StandardMaterial3D.new()
        lm.albedo_color = Color(0.08,0.55,1.0)
        lm.emission_enabled = true
        lm.emission = Color(0.02,0.3,1.0)
        lm.emission_energy_multiplier = 2.0
        stripe.material_override = lm
        stripe.position = Vector3(x, -0.025, 0)
        parent.add_child(stripe)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Runner"
    player.position = Vector3(0,0.9,2.0)
    var shape := CapsuleShape3D.new()
    shape.radius = 0.42
    shape.height = 1.6
    var collision := CollisionShape3D.new()
    collision.shape = shape
    player.add_child(collision)
    player_visual = Node3D.new()
    player.add_child(player_visual)
    _rebuild_player_visual()
    add_child(player)

    camera = Camera3D.new()
    camera.position = Vector3(0,5.0,8.8)
    camera.rotation_degrees = Vector3(-20,0,0)
    camera.fov = 72
    add_child(camera)
    camera.current = true

func _rebuild_player_visual() -> void:
    for child in player_visual.get_children():
        child.queue_free()
    var color: Color = skin_colors.get(skin, skin_colors["cyan"])
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.5
    body.mesh = capsule
    body.position.y = 0.0
    body.material_override = _glow_material(color)
    player_visual.add_child(body)
    var visor := MeshInstance3D.new()
    var visor_mesh := BoxMesh.new()
    visor_mesh.size = Vector3(0.48,0.18,0.1)
    visor.mesh = visor_mesh
    visor.position = Vector3(0,0.25,-0.37)
    visor.material_override = _glow_material(Color(0.95,1.0,1.0))
    player_visual.add_child(visor)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.48
    torus.outer_radius = 0.54
    ring.mesh = torus
    ring.rotation_degrees.x = 90
    ring.position.y = -0.55
    ring.material_override = _glow_material(color)
    player_visual.add_child(ring)

func _glow_material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 1.8
    m.metallic = 0.25
    m.roughness = 0.25
    return m

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(root)

    hud_label = Label.new()
    hud_label.position = Vector2(22,18)
    hud_label.add_theme_font_size_override("font_size", 24)
    hud_label.add_theme_color_override("font_color", Color(0.8,0.96,1))
    root.add_child(hud_label)

    coin_label = Label.new()
    coin_label.position = Vector2(22,84)
    coin_label.add_theme_font_size_override("font_size", 21)
    coin_label.add_theme_color_override("font_color", Color(1.0,0.78,0.2))
    root.add_child(coin_label)

    message_label = Label.new()
    message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    message_label.position.y = 128
    message_label.size = Vector2(700,55)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 22)
    message_label.add_theme_color_override("font_color", Color(0.45,0.95,1))
    root.add_child(message_label)

    _make_button(root, "◀", Vector2(24,-105), Vector2(90,78), func(): _change_lane(-1), true)
    _make_button(root, "▶", Vector2(126,-105), Vector2(90,78), func(): _change_lane(1), true)
    _make_button(root, "JUMP", Vector2(-118,-105), Vector2(100,78), func(): _jump(), false)
    _make_button(root, "SHOP", Vector2(-115,24), Vector2(92,56), func(): _toggle_shop(), false)

    shop_panel = PanelContainer.new()
    shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    shop_panel.position = Vector2(-240,-270)
    shop_panel.size = Vector2(480,540)
    shop_panel.visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025,0.04,0.13,0.97)
    style.border_color = Color(0.05,0.85,1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(18)
    shop_panel.add_theme_stylebox_override("panel", style)
    root.add_child(shop_panel)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    shop_panel.add_child(vb)
    var title := Label.new()
    title.text = "NEON SHOP"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    title.add_theme_color_override("font_color", Color(0.2,0.95,1))
    vb.add_child(title)
    shop_text = Label.new()
    shop_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    shop_text.add_theme_font_size_override("font_size", 17)
    vb.add_child(shop_text)
    _shop_button(vb, "Upgrade: SPEED  —  50 coins", "speed")
    _shop_button(vb, "Upgrade: MAGNET  —  60 coins", "magnet")
    _shop_button(vb, "Upgrade: SHIELD  —  70 coins", "shield")
    _shop_button(vb, "Unlock PINK skin  —  100 coins", "pink")
    _shop_button(vb, "Unlock GOLD skin  —  150 coins", "gold")
    var close := Button.new()
    close.text = "CLOSE"
    close.custom_minimum_size.y = 48
    close.pressed.connect(_toggle_shop)
    vb.add_child(close)

func _make_button(parent: Control, label: String, offset: Vector2, size: Vector2, action: Callable, left: bool) -> void:
    var b := Button.new()
    b.text = label
    b.size = size
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size", 23)
    b.add_theme_color_override("font_color", Color(0.8,0.98,1))
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.04,0.12,0.25,0.8)
    st.border_color = Color(0.0,0.8,1.0,0.9)
    st.set_border_width_all(2)
    st.set_corner_radius_all(14)
    b.add_theme_stylebox_override("normal", st)
    b.add_theme_stylebox_override("hover", st)
    b.add_theme_stylebox_override("pressed", st)
    if left:
        b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
        b.position = offset
    else:
        b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
        b.position = offset
    b.pressed.connect(action)
    parent.add_child(b)

func _shop_button(parent: VBoxContainer, caption: String, item: String) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size.y = 44
    b.add_theme_font_size_override("font_size", 16)
    b.pressed.connect(func(): _buy(item))
    parent.add_child(b)

func _start_level() -> void:
    game_active = true
    lane = 1
    distance = 0.0
    coins_run = 0
    spawn_distance = 0.0
    level_target = 250.0 + float(level - 1) * 150.0
    player.position = Vector3(0,0.9,2.0)
    vertical_velocity = 0.0
    shield_time = 0.0
    magnet_time = 0.0
    boost_time = 0.0
    for obj in objects:
        if is_instance_valid(obj):
            obj.queue_free()
    objects.clear()

func _move_world(delta: float) -> void:
    for seg in ground_segments:
        seg.position.z += run_speed * delta
        if seg.position.z > SEGMENT_LENGTH:
            seg.position.z -= SEGMENT_LENGTH * ground_segments.size()
    for obj in objects:
        if not is_instance_valid(obj):
            continue
        obj.position.z += run_speed * delta
        if obj.position.z > 9.0:
            obj.queue_free()
    objects = objects.filter(func(o): return is_instance_valid(o))

func _update_player(delta: float) -> void:
    var target_x: float = LANES[lane]
    player.position.x = lerpf(player.position.x, target_x, minf(delta * 13.0, 1.0))
    if player.position.y > 0.9 or vertical_velocity > 0.0:
        vertical_velocity -= 23.0 * delta
        player.position.y += vertical_velocity * delta
        if player.position.y < 0.9:
            player.position.y = 0.9
            vertical_velocity = 0.0
    player_visual.rotation.z = lerpf(player_visual.rotation.z, (target_x-player.position.x)*0.08, delta*8.0)
    for obj in objects:
        if not is_instance_valid(obj) or obj.is_queued_for_deletion():
            continue
        if absf(obj.position.z - player.position.z) < 1.15 and absf(obj.position.x-player.position.x) < 0.9:
            if obj.has_meta("kind"):
                _collect_or_hit(obj)

func _update_camera(delta: float) -> void:
    if is_instance_valid(player) and is_instance_valid(camera):
        camera.position.x = lerpf(camera.position.x, player.position.x * 0.28, delta*3.0)
        camera.look_at(player.position + Vector3(0,0.2,-7.0), Vector3.UP)

func _spawn_logic() -> void:
    var interval := maxf(8.0, 17.0 - run_speed * 0.35)
    if spawn_distance >= interval:
        spawn_distance = 0.0
        var lane_pick := rng.randi_range(0,2)
        var roll := rng.randf()
        if roll < 0.43:
            _spawn_obstacle(lane_pick, -38.0, "block")
        elif roll < 0.63:
            _spawn_obstacle(lane_pick, -38.0, "barrier")
        elif roll < 0.82:
            _spawn_coin_line(lane_pick, -34.0)
        elif roll < 0.93:
            _spawn_powerup(lane_pick, -36.0, "magnet" if rng.randf() < 0.5 else "shield")
        else:
            _spawn_powerup(lane_pick, -36.0, "boost")
        if rng.randf() < 0.32:
            var second := (lane_pick + rng.randi_range(1,2)) % 3
            _spawn_coin_line(second, -43.0)

func _spawn_obstacle(lane_index: int, z: float, kind: String) -> void:
    var obj := Node3D.new()
    obj.position = Vector3(LANES[lane_index],0.8,z)
    obj.set_meta("kind", kind)
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    if kind == "barrier":
        box.size = Vector3(1.45,0.65,0.7)
        mesh_instance.position.y = -0.2
    else:
        box.size = Vector3(1.25,1.65,1.0)
    mesh_instance.mesh = box
    mesh_instance.material_override = _glow_material(Color(1.0,0.12,0.32) if kind == "block" else Color(1.0,0.55,0.08))
    obj.add_child(mesh_instance)
    var rim := MeshInstance3D.new()
    var rim_mesh := BoxMesh.new()
    rim_mesh.size = box.size + Vector3(0.08,0.08,0.08)
    rim.mesh = rim_mesh
    var rm := StandardMaterial3D.new()
    rm.albedo_color = Color(0.12,0.02,0.06,0.15)
    rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rm.emission_enabled = true
    rm.emission = Color(1.0,0.08,0.22)
    rm.emission_energy_multiplier = 2.5
    rim.material_override = rm
    obj.add_child(rim)
    add_child(obj)
    objects.append(obj)

func _spawn_coin_line(lane_index: int, z: float) -> void:
    for i in range(5):
        var obj := Node3D.new()
        obj.position = Vector3(LANES[lane_index],1.0,z - float(i)*1.8)
        obj.set_meta("kind","coin")
        var mesh_instance := MeshInstance3D.new()
        var coin_mesh := CylinderMesh.new()
        coin_mesh.top_radius = 0.35
        coin_mesh.bottom_radius = 0.35
        coin_mesh.height = 0.1
        mesh_instance.mesh = coin_mesh
        mesh_instance.rotation_degrees.x = 90
        mesh_instance.material_override = _glow_material(Color(1.0,0.75,0.12))
        obj.add_child(mesh_instance)
        add_child(obj)
        objects.append(obj)

func _spawn_powerup(lane_index: int, z: float, kind: String) -> void:
    var obj := Node3D.new()
    obj.position = Vector3(LANES[lane_index],1.2,z)
    obj.set_meta("kind",kind)
    var mesh_instance := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.48
    sphere.height = 0.96
    mesh_instance.mesh = sphere
    var col := Color(0.1,0.95,0.7) if kind == "shield" else (Color(0.7,0.2,1.0) if kind == "magnet" else Color(0.1,0.55,1.0))
    mesh_instance.material_override = _glow_material(col)
    obj.add_child(mesh_instance)
    add_child(obj)
    objects.append(obj)

func _collect_or_hit(obj: Node3D) -> void:
    var kind: String = obj.get_meta("kind")
    if kind == "coin":
        coins_run += 1
        total_coins += 1
        obj.remove_meta("kind")
        obj.queue_free()
    elif kind == "magnet":
        magnet_time = 9.0 + float(upgrades.magnet)*2.0
        _show_message("MAGNET POWER-UP!")
        obj.remove_meta("kind")
        obj.queue_free()
    elif kind == "shield":
        shield_time = 9.0 + float(upgrades.shield)*2.0
        _show_message("SHIELD ACTIVATED!")
        obj.remove_meta("kind")
        obj.queue_free()
    elif kind == "boost":
        boost_time = 4.0
        _show_message("SPEED BOOST!")
        obj.remove_meta("kind")
        obj.queue_free()
    elif kind == "block" or kind == "barrier":
        if kind == "barrier" and player.position.y > 1.65:
            obj.remove_meta("kind")
            obj.queue_free()
        elif shield_time > 0.0:
            shield_time = 0.0
            obj.remove_meta("kind")
            obj.queue_free()
            _show_message("SHIELD SAVED YOU!")
        else:
            _game_over()

func _change_lane(direction: int) -> void:
    if not game_active or shop_open:
        return
    lane = clampi(lane + direction, 0, 2)

func _jump() -> void:
    if not game_active or shop_open:
        return
    if player.position.y <= 0.91:
        vertical_velocity = 9.2

func _check_level_progress() -> void:
    if distance >= level_target:
        level += 1
        total_coins += 25
        _save_game()
        _show_message("LEVEL UP!  +25 COINS")
        level_target += 150.0

func _game_over() -> void:
    if not game_active:
        return
    game_active = false
    best_distance = maxf(best_distance, distance)
    _save_game()
    _show_message("CRASH!  %d m  •  Tap RESTART" % int(distance))
    var root := ui.get_child(0) as Control
    if not buttons.has("restart"):
        var b := Button.new()
        b.name = "RestartButton"
        b.text = "RESTART"
        b.custom_minimum_size = Vector2(180,62)
        b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
        b.position = Vector2(-90,-205)
        b.add_theme_font_size_override("font_size",25)
        b.pressed.connect(func():
            if is_instance_valid(b):
                b.queue_free()
            buttons.erase("restart")
            _start_level()
        )
        root.add_child(b)
        buttons["restart"] = b

func _toggle_shop() -> void:
    shop_open = not shop_open
    shop_panel.visible = shop_open
    if shop_open:
        _refresh_shop()

func _refresh_shop() -> void:
    shop_text.text = "Coins: %d\\nSpeed Lv. %d  •  Magnet Lv. %d  •  Shield Lv. %d\\nSkin: %s\\n\\nCollect coins during runs to buy upgrades." % [total_coins, upgrades.speed, upgrades.magnet, upgrades.shield, skin.to_upper()]

func _buy(item: String) -> void:
    var cost := 50
    if item == "magnet":
        cost = 60
    elif item == "shield":
        cost = 70
    elif item == "pink":
        cost = 100
    elif item == "gold":
        cost = 150
    if item == "pink" or item == "gold":
        if purchased_skins.has(item):
            skin = item
            _rebuild_player_visual()
            _refresh_shop()
            _save_game()
            return
        if total_coins < cost:
            _show_message("NOT ENOUGH COINS")
            return
        total_coins -= cost
        purchased_skins.append(item)
        skin = item
        _rebuild_player_visual()
    else:
        if int(upgrades[item]) >= 5:
            _show_message("UPGRADE MAXED")
            return
        cost += int(upgrades[item]) * 35
        if total_coins < cost:
            _show_message("NOT ENOUGH COINS")
            return
        total_coins -= cost
        upgrades[item] = int(upgrades[item]) + 1
    _save_game()
    _refresh_shop()

func _update_hud() -> void:
    if is_instance_valid(hud_label):
        hud_label.text = "LEVEL %d   •   %d m" % [level, int(distance)]
    if is_instance_valid(coin_label):
        coin_label.text = "◆  %d  (+%d this run)" % [total_coins, coins_run]
    if is_instance_valid(shop_panel) and shop_open:
        _refresh_shop()

func _show_message(message: String) -> void:
    if is_instance_valid(message_label):
        message_label.text = message

func _save_game() -> void:
    var data := {"total_coins":total_coins,"best_distance":best_distance,"level":level,"upgrades":upgrades,"purchased_skins":purchased_skins,"skin":skin}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    total_coins = int(parsed.get("total_coins",0))
    best_distance = float(parsed.get("best_distance",0.0))
    level = int(parsed.get("level",1))
    upgrades = parsed.get("upgrades",upgrades)
    purchased_skins = parsed.get("purchased_skins",purchased_skins)
    skin = parsed.get("skin","cyan")
