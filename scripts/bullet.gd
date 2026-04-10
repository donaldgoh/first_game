extends Area2D

const BulletScene := preload("res://scenes/bullet.tscn")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: int = 15
var pierce: int = 1
var max_range: float = 500.0
var traveled: float = 0.0
var hit: Array = []
var is_enemy_bullet: bool = false

# Weapon part effects
var homing: bool = false
var homing_strength: float = 3.0
var bounces_left: int = 0
var explode_radius: float = 0.0
var chain_count: int = 0
var split_on_hit: bool = false
var delayed_detonate: bool = false
var ignore_walls: bool = false   # sky-strike bullets fly through walls

# Bounce guard — prevent multiple wall bodies triggering _hit_wall in the same frame
var _bounce_frame: int = -1

func setup(dir, dmg, spd, prc, rng):
	direction = dir
	damage = dmg
	speed = spd
	pierce = prc
	max_range = rng

func _ready():
	z_as_relative = false
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	z_index = clampi(int(global_position.y), -4096, 4096)
	# Homing steering
	if homing and not is_enemy_bullet:
		var enemies = get_tree().get_nodes_in_group("enemies")
		if not enemies.is_empty():
			var nearest = enemies[0]
			var best_dist = global_position.distance_to(nearest.global_position)
			for e in enemies:
				var d = global_position.distance_to(e.global_position)
				if d < best_dist:
					best_dist = d
					nearest = e
			var desired = (nearest.global_position - global_position).normalized()
			direction = direction.lerp(desired, homing_strength * delta).normalized()

	# Cluster Bomb: slow down as the bullet nears its range end
	if delayed_detonate and traveled >= max_range * 0.75:
		speed = maxf(speed - speed * 4.0 * delta, 40.0)

	var m = direction * speed * delta
	position += m
	traveled += m.length()
	if traveled >= max_range:
		if delayed_detonate:
			_do_detonate()
		queue_free()
		return


func _on_body_entered(body):
	if is_enemy_bullet:
		if body.is_in_group("player"):
			body.take_damage(damage)
			queue_free()
		elif not body.is_in_group("enemies") and not ignore_walls:
			# Hit a wall or obstacle
			_hit_wall()
	else:
		if body.is_in_group("enemies") and not body in hit:
			body.take_damage(damage)
			hit.append(body)
			var pl = get_tree().get_first_node_in_group("player")
			if pl and body.current_health <= 0:
				pl.on_kill()
			# Explosion
			if explode_radius > 0.0:
				for e in get_tree().get_nodes_in_group("enemies"):
					if not e in hit and global_position.distance_to(e.global_position) <= explode_radius:
						e.take_damage(damage)
						hit.append(e)
			# Chain: jump to the nearest unhit enemy
			if chain_count > 0:
				_do_chain()
			pierce -= 1
			if pierce <= 0:
				if split_on_hit:
					_do_split()
				queue_free()
		elif not body.is_in_group("player") and not body.is_in_group("enemies") and not ignore_walls:
			# Hit a wall or obstacle
			_hit_wall()

func _do_chain():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_e = null
	var best_d = INF
	for e in enemies:
		if e in hit: continue
		var d = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best_e = e
	if best_e == null: return
	var b: Node2D = BulletScene.instantiate()
	b.global_position = global_position
	b.setup((best_e.global_position - global_position).normalized(), damage, speed, 1, max_range)
	b.chain_count  = chain_count - 1
	b.hit          = hit.duplicate()
	b.explode_radius = explode_radius
	b.is_enemy_bullet = is_enemy_bullet
	get_tree().current_scene.call_deferred("add_child", b)

func _do_split():
	for i in 3:
		var split_dir = direction.rotated(deg_to_rad(-45.0 + i * 45.0))
		var b: Node2D = BulletScene.instantiate()
		# Offset each shard along its direction so they don't all overlap at spawn
		b.global_position = global_position + split_dir * 14.0
		b.setup(split_dir, int(damage * 0.6), speed, 1, max_range * 0.6)
		b.is_enemy_bullet = is_enemy_bullet
		get_tree().current_scene.call_deferred("add_child", b)

func _do_detonate():
	var radius = maxf(explode_radius, 80.0)
	var pl = get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= radius:
			e.take_damage(damage * 2)
			if pl and e.current_health <= 0: pl.on_kill()
	# Shockwave: expand several concentric Line2D circles that fade out
	var scene = get_tree().current_scene
	for ring_i in 3:
		var delay = ring_i * 0.06
		var ln = Line2D.new()
		ln.z_as_relative = false; ln.z_index = 40
		ln.width = 3.0
		ln.default_color = Color(1.0, 0.6, 0.1, 0.8 - ring_i * 0.2)
		# Build circle points
		var pts: Array = []
		for s in 33:
			var a = s * TAU / 32.0
			pts.append(Vector2(cos(a), sin(a)) * (radius * 0.3 + ring_i * radius * 0.25))
		for pt in pts:
			ln.add_point(pt)
		ln.global_position = global_position
		scene.add_child(ln)
		var tw = ln.create_tween()
		tw.tween_property(ln, "modulate:a", 0.0, 0.35).set_delay(delay)
		tw.tween_callback(ln.queue_free)

func _hit_wall():
	# Only process once per physics frame — multiple wall bodies fire body_entered separately
	var frame = Engine.get_physics_frames()
	if _bounce_frame == frame:
		return
	_bounce_frame = frame

	if bounces_left <= 0:
		if split_on_hit:
			_do_split()
		queue_free()
		return

	bounces_left -= 1

	# Cast a ray from well behind the bullet toward its travel direction to find the wall normal.
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(
		global_position - direction * 32.0,
		global_position + direction * 32.0,
		collision_mask
	)
	params.exclude = [self]
	var result = space.intersect_ray(params)
	if result:
		direction = direction.bounce(result.normal).normalized()
	else:
		# Fallback: choose the axis-flip that makes the most physical sense based on
		# which component of the direction is dominant (i.e. which wall face we hit).
		if abs(direction.x) >= abs(direction.y):
			direction.x = -direction.x
		else:
			direction.y = -direction.y

	# Push the bullet out of the wall so it doesn't immediately re-collide.
	global_position += direction * 18.0
