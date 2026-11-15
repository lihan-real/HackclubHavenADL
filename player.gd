extends CharacterBody2D

enum PaddleSide { LEFT, RIGHT }
@export var side: PaddleSide = PaddleSide.LEFT
@export var edge_margin: float = 30.0
@export var paddle_size: Vector2 = Vector2(30, 150)
@export var max_speed: float = 600.0
@export var acceleration: float = 3500.0
@export var friction: float = 4500.0
@export var trail_color: Color = Color(0.2, 0.9, 1.0, 0.45)
@export var is_cpu: bool = false
@export var cpu_speed: float = 380.0

var score: int = 0
var trail_timer: float = 0.0
var ball: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if is_cpu:
		add_to_group("cpu")
		trail_color = Color(1.0, 0.4, 0.5, 0.45)
	else:
		add_to_group("player")

	collision.position = Vector2.ZERO
	sprite.position = Vector2.ZERO
	set_paddle_size(paddle_size)

	var half_width = paddle_size.x / 2
	var screen_width = get_viewport_rect().size.x
	global_position.y = get_viewport_rect().size.y / 2
	if side == PaddleSide.LEFT:
		global_position.x = edge_margin + half_width
	else:
		global_position.x = screen_width - edge_margin - half_width


func set_paddle_size(new_size: Vector2) -> void:
	paddle_size = new_size
	var new_shape = RectangleShape2D.new()
	new_shape.size = paddle_size
	collision.shape = new_shape
	sprite.scale = paddle_size / sprite.texture.get_size()


func get_direction() -> float:
	if not is_cpu:
		return Input.get_axis("up", "down")

	if ball == null or not is_instance_valid(ball):
		ball = get_tree().get_first_node_in_group("ball")

	var screen = get_viewport_rect().size
	var target_y = screen.y / 2
	if ball != null:
		var on_left_half = ball.global_position.x < screen.x / 2
		var on_my_side = on_left_half == (side == PaddleSide.LEFT)
		if on_my_side:
			target_y = ball.global_position.y

	return clamp((target_y - global_position.y) / 80.0, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	var direction = get_direction()
	var top_speed = max_speed
	if is_cpu:
		top_speed = cpu_speed

	if direction != 0:
		velocity.y = move_toward(velocity.y, direction * top_speed, acceleration * delta)
	else:
		velocity.y = move_toward(velocity.y, 0, friction * delta)
	velocity.x = 0

	move_and_slide()

	var half_height = paddle_size.y / 2
	var screen_height = get_viewport_rect().size.y
	global_position.y = clamp(global_position.y, half_height, screen_height - half_height)

	trail_timer -= delta
	if abs(velocity.y) > 150 and trail_timer <= 0:
		trail_timer = 0.03
		make_trail()


func make_trail() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	get_parent().add_child(ghost)
	ghost.global_transform = sprite.global_transform
	ghost.modulate = trail_color

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


func hit() -> void:
	sprite.modulate = Color(2, 2, 2)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
