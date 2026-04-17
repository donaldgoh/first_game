extends CharacterBody2D

signal enemy_died(pos, xp, gold)

@export var max_health: int = 30
@export var move_speed: float = 80.0
@export var damage: int = 1   # half-hearts (2 = 1 full heart of damage)
@export var xp_value: int = 10
@export var gold_value: int = 2
@export var contact_cooldown: float = 0.3
@export var key_drop_chance: float = 0.03  # 3% chance to drop a key on death

var current_health: int
var player: Node2D = null
var contact_timer: float = 0.0
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO

func _ready():
	z_as_relative = false
	add_to_group("enemies")
	var scale_factor = 1.0 + (GameManager.floor_number - 1) * 0.50
	max_health = int(max_health * scale_factor)
	damage = int(damage * scale_factor)
	move_speed = move_speed + (GameManager.floor_number - 1) * 8.0
	current_health = max_health
	call_deferred("_find_player")

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	z_index = clampi(int(global_position.y) - 1, -4095, 4095)
	if is_dead or player == null:
		return
	contact_timer -= delta

	if knockback.length() > 10:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, delta * 8.0)

	# Aim at the centre of the player's collision box, not the feet origin.
	# The player's Col is offset Vector2(-1, -16.8125) from global_position,
	# so approaching this point keeps all contact distances symmetric.
	var player_centre : Vector2 = player.global_position + Vector2(-1.0, -32.0)

	var dir : Vector2 = (player_centre - global_position).normalized()

	# Separation: push away from nearby enemies (proximity-based, no physics needed)
	var sep : Vector2 = Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self: continue
		var diff : Vector2 = global_position - e.global_position
		var d : float = diff.length()
		if d < 40.0 and d > 0.0:
			sep += diff.normalized() * (40.0 - d) / 40.0
	dir = (dir + sep * 0.4).normalized()

	velocity = dir * move_speed
	move_and_slide()

	# Contact damage — measured from the collision-box centre so the threshold
	# is consistent regardless of approach direction.
	# Max physical contact distance from this centre is ~56 px (corner approach);
	# 64 px gives a reliable margin above that.
	var dist_to_centre : float = global_position.distance_to(player_centre)
	if dist_to_centre < 72.0 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = contact_cooldown

	# Perpendicular steering on direct physics contact
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			var to_pl : Vector2 = player.global_position - global_position
			var perp : Vector2 = Vector2(-to_pl.y, to_pl.x).normalized()
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
		v.self_modulate = Color(8, 8, 8)   # flash only this node, not shadow children
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(v): v.self_modulate = Color.WHITE
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
	# Small chance to drop a key — deferred so it runs outside the physics flush
	if randf() < key_drop_chance:
		var _drop_pos := global_position
		call_deferred("_spawn_key_drop", _drop_pos)
	GameManager.on_enemy_killed()
	emit_signal("enemy_died", global_position, xp_value, gold_value)
	queue_free()

func _spawn_key_drop(pos: Vector2) -> void:
	var key_node = Node2D.new()
	key_node.global_position = pos

	# Visual — golden key icon
	var icon = Label.new()
	icon.text = "🔑"
	icon.add_theme_font_size_override("font_size", 22)
	icon.position = Vector2(-11, -14)
	key_node.add_child(icon)

	# Pickup area
	var area = Area2D.new()
	area.collision_layer = 0; area.collision_mask = 1
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new(); shp.radius = 28.0
	col.shape = shp; area.add_child(col)
	key_node.add_child(area)

	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			GameManager.add_key()
			key_node.queue_free())

	get_tree().current_scene.add_child(key_node)

	# Bob animation — node-owned so it stops automatically when key_node is freed
	var tween = icon.create_tween()
	tween.set_loops()
	tween.tween_property(icon, "position:y", -20.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(icon, "position:y", -14.0, 0.5).set_trans(Tween.TRANS_SINE)

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
