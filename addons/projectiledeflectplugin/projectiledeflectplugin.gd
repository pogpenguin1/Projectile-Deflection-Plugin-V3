@tool
extends EditorPlugin

# Preloads the scripts that define the plugin's custom nodes
# Loaded immediately when the plugin itself loads, making sure theyre always available
var deflectableprojectile_script := preload("res://addons/projectiledeflectplugin/Scripts/deflectable_projectile_2d.gd")
var deflector_script := preload("res://addons/projectiledeflectplugin/Scripts/deflector_2d.gd")

# Custom nodes may show errors when an icon isnt given to it. These icons are purely for editor quality of life
var deflectableprojectile_icon := preload("res://addons/projectiledeflectplugin/Icons/Projectile_Icon.png")
var deflector_icon := preload("res://addons/projectiledeflectplugin/Icons/Deflect_Icon.png")


func _enter_tree():
	# Can be uncommented to quickly check if plugin is loading effectively.
	# print("Enabled Deflection Plugin")
	
	# Adds custom nodes for the deflected projectiles and the deflector.
	# Includes base type, scripts to attach, and editor icons.
	add_custom_type("DeflectableProjectile2D","Area2D",deflectableprojectile_script,deflectableprojectile_icon)
	add_custom_type("Deflector2D","Area2D",deflector_script,deflector_icon)
	add_default_input_actions()
	set_pixel_art_filter()

func _exit_tree():
	# Can be uncommented to quickly check if plugin is loading effectively.
	# print("Disabled Deflection Plugin").
	
	remove_custom_type("DeflectableProjectile2D")
	remove_custom_type("Deflector2D")
	
	
	
	
func ensure_action(action_name: StringName, events: Array[InputEvent]) -> void:
# Only add the plugin action if it doesnt already exist via user.
# Users can define their own bindings and this plugin shouldn't overwrite them.
	var key := "input/%s" % String(action_name)

	if ProjectSettings.has_setting(key):
		return

	var action := {
	"deadzone": 0.5,
	"events": events,
}

	ProjectSettings.set_setting(key, action)
	ProjectSettings.save()  # Persist changes to project.godot


# Create default input actions for movement, jump, and a deflect for use in the demo levels, and also for use elsewhere if desired.
func add_default_input_actions() -> void:
	
	# move_left = A and Left Arrow. 
	var move_left_events: Array[InputEvent] = []
	
	var ev_a := InputEventKey.new()
	ev_a.physical_keycode = KEY_A
	move_left_events.append(ev_a)
	
	var ev_left := InputEventKey.new()
	ev_left.physical_keycode = KEY_LEFT
	move_left_events.append(ev_left)
	
	ensure_action("move_left", move_left_events)
	
	
	# move_right = D and Right Arrow.
	var move_right_events: Array[InputEvent] = []
	
	var ev_d := InputEventKey.new()
	ev_d.physical_keycode = KEY_D
	move_right_events.append(ev_d)
	
	var ev_right := InputEventKey.new()
	ev_right.physical_keycode = KEY_RIGHT
	move_right_events.append(ev_right)
	
	ensure_action("move_right", move_right_events)
	
	
	# Jump = Space and Up Arrow.
	var jump_events: Array[InputEvent] = []

	var ev_space := InputEventKey.new()
	ev_space.physical_keycode = KEY_SPACE
	jump_events.append(ev_space)

	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_UP
	jump_events.append(ev_up)

	ensure_action("jump", jump_events)
	
	
	# Deflect = Right Mouse Button and Q.
	var deflect_events: Array[InputEvent] = []

	var ev_q := InputEventKey.new()
	ev_q.physical_keycode = KEY_Q
	deflect_events.append(ev_q)

	var ev_rmb := InputEventMouseButton.new()
	ev_rmb.button_index = MOUSE_BUTTON_RIGHT
	deflect_events.append(ev_rmb)

	ensure_action("deflect", deflect_events)



# Sets projects 2D defualt texture filter to nearest so that pixel art looks sharp in the demo on initial launch.
func set_pixel_art_filter() -> void:
	var key := "rendering/textures/canvas_textures/default_texture_filter"
	
	if not ProjectSettings.has_setting(key):
		return
	
	var current := int(ProjectSettings.get_setting(key))
	
	if current == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR:
		ProjectSettings.set_setting(key, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		ProjectSettings.save()
	
