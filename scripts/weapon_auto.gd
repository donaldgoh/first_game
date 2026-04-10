extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# WeaponAuto — fires bullets toward the mouse cursor.
#
# Reads one active WeaponPart from GameManager.active_part (the part id string).
# Swap the part at runtime by changing GameManager.active_part and calling
# reload_part() — or just load a new floor.
# ═══════════════════════════════════════════════════════════════════════════════

const BulletScene := preload("res://scenes/bullet.tscn")

# Base weapon stats (before part modifiers)
@export var base_fire_rate:    float = 1.5    # shots per second
@export var base_bullet_speed: float = 500.0
@export var base_pierce:       int   = 1
@export var base_range:        float = 600.0

var _player:     Node2D       = null
var _part:       WeaponPart   = null   # currently equipped part (may be null)
var _shoot_timer: float       = 0.0

func _ready():
	_player = get_parent()
	reload_part()

# Call this whenever the active part changes (e.g. after picking up a chip).
func reload_part():
	# Prefer the new combined system; fall back to legacy active_part.
	_part = GameManager.get_combined_part()
	if _part == null and GameManager.active_part != "":
		_part = WeaponPartsDatabase.get_by_id(GameManager.active_part)

func _process(delta: float):
	if _player == null or _player.is_dead: return
	if GameManager.inventory_open: return   # block firing while inventory is open

	var fire_rate = base_fire_rate * _part_val("fire_rate_mult", 1.0) * _player.attack_speed
	_shoot_timer += delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _shoot_timer >= 1.0 / fire_rate:
			_shoot_timer = 0.0
			_fire()
	else:
		# Cap so first click always fires immediately
		_shoot_timer = minf(_shoot_timer, 1.0 / fire_rate)

# ── Firing ────────────────────────────────────────────────────────────────────
func _fire():
	var snd = _player.get_node_or_null("ShootSound")
	if snd: snd.stop(); snd.play()

	if _part_val("is_laser", false):
		_fire_laser()
		return
	if _part_val("sky_strike", false):
		_fire_sky_strike()
		return

	var base_dir = (get_global_mouse_position() - global_position).normalized()
	_spawn_bullets(base_dir)

# ── Laser beam — instant hit along a line ─────────────────────────────────────
# When combined with Chain Bolt (chain_count > 0), the beam also jumps to
# chain_count additional enemies that weren't in the beam's path.
func _fire_laser():
	var from        = global_position
	var laser_dir   = (get_global_mouse_position() - from).normalized()
	var max_dist    = base_range * _part_val("bullet_range_mult", 1.0)
	var end_pos     = from + laser_dir * max_dist
	var final_dmg   = int(_player.damage * _part_val("damage_mult", 1.0))
	var chain_count = _part_val("chain_count", 0) as int

	# ── Primary beam: damage every enemy along the line ───────────────────
	var hit_set: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var t = (e.global_position - from).dot(laser_dir)
		if t < 0.0 or t > max_dist: continue
		if (e.global_position - (from + laser_dir * t)).length() <= 28.0:
			e.take_damage(final_dmg)
			if e.current_health <= 0: _player.on_kill()
			hit_set.append(e)

	# ── Chain jumps (Chain Bolt chip) ─────────────────────────────────────
	# Jump origin = whichever beam-hit enemy is nearest the cursor, so the
	# chain continues "forward" rather than snapping backward to the player.
	var chain_visuals: Array = []   # [{from: Vector2, to: Vector2}]
	if chain_count > 0 and not hit_set.is_empty():
		var mouse_pos := get_global_mouse_position()
		var jump_origin: Vector2 = hit_set[0].global_position
		for e in hit_set:
			if e.global_position.distance_to(mouse_pos) < jump_origin.distance_to(mouse_pos):
				jump_origin = e.global_position

		for _j in range(chain_count):
			var best: Node    = null
			var best_d: float = INF
			for e in get_tree().get_nodes_in_group("enemies"):
				if e in hit_set: continue
				var d = jump_origin.distance_to(e.global_position)
				if d < best_d:
					best_d = d
					best   = e
			if best == null: break
			best.take_damage(final_dmg)
			if best.current_health <= 0: _player.on_kill()
			chain_visuals.append({"from": jump_origin, "to": best.global_position})
			hit_set.append(best)
			jump_origin = best.global_position

	# ── Main beam visual ──────────────────────────────────────────────────
	var beam = Line2D.new()
	beam.z_as_relative = false; beam.z_index = 50
	beam.add_point(from); beam.add_point(end_pos)
	beam.width = 5.0; beam.default_color = Color(0.2, 1.0, 1.0, 1.0)
	get_tree().current_scene.add_child(beam)
	var glow = Line2D.new()
	glow.z_as_relative = false; glow.z_index = 49
	glow.add_point(from); glow.add_point(end_pos)
	glow.width = 18.0; glow.default_color = Color(0.0, 0.5, 1.0, 0.25)
	get_tree().current_scene.add_child(glow)
	var t1 = beam.create_tween()
	t1.tween_property(beam, "modulate:a", 0.0, 0.12).set_delay(0.04)
	t1.tween_callback(beam.queue_free)
	var t2 = glow.create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.12).set_delay(0.04)
	t2.tween_callback(glow.queue_free)

	# ── Chain arc visuals (purple/violet to distinguish from beam) ────────
	for cv in chain_visuals:
		var arc = Line2D.new()
		arc.z_as_relative = false; arc.z_index = 50
		arc.add_point(cv["from"]); arc.add_point(cv["to"])
		arc.width = 3.5; arc.default_color = Color(0.65, 0.15, 1.0, 1.0)
		get_tree().current_scene.add_child(arc)
		var arc_glow = Line2D.new()
		arc_glow.z_as_relative = false; arc_glow.z_index = 49
		arc_glow.add_point(cv["from"]); arc_glow.add_point(cv["to"])
		arc_glow.width = 14.0; arc_glow.default_color = Color(0.4, 0.0, 0.8, 0.28)
		get_tree().current_scene.add_child(arc_glow)
		var ta = arc.create_tween()
		ta.tween_property(arc, "modulate:a", 0.0, 0.18).set_delay(0.06)
		ta.tween_callback(arc.queue_free)
		var tg = arc_glow.create_tween()
		tg.tween_property(arc_glow, "modulate:a", 0.0, 0.18).set_delay(0.06)
		tg.tween_callback(arc_glow.queue_free)

