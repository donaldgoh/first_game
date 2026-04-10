extends AnimatedSprite2D

@export var open_distance: float = 80.0

var player: Node2D = null
var is_open: bool = false
var _animating: bool = false

func _ready():
	# Start frozen on frame 0 of door_open (the closed look)
	animation = "door_open"
	frame = 0
	stop()
	animation_finished.connect(_on_animation_finished)
	call_deferred("_find_player")

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _process(_delta):
	if player == null or _animating:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist < open_distance and not is_open:
		is_open = true
		_animating = true
		play("door_open")
	elif dist >= open_distance and is_open:
		is_open = false
		_animating = true
		play("door_close")

func _on_animation_finished():
	_animating = false
	stop()  # freeze on the last frame of whichever animation just finished
