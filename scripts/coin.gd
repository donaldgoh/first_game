extends Area2D

@export var gold_value: int = 2
@export var attract_speed: float = 520.0

var player: Node2D = null
var attracted: bool = false

func _ready() -> void:
	z_as_relative = false
	body_entered.connect(_on_body_entered)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	z_index = clampi(int(global_position.y), -4095, 4095)
	if player == null or not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if attracted or dist < player.pickup_radius:
		attracted = true
		global_position = global_position.move_toward(player.global_position, attract_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.add_gold(gold_value)
		var snd := AudioStreamPlayer.new()
		snd.stream = load("res://sound_effects/xp_gem.wav")
		snd.volume_db = 0
		snd.pitch_scale = 1.4   # slightly higher pitch to distinguish from XP
		get_tree().current_scene.add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
		queue_free()
