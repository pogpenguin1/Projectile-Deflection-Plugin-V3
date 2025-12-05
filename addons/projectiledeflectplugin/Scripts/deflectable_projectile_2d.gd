extends Area2D

# This node is intended for projectiles that can be deflected via Deflector2D node
# This handles movement, deflection, and necessary metadeta

# Signals for when a projectile is deflected or reaches max number of deflections
# Includes arguments for who deflected it, which direction it will head, and at what speed. 
signal deflected(deflected_by: Node, new_direction: Vector2, new_speed: float)
signal max_deflections_reached()


# Basic logic variables for projectile.
## Is this object capable of being deflected?
@export var can_be_deflected: bool = true
## Total number of deflections it can succeed in before failing
@export var max_deflections: int = 3 # 0 allows for unlimited deflections
## Base projectile speed, before being altered through deflection
@export var base_speed: float = 300.0
## Base projectile damage before being deflected
@export var base_damage: float = 1.0

# Logic for speed "stacking" (Allows for projectile to increase in speed with every deflect).
## Allows speed to stack repeatedly on itself with each deflection
@export var enable_speed_stacking: bool = false
## By how much will the speed multiply with each deflect?
@export var speed_multiplier_per_deflect: float = 1.5
## What is the maximum speed it can reach before capping?
@export var max_speed: float = 1000.0

# Logic for damage modifiers on projectile.
## By how much will the damage multiply with a deflected projectile vs a regular one?
@export var deflect_damage_multiplier: float = 1.5
## Will the projectile increase in damage every subsequent deflect?
@export var damage_increases_per_deflect: bool = false
## Bonus damage value on every subsequent deflect
@export var damage_bonus_per_deflect: float = 10.0

# Logic for homing modifier on projectile.
## allows projectiles to home and chase after enemies/objects
@export var enable_homing_after_deflect: bool = false
##  How powerful is the homing attribute?
@export var homing_strength: float = 100.0
## If using NearestTarget homing, projectiles will search this group for targets.
@export var homing_target_group: StringName = ""
## Choice between homing modes, None, OriginalSource(homes back towards orignal shooter of projectile)
## Or NearestTarget(prioritises closest enemy rather than original shooter).
@export_enum("None", "OriginalSource", "NearestTarget") var homing_mode: int = 0

# Logic for projectile ownership after a deflect (colour change, who it can damage).
## Allows the changing of colour with deflections
@export var enable_team_tint: bool = false # Toggle a colour change on team swap of projectile.
## Assigns an ID to deflections that are on your team
@export var friendly_team_id: int = 1 # Whatever the friendly team ID will be.
## The base colour of a projectile before deflection has occurred
@export var default_tint: Color = Color.WHITE # Colour prior to deflect.
## The colour of a projectile after it has been deflected and is friendly to you
@export var friendly_tint: Color = Color.SKY_BLUE # Colour when its on your team

@onready var sprite: Sprite2D = $Sprite2D

# Logic for projectile sprite swaps when projectile gets deflected.
## Allows for changing of sprites once a projectile has been deflected
@export var enable_sprite_swap_on_deflect: bool = false
## What sprite will the deflected projectile be?
@export var deflected_texture: Texture2D

# Reference to remember original sprite texture.
var original_texture: Texture2D



# Runtime state variables
# Not to be edited directly, change during gameplay and used internally by deflection system
var velocity: Vector2 = Vector2.ZERO
var current_deflections: int = 0 
var current_damage: float = 0.0
var original_source: Node = null
var current_owner: Node = null
var team_id: int = 0
var homing_target: Node2D = null

func _ready() -> void:
# Hold onto origianl texture so its restorable when projectile is launched again.
	original_texture = sprite.texture
# Destroy the projectile when it hits a physics body (player, turret, walls)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
# Ignore initial collision with whatever fired it, prevents bullets
# that spawn too close from instantly dying.
	if body == original_source and current_deflections == 0:
		return

# Ignore collisions with whoever currently owns the projectile
# (e.g. deflecting turret right after a deflect).
	if body == current_owner:
		return

# If the body wants to react to projectile hits, call its handler.
# This keeps the projectile generic: any node can implement take_projectile_hit(projectile).
	if body.has_method("take_projectile_hit"):
		body.take_projectile_hit(self)
		

# By default, destroy the projectile on any valid body hit.
	queue_free()




# Basic projectile movement
func _physics_process(delta: float) -> void:
	if velocity != Vector2.ZERO:
# If homing is enabled, and theres a target, home towards it.
		if enable_homing_after_deflect and current_deflections > 0 and homing_target != null:
			apply_homing(delta)
		
		global_position += velocity * delta
# Move the projectile according to its velocity.


		# Rotate the projectile to face the direction of travel.
		rotation = velocity.angle()
		
		
		
# Function for changing projectile colour depending on who last deflected it.
func _apply_team_visuals() -> void:
	# Sprite choice dependant on team.
	if enable_sprite_swap_on_deflect:
		if team_id == friendly_team_id and deflected_texture != null:
			sprite.texture = deflected_texture
		else:
			sprite.texture = original_texture

	# Tint choice depends on team.
	if enable_team_tint:
		if team_id == friendly_team_id:
			sprite.modulate = friendly_tint
		else:
			sprite.modulate = default_tint
		
