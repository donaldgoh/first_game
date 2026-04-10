extends Control

func _ready():
	_style()
	get_tree().paused = false
	var mins = int(GameManager.time_alive / 60)
	var secs = int(GameManager.time_alive) % 60
	var kills_per_min = 0.0
	if GameManager.time_alive > 0:
		kills_per_min = snappedf(GameManager.enemies_killed / (GameManager.time_alive / 60.0), 0.1)
	$VBox/StatsLabel.text = (
		"━━━━━━━━━━━━━━━━━━━━━\n" +
		"🏰  Floor Reached:      %d\n" +
		"⭐  Level:              %d\n" +
		"💀  Enemies Killed:     %d\n" +
		"⚔️   Kills / Min:        %.1f\n" +
		"⏱️   Time Survived:      %02d:%02d\n" +
		"💰  Gold Collected:     %dg\n" +
		"❤️   Max Health:         %d\n" +
		"🗡️   Damage:             %d\n" +
		"⚡  Attack Speed:       %.1fx\n" +
		"🛡️   Armor:              %d\n" +
		"━━━━━━━━━━━━━━━━━━━━━"
	) % [
		GameManager.floor_number,
		GameManager.player_level,
		GameManager.enemies_killed,
		kills_per_min,
		mins, secs,
		GameManager.gold,
		GameManager.p_max_health,
		GameManager.p_damage,
		GameManager.p_attack_speed,
		GameManager.p_armor
	]
	GameManager.save_meta()
	$VBox/RetryButton.pressed.connect(func():
		GameManager.reset()
		SceneLoader.goto("res://scenes/part_select.tscn"))
	$VBox/UpgradeButton.pressed.connect(func():
		GameManager.reset()
		SceneLoader.goto("res://scenes/meta_shop.tscn"))
	$VBox/MenuButton.pressed.connect(func():
		GameManager.reset()
		SceneLoader.goto("res://scenes/main_menu.tscn"))

func _style():
	# Fix root anchors
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# BG
	$BG.set_anchors_preset(Control.PRESET_FULL_RECT)
	$BG.color = Color(0.03, 0.05, 0.10)

	# Fix VBox anchors
	var vb = $VBox
	vb.set_anchor_and_offset(SIDE_LEFT, 0.5, -360)
	vb.set_anchor_and_offset(SIDE_RIGHT, 0.5, 360)
	vb.set_anchor_and_offset(SIDE_TOP, 0.5, -270)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 270)
	vb.add_theme_constant_override("separation", 16)

	# Title
	var title = $VBox/Title
	title.text = "💀  GAME OVER"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# StatsLabel
	var sl = $VBox/StatsLabel
	sl.add_theme_font_size_override("font_size", 14)
	sl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# RetryButton
	var rb = $VBox/RetryButton
	rb.text = "▶  Try Again"
	rb.custom_minimum_size = Vector2(0, 48)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rb.add_theme_font_size_override("font_size", 16)
	_apply_btn(rb, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.38, 1.0, 0.52))

	# UpgradeButton
	var ub = $VBox/UpgradeButton
	ub.text = "⬆  Hub Upgrades"
	ub.custom_minimum_size = Vector2(0, 48)
	ub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ub.add_theme_font_size_override("font_size", 16)
	_apply_btn(ub, Color(0.06, 0.10, 0.20), Color(0.18, 0.44, 0.85), Color(0.55, 0.82, 1.0))

	# MenuButton
	var mb = $VBox/MenuButton
	mb.text = "🏠  Main Menu"
	mb.custom_minimum_size = Vector2(0, 48)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mb.add_theme_font_size_override("font_size", 16)
	_apply_btn(mb, Color(0.10, 0.05, 0.06), Color(0.45, 0.12, 0.14), Color(0.85, 0.42, 0.44))

func _apply_btn(btn: Button, bg: Color, border: Color, text_color: Color = Color(0.88, 0.93, 1.0)):
	var sn = StyleBoxFlat.new()
	sn.bg_color = bg
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(6)
	sn.content_margin_left = 18; sn.content_margin_right = 18
	sn.content_margin_top = 10; sn.content_margin_bottom = 10
	var sh = sn.duplicate()
	sh.bg_color = bg.lightened(0.15)
	sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus", sn)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
