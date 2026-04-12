extends CharacterBody2D

signal health_changed(current, max_hp)
signal player_died

@export var max_health: int = 6   # half-hearts (2 = 1 full heart)
@export var move_speed: float = 200.0
@export var damage: int = 10
@export var attack_speed: float = 1.0
@export var pickup_radius: float = 80.0
@export var armor: int = 0
@export var lifesteal: int = 0
@export var luck: float = 0.0


var current_health: int
var is_dead: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 3.0
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO
var dash_duration: float = 0.15
var dash_duration_max: float = 0.15
var _facing_left: bool = false

# ── Out-of-combat speed boost ─────────────────────────────────────────────────
# When no enemies are alive the player moves faster to make room traversal feel
# snappy.  We lerp the effective speed so the transition is smooth.
const EXPLORE_SPEED_MULT := 1.2   # ×1.2 speed while rooms are clear
const SPEED_LERP_RATE    := 5.0   # how fast the speed ramps up/down (units/s)
var _effective_speed: float = 0.0 # smoothed speed used for movement each frame

func _ready():
	add_to_group("player")
	z_as_relative = false   # z_index is now absolute, not relative to parent
	max_health = GameManager.p_max_health
	move_speed = GameManager.p_move_speed
	damage = GameManager.p_damage
	attack_speed = GameManager.p_attack_speed
	pickup_radius = GameManager.p_pickup_radius
	armor = GameManager.p_armor
	lifesteal = GameManager.p_lifesteal
	current_health = GameManager.p_current_health
	_effective_speed = move_speed   # start at combat speed; ramps up once room clears
	emit_signal("health_changed", current_health, max_health)
	# Play idle animation
	var sprite = get_node_or_null("Visual")
	if sprite and sprite is AnimatedSprite2D:
		sprite.play("idle")

func _physics_process(delta):
	if is_dead: return
	# Y-sort: higher Y (further down screen = closer to viewer) draws on top
	z_index = clampi(int(global_position.y), -4095, 4095)
	dash_timer -= delta

	# Smoothly ramp between combat speed and explore speed depending on whether
	# any enemies are currently alive in the scene.
	var in_combat: bool = not get_tree().get_nodes_in_group("enemies").is_empty()
	var target_speed: float = move_speed * (1.0 if in_combat else EXPLORE_SPEED_MULT)
	_effective_speed = lerpf(_effective_speed, target_speed, SPEED_LERP_RATE * delta)

	if is_dashing:
		velocity = dash_velocity
		dash_duration -= delta
		if dash_duration <= 0:
			is_dashing = false
			dash_duration = dash_duration_max
	else:
		var input = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
		if input.length() > 0: input = input.normalized()
		velocity = input * _effective_speed
		var sprite = get_node_or_null("Visual")
		if input != Vector2.ZERO:
			if input.x != 0:
				_facing_left = input.x < 0
			if sprite:
				sprite.flip_h = _facing_left
				sprite.play("walk")
		else:
			if sprite: sprite.play("idle")
		if Input.is_action_just_pressed("ui_accept") and dash_timer <= 0 and input != Vector2.ZERO:
			is_dashing = true
			dash_velocity = input * _effective_speed * 3.5
			dash_timer = dash_cooldown

	move_and_slide()

func take_damage(amount: int):
	if is_dashing or is_dead: return
	current_health -= max(1, amount - armor)
	current_health = max(0, current_health)
	emit_signal("health_changed", current_health, max_health)
	var v = get_node_or_null("Visual")
	if v:
		if v is ColorRect:
			v.color = Color.RED
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(v): v.color = Color(0.2, 0.9, 0.3, 1)
		elif v is AnimatedSprite2D:
			v.modulate = Color.RED
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(v): v.modulate = Color.WHITE
	if current_health <= 0: die()
	GameManager.p_current_health = current_health

func heal(amount: int):
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)
	GameManager.p_current_health = current_health

func on_kill():
	if lifesteal > 0:
		heal(lifesteal)

func die():
	if is_dead: return
	is_dead = true
	velocity = Vector2.ZERO
	var visual = get_node_or_null("Visual")
	if visual:
		if visual is ColorRect:
			visual.color = Color.RED
		elif visual is AnimatedSprite2D:
			visual.modulate = Color.RED
	set_physics_process(false)
	set_process(false)
	emit_signal("player_died")
	await get_tree().create_timer(1.0).timeout
	GameManager.game_over.emit()

func apply_item(item: Dictionary):
	if item.has("max_health"):
		max_health += item.max_health
		if item.max_health > 0:
			current_health += item.max_health
		current_health = clamp(current_health, 1, max_health)
		emit_signal("health_changed", current_health, max_health)
	if item.has("speed"): move_speed += item.speed
	if item.has("damage"): damage += item.damage
	if item.has("attack_speed"): attack_speed += item.attack_speed
	if item.has("armor"): armor += item.armor
	if item.has("pickup_radius"): pickup_radius += item.pickup_radius
	if item.has("lifesteal"): lifesteal += item.lifesteal
	if item.has("luck"): luck += item.luck
	# Save to GameManager so stats persist next floor
	GameManager.p_max_health = max_health
	GameManager.p_move_speed = move_speed
	GameManager.p_damage = damage
	GameManager.p_attack_speed = attack_speed
	GameManager.p_pickup_radius = pickup_radius
	GameManager.p_armor = armor
	GameManager.p_lifesteal = lifesteal
	GameManager.p_current_health = current_health
	GameManager.p_luck = luck
	
