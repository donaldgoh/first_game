extends Control

var reroll_cost: int = 15
var _shop_slots: Array = []   # [{item, cost, btn}]

func _ready():
	_style_shop()
	_update_gold_label()
	$VBox/RerollButton.pressed.connect(_reroll)
	$VBox/ContinueButton.pressed.connect(_continue)
	$VBox/MainMenuButton.pressed.connect(_go_main_menu)
	$VBox/RerollButton.mouse_entered.connect(func(): _play_hover())
	$VBox/ContinueButton.mouse_entered.connect(func(): _play_hover())
	$VBox/MainMenuButton.mouse_entered.connect(func(): _play_hover())
	_populate()

func _style_shop():
	$ColorRect.color = Color(0.04, 0.06, 0.12)
	$BG.visible = false

	# Panel background card
	var panel = ColorRect.new()
	panel.name = "ShopPanel"
	panel.color = Color(0.06, 0.08, 0.16, 0.97)
	panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -520)
	panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  520)
	panel.set_anchor_and_offset(SIDE_TOP,    0.5, -350)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  350)
	add_child(panel)
	move_child(panel, 1)

	# VBox
	var vb = $VBox
	vb.set_anchor_and_offset(SIDE_LEFT,   0.5, -480)
	vb.set_anchor_and_offset(SIDE_RIGHT,  0.5,  480)
	vb.set_anchor_and_offset(SIDE_TOP,    0.5, -330)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  330)
	vb.add_theme_constant_override("separation", 14)

	# Title label — insert at top of VBox
	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "— UPGRADE STATION —"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)
	vb.move_child(title_lbl, 0)

	# GoldLabel
	var gl = $VBox/GoldLabel
	gl.add_theme_font_size_override("font_size", 20)
	gl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# RerollButton
	var rb = $VBox/RerollButton
	rb.custom_minimum_size = Vector2(0, 44)
	rb.add_theme_font_size_override("font_size", 15)
	_apply_btn(rb, Color(0.06, 0.10, 0.22), Color(0.22, 0.45, 0.85), Color(0.55, 0.80, 1.0))

	# ContinueButton
	var cb = $VBox/ContinueButton
	cb.text = "▶  Continue  →  Floor %d" % (GameManager.floor_number + 1)
	cb.custom_minimum_size = Vector2(0, 50)
	cb.add_theme_font_size_override("font_size", 16)
	_apply_btn(cb, Color(0.04, 0.18, 0.10), Color(0.15, 0.75, 0.38), Color(0.38, 1.0, 0.55))

	# MainMenuButton
	var mb = $VBox/MainMenuButton
	mb.text = "🏠  Exit to Hub"
	mb.custom_minimum_size = Vector2(0, 40)
	mb.add_theme_font_size_override("font_size", 14)
	_apply_btn(mb, Color(0.10, 0.05, 0.06), Color(0.40, 0.12, 0.14), Color(0.75, 0.38, 0.40))

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

func _update_gold_label():
	$VBox/GoldLabel.text = "Floor %d Complete   ·   💰  %d g" % [GameManager.floor_number, GameManager.gold]
	$VBox/RerollButton.text = "🔄  Reroll  (%d g)" % reroll_cost

