extends CharacterBody2D

signal enemy_died(pos, xp, gold)

@export var max_health: int = 500
@export var move_speed: float = 55.0
@export var damage: int = 2
@export var xp_value: int = 200
@export var gold_value: int = 50

var current_health: int
var player: Node2D = null
var attack_timer: float = 0.0
var phase: int = 1
var is_dead: bool = false
var contact_timer: float = 0.0
var enraged: bool = false

const BulletScene = preload("res://scenes/bullet.tscn")

func _ready():
	add_to_group("enemies")
	var scale_factor = 1.0 + (GameManager.floor_number - 1) * 0.4
	max_health = int(max_health * scale_factor)
	damage = int(damage * scale_factor)
	move_speed = move_speed + (GameManager.floor_number - 1) * 3.0
	current_health = max_health
	call_deferred("_find_player")

func _find_player():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if is_dead or player == null: return
	contact_timer -= delta
	attack_timer += delta
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

	# Damage player on contact; keep boss moving so it doesn't freeze against the player
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			if contact_timer <= 0:
				player.take_damage(damage)
				contact_timer = 0.8
			# Steer slightly sideways so the boss slides around the player instead of pushing straight into them
			var to_player = (player.global_position - global_position)
			var perp = Vector2(-to_player.y, to_player.x).normalized()
			# Pick whichever perpendicular side keeps the boss circling rather than backing off
			if velocity.dot(perp) < 0.0:
				perp = -perp
			velocity = velocity.normalized() * move_speed * 0.5 + perp * move_speed * 0.6
			velocity = velocity.normalized() * move_speed
			break

	var fire_rate = 1.8 if phase == 1 else (0.9 if phase == 2 else 0.5)
	if attack_timer >= fire_rate:
		attack_timer = 0.0
		match phase:
			1: _shoot_triple()
			2: _shoot_spread(8)
			3: _shoot_spread(12)

	# Phase 2 at 50% HP
	if current_health < max_health * 0.5 and phase == 1:
		phase = 2
		move_speed = 85.0
		var v = get_node_or_null("Visual")
		if v: v.color = Color(1.0, 0.4, 0.0, 1)

	# Phase 3 at 20% HP - ENRAGED
	if current_health < max_health * 0.2 and phase == 2:
		phase = 3
		move_speed = 115.0
		enraged = true
		var v = get_node_or_null("Visual")
		if v: v.color = Color(1.0, 0.0, 0.0, 1)

func _shoot_triple():
	if player == null: return
	var base = (player.global_position - global_position).normalized()
	_spawn_bullet(base)
	_spawn_bullet(base.rotated(0.25))
	_spawn_bullet(base.rotated(-0.25))

func _shoot_spread(count: int):
	for i in count:
		_spawn_bullet(Vector2(cos(i * TAU / count), sin(i * TAU / count)))

func _spawn_bullet(dir: Vector2):
	var b = BulletScene.instantiate()
	b.global_position = global_position
	b.is_enemy_bullet = true
	b.setup(dir, damage, 220.0, 1, 800.0)
	get_tree().current_scene.add_child(b)

func take_damage(amount: int):
	if is_dead: return
	current_health -= amount
	if current_health <= 0: die()

func die():
	if is_dead: return
	is_dead = true
	_spawn_particles()
	GameManager.on_enemy_killed()
	emit_signal("enemy_died", global_position, xp_value, gold_value)
	queue_free()

func _spawn_particles():
	for i in 10:
		var p = ColorRect.new()
		p.color = Color(0.5, 0.0, 0.9, 1)
		p.size = Vector2(10, 10)
		p.global_position = global_position
		get_tree().current_scene.add_child(p)
		var angle = i * TAU / 10 + randf() * 0.5
		var spd = randf_range(100, 200)
		var tween = get_tree().current_scene.create_tween()
		tween.set_parallel()
		tween.tween_property(p, "global_position",
			p.global_position + Vector2(cos(angle), sin(angle)) * spd, 0.6)
		tween.tween_property(p, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(p.queue_free)
