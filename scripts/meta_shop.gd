extends Control

# ── Constants ──────────────────────────────────────────────────────────────────
const RARITY_COL := {
	WeaponPart.Rarity.COMMON:   Color(0.60, 0.60, 0.60),
	WeaponPart.Rarity.UNCOMMON: Color(0.25, 0.62, 1.00),
	WeaponPart.Rarity.RARE:     Color(1.00, 0.65, 0.05),
}
const RARITY_ICON := {
	WeaponPart.Rarity.COMMON:   "◆",
	WeaponPart.Rarity.UNCOMMON: "◈",
	WeaponPart.Rarity.RARE:     "★",
}
const RARITY_NAME := {
	WeaponPart.Rarity.COMMON:   "Common",
	WeaponPart.Rarity.UNCOMMON: "Uncommon",
	WeaponPart.Rarity.RARE:     "Rare",
}

enum PartState { UNKNOWN, SEEN, UNLOCKED }

# ── State ──────────────────────────────────────────────────────────────────────
var _selected_part: WeaponPart = null
var _selected_state: PartState = PartState.UNKNOWN

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready():
	_style()
	_update_label()
	_populate_grid()
	$VBox/Buttons/PlayButton.pressed.connect(func():
		SceneLoader.goto("res://scenes/part_select.tscn"))
	$VBox/Buttons/MainMenuButton.pressed.connect(func():
		SceneLoader.goto("res://scenes/main_menu.tscn"))
	$VBox/ContentRow/DetailPanel/DetailVBox/DetailUnlockBtn.pressed.connect(_unlock_selected)

# ── Helpers ────────────────────────────────────────────────────────────────────
func _get_state(part: WeaponPart) -> PartState:
	if part.id in GameManager.unlocked_parts: return PartState.UNLOCKED
	if part.id in GameManager.seen_parts:     return PartState.SEEN
	return PartState.UNKNOWN

func _update_label():
	$VBox/GoldLabel.text = "💰  Lifetime Gold: %dg" % GameManager.lifetime_gold

# ── Grid population ────────────────────────────────────────────────────────────
func _populate_grid():
	var container = $VBox/ContentRow/PartList/PartListVBox
	for c in container.get_children():
		c.queue_free()

	for part in WeaponPartsDatabase.all():
		var state  = _get_state(part)
		var rcol   = RARITY_COL.get(part.rarity, Color.GRAY)
		var btn    = Button.new()
		btn.custom_minimum_size = Vector2(82, 82)
		btn.clip_text = true

		match state:
			PartState.UNKNOWN:
				# Completely hidden — just a dark tile with "?"
				btn.add_theme_stylebox_override("normal",  _card_style(Color(0.05, 0.06, 0.10), Color(0.14, 0.16, 0.22)))
				btn.add_theme_stylebox_override("hover",   _card_style(Color(0.08, 0.09, 0.15), Color(0.22, 0.24, 0.32)))
				btn.add_theme_stylebox_override("pressed", _card_style(Color(0.04, 0.05, 0.09), Color(0.14, 0.16, 0.22)))
				btn.add_theme_stylebox_override("focus",   _card_style(Color(0.05, 0.06, 0.10), Color(0.14, 0.16, 0.22)))
				btn.text = "?"
				btn.add_theme_font_size_override("font_size", 30)
				btn.add_theme_color_override("font_color",       Color(0.22, 0.24, 0.32))
				btn.add_theme_color_override("font_hover_color", Color(0.35, 0.37, 0.45))

			PartState.SEEN:
				# Silhouette — rarity border visible, rarity icon shown, no name
				btn.add_theme_stylebox_override("normal",  _card_style(Color(0.06, 0.08, 0.14), rcol.darkened(0.55)))
				btn.add_theme_stylebox_override("hover",   _card_style(Color(0.09, 0.12, 0.20), rcol.darkened(0.35)))
				btn.add_theme_stylebox_override("pressed", _card_style(Color(0.04, 0.06, 0.11), rcol.darkened(0.60)))
				btn.add_theme_stylebox_override("focus",   _card_style(Color(0.06, 0.08, 0.14), rcol.darkened(0.55)))
				btn.text = RARITY_ICON.get(part.rarity, "◆")
				btn.add_theme_font_size_override("font_size", 26)
				btn.add_theme_color_override("font_color",       rcol.darkened(0.30))
				btn.add_theme_color_override("font_hover_color", rcol.darkened(0.10))

			PartState.UNLOCKED:
				# Full card — bright rarity border, icon + short name
				btn.add_theme_stylebox_override("normal",  _card_style(Color(0.06, 0.12, 0.22), rcol.darkened(0.05)))
				btn.add_theme_stylebox_override("hover",   _card_style(Color(0.10, 0.17, 0.30), rcol.lightened(0.15)))
				btn.add_theme_stylebox_override("pressed", _card_style(Color(0.04, 0.09, 0.17), rcol.darkened(0.15)))
				btn.add_theme_stylebox_override("focus",   _card_style(Color(0.06, 0.12, 0.22), rcol.darkened(0.05)))
				var short = part.name if part.name.length() <= 9 else part.name.substr(0, 8) + "…"
				btn.text = "%s\n%s" % [RARITY_ICON.get(part.rarity, "◆"), short]
				btn.add_theme_font_size_override("font_size", 11)
				btn.add_theme_color_override("font_color",       rcol)
				btn.add_theme_color_override("font_hover_color", Color.WHITE)

		btn.pressed.connect(func(): _show_detail(part))
		container.add_child(btn)

