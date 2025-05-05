extends "res://scripts/services/input_service.gd"

var tas_mod

var debug = false

func _init():
	tas_mod = ModLoader.all_mods["emma-tasMod"]

func is_action_just_pressed(action_name: String, a: bool = true) -> bool:
	var response = is_tas_action_just_pressed(action_name) or super.is_action_just_pressed(action_name, a)

	if response and debug:
		print("THIS ONE GOT")
		print(action_name)

	return response


func is_tas_action_just_pressed(action_name):
	var frame = tas_mod.playback.current_frame

	if frame == 0:
		return false

	var frame_inputs = tas_mod.playback.tas_inputs[frame-1]
	var old_frame_inputs = tas_mod.playback.tas_inputs[frame-2]
	var is_pressed = (action_name in frame_inputs) and (not action_name in old_frame_inputs) # replace this with however you know if the action is just pressed

	if action_name == "jump" and debug:
		print(frame)
		print(is_pressed)
		print(action_name in frame_inputs)
		print(tas_mod.playback.tas_inputs[frame])
		print(is_pressed)


	return is_pressed
