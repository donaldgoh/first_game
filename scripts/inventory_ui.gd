extends CanvasLayer

# ═══════════════════════════════════════════════════════════════════════════════
# InventoryUI  —  modular weapon chip inventory
# Press I to open / close.
# ═══════════════════════════════════════════════════════════════════════════════

const EQUIP_SLOTS = 3
const PANEL_W     = 660
const PANEL_H     = 530
const SLOT_SIZE   = 150
const CHIP_SIZE   = 110

# Rarity int keys: COMMON=0, UNCOMMON=1, RARE=2  (matches WeaponPart.Rarity enum)
const RARITY_COL: Dictionary = {
	0: Color(0.55, 0.55, 0.55),
	1: Color(0.15, 0.60, 1.00),
	2: Color(1.00, 0.65, 0.05),
}
const RARITY_NAME: Dictionary = {
	0: "common",
	1: "uncommon",
	2: "rare",
}

var _chip_tex: Dictionary = {}

var _slots_row:   HBoxContainer  = null
var _inv_flow:    HFlowContainer = null
var _stats_label: Label          = null

# ── Tooltip nodes ──────────────────────────────────────────────────────────────
var _tooltip:        PanelContainer = null
var _tt_rarity:      Label          = null
var _tt_name:        Label          = null
var _tt_desc:        Label          = null
var _tt_stats:       RichTextLabel  = null
var _tt_stat_sep:    HSeparator     = null

func _ready():
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_load_textures()
	_build_ui()
	_build_tooltip()
	GameManager.inventory_changed.connect(_refresh)

func _load_textures():
	for rarity in ["common", "uncommon", "rare"]:
		var path = "res://images/%s_chip.png" % rarity
		if ResourceLoader.exists(path):
			_chip_tex[rarity] = load(path)

# ── Build the static panel layout ─────────────────────────────────────────────
func _build_ui():
	var bg = ColorRect.new()
	bg.color        = Color(0, 0, 0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel = PanelContainer.new()
	panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -PANEL_W / 2.0
	panel.offset_right  =  PANEL_W / 2.0
	panel.offset_top    = -PANEL_H / 2.0
	panel.offset_bottom =  PANEL_H / 2.0

	var style = StyleBoxFlat.new()
	style.bg_color                  = Color(0.06, 0.07, 0.12, 0.97)
	style.border_color              = Color(0.30, 0.35, 0.55)
	style.border_width_top          = 2
	style.border_width_bottom       = 2
	style.border_width_left         = 2
	style.border_width_right        = 2
	style.corner_radius_top_left    = 6
	style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_row)

	var title_lbl = Label.new()
	title_lbl.text = "  WEAPON INVENTORY"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 1.00))
	title_row.add_child(title_lbl)

	var hint = Label.new()
	hint.text = "   [I] Close  [Esc] Close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.50, 0.65))
	title_row.add_child(hint)

	_add_separator(vbox)

	# Equipped section
	var eq_lbl = Label.new()
	eq_lbl.text = "EQUIPPED  ( click slot to unequip )"
	eq_lbl.add_theme_font_size_override("font_size", 14)
	eq_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 1.00))
	vbox.add_child(eq_lbl)

	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 12)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_slots_row)

	_add_separator(vbox)

	# Inventory section
	var inv_lbl = Label.new()
	inv_lbl.text = "COLLECTED  ( click chip to equip )"
	inv_lbl.add_theme_font_size_override("font_size", 14)
	inv_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 1.00))
	vbox.add_child(inv_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size       = Vector2(PANEL_W - 24, CHIP_SIZE + 16)
	scroll.horizontal_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode     = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_inv_flow = HFlowContainer.new()
	_inv_flow.add_theme_constant_override("h_separation", 10)
	_inv_flow.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_inv_flow)

	_add_separator(vbox)

	# Combined stats section
	var stats_hdr = Label.new()
	stats_hdr.text = "COMBINED STATS"
	stats_hdr.add_theme_font_size_override("font_size", 14)
	stats_hdr.add_theme_color_override("font_color", Color(0.65, 0.75, 1.00))
	vbox.add_child(stats_hdr)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.80, 0.90, 0.80))
	_stats_label.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(PANEL_W - 24, 40)
	vbox.add_child(_stats_label)

