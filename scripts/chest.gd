extends Node2D
# ─────────────────────────────────────────────────────────────────────────────
# Chest — locked pickup that requires a key to open.
# Spawn via:
#   var c = load("res://scripts/chest.gd").new()
#   c.position = center
#   parent.add_child(c)
#   c.setup(part)   ← call AFTER add_child so _ready has run
# ─────────────────────────────────────────────────────────────────────────────

var _part: WeaponPart   = null
var _opened: bool       = false
var _player_nearby: bool = false

var _icon:   Label = null
var _prompt: Label = null
var _lbl:    Label = null

func setup(part: WeaponPart) -> void:
	_part = part

func _ready() -> void:
	# ── Chest icon ────────────────────────────────────────────────────────────
	_icon = Label.new()
	_icon.text = "📦"
	_icon.add_theme_font_size_override("font_size", 36)
	_icon.position = Vector2(-18, -22)
	add_child(_icon)

	# ── "Press E" prompt (hidden until nearby) ────────────────────────────────
	_prompt = Label.new()
	_prompt.text = "[E]  Open Chest  🔑"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 15)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	_prompt.custom_minimum_size = Vector2(220, 24)
	_prompt.position = Vector2(-110, -62)
	_prompt.visible = false
	add_child(_prompt)

	# ── Status label (shown after open or on no-key attempt) ─────────────────
	_lbl = Label.new()
	_lbl.text = ""
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 14)
	_lbl.add_theme_color_override("font_color", Color.WHITE)
	_lbl.custom_minimum_size = Vector2(260, 60)
	_lbl.position = Vector2(-130, -130)
	_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_lbl)

	# ── Proximity detection area ──────────────────────────────────────────────
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	area.monitoring      = true
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new(); shp.radius = 130.0
	col.shape = shp
	area.add_child(col)
	area.body_entered.connect(_on_player_enter)
	area.body_exited.connect(_on_player_exit)
	add_child(area)

func _on_player_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if not _opened:
			_prompt.visible = true

func _on_player_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_prompt.visible = false

func _input(event: InputEvent) -> void:
	if _opened or not _player_nearby: return
	if event.is_action_pressed("interact"):
		_try_open()
		get_viewport().set_input_as_handled()

func _try_open() -> void:
	if GameManager.use_key():
		_opened = true
		_prompt.visible = false
		_icon.text = "📭"   # open box

		if _part != null:
			GameManager.mark_seen(_part.id)
			GameManager.add_part_to_inventory(_part.id)
			var rarity_col: Color = {
				WeaponPart.Rarity.COMMON:   Color(0.75, 0.75, 0.75),
				WeaponPart.Rarity.UNCOMMON: Color(0.25, 0.65, 1.00),
				WeaponPart.Rarity.RARE:     Color(1.00, 0.65, 0.05),
			}.get(_part.rarity, Color.WHITE)
			_lbl.text = "Got  %s!\n%s\n[I] to equip" % [_part.name, _part.desc]
			_lbl.add_theme_color_override("font_color", rarity_col)
	else:
		# Flash "no key" warning
		_lbl.text = "No key!"
		_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var tw = create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func(): _lbl.text = "")
