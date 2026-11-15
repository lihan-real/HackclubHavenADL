extends Node2D

class ForceField extends AnimatableBody2D:
	var radius: float = 60.0
	var speed: float = 150.0
	var move_dir: float = 1.0
	var ball = null
	var shape: CircleShape2D

	func _init() -> void:
		shape = CircleShape2D.new()
		var col = CollisionShape2D.new()
		col.shape = shape
		add_child(col)

	func set_radius(new_radius: float) -> void:
		radius = new_radius
		shape.radius = radius
		queue_redraw()

	func _physics_process(delta: float) -> void:
		if ball != null and ball.waiting:
			return
		var height = get_viewport_rect().size.y
		position.y += move_dir * speed * delta
		if position.y < radius:
			position.y = radius
			move_dir = 1.0
		elif position.y > height - radius:
			position.y = height - radius
			move_dir = -1.0

	func _draw() -> void:
		var line_color = Color(0.38, 0.63, 0.75)
		draw_circle(Vector2.ZERO, radius, Color(0.56, 0.72, 0.74, 0.6))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, line_color, 4.0)
		var points = PackedVector2Array()
		for i in 7:
			var angle = TAU * i / 6.0
			points.append(Vector2(cos(angle), sin(angle)) * radius * 0.5)
		draw_polyline(points, line_color, 4.0)


@export var points_to_win: int = 3
@export var max_lives: int = 3
@export var time_stop_length: float = 3.0
@export var background_image: Texture2D

var player
var cpu
var ball

var round_number: int = 1
var player_score: int = 0
var cpu_score: int = 0
var lives: int = 3
var buff_counts: Dictionary = {}
var game_over: bool = false

var field = null
var field_level: int = 0

var time_stop_uses_per_round: int = 0
var time_stop_uses_left: int = 0
var time_stop_left: float = 0.0

var score_label: Label
var round_label: Label
var buff_label: Label
var message_label: Label
var stop_label: Label
var stop_overlay: ColorRect
var message_tween: Tween
var choice_panel: Control
var choice_title: Label
var choice_row: HBoxContainer
var restart_button: Button


func _ready() -> void:
	for child in get_children():
		if child.has_signal("exited"):
			ball = child
		elif child.has_method("set_paddle_size"):
			if child.is_cpu:
				cpu = child
			else:
				player = child
	if player == null or cpu == null or ball == null:
		push_error("Missing -> player: %s | cpu: %s | ball: %s" % [player, cpu, ball])
		return
	lives = max_lives
	ball.exited.connect(on_ball_exited)
	build_ui()
	start_round()

func build_background() -> void:
	if background_image == null:
		return
	var layer = CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var bg = TextureRect.new()
	bg.texture = background_image
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = get_viewport_rect().size
	layer.add_child(bg)
	
	
func make_label(parent: Node, font_size: int, pos: Vector2, label_size: Vector2, align: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = align
	parent.add_child(label)
	return label

	build_background()
	build_ui()
	start_round()
	
func build_ui() -> void:
	var screen = get_viewport_rect().size
	var layer = CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	stop_overlay = ColorRect.new()
	stop_overlay.color = Color(0.4, 0.5, 1.0, 0.18)
	stop_overlay.size = screen
	stop_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stop_overlay.visible = false
	layer.add_child(stop_overlay)

	score_label = make_label(layer, 72, Vector2(screen.x / 2 - 200, 5), Vector2(400, 90), HORIZONTAL_ALIGNMENT_CENTER)
	round_label = make_label(layer, 24, Vector2(20, 10), Vector2(450, 80), HORIZONTAL_ALIGNMENT_LEFT)
	buff_label = make_label(layer, 20, Vector2(20, screen.y - 230), Vector2(420, 220), HORIZONTAL_ALIGNMENT_LEFT)
	buff_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stop_label = make_label(layer, 40, Vector2(0, 100), Vector2(screen.x, 60), HORIZONTAL_ALIGNMENT_CENTER)
	message_label = make_label(layer, 56, Vector2(0, 220), Vector2(screen.x, 80), HORIZONTAL_ALIGNMENT_CENTER)
	message_label.modulate.a = 0.0

	choice_panel = Control.new()
	choice_panel.size = screen
	choice_panel.visible = false
	layer.add_child(choice_panel)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.size = screen
	choice_panel.add_child(dim)

	choice_title = make_label(choice_panel, 40, Vector2(0, 20), Vector2(screen.x, 140), HORIZONTAL_ALIGNMENT_CENTER)

	choice_row = HBoxContainer.new()
	choice_row.position = Vector2(screen.x / 2 - 360, 170)
	choice_row.size = Vector2(720, 400)
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.add_theme_constant_override("separation", 20)
	choice_panel.add_child(choice_row)

	restart_button = Button.new()
	restart_button.text = "Play Again"
	restart_button.add_theme_font_size_override("font_size", 32)
	restart_button.position = Vector2(screen.x / 2 - 130, 380)
	restart_button.size = Vector2(260, 70)
	restart_button.visible = false
	restart_button.pressed.connect(restart_run)
	choice_panel.add_child(restart_button)


func start_round(message: String = "") -> void:
	end_time_stop()
	player_score = 0
	cpu_score = 0
	time_stop_uses_left = time_stop_uses_per_round
	var screen = get_viewport_rect().size
	for paddle in [player, cpu]:
		paddle.global_position.y = screen.y / 2
		paddle.velocity = Vector2.ZERO
	if field != null:
		field.position = Vector2(screen.x / 2, field.radius)
		field.move_dir = 1.0
	update_hud()
	if message == "":
		message = "ROUND %d" % round_number
	show_message(message)
	ball.reset_ball()


func on_ball_exited(side: int) -> void:
	if game_over:
		return

	if side < 0:
		cpu_score += 1
	else:
		player_score += 1
	update_hud()

	if player_score >= points_to_win:
		win_round()
	elif cpu_score >= points_to_win:
		lose_life()
	else:
		ball.reset_ball()


func lose_life() -> void:
	lives -= 1
	if lives <= 0:
		lose_run()
	else:
		start_round("LIFE LOST!")


func win_round() -> void:
	end_time_stop()
	get_tree().paused = true
	choice_title.text = "ROUND %d CLEARED!\nPick an upgrade" % round_number

	for child in choice_row.get_children():
		child.queue_free()

	var options = make_buffs()
	options.shuffle()
	for i in 3:
		choice_row.add_child(make_card(options[i]))

	restart_button.visible = false
	choice_panel.visible = true


func make_card(buff: Dictionary) -> Control:
	var button
	if ResourceLoader.exists(buff["image"]):
		button = TextureButton.new()
		button.texture_normal = load(buff["image"])
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
	else:
		button = Button.new()
		button.text = buff["name"] + "\n\n" + buff["desc"]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(225, 400)
	button.pressed.connect(func(): pick_buff(buff))
	button.mouse_entered.connect(func(): button.modulate = Color(1.2, 1.2, 1.2))
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	return button


func pick_buff(buff: Dictionary) -> void:
	buff["apply"].call()
	buff_counts[buff["name"]] = buff_counts.get(buff["name"], 0) + 1
	choice_panel.visible = false
	get_tree().paused = false
	round_number += 1
	cpu.cpu_speed += 25.0
	ball.start_speed += 25.0
	start_round()


func lose_run() -> void:
	game_over = true
	end_time_stop()
	get_tree().paused = true
	for child in choice_row.get_children():
		child.queue_free()
	choice_title.text = "GAME OVER\nYou reached round %d" % round_number
	restart_button.visible = true
	choice_panel.visible = true


func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func show_message(text: String) -> void:
	if message_tween:
		message_tween.kill()
	message_label.text = text
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.0)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


