extends CharacterBody2D

@export var speed: float = 400.0
@export var up_action: String = "ui_up"
@export var down_action: String = "ui_down"

var screen_height: float

func _ready() -> void:
	screen_height = get_viewport_rect().size.y
	# 如果是右边的板，自动贴右边缘
	if position.x > get_viewport_rect().size.x / 2:
		position.x = get_viewport_rect().size.x - 40

func _physics_process(_delta: float) -> void:
	velocity.y = 0
	if Input.is_action_pressed(up_action):
		velocity.y = -speed
	if Input.is_action_pressed(down_action):
		velocity.y = speed

	# 限制在屏幕内
	position.y = clamp(position.y, 50, screen_height - 50)
	move_and_collide(velocity * _delta)
