extends CanvasLayer

@onready var hud = $Hud
@onready var label = $Hud/Label
@onready var panel = $Hud/Label/Panel
var panel_style

var is_dragging = false
var drag_start_mouse
var drag_start
var playback
var player
var stats_info
var decimal_precision
var rounding

func _ready():
    var font = FontFile.new()
    font.load_dynamic_font(ModLoader.all_mods["emma-tas_mod"].path_to_dir + "/fixedsys.ttf")
    label.add_theme_font_override("font", font)
    label.add_theme_color_override("font_color", Color.WHITE_SMOKE)

    panel.gui_input.connect(_on_gui_input)
    hud.position = Vector2(20, 390)

    panel_style = panel.get_theme_stylebox("panel")


func _on_gui_input(event: InputEvent):
    if not event is InputEventMouseButton:
        return

    if event.button_mask & 1 == 1:
        is_dragging = true
        drag_start_mouse = get_mpos()
        drag_start = hud.position

    else:
        is_dragging = false


func get_mpos():
    return get_viewport().get_mouse_position()


func format_number(number):
    var return_value = str(snapped(number, rounding)).pad_decimals(decimal_precision)
    if number >= 0:
        return_value = "+" + return_value
    return return_value



func format_numbers(format_string, numbers = null):
    if numbers == null:
        return snapped(format_string, rounding)
    return format_string % numbers.map(format_number)


func is_eligible_for_ledge_climb():
    # check 0: can ledge climb
    # check 1: not on floor
    # check 2: low shape is colliding
    # check 3: high ray is not colliding
    # check 4: down ray is colliding
    # check 5: not currently climbing
    # check 6: low shape is a wall
    # check 7: ceiling shape cast is not colliding

    var checks = []
    var result = "false ("

    checks.append(!player.is_on_floor())
    checks.append(player.ledge_climb_component.low_shape.get_collision_count() > 0)
    checks.append(player.ledge_climb_component.high_ray.get_collider() == null)
    checks.append(player.ledge_climb_component.down_ray.get_collider() != null)
    checks.append(!player.ledge_climb_component.climb_in_progress)

    if player.ledge_climb_component.low_shape.get_collision_count() > 0:
        checks.append(Util.is_wall(player.ledge_climb_component.low_shape.get_collision_normal(0), player))
    else:
        checks.append(false)

    if (
        !player.is_on_floor() and
        player.ledge_climb_component.low_shape.get_collision_count() > 0 and
        player.ledge_climb_component.high_ray.get_collider() == null and
        player.ledge_climb_component.down_ray.get_collider() != null and
        !player.ledge_climb_component.climb_in_progress and
        Util.is_wall(player.ledge_climb_component.low_shape.get_collision_normal(0), player)
    ):
        player.ledge_climb_ceiling_shape_cast.force_shapecast_update()
        checks.append(player.ledge_climb_ceiling_shape_cast.get_collision_count() == 0)
        if checks[-1]:
            result = "true ("

    else:
        checks.append(false)

    result += ",".join(checks) + ")"

    return result


func _physics_process(_delta):
    if ModLoader.all_mods["emma-tas_mod"].hud_toggle.value == false:
        hud.hide()
        return

    if not GameManager.get_player():
        hud.hide()
        return

    hud.show()

    if is_dragging:
        hud.position = drag_start + get_mpos() - drag_start_mouse

    panel_style.bg_color = ModLoader.all_mods["emma-tas_mod"].background_color.value
    label.add_theme_color_override("font_color", ModLoader.all_mods["emma-tas_mod"].text_color.value)

    decimal_precision = ModLoader.all_mods["emma-tas_mod"].rounding.value
    rounding = 0.1 ** decimal_precision

    playback = ModLoader.all_mods["emma-tas_mod"].playback
    player = GameManager.player
    stats_info = {
        "current frame": playback.current_frame,
        "frames since last input": playback.frames_since_last_input,
        "current line": playback.current_line,
        "position": format_numbers("%s, %s, %s", [player.position.x, player.position.y, player.position.z]),
        "velocity": format_numbers("%s, %s, %s (%s)", [player.velocity.x, player.velocity.y, player.velocity.z, sqrt(player.velocity.x**2 + player.velocity.z**2)]),
        "camera": format_numbers("%s, %s", [rad_to_deg(player.pivot.rotation.x), rad_to_deg(player.rotation.y)]),
        "blood": format_numbers(player.blood_amount),
        "player state": player.current_state_name,
        "touching ground": player.is_on_floor(),
        "is wallriding": player.is_on_wall(),
        "can walljump": player.wall_check(0) or player.wall_check(1),
        "walljump timer": format_numbers(player.wall_jump_timer.time_left),
        "ledge climb": is_eligible_for_ledge_climb(),
        # "can parry": figure_this_shit_out(),
    }

    var display_text = ""
    for stat_name in stats_info:
        var stat_value = stats_info[stat_name]
        display_text += "%s: %s\n" % [stat_name, stat_value]
    display_text = display_text.strip_edges()

    label.text = display_text
