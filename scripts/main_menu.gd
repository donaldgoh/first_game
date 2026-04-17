extends Control

const SettingsPanel = preload("res://scripts/settings_panel.gd")

var _settings: CanvasLayer = null

func _ready():
	_style()

	$VBox/StartButton.pressed.connect(func():
		_play_confirm()
		await get_tree().create_timer(0.1).timeout
		SceneLoader.goto("res://scenes/hub.tscn"))
	$VBox/SettingsButton.pressed.connect(_open_settings)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	$VBox/StartButton.mouse_entered.connect(func():   _play_hover())
	$VBox/SettingsButton.mouse_entered.connect(func(): _play_hover())
	$VBox/QuitButton.mouse_entered.connect(func():    _play_hover())

	# Settings overlay — added as CanvasLayer child of root Control
	_settings = SettingsPanel.new()
	add_child(_settings)

func _open_settings() -> void:
	if _settings:
		_settings.open()

func _style():
	$FullRect.color = Color(0.03, 0.05, 0.10)
	$BG.visible = false

	# Expand VBox — extra height for the Settings button
	var vb = $VBox
	vb.set_anchor_and_offset(SIDE_LEFT,   0.5, -220)
	vb.set_anchor_and_offset(SIDE_RIGHT,  0.5,  220)
	vb.set_anchor_and_offset(SIDE_TOP,    0.5, -225)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  225)
	vb.add_theme_constant_override("separation", 16)

	# Title
	var title = $VBox/Title
	title.text = "REPS"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# StartButton — "Continue" for returning players, "New Game" for first-timers
	var sb = $VBox/StartButton
	sb.text = "▶  Continue" if FileAccess.file_exists("user://meta.dat") else "▶  New Game"
	sb.custom_minimum_size = Vector2(340, 52)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sb.add_theme_font_size_override("font_size", 16)
	_apply_btn(sb, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.4, 1.0, 0.55))

	# SettingsButton
	var stb = $VBox/SettingsButton
	stb.text = "⚙  Settings"
	stb.custom_minimum_size = Vector2(340, 52)
	stb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stb.add_theme_font_size_override("font_size", 16)
	_apply_btn(stb, Color(0.08, 0.08, 0.18), Color(0.30, 0.30, 0.75), Color(0.75, 0.80, 1.0))

	# QuitButton
	var qb = $VBox/QuitButton
	qb.text = "✕  Quit"
	qb.custom_minimum_size = Vector2(340, 52)
	qb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qb.add_theme_font_size_override("font_size", 16)
	_apply_btn(qb, Color(0.12, 0.05, 0.06), Color(0.50, 0.12, 0.14), Color(0.85, 0.42, 0.42))

	# Controls hint label
	var ctrl = $VBox/Controls
	ctrl.text = "WASD · Move   Mouse · Aim   LMB · Shoot   E · Interact   ESC · Pause   TAB · Map"
	ctrl.add_theme_font_size_override("font_size", 12)
	ctrl.add_theme_color_override("font_color", Color(0.35, 0.45, 0.60))
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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

func _play_hover():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_hover.mp3")
	snd.volume_db = -8
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)

func _play_confirm():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_confirm.mp3")
	snd.volume_db = -5
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
