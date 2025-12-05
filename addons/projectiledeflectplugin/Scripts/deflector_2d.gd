extends Area2D

# This node can deflect deflectable_projectile instances that enter its Area2D.
# Can be placed on players, shieds, enemies, etc.

# Signals for when deflections pass or fail, and for deflection windows of opportunity.
signal deflect_successful(projectile: Node)
signal deflect_failed(projectile: Node)
signal deflect_window_started()
signal deflect_window_ended()
## Enable/Disable Deflecting Mechanic
@export var enabled: bool = true
## Allows you to define only a certain class of projectiles as deflectable
@export var deflect_only_projectiles_in_group: StringName = "deflectable"
## Cooldown time on when this scene/actor can deflect again
@export var deflect_cooldown: float = 0.5
## Time in which deflection is available for scene/actor
@export var deflect_window: float = 0.3
## If enabled, deflection always occurs for scene/actor
@export var always_deflect_when_enabled: bool = false

## Different behaviours for how the projectile will be deflected
## "StraightBack" = invert projectile velocity 
## "TowardsOrigin" = towards projectile source
## "TowardsCrosshair" = towards player crosshair
## "RandomCone" = deflect in random area within specific angle
@export_enum("StraightBack", "TowardsOrigin", "TowardsCrosshair", "RandomCone")
var direction_mode: int = 0

# Logic for RandomCone direction_mode
## The area (in a cone shape) in which a deflection can randomly direct itself
@export var random_cone_angle_degree: float = 30.0

# Speed Behaviour enum
## Different behaviours for speed after deflection
## "Keep" = use projectile's base speed settings
## "Multiply" = Multiply speed after deflect by set amount
## "SetAbsolute" = Override projectile speed settings for a base value through deflector
@export_enum("Keep", "Multiply", "SetAbsolute")
var speed_mode: int = 1

## Multiplier for speed after projectile has been deflected
@export var speed_multiplier: float = 1.5 # Multiplier for deflection projectile speed
## Absolute speed value for override
@export var absolute_speed: float = 500.0 # Override speed settings in projectile script
## Delay before deflect happens (useful for animations, slow-mo, and more)
@export var deflect_delay: float = 0.0 # Can add a slight delay to deflection occuring


# Ownership handling
## Does the projectile belong to someone else after the deflect?
@export var change_owner_on_deflect: bool = true
## Assign ID to whoever now owns the projectile
@export var new_team_id: int = -1 # -1 = ignore, use deflector's team if you add team settings

#Runtime state variables
# Not to be edited directly, change during gameplay and used internally by deflection system
var cooldown_timer: float = 0.0
var window_timer: float = 0.0
var window_active: bool = false

# Automatically connects Area2D signal so user doesnt have to wire manually
func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# Decrease cooldown timer for every physics frame till reaches 0 
func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	# If delfect window is active, count it down until it runs out. Emit signal when time has depleted.
	if window_active:
		window_timer -= delta
		if window_timer <= 0.0:
			window_active = false
			emit_signal("deflect_window_ended")

func get_deflect_direction(projectile: Node) -> Vector2:
	
# As a starting point, get the projectiles current velocity.
	var incoming_velocity: Vector2 = projectile.velocity
	
	match direction_mode:
		0: # StraightBack
		# Send projectile back right where it came from
			if incoming_velocity.length() > 0.0:
				return -incoming_velocity.normalized()
			else:
				#If its stationary then push it away from deflector, helps avoid glitches.
				return (projectile.global_position - global_position).normalized()
				
		1: # TowardsOrigin
		# Aim back at who originally fired the projectile.
			if projectile.original_source != null and projectile.original_source is Node2D:
				var source := projectile.original_source as Node2D
				return (source.global_position - projectile.global_position).normalized()
			else: 
				#Fallback to using StraightBack if no valid origin exists.
				if incoming_velocity.length() > 0.0:
					return -incoming_velocity.normalized()
				return (projectile.global_position - global_position).normalized()
				
		2: # TowardsCursor
		# Aim towards players current mouse position
			var mouse_pos := get_global_mouse_position()
			return (mouse_pos - projectile.global_position).normalized()
			
		3: # RandomCone
		# Start from a base direction, than randomise it within a cone.
			var base_direction: Vector2
			if incoming_velocity.length() > 0.0:
				base_direction = -incoming_velocity.normalized()
			else:
				base_direction = (projectile.global_position - global_position).normalized()
			
			var half_angle_rad :=  deg_to_rad(random_cone_angle_degree * 0.5)
			var offset := randf_range(-half_angle_rad, half_angle_rad)
			return base_direction.rotated(offset).normalized()
			
		# Default Fallback is StraightBack.
	if incoming_velocity.length() > 0.0:
			return -incoming_velocity.normalized()
	return (projectile.global_position - global_position).normalized()
		
		


