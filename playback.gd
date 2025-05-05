extends "res://addons/ModLoader/mod_node.gd"

# set this to true if you want to have control while the tas is playing
var dont_disable_inputs = false

var is_recording = false
var recording_images = []
var img_index = 0
var disable_mouse = false
var player
var saved_events = {}
var lines = []
var tas_inputs = []
var current_frame = -1
var frames_since_last_input = -1
var pressed_keys = []
var joystick_input_processing = null
var joypad_keys = []
var current_line = ""


func disable_inputs():
    if dont_disable_inputs:
        return

    disable_mouse = true
    Input.set_mouse_mode(1)
    for action in ["move_forward", "move_backward", "move_left", "move_right", "jump", "wall_jump", "crouch", "slide", "ground_pound", "ledge_climb", "attack", "shoot", "air_dash", "parry", "restart_level", "restart"]:
        saved_events[action] = InputMap.action_get_events(action)
        InputMap.action_erase_events(action) # removes all* keybinds


func enable_inputs():
    if dont_disable_inputs:
        return

    disable_mouse = false
    Input.set_mouse_mode(2)
    for action in saved_events:
        for event in saved_events[action]:
            InputMap.action_add_event(action, event) # re-adds keybinds
    saved_events = {}


func stop_tas():
    current_frame = -1
    for input in pressed_keys:
        Input.action_release(input)
    pressed_keys = []
    if joystick_input_processing != null:
        joystick_event(0, 0)
        joystick_input_processing = null


func play_inputs(inputs):
    tas_inputs = inputs.map(func (input_item): return input_item[0])
    lines = inputs.map(func (input_item): return input_item[1])

    disable_inputs()
    stop_tas()
    current_frame = 0
    pressed_keys = []


func combine_images(dir):
    if OS.execute("which", ["ffmpeg"]) != 0:
        push_error("ffmpeg not installed, skipping video creation")
        return

    var commands = [
        "-f", "concat",
        "-safe", "0",
        "-i", dir + "/video/files.txt",
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-pix_fmt", "yuv420p",
        "-an",
        "-shortest",
        dir + "/output.mp4"
    ]

    var output = []
    var exit_code = OS.execute("ffmpeg", commands, output, true)
    if exit_code != 0:
        push_error("ffmpeg error: ", output)
    else:
        print("ffmpeg finished")


