extends Control

var reroll_cost: int = 15

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
	$ColorRect.color = Color(0.03, 0.05, 0.10)
	$BG.visible = false

	# Expand VBox
	var vb = $VBox
	vb.set_anchor_and_offset(SIDE_LEFT, 0.5, -500)
	vb.set_anchor_and_offset(SIDE_RIGHT, 0.5, 500)
	vb.set_anchor_and_offset(SIDE_TOP, 0.5, -300)
	vb.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 300)
	vb.add_theme_constant_override("separation", 18)

	# GoldLabel
	var gl = $VBox/GoldLabel
	gl.add_theme_font_size_override("font_size", 22)
	gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# RerollButton
	var rb = $VBox/RerollButton
	rb.custom_minimum_size = Vector2(0, 46)
	rb.add_theme_font_size_override("font_size", 15)
	_apply_btn(rb, Color(0.07, 0.11, 0.22), Color(0.22, 0.50, 0.88), Color(0.55, 0.80, 1.0))

	# ContinueButton
	var cb = $VBox/ContinueButton
	cb.text = "▶  Continue →  Floor %d" % (GameManager.floor_number + 1)
	cb.custom_minimum_size = Vector2(0, 46)
	cb.add_theme_font_size_override("font_size", 15)
	_apply_btn(cb, Color(0.05, 0.16, 0.10), Color(0.18, 0.72, 0.38), Color(0.38, 1.0, 0.52))

	# MainMenuButton
	var mb = $VBox/MainMenuButton
	mb.text = "🏠  Main Menu"
	mb.custom_minimum_size = Vector2(0, 46)
	mb.add_theme_font_size_override("font_size", 15)
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

func _update_gold_label():
	$VBox/GoldLabel.text = "Floor %d Complete!   💰 Gold: %dg" % [GameManager.floor_number, GameManager.gold]
	$VBox/RerollButton.text = "🔄 Reroll (%dg)" % reroll_cost

func _populate():
	for c in $VBox/ItemRow.get_children():
		c.queue_free()
	_add_potion("💊 Small Potion", "Restore 30 HP", 10, 30)
	_add_potion("💉 Large Potion", "Restore 80 HP", 25, 80)
	for item in ItemDatabase.get_random_items(4):
		var cost = {"common":10, "uncommon":25, "rare":45}.get(item.get("rarity","common"), 15)
		var rarity = item.get("rarity", "common")
		var palettes = {
			"common":   {"bg": Color(0.10, 0.12, 0.18), "border": Color(0.38, 0.50, 0.62), "text": Color(0.82, 0.88, 1.0),  "badge": "⬜ COMMON"},
			"uncommon": {"bg": Color(0.06, 0.12, 0.24), "border": Color(0.15, 0.55, 1.00), "text": Color(0.55, 0.88, 1.0),  "badge": "🔷 UNCOMMON"},
			"rare":     {"bg": Color(0.16, 0.08, 0.04), "border": Color(1.00, 0.72, 0.10), "text": Color(1.00, 0.88, 0.40), "badge": "🌟 RARE"},
		}
		var palette = palettes.get(rarity, palettes["common"])
		var btn = Button.new()
		btn.text = "%s\n%s\n%s\n💰 %dg" % [palette["badge"], item.name, item.desc, cost]
		btn.custom_minimum_size = Vector2(240, 130)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.mouse_entered.connect(func(): _play_hover())
		btn.pressed.connect(func(): _buy(item, cost, btn))
		var sn = StyleBoxFlat.new()
		sn.bg_color = palette["bg"]
		sn.border_color = palette["border"]
		sn.set_border_width_all(2)
		sn.set_corner_radius_all(6)
		sn.content_margin_left = 14; sn.content_margin_right = 14
		sn.content_margin_top = 10; sn.content_margin_bottom = 10
		var sh = sn.duplicate()
		sh.bg_color = palette["bg"].lightened(0.15)
		sh.border_color = palette["border"].lightened(0.25)
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_stylebox_override("focus", sn)
		btn.add_theme_color_override("font_color", palette["text"])
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		$VBox/ItemRow.add_child(btn)

func _add_potion(label: String, desc: String, cost: int, heal_amount: int):
	var btn = Button.new()
	btn.text = "%s\n%s\n💰 %dg" % [label, desc, cost]
	btn.custom_minimum_size = Vector2(240, 120)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_entered.connect(func(): _play_hover())
	btn.pressed.connect(func(): _buy_potion(heal_amount, cost, btn))
	var bg = Color(0.05, 0.14, 0.08)
	var border = Color(0.18, 0.65, 0.35)
	var text_color = Color(0.45, 1.0, 0.58)
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
	$VBox/ItemRow.add_child(btn)

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
	SceneLoader.goto("res://scenes/main_menu.tscn")

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
