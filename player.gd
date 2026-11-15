extends CharacterBody2D
var score = 0
func _physics_process(delta):
	var input_direction = Input.get_vector("ui_left","ui_right","up","down")
	velocity = input_direction * 400
	velocity.x = 0
	move_and_slide()