# Starts the deflect window of opportunity
func start_deflect_window() -> void:
	if not enabled:
		return
		
# Still on cooldown, so it fails
	if cooldown_timer > 0.0:
		return
		
	window_active = true # Sets window as active
	window_timer = deflect_window
	cooldown_timer = deflect_cooldown
	emit_signal("deflect_window_started")

# Detect incoming projectiles and decide whether or not to deflect
# Fails if deflect window is inactive or disabled altogehter
func _on_area_entered(area: Area2D) -> void:
	# If the deflector is disabled, never deflect.
	if not enabled:
		emit_signal("deflect_failed", area)
		return

# If we're NOT in "always deflect" mode, respect the window.
	if not always_deflect_when_enabled and not window_active:
		emit_signal("deflect_failed", area)
		return
		
# If a specific grouping filter is set, only deflect areas that belong to that group.
	if deflect_only_projectiles_in_group != StringName("") and not area.is_in_group(deflect_only_projectiles_in_group):
		return
		
	# Safety check, if area doesnt have a deflect feature, it isnt compatable, so return
	if not area.has_method("deflect"):
		return
		
	var projectile = area

# Direction: based on direction_mode stated earlier
# If the direction vector is null, fail to emit a successful signal
	var deflect_direction: Vector2 = get_deflect_direction(projectile)
	if deflect_direction == Vector2.ZERO:
		emit_signal("deflect_failed", projectile)
		return
		
	
# Speed: decide the final speed using speed_mode by affecting these values
	var speed_override: float = -1.0 # not in effect initially
	var current_speed: float = projectile.velocity.length()
	if current_speed <= 0.0:
		current_speed = projectile.base_speed
	
	match speed_mode:
		0: # Keep (use projectile base settings)
			speed_override = -1.0
			
		1: #Multiply (can multiply speed by set amount on deflect)
			speed_override = current_speed * speed_multiplier
			
		2: # SetAbsolute (override base settings for a hard-coded speed)
			speed_override = absolute_speed
			
		
# Ability to change ownership of projectile.
	if new_team_id != -1:
		projectile.team_id = new_team_id
		
	var owner_for_projectile: Node = projectile.current_owner
	if change_owner_on_deflect:
# Treat the parent as the owner, not the Deflector2D child itself. This is useful for DEBUGGING.
		if get_parent() != null:
			owner_for_projectile = get_parent()
		else:
			owner_for_projectile = self
		
# Ability to delay when the deflect happens (useful for animation syncing, slow-mo)
	if deflect_delay > 0.0:
# Freeze projectile and turn off collisions so it doesnt run into player or walls during delay.

		projectile.velocity = Vector2.ZERO
		if projectile.has_method("set_collision_enabled"):
			projectile.set_collision_enabled(false)
			
		await get_tree().create_timer(deflect_delay).timeout
		
# Projectile might have been destroyed during wait for other reasons.
		if not is_instance_valid(projectile):
			window_active = false
			emit_signal("deflect_window_ended")
			return
		
# Turn collisions back on before firing it back.
		if projectile.has_method("set_collision_enabled"):
			projectile.set_collision_enabled(true)
		
# Perform the deflect
	projectile.deflect(deflect_direction, owner_for_projectile, speed_override)
	
	emit_signal("deflect_successful", projectile)
	
# Close deflect window of opportunity after success
	window_active = false
	emit_signal("deflect_window_ended")
		
		
		
		
		
