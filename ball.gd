extends CharacterBody2D

signal exited(side: int)

@export var ball_texture: Texture2D = preload("res://ball.png")
@export var ball_size: float = 30.0
@export var start_speed: float = 450.0
@export var speed_increase: float = 25.0
@export var max_speed: float = 1100.0
@export var trail_color: Color = Color(1, 1, 1, 0.35)

var hit_cooldown: float = 0.0
var speed: float = 0.0
var direction: Vector2 = Vector2.ZERO
var waiting: bool = false
var trail_timer: float = 0.0
var sprite: Sprite2D
var radius: float = 15.0


func _ready() -> void:
	add_to_group("ball")
	radius = ball_size / 2

	sprite = Sprite2D.new()
	sprite.texture = ball_texture
	sprite.scale = Vector2(ball_size, ball_size) / ball_texture.get_size()
	add_child(sprite)

	var shape = CircleShape2D.new()
	shape.radius = radius
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

	reset_ball()


func reset_ball() -> void:
	waiting = true
	global_position = get_viewport_rect().size / 2
	speed = start_speed
	var x_dir = 1.0 if randf() < 0.5 else -1.0
	direction = Vector2(x_dir, randf_range(-0.5, 0.5)).normalized()
	await get_tree().create_timer(1.0).timeout
	waiting = false


func rescue(side: int) -> void:
	waiting = true
	var size = get_viewport_rect().size
	if side < 0:
		global_position.x = 100.0
	else:
		global_position.x = size.x - 100.0
	global_position.y = clamp(global_position.y, radius, size.y - radius)
	direction.x = -sign(side) * abs(direction.x)
	await get_tree().create_timer(0.6).timeout
	waiting = false


func _physics_process(delta: float) -> void:
	if waiting:
		return

	hit_cooldown = maxf(hit_cooldown - delta, 0.0)

	var hit_info = move_and_collide(direction * speed * delta)
	if hit_info:
		var other = hit_info.get_collider()
		var normal = hit_info.get_normal()
		if other.has_method("hit"):
			if absf(normal.x) > absf(normal.y):
				# front face of the paddle: always send the ball AWAY from it
				var x_dir = 1.0 if normal.x > 0.0 else -1.0
				var offset = (global_position.y - other.global_position.y) / (other.paddle_size.y / 2)
				offset = clamp(offset, -1.0, 1.0)
				direction = Vector2(x_dir, offset * 0.75).normalized()
				if hit_cooldown <= 0.0:
					other.hit()
					speed = min(speed + speed_increase, max_speed)
					hit_cooldown = 0.1
			else:
				# top or bottom edge of the paddle: just deflect, don't flip x
				direction = direction.bounce(normal).normalized()
				global_position += normal * 2.0
		else:
			direction = direction.bounce(normal)

	var size = get_viewport_rect().size
	if global_position.y < radius:
		global_position.y = radius
		direction.y = abs(direction.y)
	elif global_position.y > size.y - radius:
		global_position.y = size.y - radius
		direction.y = -abs(direction.y)

	if global_position.x < -radius:
		waiting = true
		exited.emit(-1)
		return
	if global_position.x > size.x + radius:
		waiting = true
		exited.emit(1)
		return

	trail_timer -= delta
	if trail_timer <= 0:
		trail_timer = 0.03
		make_trail()


func make_trail() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	get_parent().add_child(ghost)
	ghost.global_transform = sprite.global_transform
	ghost.modulate = trail_color
	ghost.z_index = -1

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