func _add_separator(parent: Control):
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.28, 0.45))
	parent.add_child(sep)

# ── Tooltip construction ───────────────────────────────────────────────────────
func _build_tooltip():
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_tooltip.custom_minimum_size  = Vector2(260, 0)
	_tooltip.visible              = false
	_tooltip.z_index              = 50

	var style = StyleBoxFlat.new()
	style.bg_color                   = Color(0.05, 0.06, 0.11, 0.97)
	style.border_color               = Color(0.35, 0.40, 0.60)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left        = 12
	style.content_margin_right       = 12
	style.content_margin_top         = 10
	style.content_margin_bottom      = 10
	_tooltip.add_theme_stylebox_override("panel", style)
	add_child(_tooltip)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(vbox)

	# Rarity badge
	_tt_rarity = Label.new()
	_tt_rarity.add_theme_font_size_override("font_size", 10)
	_tt_rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tt_rarity)

	# Part name
	_tt_name = Label.new()
	_tt_name.add_theme_font_size_override("font_size", 16)
	_tt_name.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_tt_name.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	_tt_name.custom_minimum_size = Vector2(236, 0)
	_tt_name.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tt_name)

	# Separator before desc
	var sep1 = HSeparator.new()
	sep1.add_theme_color_override("color", Color(0.22, 0.25, 0.40))
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep1)

	# Description
	_tt_desc = Label.new()
	_tt_desc.add_theme_font_size_override("font_size", 12)
	_tt_desc.add_theme_color_override("font_color", Color(0.65, 0.68, 0.82))
	_tt_desc.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_tt_desc.custom_minimum_size  = Vector2(236, 0)
	_tt_desc.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tt_desc)

	# Separator before stats (hidden when no stats)
	_tt_stat_sep = HSeparator.new()
	_tt_stat_sep.add_theme_color_override("color", Color(0.22, 0.25, 0.40))
	_tt_stat_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_stat_sep.visible = false
	vbox.add_child(_tt_stat_sep)

	# Stats (RichTextLabel for per-line colouring)
	_tt_stats = RichTextLabel.new()
	_tt_stats.bbcode_enabled       = true
	_tt_stats.fit_content          = true
	_tt_stats.scroll_active        = false
	_tt_stats.custom_minimum_size  = Vector2(236, 0)
	_tt_stats.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_tt_stats.add_theme_font_size_override("normal_font_size", 12)
	_tt_stats.visible              = false
	vbox.add_child(_tt_stats)

# ── Show / hide tooltip ────────────────────────────────────────────────────────
func _show_tooltip(part: WeaponPart):
	var rcol  = RARITY_COL.get(part.rarity, Color.GRAY)
	var rname = RARITY_NAME.get(part.rarity, "common").to_upper()

	# Update rarity badge colour
	_tt_rarity.text = rname
	_tt_rarity.add_theme_color_override("font_color", rcol)

	# Name
	_tt_name.text = part.name

	# Update tooltip border to match rarity colour
	var style = StyleBoxFlat.new()
	style.bg_color              = Color(rcol.r * 0.10, rcol.g * 0.10, rcol.b * 0.10, 0.97)
	style.border_color          = rcol.darkened(0.10)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 10
	style.content_margin_bottom = 10
	_tooltip.add_theme_stylebox_override("panel", style)

	# Description
	_tt_desc.text = part.desc

	# Stats
	var stat_bbcode = _build_stat_bbcode(part)
	if stat_bbcode.is_empty():
		_tt_stat_sep.visible = false
		_tt_stats.visible    = false
	else:
		_tt_stat_sep.visible  = true
		_tt_stats.visible     = true
		_tt_stats.text        = stat_bbcode

	_tooltip.visible = true
	# Force a size recalculation so position clamping works immediately
	_tooltip.reset_size()

func _hide_tooltip():
	_tooltip.visible = false

