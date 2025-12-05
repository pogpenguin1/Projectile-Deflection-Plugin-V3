extends Node2D

@onready var player := $Player
@onready var deflector := $Player/Deflector2D
@onready var projectile :=	preload("res://addons/projectiledeflectplugin/Demo/demo_projectile.tscn")


func _ready():
	#Spawn player somewhere normal
	player.global_position = Vector2(0,5)
	
	