# Function for launching a projectile
func launch(direction: Vector2, speed: float = base_speed, source: Node = null, team: int = 0) -> void:
	original_source = source # Who fired the projectile.
	current_owner = source # Ownership can chance depending on deflections.
	team_id = team # Stores team projectile data, can be used to prevent friendly fire.
	
# Reset state when spawned, alongside damage.
	current_deflections = 0
	current_damage = base_damage
	print("Projectile launched. base_damage =", base_damage, "current_damage =", current_damage)
	
# Reset sprite texture back to original when projectile is launched.
	if enable_sprite_swap_on_deflect and original_texture != null:
		sprite.texture = original_texture
	
# Call for team visuals function for whoever owns it at projectile spawn.
		_apply_team_visuals()
	
	
	direction = direction.normalized()
	velocity = direction * speed

# Steering logic for homing projectile mechanic.
# turns velocity gradually towards the homing target.
func apply_homing(delta: float) -> void:
	if homing_target == null:
		return
	if not is_instance_valid(homing_target):
		homing_target = null
		return
		
	var to_target := homing_target.global_position - global_position
	if to_target == Vector2.ZERO:
		return
		
	var desired_direction := to_target.normalized()
	var current_speed := velocity.length()
	if current_speed <= 0.0:
		current_speed = base_speed
		
	var current_direction := velocity.normalized()
	var turn_rate := clamp(homing_strength * delta, 0.0, 1.0)
	var new_direction := current_direction.lerp(desired_direction, turn_rate).normalized()
	
	velocity = new_direction * current_speed




func set_homing_target_after_deflect(deflected_by: Node) -> void:
	homing_target = null
	
	match homing_mode:
		0: # None
			return

		1: # OriginalSource = home back to enemy that fired the projectile.
			if original_source is Node2D and is_instance_valid(original_source):
				homing_target = original_source
				
		2: # NearestTarget = search a group for the closest Node2D to home in on.
			homing_target = find_nearest_homing_target()
			

# Finds nearest Node2D in homing_target_group
func find_nearest_homing_target() -> Node2D:
	if homing_target_group == StringName(""):
		return null
		
	var closest_node: Node2D = null
	var closest_distance_sq := INF
	
	var homing_candidates := get_tree().get_nodes_in_group(homing_target_group)
	for node in homing_candidates:
		if not (node is Node2D):
			continue
		if node == current_owner:
			continue
		
			var homing_n2d := node as Node2D
			var distance_sq := global_position.distance_squared_to(homing_n2d.global_position)
			if distance_sq < closest_distance_sq:
				closest_distance_sq = distance_sq
				closest_node = homing_n2d
		
	return closest_node




func set_collision_enabled(enabled: bool) -> void:
# Toggle Area2D monitoring so it stops sending/receiving area/body signals, allowing deflect delay to work properly.
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)

# Disable collisionshape2D so it cant be hit or hit.
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)

# Called bt Deflector2D when deflection occurs
func deflect(new_direction: Vector2, deflected_by: Node, speed_override: float = -1.0) -> void:
	if not can_be_deflected:
		return
		
# If max_deflections is 0, treat it as unlimited and skip the check.
# If current deflections is greater than or equal to the max amount set, emit signal.
	if max_deflections > 0 and current_deflections >= max_deflections:
		emit_signal("max_deflections_reached")
		return
		
# Update deflection counter and ownership
	current_deflections += 1
	current_owner = deflected_by
	
	if current_deflections == 1:
# First deflect: go from base damage and boost it once.
		current_damage = base_damage * deflect_damage_multiplier
	else:
# Later deflects stack on top of existing damage.
		if damage_increases_per_deflect:
# Multiply and add flat bonus each time.
			current_damage = current_damage * deflect_damage_multiplier + damage_bonus_per_deflect
		else:
# If stacking is turned off, still keep the bonus buff.
			current_damage = base_damage * deflect_damage_multiplier


# Determine current speed, always use base speed if speed is 0 or somehow negative
	var current_speed := velocity.length()
	if current_speed <= 0.0:
		current_speed = base_speed
		
	var final_speed := current_speed

# Optional speed override used by SetAbsolute setting in the deflector node
	if speed_override > 0.0:
		final_speed = speed_override

# Optional speed stacking functionality.
	if enable_speed_stacking:
		final_speed *= speed_multiplier_per_deflect
		if final_speed > max_speed:
			final_speed = max_speed
	
	velocity = new_direction.normalized() * final_speed
	
# If enabled, swap to the deflected texture once the projectile is deflected.
	if enable_sprite_swap_on_deflect and deflected_texture != null:
		sprite.texture = deflected_texture
		
# If homing is enabled, pick target to chase after the deflect occurs.
	if enable_homing_after_deflect:
# This avoids multi-deflect setups from fighting with homing logic.
		if current_deflections == 1:
			set_homing_target_after_deflect(deflected_by)
		else: 
			homing_target = null
	
	
# If feature enabled, swaps colour and sprite of projectile to whichever team now has ownership.
	_apply_team_visuals()
	
	
	# DEBUG: log every deflect
	var deflector_label := "Unknown"
	if deflected_by != null:
		deflector_label = deflected_by.name
		
	print(
		"[DEFLECT] by: ", deflector_label,
		" deflect_count: ", current_deflections,
		" speed: ", final_speed,
		" damage: ", current_damage
	)
	
	#print("Deflected") FOR DEBUG
	emit_signal("deflected", deflected_by, new_direction, final_speed)
