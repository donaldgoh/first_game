extends "res://scripts/enemy_base.gd"

# ── Tuning ────────────────────────────────────────────────────────────────────
const BULLET_SCENE   := preload("res://scenes/bullet.tscn")
const PREFERRED_DIST := 220.0   # tries to stay this far from the player
const STRAFE_SPEED   := 55.0    # sideways drift while kiting
const FIRE_INTERVAL  := 2.2     # seconds between shots
const BULLET_SPEED   := 260.0
const BULLET_RANGE   := 520.0
const BULLET_DAMAGE  := 1       # 1 half-heart per bullet

# ── State ──────────────────────────────────────────────────────────────────────
var _fire_timer: float = 1.0    # start with a small delay before first shot
var _strafe_dir: float = 1.0    # +1 or -1 strafe direction
var _strafe_flip_timer: float = 0.0

func _ready():
	super._ready()
	# Shooters are lighter on health but keep their distance
	max_health  = int(max_health * 0.75)
	current_health = max_health
	move_speed  = 55.0
	damage      = 1   # minimal contact damage — they prefer ranged

func _physics_process(delta):
	z_index = clampi(int(global_position.y), -4095, 4095)
	if is_dead or player == null: return
	contact_timer -= delta

	# ── Firing ────────────────────────────────────────────────────────────────
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_shoot()

	# ── Strafe flip every 1-2 s ───────────────────────────────────────────────
	_strafe_flip_timer -= delta
	if _strafe_flip_timer <= 0.0:
		_strafe_flip_timer = randf_range(1.0, 2.2)
		_strafe_dir = -_strafe_dir

	if knockback.length() > 10:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, delta * 8.0)
	else:
		var to_player = player.global_position - global_position
		var dist      = to_player.length()
		var dir_to    = to_player.normalized()

		# Radial component: approach if far, retreat if close
		var radial: Vector2
		if dist > PREFERRED_DIST + 30.0:
			radial = dir_to * move_speed
		elif dist < PREFERRED_DIST - 30.0:
			radial = -dir_to * move_speed
		else:
			radial = Vector2.ZERO   # in the sweet spot — just strafe

		# Tangential component: strafe sideways around the player
		var tangent = Vector2(-dir_to.y, dir_to.x) * STRAFE_SPEED * _strafe_dir

		# Separation from other enemies
		var sep = Vector2.ZERO
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self: continue
			var diff = global_position - e.global_position
			var d    = diff.length()
			if d < 48.0 and d > 0.0:
				sep += diff.normalized() * (48.0 - d) / 48.0
		sep *= 0.5

		velocity = radial + tangent + sep * move_speed

	move_and_slide()

	# Contact damage (very rare since it tries to keep distance)
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			if contact_timer <= 0:
				player.take_damage(damage)
				contact_timer = contact_cooldown
			break

func _shoot():
	if player == null: return
	var dir = (player.global_position - global_position).normalized()
	# Small aim spread so it's not perfectly accurate
	dir = dir.rotated(randf_range(-0.12, 0.12))

	var b = BULLET_SCENE.instantiate()
	b.global_position = global_position
	b.is_enemy_bullet = true
	b.setup(dir, BULLET_DAMAGE, BULLET_SPEED, 1, BULLET_RANGE)
	get_tree().current_scene.call_deferred("add_child", b)

func get_color() -> Color:
	return Color(0.3, 0.5, 1.0, 1.0)   # blue death particles