# ── Cursor-following in _process ──────────────────────────────────────────────
func _process(_delta):
	if not _tooltip or not _tooltip.visible:
		return
	var mp   = get_viewport().get_mouse_position()
	var vsz  = get_viewport().get_visible_rect().size
	var tsz  = _tooltip.size
	const OFFSET_X = 18
	const OFFSET_Y = 12
	var tx = mp.x + OFFSET_X
	var ty = mp.y + OFFSET_Y
	# Flip left if it would overflow the right edge
	if tx + tsz.x > vsz.x - 8:
		tx = mp.x - tsz.x - OFFSET_X
	# Flip up if it would overflow the bottom edge
	if ty + tsz.y > vsz.y - 8:
		ty = mp.y - tsz.y - OFFSET_Y
	_tooltip.position = Vector2(tx, ty)

# ── Stat bbcode builder ────────────────────────────────────────────────────────
# Returns a BBCode string with one stat per line, colour-coded:
#   green  = beneficial multiplier or flat bonus
#   red    = detrimental multiplier
#   cyan   = special mechanic / flag
func _build_stat_bbcode(part: WeaponPart) -> String:
	var lines: Array = []

	# Multipliers
	if not is_equal_approx(part.damage_mult, 1.0):
		lines.append(_mult_line("Damage", part.damage_mult))
	if not is_equal_approx(part.fire_rate_mult, 1.0):
		lines.append(_mult_line("Fire Rate", part.fire_rate_mult))
	if not is_equal_approx(part.bullet_speed_mult, 1.0):
		lines.append(_mult_line("Bullet Speed", part.bullet_speed_mult))
	if not is_equal_approx(part.bullet_range_mult, 1.0):
		lines.append(_mult_line("Bullet Range", part.bullet_range_mult))

	# Flat bonuses
	if part.pierce_bonus > 0:
		lines.append("[color=#88ccff]+ Pierce  +%d[/color]" % part.pierce_bonus)
	if part.bounce_bonus > 0:
		lines.append("[color=#88ccff]+ Bounce  +%d wall%s[/color]" % [
			part.bounce_bonus, "s" if part.bounce_bonus > 1 else ""])

	# Spread
	if part.spread_count > 1:
		lines.append("[color=#88ccff]+ Spread  %d pellets  (%.0f°)[/color]" % [
			part.spread_count, part.spread_angle])

	# Special flags
	if part.homing:
		lines.append("[color=#ffe066]★ Homing  (strength %.1f)[/color]" % part.homing_strength)
	if part.explode_radius > 0.0 and not part.delayed_detonate:
		lines.append("[color=#ff9944]★ Explosion  radius %.0f[/color]" % part.explode_radius)
	if part.chain_count > 0:
		lines.append("[color=#44ddff]★ Chain  ×%d jumps[/color]" % part.chain_count)
	if part.split_on_hit:
		lines.append("[color=#44ddff]★ Split into 3 shards on final pierce[/color]")
	if part.is_laser:
		lines.append("[color=#ff4488]★ Laser Beam  (instant line)[/color]")
	if part.sky_strike:
		lines.append("[color=#bb88ff]★ Sky Strike  (bullets fall from above)[/color]")
	if part.delayed_detonate:
		lines.append("[color=#ff9944]★ Cluster Bomb  — slow + explodes at range end  (r %.0f, ×2 dmg)[/color]" \
			% part.explode_radius)

	return "\n".join(lines)

# Helper: format a multiplier stat line with green (≥1) or red (<1) colour
func _mult_line(label: String, value: float) -> String:
	var mult_sign := "×"
	var col    = "#66ee88" if value >= 1.0 else "#ff6655"
	var prefix = "▲" if value >= 1.0 else "▼"
	return "[color=%s]%s %s  %s%.2f[/color]" % [col, prefix, label, mult_sign, value]

# ── Refresh ───────────────────────────────────────────────────────────────────
func _refresh():
	if not visible:
		return
	_hide_tooltip()
	_rebuild_slots()
	_rebuild_inventory()
	_rebuild_stats()