func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	return s

# ── Detail panel ──────────────────────────────────────────────────────────────
func _show_detail(part: WeaponPart):
	_selected_part  = part
	_selected_state = _get_state(part)

	var rcol = RARITY_COL.get(part.rarity, Color.GRAY)
	var dn   = $VBox/ContentRow/DetailPanel/DetailVBox/DetailName
	var dd   = $VBox/ContentRow/DetailPanel/DetailVBox/DetailDesc
	var ds   = $VBox/ContentRow/DetailPanel/DetailVBox/DetailStatus
	var ub   = $VBox/ContentRow/DetailPanel/DetailVBox/DetailUnlockBtn

	match _selected_state:
		PartState.UNKNOWN:
			dn.text = "???"
			dn.add_theme_color_override("font_color", Color(0.32, 0.34, 0.42))
			dd.text = "Find this chip during a run to reveal more."
			dd.add_theme_color_override("font_color", Color(0.38, 0.40, 0.50))
			ds.text = "◆  UNDISCOVERED"
			ds.add_theme_color_override("font_color", Color(0.28, 0.30, 0.38))
			ds.add_theme_font_size_override("font_size", 14)
			ub.visible = false

		PartState.SEEN:
			dn.text = "???   %s" % RARITY_ICON.get(part.rarity, "")
			dn.add_theme_color_override("font_color", rcol.darkened(0.20))
			dd.text = "You've encountered this chip in a run.\nUnlock it to reveal its full abilities."
			dd.add_theme_color_override("font_color", Color(0.62, 0.72, 0.85))
			ds.text = "👁  SEEN   ·   %s   ·   %dg to unlock" % [RARITY_NAME.get(part.rarity, "?"), part.cost]
			ds.add_theme_color_override("font_color", rcol.darkened(0.10))
			ds.add_theme_font_size_override("font_size", 14)
			ub.text    = "🔓  UNLOCK  —  %dg" % part.cost
			ub.visible = true

		PartState.UNLOCKED:
			dn.text = part.name
			dn.add_theme_color_override("font_color", rcol)
			dd.text = part.desc
			dd.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
			ds.text = "✅  UNLOCKED   ·   %s" % RARITY_NAME.get(part.rarity, "?")
			ds.add_theme_color_override("font_color", Color(0.30, 1.00, 0.52))
			ds.add_theme_font_size_override("font_size", 14)
			ub.visible = false

# ── Unlock ─────────────────────────────────────────────────────────────────────
func _unlock_selected():
	if _selected_part == null: return
	if _selected_state == PartState.UNLOCKED: return
	if GameManager.spend_lifetime_gold(_selected_part.cost):
		if _selected_part.id not in GameManager.unlocked_parts:
			GameManager.unlocked_parts.append(_selected_part.id)
		GameManager.save_meta()
		_update_label()
		_populate_grid()
		_show_detail(_selected_part)

# ── Styling ────────────────────────────────────────────────────────────────────
func _style():
	$VBox/GoldLabel.add_theme_font_size_override("font_size", 18)
	$VBox/GoldLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	# Title
	var title = Label.new()
	title.text = "📦  COLLECTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	$VBox.add_child(title)
	$VBox.move_child(title, 1)

	# Subtitle legend
	var legend = Label.new()
	legend.text = "◆ = unseen   ◈ / ★ = seen, locked   full name = unlocked"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color(0.42, 0.48, 0.58))
	$VBox.add_child(legend)
	$VBox.move_child(legend, 2)

	# Detail panel style
	var dp_style = StyleBoxFlat.new()
	dp_style.bg_color = Color(0.05, 0.07, 0.14)
	dp_style.border_color = Color(0.22, 0.50, 0.88)
	dp_style.set_border_width_all(2)
	dp_style.set_corner_radius_all(8)
	dp_style.content_margin_left   = 20
	dp_style.content_margin_right  = 20
	dp_style.content_margin_top    = 16
	dp_style.content_margin_bottom = 16
	$VBox/ContentRow/DetailPanel.add_theme_stylebox_override("panel", dp_style)

	# Detail labels
	$VBox/ContentRow/DetailPanel/DetailVBox/DetailName.add_theme_font_size_override("font_size", 22)
	$VBox/ContentRow/DetailPanel/DetailVBox/DetailDesc.add_theme_font_size_override("font_size", 15)
	$VBox/ContentRow/DetailPanel/DetailVBox/DetailDesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	sn.bg_color = bg; sn.border_color = border
	sn.set_border_width_all(2); sn.set_corner_radius_all(6)
	sn.content_margin_left = 18; sn.content_margin_right = 18
	sn.content_margin_top = 10;  sn.content_margin_bottom = 10
	var sh = sn.duplicate()
	sh.bg_color = bg.lightened(0.15); sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
