extends Node2D

var cache = {}
var player
var font
var is_dragging = false
var drag_start_mouse
var drag_start


func apply_acceleration(velocity, wish_dir, projected_speed, acceleration, top_speed, delta, sliding):
    var speed_remaining = (top_speed * wish_dir.length()) - projected_speed

    if speed_remaining <= 0:
        return velocity

    var slide_mult: float = 1
    if sliding:
        slide_mult = player.slide_multiplier

    var accel_final = acceleration * delta * top_speed * slide_mult

    return Vector3(velocity.x + accel_final * wish_dir.x, velocity.y, velocity.z + accel_final * wish_dir.z)


func apply_friction(velocity, delta, moving_backward):
    var current_speed = velocity.length()

    if (current_speed < 0.1):
        return Vector3.ZERO

    var final_friction = player.friction
    if moving_backward and not player.is_crouching:
        final_friction = final_friction / 2

    var friction_curve = clampf(current_speed, player.lin_friction_speed, INF)

    var speed_scalar = maxf(current_speed - friction_curve * final_friction * delta, 0)

    if speed_scalar > 0:
        return velocity.normalized() * speed_scalar
    else:
        return Vector3.ZERO


func clip_velocity(velocity, normal, overbounce, delta):
    var move_vector = velocity.normalized()

    var correction_amount = move_vector.dot(normal) * overbounce

    var correction_dir = normal * correction_amount
    return velocity - correction_dir


func calculate_slide_velocity(transform, velocity, delta):
    var wish_dir = Vector3(transform.y, 0, -transform.x).normalized()
    var projected_speed = (velocity * Vector3(1, 0, 1)).dot(wish_dir)

    var slide_ground_move_input_speed = min(player.slide_state.base_speed, player.player_slide_max_speed)
    var crouch_ground_move_input_speed = min(player.slide_state._crouch_speed, 32)
    var ground_move_input_speed = max(slide_ground_move_input_speed, crouch_ground_move_input_speed)

    var new_velocity = apply_acceleration(velocity, wish_dir, projected_speed, player.accel, ground_move_input_speed, delta, true)

    if player.on_floor == player.grounded_prev:
        new_velocity = apply_friction(new_velocity, delta, false)

    if player.is_on_wall:
        new_velocity = clip_velocity(new_velocity, player.get_wall_normal(), 1, delta)

    if new_velocity.length() < player.slide_state.MIN_SLIDE_SPEED and new_velocity.normalized().dot(wish_dir) > 0:
        new_velocity = wish_dir * player.slide_state.MIN_SLIDE_SPEED

    return new_velocity


func calculate_air_velocity(wish_dir, velocity, yaw, joystick, delta):
    if player.in_air_state.ground_pounding and Input.is_action_pressed("ground_pound") and player.in_air_state._calc_time_since_ground_pound_started() > 100:
        velocity = velocity.lerp(Vector3.ZERO, player.in_air_state._GROUND_POUND_HORIZONTAL_DECELLERATION_SPEED * delta)

    var new_velocity = velocity + (wish_dir * player.in_air_state._final_air_control_amount * delta)
    if new_velocity.length() > velocity.length():
        new_velocity = new_velocity.normalized() * velocity.length()
    return new_velocity


func calculate_wallrun_velocity(wish_dir, velocity, yaw, joystick, delta):
    var new_velocity = velocity + (wish_dir * player.wall_run_state.AIR_CONTROL_AMOUNT * delta)
    if new_velocity.length() > velocity.length():
        new_velocity = new_velocity.normalized() * velocity.length()
    return new_velocity


func calculate_water_velocity(input_dir, velocity, yaw, joystick, delta):
    if input_dir:
        var player_camera = GameManager.get_player_camera()

        velocity = (player_camera.global_transform.basis.z).normalized() * input_dir.y + \
                   (player_camera.global_transform.basis.x).normalized() * input_dir.x
        return velocity * player.swim_speed
    return velocity.move_toward(Vector3.ZERO, delta * player.in_water_state.WATER_SLOW_DOWN_SPEED)


func calculate_dogpaddling_velocity(input_dir, velocity, yaw, joystick, delta):
    if input_dir:
        var player_camera = GameManager.get_player_camera()

        var move_dir = player_camera.global_transform.basis.z
        if input_dir.y < 0:
            move_dir.y = max(move_dir.y, 0)
        elif input_dir.y > 0:
            move_dir.y = min(move_dir.y, 0)
        move_dir = move_dir.normalized()

        velocity = (move_dir * input_dir.y) + \
                   (player_camera.global_transform.basis.x).normalized() * input_dir.x
        return velocity * player.swim_speed
    return velocity.move_toward(Vector3.ZERO, delta * player.in_water_state.WATER_SLOW_DOWN_SPEED)