# ── Sky Strike — bullets fall from above toward cursor ─────────────────────────
func _fire_sky_strike():
	var mouse_pos     = get_global_mouse_position()
	var final_damage  = int(_player.damage * _part_val("damage_mult", 1.0))
	var final_speed   = base_bullet_speed * _part_val("bullet_speed_mult", 1.0) * 1.5
	var final_pierce  = base_pierce + _part_val("pierce_bonus", 0)
	var final_bounces = _part_val("bounce_bonus", 0)
	var count         = _part_val("spread_count", 1)

	# Bullets spawn this many pixels above the cursor and fall straight down.
	# The range must be >= sky_offset so the bullet actually reaches the cursor.
	# Add 200 px of extra travel so it passes through enemies below the cursor too.
	const SKY_OFFSET := 550.0
	var final_range: float = (SKY_OFFSET + 200.0) * float(_part_val("bullet_range_mult", 1.0))

	# Target marker cross
	var marker = Node2D.new()
	marker.global_position = mouse_pos
	marker.z_as_relative = false; marker.z_index = 10
	get_tree().current_scene.add_child(marker)
	for pts in [[Vector2(-14, 0), Vector2(14, 0)], [Vector2(0, -14), Vector2(0, 14)]]:
		var ln = Line2D.new()
		ln.add_point(pts[0]); ln.add_point(pts[1])
		ln.width = 2.5; ln.default_color = Color(1.0, 0.25, 0.1, 0.9)
		marker.add_child(ln)
	var mt = marker.create_tween()
	mt.tween_property(marker, "modulate:a", 0.0, 0.35)
	mt.tween_callback(marker.queue_free)

	for i in range(count):
		var ox = 0.0
		if count > 1:
			ox = (i - (count - 1) * 0.5) * 60.0
		var b: Node2D = BulletScene.instantiate()
		b.global_position = Vector2(mouse_pos.x + ox, mouse_pos.y - SKY_OFFSET)
		b.setup(Vector2(0, 1), final_damage, final_speed, final_pierce, final_range)
		b.ignore_walls = true   # sky-strike passes through walls during descent
		_apply_bullet_specials(b, final_bounces)
		get_tree().current_scene.add_child(b)

func _spawn_bullets(base_dir: Vector2):
	# ── Compute final stats from base + part modifiers ────────────────────────
	var final_speed   = base_bullet_speed * _part_val("bullet_speed_mult", 1.0)
	var final_range   = base_range        * _part_val("bullet_range_mult", 1.0)
	var final_pierce  = base_pierce       + _part_val("pierce_bonus", 0)
	var final_damage  = int(_player.damage * _part_val("damage_mult", 1.0))
	var final_bounces = _part_val("bounce_bonus", 0)

	# ── Spread directions ─────────────────────────────────────────────────────
	var spread_count = _part_val("spread_count", 1)
	var spread_angle = _part_val("spread_angle", 0.0)
	var dirs: Array[Vector2] = []

	if spread_count <= 1:
		dirs = [base_dir]
	else:
		var half = spread_angle / 2.0
		var step = spread_angle / float(spread_count - 1)
		for i in range(spread_count):
			dirs.append(base_dir.rotated(deg_to_rad(-half + step * i)))

	# ── Spawn one bullet per direction ────────────────────────────────────────
	for dir in dirs:
		var b: Node2D = BulletScene.instantiate()
		b.global_position = global_position
		b.setup(dir, final_damage, final_speed, final_pierce, final_range)
		_apply_bullet_specials(b, final_bounces)
		get_tree().current_scene.add_child(b)

func _apply_bullet_specials(b: Node2D, final_bounces: int):
	if _part_val("homing", false):
		b.homing          = true
		b.homing_strength = _part_val("homing_strength", 3.0)
	if final_bounces > 0:
		b.bounces_left = final_bounces
	if _part_val("explode_radius", 0.0) > 0.0:
		b.explode_radius = _part_val("explode_radius", 0.0)
	b.chain_count     = _part_val("chain_count", 0)
	b.split_on_hit    = _part_val("split_on_hit", false)
	b.delayed_detonate = _part_val("delayed_detonate", false)

# ── Helper: safely read a property from the active part, or return default ────
func _part_val(property: String, default: Variant) -> Variant:
	if _part == null: return default
	var v = _part.get(property)
	return v if v != null else default