# ── Equipped slot cards ────────────────────────────────────────────────────────
func _rebuild_slots():
	for c in _slots_row.get_children():
		c.queue_free()
	for slot in EQUIP_SLOTS:
		var id   = GameManager.equipped_parts[slot]
		var part = WeaponPartsDatabase.get_by_id(id) if id != "" else null
		_slots_row.add_child(_make_slot_card(slot, part))

func _make_slot_card(slot: int, part) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.focus_mode          = Control.FOCUS_NONE

	var sn = StyleBoxFlat.new()
	sn.corner_radius_top_left     = 4
	sn.corner_radius_top_right    = 4
	sn.corner_radius_bottom_left  = 4
	sn.corner_radius_bottom_right = 4

	if part != null:
		var rcol              = RARITY_COL.get(part.rarity, Color.GRAY)
		sn.bg_color           = Color(rcol.r * 0.18, rcol.g * 0.18, rcol.b * 0.18, 1.0)
		sn.border_color       = rcol
		sn.border_width_top   = 2; sn.border_width_bottom = 2
		sn.border_width_left  = 2; sn.border_width_right  = 2
	else:
		sn.bg_color           = Color(0.10, 0.11, 0.18, 1.0)
		sn.border_color       = Color(0.25, 0.28, 0.42)
		sn.border_width_top   = 1; sn.border_width_bottom = 1
		sn.border_width_left  = 1; sn.border_width_right  = 1

	var sh             = sn.duplicate()
	sh.border_color    = Color(0.80, 0.85, 1.00) if part != null else Color(0.40, 0.45, 0.70)
	sh.border_width_top = 2; sh.border_width_bottom = 2
	sh.border_width_left = 2; sh.border_width_right  = 2

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	btn.add_child(vbox)

	if part != null:
		var rkey = RARITY_NAME.get(part.rarity, "common")
		if _chip_tex.has(rkey):
			var tex                    = TextureRect.new()
			tex.texture                = _chip_tex[rkey]
			tex.custom_minimum_size    = Vector2(36, 36)
			tex.expand_mode            = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode           = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture_filter         = CanvasItem.TEXTURE_FILTER_NEAREST
			tex.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
			vbox.add_child(tex)

		var nl = Label.new()
		nl.text                     = part.name
		nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_color_override("font_color", Color.WHITE)
		nl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode            = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size      = Vector2(SLOT_SIZE - 12, 0)
		vbox.add_child(nl)

		var rl = Label.new()
		rl.text                 = "click to remove"
		rl.add_theme_font_size_override("font_size", 10)
		rl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.75))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rl)

		# Tooltip connections (capture part in closure)
		var cap_part = part
		btn.mouse_entered.connect(func(): _show_tooltip(cap_part))
		btn.mouse_exited.connect(func(): _hide_tooltip())
	else:
		var sl = Label.new()
		sl.text                 = "Slot %d" % (slot + 1)
		sl.add_theme_font_size_override("font_size", 14)
		sl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.60))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sl)

		var el = Label.new()
		el.text                 = "empty"
		el.add_theme_font_size_override("font_size", 12)
		el.add_theme_color_override("font_color", Color(0.28, 0.32, 0.50))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(el)

	var cap = slot
	btn.pressed.connect(func():
		if GameManager.equipped_parts[cap] != "":
			GameManager.unequip_slot(cap)
		_refresh_weapon()
	)
	return btn

# ── Inventory chip cards ───────────────────────────────────────────────────────
func _rebuild_inventory():
	for c in _inv_flow.get_children():
		c.queue_free()
	if GameManager.inventory_parts.is_empty():
		var lbl = Label.new()
		lbl.text = "No chips collected yet.  Find them in treasure rooms!"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.65))
		_inv_flow.add_child(lbl)
		return
	for i in GameManager.inventory_parts.size():
		var id   = GameManager.inventory_parts[i]
		var part = WeaponPartsDatabase.get_by_id(id)
		if part == null:
			continue
		_inv_flow.add_child(_make_chip_card(i, part))

