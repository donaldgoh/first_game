extends "res://scripts/enemy_base.gd"

# Spider mob — AnimatedSprite2D "Visual" with animations set up in the editor.
# Sprite faces LEFT by default, so:
#   flip_h = false → facing left
#   flip_h = true  → facing right

var _anim: AnimatedSprite2D = null
var _attacking: bool = false

func _ready():
	super._ready()
	_anim = get_node_or_null("Visual")
	if _anim == null:
		push_error("enemy_spider: no 'Visual' AnimatedSprite2D child found")
		return
	_anim.play("walking")

func _physics_process(delta):
	super._physics_process(delta)
	if _anim == null or is_dead: return

	# Sprite faces left by default — flip when moving/attacking to the right
	if player:
		_anim.flip_h = player.global_position.x > global_position.x

	# Switch between walk and attack animation
	var want_attack = contact_timer > 0.0
	if want_attack != _attacking:
		_attacking = want_attack
		_anim.play("attack" if _attacking else "walking")
