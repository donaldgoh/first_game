extends Control

func _ready():
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameManager.save_meta()

func _build_ui():
	# Full-screen dark background
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred panel — anchored to screen center
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 640)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var ps = StyleBoxFlat.new()
	ps.bg_color     = Color(0.05, 0.07, 0.14, 0.97)
	ps.border_color = Color(0.55, 0.12, 0.14)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	var mg = MarginContainer.new()
	mg.add_theme_constant_override("margin_left",   28)
	mg.add_theme_constant_override("margin_right",  28)
	mg.add_theme_constant_override("margin_top",    22)
	mg.add_theme_constant_override("margin_bottom", 22)
	mg.add_child(outer)
	panel.add_child(mg)

	# ── Title ──────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "💀  GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22))
	outer.add_child(title)

	var divider = HSeparator.new()
	var div_sty = StyleBoxFlat.new()
	div_sty.bg_color = Color(0.55, 0.12, 0.14, 0.6)
	div_sty.content_margin_top = 1
	divider.add_theme_stylebox_override("separator", div_sty)
	outer.add_child(divider)

	# ── Stats (scrollable so it always fits) ───────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var stats_lbl = Label.new()
	stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	scroll.add_child(stats_lbl)

	var mins = int(GameManager.time_alive / 60)
	var secs = int(GameManager.time_alive) % 60
	var kpm  = 0.0
	if GameManager.time_alive > 0:
		kpm = snappedf(GameManager.enemies_killed / (GameManager.time_alive / 60.0), 0.1)
	stats_lbl.text = (
		"🏰  Floor Reached      %d\n" +
		"⭐  Level              %d\n" +
		"💀  Enemies Killed     %d\n" +
		"⚔️   Kills / Min        %.1f\n" +
		"⏱️   Time Survived      %02d:%02d\n" +
		"💰  Gold Collected     %dg\n" +
		"❤️   Max Health         %d\n" +
		"🗡️   Damage             %d\n" +
		"⚡  Attack Speed       %.1fx"
	) % [
		GameManager.floor_number, GameManager.player_level,
		GameManager.enemies_killed, kpm,
		mins, secs, GameManager.gold,
		GameManager.p_max_health, GameManager.p_damage,
		GameManager.p_attack_speed
	]

	# ── Buttons ────────────────────────────────────────────────────────────
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	outer.add_child(btn_vbox)

	var retry_btn = _make_btn("▶  Try Again",
		Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.38, 1.0, 0.52))
	retry_btn.pressed.connect(func():
		_sfx_confirm()
		GameManager.reset()
		SceneLoader.goto("res://scenes/dungeon.tscn"))
	btn_vbox.add_child(retry_btn)

	var menu_btn = _make_btn("🏠  Return to Hub",
		Color(0.10, 0.05, 0.06), Color(0.45, 0.12, 0.14), Color(0.85, 0.42, 0.44))
	menu_btn.pressed.connect(func():
		_sfx_confirm()
		SceneLoader.goto("res://scenes/hub.tscn"))
	btn_vbox.add_child(menu_btn)

func _make_btn(label: String, bg: Color, border: Color, text_col: Color) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)
	btn.mouse_entered.connect(func(): _sfx_hover())
	var sn = StyleBoxFlat.new()
	sn.bg_color = bg; sn.border_color = border
	sn.set_border_width_all(2); sn.set_corner_radius_all(6)
	sn.content_margin_left = 18; sn.content_margin_right = 18
	sn.content_margin_top = 10; sn.content_margin_bottom = 10
	var sh = sn.duplicate()
	sh.bg_color = bg.lightened(0.15); sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn

func _sfx_hover():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_hover.mp3")
	snd.volume_db = -8
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)

func _sfx_confirm():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_confirm.mp3")
	snd.volume_db = -3
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)
