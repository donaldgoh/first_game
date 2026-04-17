extends CanvasLayer

const SettingsPanel = preload("res://scripts/settings_panel.gd")

var _settings: CanvasLayer = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBox/ResumeButton.process_mode  = Node.PROCESS_MODE_ALWAYS
	$Panel/VBox/SettingsButton.process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBox/MenuButton.process_mode    = Node.PROCESS_MODE_ALWAYS
	$Panel.hide()

	$Panel/VBox/ResumeButton.pressed.connect(func(): _sfx_confirm(); toggle())
	$Panel/VBox/SettingsButton.pressed.connect(func(): _sfx_confirm(); _open_settings())
	$Panel/VBox/MenuButton.pressed.connect(func():
		_sfx_confirm()
		get_tree().paused = false
		SceneLoader.goto("res://scenes/hub.tscn"))

	for btn in [$Panel/VBox/ResumeButton, $Panel/VBox/SettingsButton, $Panel/VBox/MenuButton]:
		btn.mouse_entered.connect(_sfx_hover)

	# Build settings overlay (child of this CanvasLayer)
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.closed.connect(func(): pass)   # panel saves on close

	_style_panel()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if _settings and _settings.visible:
			_settings.close()
		else:
			toggle()
		get_viewport().set_input_as_handled()

func toggle():
	var showing = $Panel.visible
	$Panel.visible = !showing
	get_tree().paused = !showing

func _open_settings() -> void:
	if _settings:
		_settings.open()

func _style_panel():
	# Expand Panel
	var panel = $Panel
	panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -170)
	panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  170)
	panel.set_anchor_and_offset(SIDE_TOP,    0.5, -175)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  175)

	# Panel StyleBoxFlat
	var psb = StyleBoxFlat.new()
	psb.bg_color     = Color(0.04, 0.06, 0.13, 0.97)
	psb.border_color = Color(0.22, 0.50, 0.88)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", psb)

	# Fix VBox to fill panel with insets
	var vb = $Panel/VBox
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.set_anchor_and_offset(SIDE_LEFT,   0,  16)
	vb.set_anchor_and_offset(SIDE_TOP,    0,  14)
	vb.set_anchor_and_offset(SIDE_RIGHT,  1, -16)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 1, -14)
	vb.add_theme_constant_override("separation", 14)

	# Title
	var title = $Panel/VBox/Title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))

	# ResumeButton
	var rb = $Panel/VBox/ResumeButton
	rb.text = "▶  Resume"
	rb.custom_minimum_size = Vector2(280, 46)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rb.add_theme_font_size_override("font_size", 15)
	rb.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_btn(rb, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.38, 1.0, 0.52))

	# SettingsButton
	var sb = $Panel/VBox/SettingsButton
	sb.text = "⚙  Settings"
	sb.custom_minimum_size = Vector2(280, 46)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sb.add_theme_font_size_override("font_size", 15)
	sb.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_btn(sb, Color(0.08, 0.08, 0.18), Color(0.30, 0.30, 0.75), Color(0.75, 0.80, 1.0))

	# MenuButton
	var mb = $Panel/VBox/MenuButton
	mb.text = "🏠  Return to Hub"
	mb.custom_minimum_size = Vector2(280, 46)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mb.add_theme_font_size_override("font_size", 15)
	mb.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_btn(mb, Color(0.06, 0.10, 0.20), Color(0.18, 0.44, 0.85), Color(0.55, 0.82, 1.0))

func _apply_btn(btn: Button, bg: Color, border: Color, text_color: Color = Color(0.88, 0.93, 1.0)):
	var sn = StyleBoxFlat.new()
	sn.bg_color     = bg
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(6)
	sn.content_margin_left = 18;  sn.content_margin_right  = 18
	sn.content_margin_top  = 10;  sn.content_margin_bottom = 10
	var sh = sn.duplicate()
	sh.bg_color     = bg.lightened(0.15)
	sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _sfx_hover() -> void:
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_hover.mp3")
	snd.volume_db = -8
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)

func _sfx_confirm() -> void:
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_confirm.mp3")
	snd.volume_db = -5
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)