func calculate_velocity(velocity, yaw, joystick, delta):
    var transform = Vector2(cos(deg_to_rad(yaw)), sin(deg_to_rad(yaw)))
    var input_dir = Vector2(cos(deg_to_rad(joystick - 90)), sin(deg_to_rad(joystick - 90)))
    var wish_dir = Vector3(transform.x * input_dir.x - transform.y * input_dir.y, 0, transform.y * input_dir.x + transform.x * input_dir.y).normalized()

    var moving_backwards = false
    var top_speed
    var sliding = false

    match player.current_state_name:
        "OnGround":
            moving_backwards = input_dir.y > 0
            top_speed = player.top_speed_ground

        "Crouch":
            top_speed = min(player.crouch_state.speed, 32)

        "Slide":
            return calculate_slide_velocity(transform, velocity, delta) * Vector3(1, 0, 1)

        "InAir":
            return calculate_air_velocity(wish_dir, velocity, yaw, joystick, delta) * Vector3(1, 0, 1)

        "WallRun":
            return calculate_wallrun_velocity(wish_dir, velocity, yaw, joystick, delta) * Vector3(1, 0, 1)

        "InWater":
            return calculate_water_velocity(input_dir, velocity, yaw, joystick, delta) * Vector3(1, 0, 1)

        "DogPaddling":
            return calculate_dogpaddling_velocity(input_dir, velocity, yaw, joystick, delta) * Vector3(1, 0, 1)

        _:
            return velocity * Vector3(1, 0, 1)

    if moving_backwards:
        top_speed = top_speed / 2

    var projected_speed = (velocity * Vector3(1, 0, 1)).dot(wish_dir)
    var new_velocity = apply_acceleration(velocity, wish_dir, projected_speed, player.accel, top_speed, delta, sliding)

    if player.on_floor == player.grounded_prev:
        new_velocity = apply_friction(new_velocity, delta, moving_backwards)

    if player.is_on_wall:
        new_velocity = clip_velocity(new_velocity, player.get_wall_normal(), 1, delta)

    return new_velocity * Vector3(1, 0, 1)


func _ready():
    font = FontFile.new()
    font.load_dynamic_font(ModLoader.all_mods["emma-tas_mod"].path_to_dir + "/fixedsys.ttf")


