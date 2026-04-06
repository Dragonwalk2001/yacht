extends CharacterBody2D

@export var speed: float = 400.0

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	reset()

func reset() -> void:
	position = screen_size / 2
	# 随机初始方向
	var angle = randf_range(-PI / 4, PI / 4)
	var dir = 1 if randf() > 0.5 else -1
	velocity = Vector2(cos(angle) * dir, sin(angle)) * speed

func _physics_process(_delta: float) -> void:
	var collision = move_and_collide(velocity * _delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal())

	# 上下边界反弹
	if position.y <= 0 or position.y >= screen_size.y:
		velocity.y = -velocity.y
		position.y = clamp(position.y, 0, screen_size.y)

	# 出界得分
	if position.x < 0:
		get_parent().score(2)
		reset()
	elif position.x > screen_size.x:
		get_parent().score(1)
		reset()
