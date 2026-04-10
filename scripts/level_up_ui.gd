extends CanvasLayer

var _bg: ColorRect = null

func _ready():
	$Panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.level_up.connect(_on_level_up)

	# Full-screen dim overlay behind the panel
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.z_index = -1
	add_child(_bg)
	move_child(_bg, 0)

func _on_level_up(lvl):
	get_tree().paused = true

	# Clear old cards
	for c in $Panel/VBox/ItemRow.get_children():
		c.queue_free()

	# Build new cards
	for item in ItemDatabase.get_random_items(3):
		$Panel/VBox/ItemRow.add_child(_make_card(item))

	$Panel/VBox/Title.text = "— LEVEL UP —"
	$Panel/VBox/Title.add_theme_font_size_override("font_size", 28)
	$Panel/VBox/Title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1))
	$Panel/VBox/Subtitle.text = "Level %d  ·  Choose your upgrade" % lvl
	$Panel/VBox/Subtitle.add_theme_font_size_override("font_size", 15)
	$Panel/VBox/Subtitle.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9, 1))

	# Style the panel itself
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	panel_style.border_color = Color(0.25, 0.55, 0.85, 1)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	$Panel.add_theme_stylebox_override("panel", panel_style)

	# Center the panel: 940 wide x 320 tall
	$Panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -470)
	$Panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  470)
	$Panel.set_anchor_and_offset(SIDE_TOP,    0.5, -175)
	$Panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  175)

	$Panel.show()
	$Panel.pivot_offset = Vector2(470, 175)
	$Panel.scale = Vector2(0.88, 0.88)
	$Panel.modulate.a = 0.0

	# Animate in
	var tw = create_tween()
	tw.set_parallel()
	tw.tween_property($Panel, "scale",       Vector2(1, 1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property($Panel, "modulate:a",  1.0,           0.18)
	tw.tween_property(_bg,    "color",       Color(0, 0, 0, 0.72), 0.2)

func _make_card(item: Dictionary) -> Button:
	var rarity = item.get("rarity", "common")

	# Per-rarity palette
	var palettes = {
		"common": {
			"bg":     Color(0.10, 0.13, 0.18),
			"border": Color(0.38, 0.50, 0.62),
			"glow":   Color(0.38, 0.50, 0.62),
			"text":   Color(0.82, 0.88, 1.00),
			"sub":    Color(0.55, 0.65, 0.78),
			"badge":  "⬜ COMMON",
			"badge_color": Color(0.55, 0.65, 0.78),
		},
		"uncommon": {
			"bg":     Color(0.06, 0.13, 0.24),
			"border": Color(0.15, 0.58, 1.00),
			"glow":   Color(0.15, 0.58, 1.00),
			"text":   Color(0.55, 0.88, 1.00),
			"sub":    Color(0.40, 0.70, 0.95),
			"badge":  "🔷 UNCOMMON",
			"badge_color": Color(0.3, 0.7, 1.0),
		},
		"rare": {
			"bg":     Color(0.16, 0.08, 0.04),
			"border": Color(1.00, 0.72, 0.10),
			"glow":   Color(1.00, 0.72, 0.10),
			"text":   Color(1.00, 0.88, 0.40),
			"sub":    Color(0.95, 0.75, 0.45),
			"badge":  "🌟 RARE",
			"badge_color": Color(1.0, 0.80, 0.2),
		},
	}
	var p = palettes.get(rarity, palettes["common"])

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(280, 130)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.clip_text = false

	# Normal style
	var sn = StyleBoxFlat.new()
	sn.bg_color = p.bg
	sn.border_color = p.border
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sn.set_border_width(side, 2)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		sn.set_corner_radius(corner, 10)
	sn.content_margin_left   = 14
	sn.content_margin_right  = 14
	sn.content_margin_top    = 10
	sn.content_margin_bottom = 10

	# Hover style — brighter border + bg
	var sh = sn.duplicate()
	sh.bg_color = p.bg.lightened(0.18)
	sh.border_color = p.glow.lightened(0.25)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sh.set_border_width(side, 3)

	var sf = sn.duplicate()  # focus same as normal (no dotted box)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sf)

	btn.add_theme_color_override("font_color",       p.text)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

	# Card text: badge line, bold name, desc
	btn.text = "%s\n%s\n%s" % [p.badge, item.name.to_upper(), item.desc]

	# Badge color via Label — we fake it by putting a RichTextLabel inside
	# But Button doesn't support rich text, so use color on the whole button
	# and set badge using a separate label approach via a VBox child isn't possible
	# So we just use the text approach with the theme color.
	# Override font color per-rarity already covers it well enough.

	btn.pressed.connect(func(): _pick(item))
	btn.mouse_entered.connect(func(): _play_hover())
	return btn

func _play_hover():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_hover.mp3")
	snd.volume_db = -8
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

func _pick(item):
	# Animate out
	var tw = create_tween()
	tw.set_parallel()
	tw.tween_property($Panel, "scale",      Vector2(0.9, 0.9), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property($Panel, "modulate:a", 0.0,               0.14)
	tw.tween_property(_bg,    "color",      Color(0, 0, 0, 0), 0.14)
	await tw.finished

	$Panel.hide()
	get_tree().paused = false

	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_confirm.mp3")
	snd.volume_db = 3
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

	var pl = get_tree().get_first_node_in_group("player")
	if pl: pl.apply_item(item)
