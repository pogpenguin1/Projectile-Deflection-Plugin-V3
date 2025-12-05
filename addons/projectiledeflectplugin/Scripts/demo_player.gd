extends CharacterBody2D

# Movement 
const SPEED:float = 100.0
const JUMP_VELOCITY:float = -220.0
const GRAVITY_MULTIPLIER:float = 800

# Cached references to child nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var deflector = $Deflector2D

func _ready() -> void:
# Optional visual feedback: youcan change sprite when deflect window is active.
	if deflector.has_signal("deflect_window_started"):
		deflector.deflect_window_started.connect(_on_deflect_window_started)
	if deflector.has_signal("deflect_window_ended"):
		deflector.deflect_window_ended.connect(_on_deflect_window_ended)
		
func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	velocity.x = input_dir * SPEED

	if not is_on_floor():
		velocity.y += GRAVITY_MULTIPLIER * delta
	else:
# Only allow jumping when players grounded.
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	# Actually move and collide.
	move_and_slide()

	# --- DEFLECT INPUT ---
	if Input.is_action_just_pressed("deflect"):
		if deflector.has_method("start_deflect_window"):
			deflector.start_deflect_window()
		elif deflector.has_method("activate"):
			deflector.activate()


func _on_deflect_window_started() -> void:
	# If you're using frames (0 = normal, 1 = barrier), switch to barrier frame.
	if "frame" in sprite:
		sprite.frame = 1


func _on_deflect_window_ended() -> void:
	# Switch back to normal frame.
	if "frame" in sprite:
		sprite.frame = 0

		