func update():
    if current_frame == -1:
        return

    if not GameManager.get_player():
        return

    player = GameManager.player

    if current_frame >= len(tas_inputs):
        stop_tas()
        enable_inputs()
        return

    if is_recording:
        var img_path = "%s/video/%s.jpg" % [ModLoader.all_mods["emma-tas_mod"].path_to_dir, img_index]
        ModLoader.all_mods["emma-tas_mod"].get_viewport().get_texture().get_image().save_jpg(img_path, 0.85)
        recording_images.append([img_path, Engine.get_physics_ticks_per_second()])
        img_index += 1

    if disable_mouse:
        Input.set_mouse_mode(1)

    var no_input = true
    while no_input:
        if lines[current_frame] == current_line:
            frames_since_last_input += 1
        else:
            frames_since_last_input = 1
        current_line = lines[current_frame]
        no_input = false
        var frame_inputs = tas_inputs[current_frame]
        for input in frame_inputs:
            input = input.to_lower()
            var function = input.split("(")[0]
            var args = input.split("(")[1].split(")")[0].split(",")

            if input == "instantinput":
                for action in frame_inputs[1]:
                    if action in pressed_keys:
                        pressed_keys.erase(action)
                        Input.action_release(action)
                    Input.action_press(action)
                    Input.action_release(action)
                no_input = true
                break

            elif input == "noinput":
                no_input = true

            elif function == "joystick":
                var angle = args[0].to_float() - 90
                var force = args[1].to_float()
                joystick_event(angle, force)
                joystick_input_processing = true

            elif function == "movecamera":
                move_camera(args[0], args[1], false)

            elif function == "movecameraby":
                move_camera(args[0], args[1], true)

            elif function == "tickrate":
                Engine.set_physics_ticks_per_second(args[0].to_int())

            elif function == "print":
                var print_map = {
                    "pos": player.global_position,
                    "position": player.global_position,
                    "vel": player.velocity,
                    "velocity": player.velocity,
                }
                var print_string = ""
                args.remove_at(0)
                for arg in args:
                    if arg in print_map:
                        print_string += str(print_map[arg]) + " "
                    else:
                        if "\\n" in arg:
                            print_string += arg.replace("\\n", "\n")
                        else:
                            print_string += arg + " "
                print(print_string)

            elif function == "pause":
                ModLoader.all_mods["emma-tas_mod"].get_tree().paused = true

            elif function == "camera_pause":
                ModLoader.all_mods["emma-tas_mod"].camera_pause = true
                ModLoader.all_mods["emma-tas_mod"].get_tree().paused = true

            elif function == "start_recording":
                var dir_access = DirAccess.open(ModLoader.all_mods["emma-tas_mod"].path_to_dir)
                if not dir_access.dir_exists("video"):
                    dir_access.make_dir("video")

                is_recording = true
                recording_images = []
                img_index = 0

            elif function == "end_recording":
                is_recording = false
                var make_video = args[0] == "true"

                var dir = ModLoader.all_mods["emma-tas_mod"].path_to_dir
                var file = FileAccess.open(dir + "/video/files.txt", FileAccess.WRITE)
                file.store_line("ffconcat version 1.0")
                for index in range(recording_images.size()):
                    var img_path = recording_images[index][0]
                    file.store_line("file '%s'" % img_path)
                    if index == 0:
                        file.store_line("duration 1") # makes first frame longer
                    else:
                        file.store_line("duration %f" % (1.0 / recording_images[index][1]))
                file.close()

                if make_video:
                    Thread.new().start(combine_images.bind(dir))

            else:
                Input.action_press(input)
                if input not in pressed_keys:
                    pressed_keys.append(input)

        current_frame += 1

        if no_input:
            continue

        for input in pressed_keys:
            if input not in frame_inputs:
                pressed_keys.erase(input)
                var joystick_command = null
                for new_input in frame_inputs:
                    if "joystick" in new_input:
                        joystick_command = new_input
                        break
                if joystick_command == null:
                    Input.action_release(input)
                else:
                    var angle_radians = deg_to_rad(joystick_command.split("(")[1].split(")")[0].split(",")[0].to_float() - 90)
                    var axis_x = cos(angle_radians)
                    var axis_y = sin(angle_radians)
                    var key_x = "move_left" if axis_x < 0 else "move_right" if axis_x > 0 else ""
                    var key_y = "move_forward" if axis_y < 0 else "move_backward" if axis_y > 0 else ""
                    for key in joypad_keys:
                        if key != key_x and key != key_y:
                            Input.action_release(key)

        if joystick_input_processing == false:
            joystick_event(0, 0)
            joystick_input_processing = null

        if joystick_input_processing == true:
            joystick_input_processing = false

func move_camera(pitch, yaw, relative):
    pitch = deg_to_rad(pitch)
    yaw = deg_to_rad(yaw)

    if relative:
        pitch += player.pivot.rotation.x
        yaw += player.rotation.y

    var min_pitch = deg_to_rad(-89)
    var max_pitch = deg_to_rad(89)

    if pitch < min_pitch:
        pitch = min_pitch
    elif pitch > max_pitch:
        pitch = max_pitch

    player.pivot.rotation.x = pitch
    player.rotation.y = yaw


func joystick_event(degrees, force):
    var angle_radians = deg_to_rad(degrees)

    var axis_x = cos(angle_radians) * force
    var axis_y = sin(angle_radians) * force

    axis_x = clamp(axis_x, -1.0, 1.0)
    axis_y = clamp(axis_y, -1.0, 1.0)

    var event_x = InputEventJoypadMotion.new()
    event_x.device = 0
    event_x.axis = JOY_AXIS_LEFT_X
    event_x.axis_value = axis_x
    Input.parse_input_event(event_x)

    var event_y = InputEventJoypadMotion.new()
    event_y.device = 0
    event_y.axis = JOY_AXIS_LEFT_Y
    event_y.axis_value = axis_y
    Input.parse_input_event(event_y)

    Input.flush_buffered_events() # otherwise get_joy_axis lags behind by one frame

    var key_x = "move_left" if axis_x < 0 else "move_right" if axis_x > 0 else ""
    var key_y = "move_forward" if axis_y < 0 else "move_backward" if axis_y > 0 else ""

    for key in joypad_keys:
        if key != key_x and key != key_y:
            Input.action_release(key)

    joypad_keys.clear()

    if key_x != "":
        Input.action_press(key_x, abs(axis_x))
        joypad_keys.append(key_x)

    if key_y != "":
        Input.action_press(key_y, abs(axis_y))
        joypad_keys.append(key_y)