func _draw():
    if ModLoader.all_mods["emma-tas_mod"].graph_toggle.value == false:
        return

    if not GameManager.get_player():
        return
    player = GameManager.player

    var start_x = 70
    var start_y = 50
    var end_x = 360 + start_x
    var end_y = 300 + start_y
    var max_pixels = 300

    var color = Color8(128, 0, 0)
    var step = 30
    for x in range(start_x, end_x + 1, step):
        draw_line(Vector2(x, start_y), Vector2(x, end_y), color)
    for y in range(start_y, end_y + 1, step):
        draw_line(Vector2(start_x, y), Vector2(end_x, y), color)

    var yaw = -rad_to_deg(player.rotation.y)
    var delta = 1.0 / Engine.physics_ticks_per_second

    var cache_key = "|".join([player.current_state_name, player.velocity, delta])
    var cache_value = cache.get(cache_key)
    if cache_value == null:
        var bests = [[0, 0], [0, 0]]
        var best_angles = []

        var new_best = []
        var sources = [[0, 0]]
        var start_angle = -180.0
        var end_angle = 180.0
        var angle = start_angle

        var default_velocity = calculate_velocity(player.velocity, yaw, 0, delta)

        var y_values = []
        var min_y = INF
        var max_y = -INF
        while angle <= end_angle:
            var speed
            if player.current_state_name == "Slide":
                speed = calculate_velocity(player.velocity, angle, 0, delta).length()
            else:
                speed = calculate_velocity(player.velocity, yaw, angle, delta).length()
            y_values.append(speed)
            if speed < min_y:
                min_y = speed
            if speed > max_y:
                max_y = speed
            new_best.append([angle, speed])
            angle += 1.0

        new_best.sort_custom(func(a, b): return a[1] > b[1])
        if new_best.size() > 10:
            new_best.resize(10)
        best_angles = new_best

        new_best = []
        for source in best_angles.slice(0, 5):
            var center = source[0]
            start_angle = max(-180.0, center - 1.0)
            end_angle = min(180.0, center + 1.0)
            angle = start_angle

            while angle <= end_angle:
                var speed
                if player.current_state_name == "Slide":
                    speed = calculate_velocity(player.velocity, angle, 0, delta).length()
                else:
                    speed = calculate_velocity(player.velocity, yaw, angle, delta).length()
                new_best.append([angle, speed])
                angle += 0.1

        new_best.sort_custom(func(a, b): return a[1] > b[1])
        if new_best.size() > 10:
            new_best.resize(10)
        best_angles = new_best

        for source in best_angles:
            var center = source[0]
            start_angle = max(-180.0, center - 0.1)
            end_angle = min(180.0, center + 0.1)
            angle = start_angle

            while angle <= end_angle:
                var speed
                if player.current_state_name == "Slide":
                    speed = calculate_velocity(player.velocity, angle, 0, delta).length()
                else:
                    speed = calculate_velocity(player.velocity, yaw, angle, delta).length()

                var angle_threshold = 10 # this is done to prevent bests from being too close
                if speed > bests[1][1]:
                    if abs(angle - bests[0][0]) < angle_threshold:
                        if speed > bests[0][1]:
                            bests[0] = [angle, speed]
                    elif abs(angle - bests[1][0]) < angle_threshold:
                        if speed > bests[1][1]:
                            bests[1] = [angle, speed]
                    else:
                        bests[0] = bests[1]
                        bests[1] = [angle, speed]
                elif speed > bests[0][1] and abs(angle - bests[1][0]) >= angle_threshold:
                    bests[0] = [angle, speed]

                angle += 0.01

        var mapping = max_y - min_y
        var flat_line = mapping < 0.001

        var lines = [PackedVector2Array()]
        var previous_speed = y_values[0]
        for x_value in range(len(y_values)):
            var speed = y_values[x_value]
            var y_value = 0.5
            if not flat_line:
                y_value = (speed - min_y) / mapping # 0 to 1 (min to max)
            y_value = 1 - y_value # 0 to 1 (max to min)
            y_value *= max_pixels
            if absf(speed - previous_speed) > 0.05:
                lines.append(PackedVector2Array())
            lines[-1].append(Vector2(x_value + start_x, y_value + start_y))
            previous_speed = speed

        cache_value = [lines, max_y, min_y, bests, default_velocity, flat_line, mapping]
        cache[cache_key] = cache_value

    var lines = cache_value[0]
    var max_y = cache_value[1]
    var min_y = cache_value[2]
    var bests = cache_value[3]
    var default_velocity = cache_value[4]
    var flat_line = cache_value[5]
    var mapping = cache_value[6]

    for points in lines:
        if points.size() > 1:
            draw_polyline(points, Color.RED, 1, false)
        else:
            draw_circle(points[0], 1, Color.RED)

    draw_string(font, Vector2(10, 54), snapped(max_y, 0.001))
    draw_string(font, Vector2(10, 203), "Speed")
    draw_string(font, Vector2(10, 354), snapped(min_y, 0.001))

    draw_string(font, Vector2(49, 367), "-180°")
    if player.current_state_name == "Slide":
        draw_string(font, Vector2(193, 367), "Camera yaw")
    else:
        draw_string(font, Vector2(193, 367), "Movement angle")
    draw_string(font, Vector2(410, 367), "+180°")

    if bests.size() > 0 and player.current_state_name:
        var first_best = bests[0]
        var second_best = bests[1]
        if first_best[0] >= 0:
            first_best = bests[1]
            second_best = bests[0]

        if abs(first_best[1] - default_velocity.length()) < 0.001:
            draw_string(font, Vector2(10, 20), "Best: 0.00, %.4f" % first_best[1])
        else:
            draw_string(font, Vector2(10, 20), "First best: %.2f, %.4f" % first_best)
            draw_string(font, Vector2(10, 36), "Second best: %.2f, %.4f" % second_best)

    draw_string(font, Vector2(260, 20), "Speed step: %.3f" % (0 if flat_line else mapping / max_pixels * step))
    draw_string(font, Vector2(260, 36), "Angle step: %.3f" % (1.0 * step))

    if player.current_state_name == "Slide":
        var player_angle = fmod(180 - yaw, 360)
        if player_angle < 0.00001:
            draw_line(Vector2(end_x, start_y), Vector2(end_x, end_y), Color8(128, 255, 128))
        elif player_angle > 359.99999:
            draw_line(Vector2(start_x, start_y), Vector2(start_x, end_y), Color8(128, 255, 128))
        draw_line(Vector2(player_angle + start_x, start_y), Vector2(player_angle + start_x, end_y), Color8(128, 255, 128))
    else:
        var x_axis = Input.get_axis("move_backward", "move_forward")
        var y_axis = Input.get_axis("move_left", "move_right")
        if x_axis != 0 or y_axis != 0:
            var player_angle = fmod(270 - rad_to_deg(atan2(x_axis, y_axis)), 360)
            if player_angle == 0:
                draw_line(Vector2(end_x, start_y), Vector2(end_x, end_y), Color8(128, 255, 128))
            draw_line(Vector2(player_angle + start_x, start_y), Vector2(player_angle + start_x, end_y), Color8(128, 255, 128))


func _process(delta):
    queue_redraw()
