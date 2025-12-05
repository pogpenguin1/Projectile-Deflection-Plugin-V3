extends StaticBody2D


# Which projectiel scene this turret should fire.
@export var projectile_scene: PackedScene

## How often to fire projectiles (in seconds).
@export var fire_interval: float = 5.0

## Speed of fired projectiles.
@export var projectile_speed: float = 250.0

## Which node to aim at (the player?).
@export var target_player_path: NodePath

@onready var muzzle: Node2D = $FiringMuzzle
@onready var target_player := get_node_or_null(target_player_path)

var _time_accumulated: float = 0.0


func _physics_process(delta: float) -> void:
	# Simple timer: fire once every fire_interval seconds.
	_time_accumulated += delta
	if _time_accumulated >= fire_interval:
		_time_accumulated -= fire_interval
		_fire_projectile()


func _fire_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	# Add projectile to the main scene so it behaves like everything else.
	get_tree().current_scene.add_child(projectile)

	# Spawn at the firing muzzle position.
	projectile.global_position = muzzle.global_position

	# Decide direction: aim at player if we have one, otherwise just shoot left.
	var dir: Vector2
	if target_player != null:
		dir = (target_player.global_position - projectile.global_position).normalized()
	else:
		dir = Vector2.LEFT

	# Launch using your DeflectableProjectile2D.
	projectile.launch(dir, projectile_speed, self, 1)
