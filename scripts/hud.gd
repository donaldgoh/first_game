extends CanvasLayer

var boss_bar: ProgressBar = null
var boss_label: Label = null

# Heart display — each slot = 1 full heart (2 half-hearts)
var _hearts_row: HBoxContainer = null
var _heart_slots: Array = []   # Array of TextureRect, one per heart slot

func _ready():
	await get_tree().process_frame
	GameManager.xp_changed.connect(func(c,r): $M/V/XP.max_value=r; $M/V/XP.value=c)
	GameManager.level_up.connect(func(l): $M/V/Top/LvLabel.text="LV %d"%l)
	GameManager.gold_changed.connect(func(g): $M/V/Top/GoldLabel.text = "%dg" % g)
	var pl = get_tree().get_first_node_in_group("player")
	if pl:
		pl.health_changed.connect(_on_hp)
		_on_hp(pl.current_health, pl.max_health)
	_create_boss_bar()
	_style_hud()

func _create_boss_bar():
	# Outer container — anchored to bottom-centre, sized for 1920×1080
	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vb.offset_left   = -360
	vb.offset_right  =  360
	vb.offset_top    = -160
	vb.offset_bottom = -100
	vb.add_theme_constant_override("separation", 4)

	# Boss name label
	boss_label = Label.new()
	boss_label.text = "👹  BOSS"
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.45, 1.0))
	boss_label.add_theme_font_size_override("font_size", 20)
	boss_label.visible = false

	# Health bar
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(720, 30)
	boss_bar.show_percentage = false
	boss_bar.visible = false

	var boss_bg = StyleBoxFlat.new()
	boss_bg.bg_color     = Color(0.10, 0.04, 0.04)
	boss_bg.border_color = Color(0.50, 0.12, 0.50)
	boss_bg.set_border_width_all(2)
	boss_bg.set_corner_radius_all(5)
	boss_bar.add_theme_stylebox_override("background", boss_bg)

	var boss_fill = StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.85, 0.10, 0.85)
	boss_fill.set_corner_radius_all(5)
	boss_bar.add_theme_stylebox_override("fill", boss_fill)

	vb.add_child(boss_label)
	vb.add_child(boss_bar)
	add_child(vb)

func _style_hud():
	# Dark bg strip behind HUD
	var strip = ColorRect.new()
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.custom_minimum_size = Vector2(0, 36)
	strip.color = Color(0, 0, 0, 0.55)
	strip.z_index = -1
	add_child(strip)

	# Hide the old HP bar and label — hearts replace them
	$M/V/Top/HP.visible = false
	$M/V/Top/HPLabel.visible = false

	# Style XP bar
	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.05, 0.08, 0.18)
	xp_bg.border_color = Color(0.12, 0.28, 0.55)
	xp_bg.set_border_width_all(1)
	xp_bg.set_corner_radius_all(3)
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.22, 0.52, 1.0)
	xp_fill.set_corner_radius_all(3)
	var xp_bar = $M/V/XP
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.custom_minimum_size = Vector2(0, 10)

	# Style labels
	var lv_label = $M/V/Top/LvLabel
	lv_label.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	lv_label.add_theme_font_size_override("font_size", 14)
	lv_label.text = "LV 1"

	var gold_label = $M/V/Top/GoldLabel
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.text = "0g"

	# Coin icon — inserted right before GoldLabel
	var coin_icon = TextureRect.new()
	coin_icon.texture = TEX_COIN
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(18, 18)
	$M/V/Top.add_child(coin_icon)
	$M/V/Top.move_child(coin_icon, $M/V/Top.get_child_count() - 2)

	# Pistol icon — appended after GoldLabel
	var gun_sep = Control.new()
	gun_sep.custom_minimum_size = Vector2(10, 0)
	$M/V/Top.add_child(gun_sep)
	var pistol_icon = TextureRect.new()
	pistol_icon.texture = TEX_PISTOL
	pistol_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pistol_icon.custom_minimum_size = Vector2(22, 18)
	$M/V/Top.add_child(pistol_icon)

# ── Heart display ─────────────────────────────────────────────────────────────
# max_hp and cur are in half-hearts. Each visual heart = 2 half-hearts.
#   left  half: bright red  = filled,  dark red = empty
#   right half: bright red  = filled,  dark red = empty

const TEX_COIN       = preload("res://images/coin.png")
const TEX_PISTOL     = preload("res://images/pistol.png")
const TEX_HEART      = preload("res://images/heart.png")
const TEX_HEART_HALF = preload("res://images/heart_half.png")
const TEX_HEART_EMPTY = preload("res://images/heart_half.png")  # reused, tinted dark

func _build_hearts(max_hp: int):
	if _hearts_row and is_instance_valid(_hearts_row):
		_hearts_row.queue_free()
	_hearts_row = null
	_heart_slots.clear()

	var total_hearts = ceili(max_hp / 2.0)

	_hearts_row = HBoxContainer.new()
	_hearts_row.add_theme_constant_override("separation", 4)
	$M/V/Top.add_child(_hearts_row)
	$M/V/Top.move_child(_hearts_row, 0)

	for _i in range(total_hearts):
		var icon = TextureRect.new()
		icon.texture = TEX_HEART
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		_hearts_row.add_child(icon)
		_heart_slots.append(icon)

func _on_hp(cur: int, mx: int):
	var needed = ceili(mx / 2.0)
	if _heart_slots.size() != needed:
		_build_hearts(mx)

	# Each slot covers 2 half-hearts: i*2 (left) and i*2+1 (right)
	for i in range(_heart_slots.size()):
		var icon: TextureRect = _heart_slots[i]
		var filled = cur - i * 2  # how many half-hearts remain for this slot
		if filled >= 2:
			icon.texture = TEX_HEART           # full heart
			icon.modulate = Color.WHITE
		elif filled == 1:
			icon.texture = TEX_HEART_HALF      # half heart
			icon.modulate = Color.WHITE
		else:
			icon.texture = TEX_HEART_HALF      # empty — reuse half texture, tint dark
			icon.modulate = Color(0.25, 0.08, 0.08)

func _process(_delta):
	var pl = get_tree().get_first_node_in_group("player")
	if pl and "dash_timer" in pl:
		$M/V/Top/LvLabel.modulate = Color(0.4, 1, 0.4, 1) if pl.dash_timer <= 0 else Color(0.7, 0.7, 0.7, 1)
	var bosses = get_tree().get_nodes_in_group("enemies")
	var boss = null
	for e in bosses:
		if "phase" in e:
			boss = e
			break
	if boss and is_instance_valid(boss):
		boss_bar.visible = true
		boss_label.visible = true
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.current_health
		match boss.phase:
			1: boss_bar.modulate = Color(0.8, 0.1, 0.8, 1)
			2: boss_bar.modulate = Color(1.0, 0.4, 0.0, 1)
			3: boss_bar.modulate = Color(1.0, 0.0, 0.0, 1)
	else:
		boss_bar.visible = false
		boss_label.visible = false