func _populate():
	_shop_slots.clear()
	var old_buy_all = $VBox.get_node_or_null("BuyAllButton")
	if old_buy_all: old_buy_all.free()
	for c in $VBox/ItemRow.get_children():
		c.queue_free()
	for item in ItemDatabase.get_random_items(3):
		var cost = {"common":10, "uncommon":25, "rare":45}.get(item.get("rarity","common"), 15)
		var rarity = item.get("rarity", "common")
		var palettes = {
			"common":   {"bg": Color(0.10, 0.12, 0.18), "border": Color(0.38, 0.50, 0.62), "text": Color(0.82, 0.88, 1.0),  "badge": "⬜ COMMON"},
			"uncommon": {"bg": Color(0.06, 0.12, 0.24), "border": Color(0.15, 0.55, 1.00), "text": Color(0.55, 0.88, 1.0),  "badge": "🔷 UNCOMMON"},
			"rare":     {"bg": Color(0.16, 0.08, 0.04), "border": Color(1.00, 0.72, 0.10), "text": Color(1.00, 0.88, 0.40), "badge": "🌟 RARE"},
		}
		var palette = palettes.get(rarity, palettes["common"])
		var btn = Button.new()
		btn.text = "%s\n%s\n%s\n─────\n💰  %d g" % [palette["badge"], item.name, item.desc, cost]
		btn.custom_minimum_size = Vector2(200, 150)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		btn.mouse_entered.connect(func(): _play_hover())
		btn.pressed.connect(func(): _buy(item, cost, btn))
		_shop_slots.append({"item": item, "cost": cost, "btn": btn})
		var sn = StyleBoxFlat.new()
		sn.bg_color = palette["bg"]
		sn.border_color = palette["border"]
		sn.set_border_width_all(2)
		sn.set_corner_radius_all(8)
		sn.border_width_top = 4
		sn.content_margin_left = 16; sn.content_margin_right = 16
		sn.content_margin_top = 14; sn.content_margin_bottom = 14
		var sh = sn.duplicate()
		sh.bg_color = palette["bg"].lightened(0.18)
		sh.border_color = palette["border"].lightened(0.30)
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_stylebox_override("focus", sn)
		btn.add_theme_color_override("font_color", palette["text"])
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		$VBox/ItemRow.add_child(btn)

	# Buy All button
	var total_cost = _shop_slots.reduce(func(acc, s): return acc + s["cost"], 0)
	var buy_all_btn = Button.new()
	buy_all_btn.name = "BuyAllButton"
	buy_all_btn.text = "🛒  Buy All  (%dg)" % total_cost
	buy_all_btn.custom_minimum_size = Vector2(280, 48)
	buy_all_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_all_btn.add_theme_font_size_override("font_size", 15)
	buy_all_btn.mouse_entered.connect(func(): _play_hover())
	buy_all_btn.pressed.connect(_buy_all)
	_apply_btn(buy_all_btn, Color(0.10, 0.08, 0.18), Color(0.55, 0.30, 0.90), Color(0.85, 0.70, 1.0))
	var item_row_idx = $VBox/ItemRow.get_index()
	$VBox.add_child(buy_all_btn)
	$VBox.move_child(buy_all_btn, item_row_idx + 1)

func _add_potion(label: String, desc: String, cost: int, heal_amount: int):
	var btn = Button.new()
	btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost]
	btn.custom_minimum_size = Vector2(240, 120)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_entered.connect(func(): _play_hover())
	btn.pressed.connect(func(): _buy_potion(heal_amount, cost, btn))
	_style_shop_btn(btn, Color(0.05, 0.14, 0.08), Color(0.18, 0.65, 0.35), Color(0.45, 1.0, 0.58))
	$VBox/ItemRow.add_child(btn)

func _add_heart(label: String, desc: String, cost: int):
	var btn = Button.new()
	btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost]
	btn.custom_minimum_size = Vector2(240, 120)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_entered.connect(func(): _play_hover())
	btn.pressed.connect(func():
		if GameManager.spend_gold(cost):
			GameManager.p_max_health += 1
			GameManager.p_current_health = min(GameManager.p_current_health + 1, GameManager.p_max_health)
			var pl = get_tree().get_first_node_in_group("player")
			if pl:
				pl.max_health = GameManager.p_max_health
				pl.current_health = GameManager.p_current_health
				pl.emit_signal("health_changed", pl.current_health, pl.max_health)
			btn.text = "✅ MAX HP UP!"
			btn.disabled = true
			_update_gold_label()
			_play_confirm()
		else:
			btn.text = "❌ Not enough gold!"
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(btn) and not btn.disabled:
				btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost])
	var bg = Color(0.14, 0.04, 0.06)
	var border = Color(0.85, 0.20, 0.25)
	var text_color = Color(1.0, 0.55, 0.58)
	_style_shop_btn(btn, bg, border, text_color)
	$VBox/ItemRow.add_child(btn)