func _make_chip_card(inv_index: int, part) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
	btn.focus_mode          = Control.FOCUS_NONE

	var rcol = RARITY_COL.get(part.rarity, Color.GRAY)

	var sn = StyleBoxFlat.new()
	sn.bg_color                   = Color(rcol.r * 0.15, rcol.g * 0.15, rcol.b * 0.15, 1.0)
	sn.border_color               = rcol
	sn.border_width_top           = 2; sn.border_width_bottom = 2
	sn.border_width_left          = 2; sn.border_width_right  = 2
	sn.corner_radius_top_left     = 4; sn.corner_radius_top_right    = 4
	sn.corner_radius_bottom_left  = 4; sn.corner_radius_bottom_right = 4

	var sh           = sn.duplicate()
	sh.bg_color      = Color(rcol.r * 0.30, rcol.g * 0.30, rcol.b * 0.30, 1.0)
	sh.border_color  = Color.WHITE

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	btn.add_child(vbox)

	var rkey = RARITY_NAME.get(part.rarity, "common")
	if _chip_tex.has(rkey):
		var tex                   = TextureRect.new()
		tex.texture               = _chip_tex[rkey]
		tex.custom_minimum_size   = Vector2(30, 30)
		tex.expand_mode           = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter        = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(tex)

	var nl = Label.new()
	nl.text                 = part.name
	nl.add_theme_font_size_override("font_size", 12)
	nl.add_theme_color_override("font_color", Color.WHITE)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size  = Vector2(CHIP_SIZE - 10, 0)
	vbox.add_child(nl)

	var rl = Label.new()
	rl.text                 = rkey.to_upper()
	rl.add_theme_font_size_override("font_size", 10)
	rl.add_theme_color_override("font_color", rcol)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rl)

	# Tooltip connections
	var cap_part = part
	btn.mouse_entered.connect(func(): _show_tooltip(cap_part))
	btn.mouse_exited.connect(func(): _hide_tooltip())

	var cap = inv_index
	btn.pressed.connect(func():
		var target_slot = -1
		for s in EQUIP_SLOTS:
			if GameManager.equipped_parts[s] == "":
				target_slot = s
				break
		if target_slot == -1:
			target_slot = 0
		GameManager.equip_part(cap, target_slot)
		_refresh_weapon()
	)
	return btn

# ── Combined stats ─────────────────────────────────────────────────────────────
func _rebuild_stats():
	var c = GameManager.get_combined_part()
	if c == null:
		_stats_label.text = "No chips equipped.  Equip chips above to combine their effects."
		return

	var lines: Array = []
	if c.damage_mult != 1.0:
		lines.append("Damage x%.2f" % c.damage_mult)
	if c.fire_rate_mult != 1.0:
		lines.append("Fire Rate x%.2f" % c.fire_rate_mult)
	if c.bullet_speed_mult != 1.0:
		lines.append("Speed x%.2f" % c.bullet_speed_mult)
	if c.bullet_range_mult != 1.0:
		lines.append("Range x%.2f" % c.bullet_range_mult)
	if c.pierce_bonus > 0:
		lines.append("Pierce +%d" % c.pierce_bonus)
	if c.bounce_bonus > 0:
		lines.append("Bounce +%d" % c.bounce_bonus)
	if c.spread_count > 1:
		lines.append("Spread %d pellets" % c.spread_count)
	if c.homing:
		lines.append("Homing")
	if c.explode_radius > 0:
		lines.append("Explode r=%.0f" % c.explode_radius)

	_stats_label.text = "  |  ".join(lines) if lines.size() > 0 else "No bonus stats."

# ── Weapon reload helper ───────────────────────────────────────────────────────
func _refresh_weapon():
	var pl = get_tree().get_first_node_in_group("player")
	if pl:
		var wa = pl.get_node_or_null("WeaponAuto")
		if wa and wa.has_method("reload_part"):
			wa.reload_part()

# ── Toggle ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or (visible and event.keycode == KEY_ESCAPE):
			_toggle()
			get_viewport().set_input_as_handled()

func _toggle():
	visible                    = not visible
	GameManager.inventory_open = visible
	if visible:
		_refresh()
	else:
		_hide_tooltip()
