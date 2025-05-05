extends "res://addons/ModLoader/mod_node.gd"

var player
var advance_frame = false
var parser
var playback
var saved_pos
var camera_pause = false:
    set(value):
        if value == false:
            saved_pos = null
            player.process_mode = PROCESS_MODE_INHERIT
        camera_pause = value

var hud_toggle = Setting.new(self, "Info HUD enabled", Setting.SETTING_BOOL, true)
var graph_toggle = Setting.new(self, "Angle graph enabled", Setting.SETTING_BOOL, true)

var rounding = Setting.new(self, "Decimal rounding", Setting.SETTING_INT, 3, Vector2(0, 10))

var tas_file = Setting.new(self, "TAS file path", Setting.SETTING_BUTTON, func(): file_selector(["*.tas"], tas_file))
var keybinds_file = Setting.new(self, "Keybinds path", Setting.SETTING_BUTTON, func(): file_selector(["*.json"], keybinds_file))
var background_color = Setting.new(self, "Background color", Setting.SETTING_BUTTON, func(): color_picker(background_color))
var text_color = Setting.new(self, "Text color", Setting.SETTING_BUTTON, func(): color_picker(text_color))


func file_selector(file_filters, target_var):
    var file_dialog = FileDialog.new()
    file_dialog.set_filters(file_filters)
    file_dialog.set_file_mode(0)
    file_dialog.set_access(2)
    file_dialog.connect("file_selected", func(path): target_var.value = path)
    add_child(file_dialog)
    file_dialog.popup_centered_ratio()


func color_picker(target_var):
    var color_picker = ColorPicker.new()
    color_picker.connect("color_changed", func(color): target_var.value = color)

    var canvas_layer = CanvasLayer.new()
    canvas_layer.layer = 10
    add_child(canvas_layer)

    var close_button = Button.new()
    close_button.text = "Close"
    close_button.connect("pressed", func(): color_picker.queue_free(); close_button.queue_free(); canvas_layer.queue_free())

    canvas_layer.add_child(color_picker)
    canvas_layer.add_child(close_button)

    close_button.set_position(Vector2(4, -34))
    close_button.set_size(Vector2(256, 31))
    canvas_layer.set_offset(Vector2(1200, 250))


func init():
    settings = {
        "settings_page_name" = "TAS mod",
        "settings_list" = [
            rounding,
            text_color,
            background_color,
            keybinds_file,
            tas_file,
            graph_toggle,
            hud_toggle,
        ],
    }

    process_mode = PROCESS_MODE_ALWAYS
    process_physics_priority = 1

    add_input_event("advance_frame", [KEY_BRACKETLEFT])
    add_input_event("resume", [KEY_BRACKETRIGHT])
    add_input_event("start_tas", [KEY_BACKSLASH])
    add_input_event("stop_tas", [KEY_SEMICOLON])
    add_input_event("update_inputs", [KEY_APOSTROPHE])

    var hud_scene = load(path_to_dir + "/hud.tscn").instantiate()
    var hud_script = load(path_to_dir + "/hud.gd")
    hud_scene.set_script(hud_script)
    add_child(hud_scene)

    var graph_scene = load(path_to_dir + "/graph.tscn").instantiate()
    var graph_script = load(path_to_dir + "/graph.gd")
    graph_scene.set_script(graph_script)
    add_child(graph_scene)

    var input_service_override = load(path_to_dir + "/input_service.gd")
    input_service_override.take_over_path("res://scripts/services/input_service.gd")
    InputService.set_script(input_service_override)


func _input(event: InputEvent) -> void:
    if not camera_pause:
        return

    if event is InputEventMouseMotion:
        player.rotate_y(-event.relative.x * (player.look_sensitivity / 100))
        var rotation_amount_degrees = rad_to_deg(-event.relative.y * (player.look_sensitivity / 100) * GameManager.y_axis_inversion)
        var min_allowed_rotation = player._MIN_X_ROTATION_DEGREES - player.pivot.rotation_degrees.x
        var max_allowed_rotation = player._MAX_X_ROTATION_DEGREES - player.pivot.rotation_degrees.x
        rotation_amount_degrees = clamp(rotation_amount_degrees, min_allowed_rotation, max_allowed_rotation)
        player.pivot.rotate_x(deg_to_rad(rotation_amount_degrees))


func start_tas():
    if tas_file.value != "" and keybinds_file.value != "":
        if playback != null and playback.current_frame != -1:
            playback.stop_tas()
            playback.enable_inputs()
            playback = null

        # ResourceLoader.load(path, type_hint, cache_mode)
        parser = ResourceLoader.load(path_to_dir + "/parser.gd", "", 0).new()
        playback = ResourceLoader.load(path_to_dir + "/playback.gd", "", 0).new()
        playback.play_inputs(parser.read(tas_file.value, keybinds_file.value))


func close_file(file):
    await get_tree().create_timer(1).timeout
    file.close()


func _physics_process(delta):
    player = GameManager.player
    if not is_instance_valid(player):
        return

    if advance_frame:
        advance_frame = false
        get_tree().paused = true

    if camera_pause:
        player.process_mode = PROCESS_MODE_ALWAYS
        if saved_pos == null:
            saved_pos = player.global_position
        player.global_position = saved_pos
        player.velocity = Vector3()

    if Input.is_action_just_pressed("start_tas"):
        camera_pause = false
        start_tas()

    if Input.is_action_just_pressed("stop_tas"):
        camera_pause = false
        if playback != null and playback.current_frame != -1:
            playback.stop_tas()
            playback.enable_inputs()
            playback = null

    if Input.is_action_just_pressed("advance_frame"):
        camera_pause = false
        advance_frame = true
        get_tree().paused = false

    if Input.is_action_just_pressed("resume"):
        camera_pause = false
        get_tree().paused = false

    if Input.is_action_just_pressed("update_inputs") and tas_file.value != "" and keybinds_file.value != "":
        parser = ResourceLoader.load(path_to_dir + "/parser.gd", "", 0).new()
        var inputs = parser.read(tas_file.value, keybinds_file.value)
        playback.tas_inputs = inputs.map(func (input_item): return input_item[0])
        playback.lines = inputs.map(func (input_item): return input_item[1])

    if get_tree().paused:
        return

    playback.update()