func update_hud() -> void:
	score_label.text = "%d : %d" % [player_score, cpu_score]
	round_label.text = "ROUND %d   (first to %d)\nLIVES %d / %d" % [round_number, points_to_win, lives, max_lives]
	var lines = PackedStringArray()
	for buff_name in buff_counts:
		var count = buff_counts[buff_name]
		if count == 1:
			lines.append(buff_name)
		else:
			lines.append("%s x%d" % [buff_name, count])
	if time_stop_uses_per_round > 0:
		lines.append("Time stops left: %d  [SHIFT]" % time_stop_uses_left)
	buff_label.text = "\n".join(lines)


func total_upgrades() -> int:
	var total = 0
	for buff_name in buff_counts:
		total += buff_counts[buff_name]
	return total


func make_buffs() -> Array:
	return [
		{"name": "Heal", "image": "res://heal.png", "desc": "Get back one life. Does nothing at max lives.", "apply": buff_heal},
		{"name": "Expand paddle", "image": "res://expand_paddle.png", "desc": "Your paddle gets longer. Gains shrink as you collect upgrades.", "apply": buff_expand},
		{"name": "Time stop", "image": "res://time_stop.png", "desc": "Press SHIFT once per round to freeze time for 3 seconds. Each copy adds a use.", "apply": buff_time_stop},
		{"name": "Force field", "image": "res://force_field.png", "desc": "A force field bounces the ball up and down the middle. Upgrades make it bigger.", "apply": buff_force_field},
	]


func buff_heal() -> void:
	lives = mini(lives + 1, max_lives)


func buff_expand() -> void:
	var growth = 0.30 * pow(0.8, total_upgrades())
	var new_height = minf(player.paddle_size.y * (1.0 + growth), 400.0)
	player.set_paddle_size(Vector2(player.paddle_size.x, new_height))


func buff_time_stop() -> void:
	time_stop_uses_per_round += 1


func buff_force_field() -> void:
	field_level += 1
	var new_radius = minf(40.0 + 20.0 * field_level, 120.0)
	if field == null:
		field = ForceField.new()
		field.ball = ball
		add_child(field)
		field.set_radius(new_radius)
	else:
		field.set_radius(new_radius)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT:
		try_time_stop()


func try_time_stop() -> void:
	if game_over or time_stop_left > 0.0 or time_stop_uses_left <= 0:
		return
	time_stop_uses_left -= 1
	time_stop_left = time_stop_length
	set_frozen(true)
	stop_overlay.visible = true
	update_hud()


func end_time_stop() -> void:
	time_stop_left = 0.0
	set_frozen(false)
	if stop_overlay != null:
		stop_overlay.visible = false
	if stop_label != null:
		stop_label.text = ""


func set_frozen(frozen: bool) -> void:
	var mode = Node.PROCESS_MODE_INHERIT
	if frozen:
		mode = Node.PROCESS_MODE_DISABLED
	for node in [ball, cpu, field]:
		if node != null and is_instance_valid(node):
			node.process_mode = mode


func _process(delta: float) -> void:
	if time_stop_left > 0.0:
		time_stop_left -= delta
		stop_label.text = "TIME STOPPED  %.1f" % maxf(time_stop_left, 0.0)
		if time_stop_left <= 0.0:
			end_time_stop()
