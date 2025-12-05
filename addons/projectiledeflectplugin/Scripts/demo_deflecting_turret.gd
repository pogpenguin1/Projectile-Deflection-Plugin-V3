extends StaticBody2D


## Which projectile scene this turret should fire.
@export var projectile_scene: PackedScene

## How often to fire projectiles (in seconds).
@export var fire_interval: float = 3.0    

## How often this turret can attempt a deflect (in seconds). # Currently, just a debug option.
@export var deflect_interval: float = 10.0

## Speed of fired projectiles.
@export var projectile_speed: float = 150.0

## Which node to aim at (the player?).
@export var target_player_path: NodePath

## How many projectiles can this turret deflect before shield break?
@export var max_deflects: int = 3

## Which team ID is the turret vulnterable to?
@export var vulnerable_to_team_id: int = 0

@onready var muzzle: Node2D = $FiringMuzzle
@onready var target_player := get_node_or_null(target_player_path)

# Deflector2D child used to actually perform the deflect.
@onready var deflector: Node = $Deflector2D

var fire_timer: float = 0.0
var deflect_timer: float = 0.0
var deflects_done: int = 0
var is_destroyed: bool = false


func _ready() -> void:
# Look for successful deflects from this turret's deflector.
	if deflector.has_signal("deflect_successful"):
		deflector.deflect_successful.connect(on_deflect_success)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
		
# Timing on the firing of projectiles.
	fire_timer += delta
	if fire_timer >= fire_interval:
		fire_timer -= fire_interval
		fire_projectile()

# Deflect window of opportunity logic
	deflect_timer += delta
	if deflect_timer >= deflect_interval:
		deflect_timer -= deflect_interval
		start_deflect_window()


func fire_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
# Add projectile to the main scene so it behaves like everthing else.
	get_tree().current_scene.add_child(projectile)

# Base spawn position =  at the firing muzzle.
	var spawn_pos: Vector2 = muzzle.global_position

# Decide direction: aim at player if they exist, otherwise just shoot left. (avoids anoyying errors)
	var dir: Vector2
	if target_player != null:
		dir = (target_player.global_position - spawn_pos).normalized()
	else:
		dir = Vector2.LEFT

# Nudge spawn point forward so it doesn't clip the turret collider and instantly die.
	var spawn_offset: float = 15.0
	spawn_pos += dir * spawn_offset

	projectile.global_position = spawn_pos

# Launch using your DeflectableProjectile2D.
# Fire as enemy team (1) so player deflects turn it "friendly", and this turret's deflector
# cango and turn them back to enemy again.
	projectile.launch(dir, projectile_speed, self, 1)


func start_deflect_window() -> void:
# Ask the Deflector2D to open its deflect window.
# It will stay open for deflect_window seconds (set on the Deflector2D).
	if deflector == null:
		return
	
	if deflector.has_method("start_deflect_window"):
		deflector.start_deflect_window()
	
func on_deflect_success(projectile: Node) -> void:
	if is_destroyed:
		return

	deflects_done += 1
	print("DeflectingTurret: deflected projectile, count =", deflects_done)

	if deflects_done >= max_deflects:
# Break the shield and disable this deflector so it can't deflect anymore.
		deflector.enabled = false

# If you're using 'always_deflect_when_enabled', also overrides that.
		deflector.always_deflect_when_enabled = false
			
			
# Optional: change colour to show it's vulnerable.
		if has_node("Sprite2D"):
			$Sprite2D.modulate = Color(1.0, 0.6, 0.6)  # light red tint


# Called from projectiles via body.has_method("take_projectile_hit").
func take_projectile_hit(projectile: Node) -> void:
	if is_destroyed:
		return

	# Only vulnerable once the deflector is disabled.
	if deflector.enabled:
		return

	# Only let projectiles from the "player" team destroy it.
	if projectile.team_id == vulnerable_to_team_id:
		is_destroyed = true
		print("DeflectingTurret: destroyed by projectile from team", projectile.team_id)
		queue_free()