func _add_key(label: String, desc: String, cost: int):
	var btn = Button.new()
	btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost]
	btn.custom_minimum_size = Vector2(240, 120)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_entered.connect(func(): _play_hover())
	btn.pressed.connect(func():
		if GameManager.spend_gold(cost):
			GameManager.add_key()
			btn.text = "✅ KEY ADDED!"
			btn.disabled = true
			_update_gold_label()
			_play_confirm()
		else:
			btn.text = "❌ Not enough gold!"
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(btn) and not btn.disabled:
				btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost])
	var bg = Color(0.12, 0.10, 0.02)
	var border = Color(0.90, 0.78, 0.15)
	var text_color = Color(1.0, 0.92, 0.40)
	_style_shop_btn(btn, bg, border, text_color)
	$VBox/ItemRow.add_child(btn)

func _style_shop_btn(btn: Button, bg: Color, border: Color, text_color: Color):
	var sn = StyleBoxFlat.new()
	sn.bg_color = bg
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(6)
	sn.content_margin_left = 14; sn.content_margin_right = 14
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

func _buy_potion(heal_amount: int, cost: int, btn: Button):
	if GameManager.spend_gold(cost):
		GameManager.p_current_health = min(
			GameManager.p_current_health + heal_amount,
			GameManager.p_max_health)
		btn.text = "✅ HEALED!\n+%d HP" % heal_amount
		btn.disabled = true
		_update_gold_label()
		_play_confirm()
	else:
		btn.text = "❌ Not enough gold!"
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(btn) and not btn.disabled:
			btn.text = "%s\nRestore %d HP\n💰 %dg" % [btn.name, heal_amount, cost]

func _buy(item, cost, btn):
	if GameManager.spend_gold(cost):
		var pl = get_tree().get_first_node_in_group("player")
		if pl: pl.apply_item(item)
		btn.text = "✅ BOUGHT!\n" + item.name
		btn.disabled = true
		_update_gold_label()
		_play_confirm()
	else:
		btn.text = "❌ Not enough gold!\n" + item.name
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(btn) and not btn.disabled:
			btn.text = "%s %s\n%s\n💰 %dg" % [
				{"common":"⚪","uncommon":"🔵","rare":"🟡"}.get(item.get("rarity","common"),"⚪"),
				item.name, item.desc, cost]

func _buy_all():
	var bought_any := false
	for slot in _shop_slots:
		var btn: Button = slot["btn"]
		if btn.disabled: continue
		if GameManager.spend_gold(slot["cost"]):
			var pl = get_tree().get_first_node_in_group("player")
			if pl: pl.apply_item(slot["item"])
			btn.text = "✅ BOUGHT!\n" + slot["item"].name
			btn.disabled = true
			bought_any = true
	if bought_any:
		_update_gold_label()
		_play_confirm()
	else:
		var buy_all_btn = $VBox.get_node_or_null("BuyAllButton")
		if buy_all_btn:
			var orig = buy_all_btn.text
			buy_all_btn.text = "❌ Not enough gold!"
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(buy_all_btn): buy_all_btn.text = orig

func _reroll():
	if GameManager.spend_gold(reroll_cost):
		reroll_cost += 5
		_populate()
		_update_gold_label()
		_play_confirm()

func _continue():
	_play_confirm()
	GameManager.floor_number += 1
	SceneLoader.goto("res://scenes/dungeon.tscn")

func _go_main_menu():
	_play_confirm()
	GameManager.reset_run()
	SceneLoader.goto("res://scenes/hub.tscn")

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
	snd.volume_db = -3
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
