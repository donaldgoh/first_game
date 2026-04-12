extends CharacterBody2D

signal enemy_died(pos, xp, gold)

@export var max_health: int = 30
@export var move_speed: float = 80.0
@export var damage: int = 1   # half-hearts (2 = 1 full heart of damage)
@export var xp_value: int = 10
@export var gold_value: int = 2
@export var contact_cooldown: float = 0.6

var current_health: int
var player: Node2D = null
var contact_timer: float = 0.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO

func _ready():
	z_as_relative = false
	add_to_group("enemies")
	var scale_factor = 1.0 + (GameManager.floor_number - 1) * 0.35
	max_health = int(max_health * scale_factor)
	damage = int(damage * scale_factor)
	move_speed = move_speed + (GameManager.floor_number - 1) * 5.0
	current_health = max_health
	call_deferred("_find_player")

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	z_index = clampi(int(global_position.y), -4095, 4095)
	if is_dead or player == null: return
	contact_timer -= delta

	if knockback.length() > 10:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, delta * 8.0)
	else:
		var dir = (player.global_position - global_position).normalized()

		# Separation: push away from nearby enemies so they don't stack
		var sep = Vector2.ZERO
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self: continue
			var diff = global_position - e.global_position
			var dist = diff.length()
			if dist < 40.0 and dist > 0.0:
				sep += diff.normalized() * (40.0 - dist) / 40.0
		dir = (dir + sep * 0.6).normalized()

		velocity = dir * move_speed

	move_and_slide()

	# Deal contact damage and steer sideways to prevent getting pinned on the player
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			if contact_timer <= 0:
				player.take_damage(damage)
				contact_timer = contact_cooldown
			# Perpendicular steering — slide around the player instead of locking
			var to_player = (player.global_position - global_position)
			var perp = Vector2(-to_player.y, to_player.x).normalized()
			if velocity.dot(perp) < 0.0:
				perp = -perp
			velocity = (velocity.normalized() * 0.4 + perp * 0.6).normalized() * move_speed
			break

func take_damage(amount: int):
	if is_dead: return
	current_health -= amount
	if player:
		knockback = (global_position - player.global_position).normalized() * 120.0
	var v = get_node_or_null("Visual")
	if v:
		v.modulate = Color(8, 8, 8)   # bright-white flash, works on any CanvasItem
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(v): v.modulate = Color.WHITE
	if current_health <= 0: die()

func get_color() -> Color:
	return Color(0.9, 0.2, 0.2, 1)

func die():
	if is_dead: return
	is_dead = true
	_spawn_particles()
	# Play death sound
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/enemy_death.ogg")
	snd.volume_db = -5
	get_tree().current_scene.add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	GameManager.on_enemy_killed()
	emit_signal("enemy_died", global_position, xp_value, gold_value)
	queue_free()

func _spawn_particles():
	for i in 6:
		var p = ColorRect.new()
		p.color = get_color()
		p.size = Vector2(6, 6)
		p.global_position = global_position
		get_tree().current_scene.add_child(p)
		var angle = i * TAU / 6 + randf() * 0.5
		var spd = randf_range(80, 160)
		var tween = get_tree().current_scene.create_tween()
		tween.set_parallel()
		tween.tween_property(p, "global_position",
			p.global_position + Vector2(cos(angle), sin(angle)) * spd, 0.5)
		tween.tween_property(p, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(p.queue_free)
