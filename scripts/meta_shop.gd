extends Control

var _selected_part: WeaponPart = null

func _ready():
	_style()
	_update_label()
	_populate_parts()
	$VBox/Buttons/PlayButton.pressed.connect(func():
		SceneLoader.goto("res://scenes/part_select.tscn"))
	$VBox/Buttons/MainMenuButton.pressed.connect(func():
		SceneLoader.goto("res://scenes/main_menu.tscn"))
	$VBox/ContentRow/DetailPanel/DetailVBox/DetailUnlockBtn.pressed.connect(_unlock_selected)

func _style():
	# Gold label
	$VBox/GoldLabel.add_theme_font_size_override("font_size", 18)
	$VBox/GoldLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	# Title label above parts list
	var title = Label.new()
	title.text = "🔫  WEAPON PARTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	$VBox.add_child(title)
	$VBox.move_child(title, 1)

	# Style detail panel
	var dp_style = StyleBoxFlat.new()
	dp_style.bg_color = Color(0.05, 0.07, 0.14)
	dp_style.border_color = Color(0.22, 0.50, 0.88)
	dp_style.set_border_width_all(2)
	dp_style.set_corner_radius_all(8)
	dp_style.content_margin_left = 20
	dp_style.content_margin_right = 20
	dp_style.content_margin_top = 16
	dp_style.content_margin_bottom = 16
	$VBox/ContentRow/DetailPanel.add_theme_stylebox_override("panel", dp_style)

	# Detail labels
	var dn = $VBox/ContentRow/DetailPanel/DetailVBox/DetailName
	dn.add_theme_font_size_override("font_size", 22)
	dn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

	var dd = $VBox/ContentRow/DetailPanel/DetailVBox/DetailDesc
	dd.add_theme_font_size_override("font_size", 15)
	dd.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))

	# Unlock button
	var ub = $VBox/ContentRow/DetailPanel/DetailVBox/DetailUnlockBtn
	ub.custom_minimum_size = Vector2(0, 44)
	ub.add_theme_font_size_override("font_size", 15)
	_apply_btn(ub, Color(0.06, 0.10, 0.20), Color(0.18, 0.44, 0.85), Color(0.55, 0.82, 1.0))

	# Bottom buttons
	$VBox/Buttons.add_theme_constant_override("separation", 16)
	var pb = $VBox/Buttons/PlayButton
	pb.text = "▶  Play"
	pb.custom_minimum_size = Vector2(200, 48)
	pb.add_theme_font_size_override("font_size", 16)
	_apply_btn(pb, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.38, 1.0, 0.52))

	var mb = $VBox/Buttons/MainMenuButton
	mb.text = "🏠  Main Menu"
	mb.custom_minimum_size = Vector2(200, 48)
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

func _update_label():
	$VBox/GoldLabel.text = "💰  Lifetime Gold: %dg" % GameManager.lifetime_gold

func _populate_parts():
	for c in $VBox/ContentRow/PartList/PartListVBox.get_children():
		c.queue_free()

	for part in WeaponPartsDatabase.all():
		var is_unlocked = part.id in GameManager.unlocked_parts
		var btn = Button.new()
		btn.text = "%s  %s" % ["✅" if is_unlocked else "🔒", part.name]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)

		# Style per lock state
		var bg     = Color(0.06, 0.12, 0.22) if is_unlocked else Color(0.08, 0.08, 0.12)
		var border = Color(0.20, 0.52, 0.92) if is_unlocked else Color(0.25, 0.28, 0.35)
		var tcol   = Color(0.3, 1.0, 0.6)    if is_unlocked else Color(0.55, 0.60, 0.70)
		var sn = StyleBoxFlat.new()
		sn.bg_color = bg; sn.border_color = border
		sn.set_border_width_all(1); sn.set_corner_radius_all(4)
		sn.content_margin_left = 12; sn.content_margin_right = 12
		sn.content_margin_top = 6;   sn.content_margin_bottom = 6
		var sh = sn.duplicate()
		sh.bg_color = bg.lightened(0.12); sh.border_color = border.lightened(0.2)
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover",  sh)
		btn.add_theme_stylebox_override("focus",  sn)
		btn.add_theme_color_override("font_color",       tcol)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

		btn.pressed.connect(func(): _show_detail(part))
		$VBox/ContentRow/PartList/PartListVBox.add_child(btn)

func _show_detail(part: WeaponPart):
	_selected_part = part
	var is_unlocked = part.id in GameManager.unlocked_parts
	var dn = $VBox/ContentRow/DetailPanel/DetailVBox/DetailName
	var dd = $VBox/ContentRow/DetailPanel/DetailVBox/DetailDesc
	var ds = $VBox/ContentRow/DetailPanel/DetailVBox/DetailStatus
	var ub = $VBox/ContentRow/DetailPanel/DetailVBox/DetailUnlockBtn
	dn.text = part.name
	dd.text = part.desc
	if is_unlocked:
		ds.text = "✅  UNLOCKED"
		ds.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		ds.add_theme_font_size_override("font_size", 15)
		ub.visible = false
	else:
		ds.text = "🔒  LOCKED"
		ds.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		ds.add_theme_font_size_override("font_size", 15)
		ub.text = "⚡  UNLOCK  —  %dg" % part.cost
		ub.visible = true

func _unlock_selected():
	if _selected_part == null: return
	if GameManager.spend_lifetime_gold(_selected_part.cost):
		GameManager.unlocked_parts.append(_selected_part.id)
		GameManager.save_meta()
		_update_label()
		_populate_parts()
		_show_detail(_selected_part)
