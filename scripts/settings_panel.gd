extends CanvasLayer
# ═══════════════════════════════════════════════════════════════════════════
# SETTINGS PANEL  —  reusable overlay for pause menu & main menu.
#
# Usage:
#   var _settings := preload("res://scripts/settings_panel.gd").new()
#   add_child(_settings)
#   _settings.open()
#
# Settings are saved to user://settings.cfg and reloaded on next open.
# ═══════════════════════════════════════════════════════════════════════════

const SAVE_PATH := "user://settings.cfg"

signal closed

# Node references built in _build_ui
var _sliders : Dictionary = {}  # key → {slider: HSlider, val_lbl: Label}
var _fs_btn  : Button

func _ready() -> void:
	layer        = 30          # above pause menu (layer 10) and full-map (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_settings()
	hide()

# ── Public API ──────────────────────────────────────────────────────────────
func open() -> void:
	_load_settings()     # restore saved values
	_update_fs_label()   # sync button to actual current window mode
	show()

func close() -> void:
	_save_settings()
	hide()
	closed.emit()

# ── UI construction ─────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Root Control — fills the entire viewport so children have a proper rect.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	# Full-screen dim overlay (blocks mouse clicks to elements behind)
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	# CenterContainer — reliably centres its child without any anchor math.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(center)

	# Panel — fixed size; CenterContainer places it at the screen centre.
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400.0, 440.0)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_box(panel)
	center.add_child(panel)

	# VBox — fills the panel with uniform padding.
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.set_anchor_and_offset(SIDE_LEFT,   0, 22.0)
	vb.set_anchor_and_offset(SIDE_TOP,    0, 18.0)
	vb.set_anchor_and_offset(SIDE_RIGHT,  1, -22.0)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 1, -18.0)
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	# ── Title ────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "⚙  SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	vb.add_child(title)

	vb.add_child(_make_sep())

	# ── Volume sliders ────────────────────────────────────────────────────
	_add_slider(vb, "Master Volume", "master", 80)
	_add_slider(vb, "Music Volume",  "music",  80)
	_add_slider(vb, "SFX Volume",    "sfx",    80)

	vb.add_child(_make_sep())

	# ── Fullscreen toggle ─────────────────────────────────────────────────
	_fs_btn = Button.new()
	_fs_btn.text = "Fullscreen:  OFF"
	_fs_btn.custom_minimum_size = Vector2(300.0, 42.0)
	_fs_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fs_btn.add_theme_font_size_override("font_size", 14)
	_fs_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_fs_btn.pressed.connect(_toggle_fullscreen)
	_apply_btn(_fs_btn, Color(0.06, 0.10, 0.20), Color(0.18, 0.44, 0.85))
	vb.add_child(_fs_btn)

	vb.add_child(_make_sep())

	# ── Done button ───────────────────────────────────────────────────────
	var done := Button.new()
	done.text = "✓  Done"
	done.custom_minimum_size = Vector2(300.0, 46.0)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.add_theme_font_size_override("font_size", 15)
	done.process_mode = Node.PROCESS_MODE_ALWAYS
	done.pressed.connect(close)
	_apply_btn(done, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.40, 1.0, 0.55))
	vb.add_child(done)


func _add_slider(parent: VBoxContainer, label_text: String, key: String, default_val: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(148.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
	hb.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step      = 1
	slider.value     = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	hb.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = str(default_val)
	val_lbl.custom_minimum_size = Vector2(36.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.60, 0.70, 0.85))
	hb.add_child(val_lbl)

	_sliders[key] = {"slider": slider, "val_lbl": val_lbl}

	# Keep label in sync and apply volume immediately
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = str(int(v))
		_apply_volume(key, v))


# ── Volume helpers ──────────────────────────────────────────────────────────
func _apply_volume(key: String, value: float) -> void:
	var db: float = linear_to_db(value / 100.0) if value > 0.0 else -80.0
	match key:
		"master":
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
		"music":
			var idx := AudioServer.get_bus_index("Music")
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, db)
		"sfx":
			var idx := AudioServer.get_bus_index("SFX")
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, db)


func _is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or \
		   m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _set_fullscreen(enable: bool) -> void:
	if enable:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_fs_label()

func _update_fs_label() -> void:
	if _fs_btn == null:
		return
	_fs_btn.text = "Fullscreen:  ON" if _is_fullscreen() else "Fullscreen:  OFF"

func _toggle_fullscreen() -> void:
	_set_fullscreen(not _is_fullscreen())


# ── Persistence ─────────────────────────────────────────────────────────────
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in _sliders:
		cfg.set_value("audio", key, _sliders[key]["slider"].value)
	cfg.set_value("display", "fullscreen", _is_fullscreen())
	cfg.save(SAVE_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key: String in _sliders:
			var v: float = cfg.get_value("audio", key, 80.0)
			_sliders[key]["slider"].value  = v
			_sliders[key]["val_lbl"].text  = str(int(v))
			_apply_volume(key, v)
		var fs: bool = cfg.get_value("display", "fullscreen", false)
		_set_fullscreen(fs)
	else:
		# No save file yet — just sync the label to whatever the window currently is.
		_update_fs_label()


# ── Style helpers ────────────────────────────────────────────────────────────
func _make_sep() -> HSeparator:
	var s := HSeparator.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.22, 0.28, 0.40, 0.55)
	ssb.content_margin_top = 1; ssb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", ssb)
	return s


func _style_box(panel: Panel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.04, 0.06, 0.13, 0.98)
	sb.border_color = Color(0.22, 0.50, 0.88, 1.00)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)


func _apply_btn(btn: Button, bg: Color, border: Color,
		text_color: Color = Color(0.88, 0.93, 1.0)) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color    = bg
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(6)
	sn.content_margin_left = 18;  sn.content_margin_right  = 18
	sn.content_margin_top  = 10;  sn.content_margin_bottom = 10
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color    = bg.lightened(0.15)
	sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
