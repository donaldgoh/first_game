extends Control

# ═══════════════════════════════════════════════════════════════════════════════
# Part Select — pre-run chip picker.
# Shows ALL chips sorted by rarity; player clicks any card to start the run.
# ═══════════════════════════════════════════════════════════════════════════════

const RARITY_COL = {
	0: Color(0.55, 0.58, 0.70),   # common  — grey-blue
	1: Color(0.25, 0.85, 0.45),   # uncommon — green
	2: Color(0.95, 0.65, 0.10),   # rare     — gold
}
const RARITY_NAME = {0: "COMMON", 1: "UNCOMMON", 2: "RARE"}

func _ready():
	$BG.color = Color(0.04, 0.03, 0.09)
	$VBox.hide()   # hide the placeholder nodes from the scene
	_build_ui()

# ── Build entire UI in code ────────────────────────────────────────────────────
func _build_ui():
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Header ────────────────────────────────────────────────────────────────
	var header = PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 72)
	var hbg = StyleBoxFlat.new()
	hbg.bg_color = Color(0.06, 0.05, 0.12)
	hbg.border_color = Color(0.18, 0.18, 0.28)
	hbg.set_border_width_all(0)
	hbg.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", hbg)
	root.add_child(header)

	var header_inner = VBoxContainer.new()
	header_inner.add_theme_constant_override("separation", 2)
	header_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(header_inner)

	var title = Label.new()
	title.text = "— SELECT STARTING CHIP —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	header_inner.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Choose any chip to equip for this run."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	header_inner.add_child(subtitle)

	# ── Scrollable chip grid ───────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left",   28)
	content_margin.add_theme_constant_override("margin_right",  28)
	content_margin.add_theme_constant_override("margin_top",    22)
	content_margin.add_theme_constant_override("margin_bottom", 22)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content)
	scroll.add_child(content_margin)

	# Sort all parts into rarity buckets
	var all_parts = WeaponPartsDatabase.all()
	for rarity in [0, 1, 2]:
		var bucket: Array = []
		for p in all_parts:
			if int(p.rarity) == rarity:
				bucket.append(p)
		if bucket.is_empty(): continue

		# Section header
		var sec_hbox = HBoxContainer.new()
		sec_hbox.add_theme_constant_override("separation", 10)
		content.add_child(sec_hbox)

		var sec_label = Label.new()
		sec_label.text = RARITY_NAME[rarity]
		sec_label.add_theme_font_size_override("font_size", 13)
		sec_label.add_theme_color_override("font_color", RARITY_COL[rarity])
		sec_hbox.add_child(sec_label)

		var line = HSeparator.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line_style = StyleBoxFlat.new()
		line_style.bg_color = RARITY_COL[rarity].darkened(0.55)
		line_style.content_margin_top = 1
		line.add_theme_stylebox_override("separator", line_style)
		sec_hbox.add_child(line)

		# Card flow
		var flow = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(flow)

		for part in bucket:
			flow.add_child(_make_card(part))

	# ── Bottom bar ─────────────────────────────────────────────────────────────
	var bar = PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.05, 0.12)
	bar_bg.border_color = Color(0.18, 0.18, 0.28)
	bar_bg.set_border_width_all(0)
	bar_bg.border_width_top = 2
	bar.add_theme_stylebox_override("panel", bar_bg)
	root.add_child(bar)

	var bar_inner = HBoxContainer.new()
	bar_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_inner.add_theme_constant_override("separation", 20)
	bar.add_child(bar_inner)

	var back_btn = _make_btn("← Back to Menu",
		Color(0.10, 0.05, 0.06), Color(0.45, 0.12, 0.14), Color(0.80, 0.42, 0.42))
	back_btn.custom_minimum_size = Vector2(220, 42)
	back_btn.pressed.connect(func():
		_play_confirm()
		SceneLoader.goto("res://scenes/main_menu.tscn"))
	back_btn.mouse_entered.connect(func(): _play_hover())
	bar_inner.add_child(back_btn)

	var skip_btn = _make_btn("▶  Play Without a Chip",
		Color(0.07, 0.10, 0.16), Color(0.25, 0.40, 0.65), Color(0.55, 0.75, 1.0))
	skip_btn.custom_minimum_size = Vector2(260, 42)
	skip_btn.pressed.connect(func():
		_play_confirm()
		GameManager.reset()
		GameManager.active_part = ""
		await get_tree().create_timer(0.1).timeout
		SceneLoader.goto("res://scenes/dungeon.tscn"))
	skip_btn.mouse_entered.connect(func(): _play_hover())
	bar_inner.add_child(skip_btn)

# ── Card widget ────────────────────────────────────────────────────────────────
func _make_card(part: WeaponPart) -> Button:
	var rcol = RARITY_COL[int(part.rarity)]

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(215, 130)
	btn.clip_contents = false
	btn.focus_mode = Control.FOCUS_NONE

	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.07, 0.09, 0.16)
	sn.border_color = rcol.darkened(0.25)
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(5)
	sn.content_margin_left   = 10
	sn.content_margin_right  = 10
	sn.content_margin_top    = 8
	sn.content_margin_bottom = 8
	var sh = sn.duplicate()
	sh.bg_color    = rcol.darkened(0.65)
	sh.border_color = rcol.lightened(0.2)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)

	# Overlay layout (passes mouse events through to the button)
	var inner = VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	# Rarity badge
	var badge = Label.new()
	badge.text = RARITY_NAME[int(part.rarity)]
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", rcol)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(badge)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = part.name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = part.desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.65, 0.78))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	# Cost tag
	var cost_lbl = Label.new()
	cost_lbl.text = "Shop: %dg" % part.cost
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 0.75))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cost_lbl)

	btn.pressed.connect(func(): _select(part))
	btn.mouse_entered.connect(func(): _play_hover())
	return btn

# ── Helpers ───────────────────────────────────────────────────────────────────
func _make_btn(label_text: String, bg: Color, border: Color, text_col: Color) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	var sn = StyleBoxFlat.new()
	sn.bg_color = bg; sn.border_color = border
	sn.set_border_width_all(2); sn.set_corner_radius_all(6)
	sn.content_margin_left = 18; sn.content_margin_right = 18
	sn.content_margin_top = 10; sn.content_margin_bottom = 10
	var sh = sn.duplicate()
	sh.bg_color = bg.lightened(0.15); sh.border_color = border.lightened(0.3)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn

func _select(part: WeaponPart):
	_play_confirm()
	GameManager.reset()
	GameManager.active_part = part.id
	await get_tree().create_timer(0.1).timeout
	SceneLoader.goto("res://scenes/dungeon.tscn")

func _play_hover():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_hover.mp3")
	snd.volume_db = -8
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)

func _play_confirm():
	var snd = AudioStreamPlayer.new()
	snd.stream = load("res://sound_effects/menu_confirm.mp3")
	snd.volume_db = -5
	add_child(snd); snd.play()
	snd.finished.connect(snd.queue_free)
