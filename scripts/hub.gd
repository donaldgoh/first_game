extends Node2D
# ═══════════════════════════════════════════════════════════════════════════════
# HUB — walkable area between runs.
# Player spawns here from the main menu.  Walk through the north door to enter
# the dungeon.  Approach NPCs and press E to use them.
# Walls + obstacles use simple StaticBody2D + ColorRect blocks.
# ═══════════════════════════════════════════════════════════════════════════════

const ROOM_W  := 1920.0
const ROOM_H  := 1344.0
const WALL_T  :=   48.0
const DOOR_W  :=  128.0   # opening width in the north wall

const PlayerScene := preload("res://scenes/player.tscn")

# ── Palette ───────────────────────────────────────────────────────────────────
const C_FLOOR     := Color(0.14, 0.16, 0.21)
const C_FLOOR_ALT := Color(0.16, 0.18, 0.24)
const C_WALL      := Color(0.10, 0.11, 0.16)
const C_WALL_TOP  := Color(0.24, 0.26, 0.34)
const C_DOOR      := Color(0.55, 0.38, 0.12)   # warm wood colour for the door frame

# ── NPC definitions (Gate Keeper replaced by the actual door) ─────────────────
const NPCS := [
	{
		"name":   "Merchant",
		"desc":   "[E]  Open Collection",
		"color":  Color(0.20, 0.45, 0.90),
		"pos":    Vector2(580, 500),
		"action": "collection",
	},
	{
		"name":   "Blacksmith",
		"desc":   "[E]  Upgrade Stats",
		"color":  Color(0.75, 0.50, 0.15),
		"pos":    Vector2(1340, 500),
		"action": "blacksmith",
	},
]

# ── Blacksmith upgrade definitions ────────────────────────────────────────────
const UPGRADES := [
	{
		"id":    "hp",
		"icon":  "❤",
		"name":  "Max Health",
		"desc":  "+2 max health per level",
		"max":   5,
		"costs": [1, 1, 2, 2, 3],
	},
	{
		"id":    "damage",
		"icon":  "⚔",
		"name":  "Damage",
		"desc":  "+2 damage per level",
		"max":   5,
		"costs": [1, 1, 2, 2, 3],
	},
	{
		"id":    "speed",
		"icon":  "⚡",
		"name":  "Move Speed",
		"desc":  "+20 speed per level",
		"max":   5,
		"costs": [1, 1, 2, 2, 3],
	},
]

# ── Runtime ───────────────────────────────────────────────────────────────────
var _player      : Node2D    = null
var _prompt_lbl  : Label     = null
var _near_action : String    = ""
var _smith_layer : CanvasLayer = null   # blacksmith overlay
var _smith_open  : bool      = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false
	GameManager.p_current_health = GameManager.p_max_health
	_build_room()
	_build_door()
	_build_obstacles()
	_build_npcs()
	_spawn_player()
	_build_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _smith_open:
		_sfx_confirm()
		_close_blacksmith()
		return
	if event.is_action_pressed("interact"):
		if _smith_open:
			_sfx_confirm()
			_close_blacksmith()
		elif _near_action != "":
			_sfx_confirm()
			_go(_near_action)

# ── Room ──────────────────────────────────────────────────────────────────────
func _build_room() -> void:
	# Checkerboard floor
	var tile := 96.0
	var cols  := int(ROOM_W / tile) + 1
	var rows  := int(ROOM_H / tile) + 1
	for r in rows:
		for c in cols:
			var fl := ColorRect.new()
			fl.size     = Vector2(tile, tile)
			fl.position = Vector2(c * tile, r * tile)
			fl.color    = C_FLOOR if (r + c) % 2 == 0 else C_FLOOR_ALT
			fl.z_index  = -10
			fl.z_as_relative = false
			add_child(fl)

	# North wall — two pieces with a gap in the centre for the door
	var door_cx   := ROOM_W * 0.5
	var door_left := door_cx - DOOR_W * 0.5
	_wall(Vector2(0,          0), Vector2(door_left,            WALL_T))  # N-left
	_wall(Vector2(door_cx + DOOR_W * 0.5, 0),
		  Vector2(ROOM_W - (door_cx + DOOR_W * 0.5), WALL_T))            # N-right

	# South / West / East walls (solid)
	_wall(Vector2(0,               ROOM_H - WALL_T), Vector2(ROOM_W, WALL_T))
	_wall(Vector2(0,               WALL_T          ), Vector2(WALL_T, ROOM_H - WALL_T * 2))
	_wall(Vector2(ROOM_W - WALL_T, WALL_T          ), Vector2(WALL_T, ROOM_H - WALL_T * 2))

func _wall(pos: Vector2, sz: Vector2, col: Color = C_WALL) -> void:
	var vis := ColorRect.new()
	vis.color    = col
	vis.size     = sz
	vis.position = pos
	vis.z_index  = -9
	vis.z_as_relative = false
	add_child(vis)

	var edge := ColorRect.new()
	edge.color    = C_WALL_TOP
	edge.size     = Vector2(sz.x, 4)
	edge.position = pos
	edge.z_index  = -8
	edge.z_as_relative = false
	add_child(edge)

	var sb  := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask  = 0
	var cs  := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size    = sz
	cs.shape    = shp
	cs.position = sz * 0.5
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)

# ── Door ──────────────────────────────────────────────────────────────────────
func _build_door() -> void:
	var door_cx   := ROOM_W * 0.5
	var door_left := door_cx - DOOR_W * 0.5

	# Left post
	_door_post(Vector2(door_left - 16, 0), Vector2(16, WALL_T + 32))
	# Right post
	_door_post(Vector2(door_cx + DOOR_W * 0.5, 0), Vector2(16, WALL_T + 32))

	# Lintel (top bar across the gap)
	var lintel := ColorRect.new()
	lintel.color    = C_DOOR.darkened(0.25)
	lintel.size     = Vector2(DOOR_W + 32, 14)
	lintel.position = Vector2(door_left - 16, 0)
	lintel.z_index  = 1
	lintel.z_as_relative = false
	add_child(lintel)

	# Dungeon label above the door
	var lbl := Label.new()
	lbl.text = "DUNGEON"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.size     = Vector2(DOOR_W + 80, 22)
	lbl.position = Vector2(door_cx - (DOOR_W + 80) * 0.5, WALL_T + 36)
	lbl.z_index  = 5
	lbl.z_as_relative = false
	add_child(lbl)

	# Bouncing arrow pointing up toward the door
	var arrow := Label.new()
	arrow.text = "▲"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	arrow.size     = Vector2(DOOR_W, 24)
	arrow.position = Vector2(door_cx - DOOR_W * 0.5, WALL_T + 62)
	arrow.z_index  = 5
	arrow.z_as_relative = false
	add_child(arrow)
	var tw := arrow.create_tween()
	tw.set_loops()
	tw.tween_property(arrow, "position:y", arrow.position.y - 8.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position:y", arrow.position.y,       0.5).set_trans(Tween.TRANS_SINE)

	# Trigger — player walks through the gap to enter the dungeon
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	area.position        = Vector2(door_cx, WALL_T * 0.5)
	var cs  := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size = Vector2(DOOR_W - 8, WALL_T + 16)
	cs.shape = shp
	area.add_child(cs)
	add_child(area)

	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			_go("dungeon"))

func _door_post(pos: Vector2, sz: Vector2) -> void:
	var vis := ColorRect.new()
	vis.color    = C_DOOR
	vis.size     = sz
	vis.position = pos
	vis.z_index  = 1
	vis.z_as_relative = false
	add_child(vis)

	# Physics so the player can't slip through the post
	var sb  := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask  = 0
	var cs  := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size    = sz
	cs.shape    = shp
	cs.position = sz * 0.5
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)

# ── Interior obstacles ────────────────────────────────────────────────────────
func _build_obstacles() -> void:
	var pillars := [
		# flanking the door opening
		Vector2(720,  220), Vector2(1200, 220),
		# flanking each NPC
		Vector2(360,  360), Vector2(360,  640),
		Vector2(800,  360), Vector2(800,  640),
		Vector2(1120, 360), Vector2(1120, 640),
		Vector2(1560, 360), Vector2(1560, 640),
		# bottom decorative row
		Vector2(480,  960), Vector2(720,  960),
		Vector2(1200, 960), Vector2(1440, 960),
	]
	for p in pillars:
		_pillar(p)

func _pillar(centre: Vector2) -> void:
	const SZ := Vector2(48, 48)
	var pos   := centre - SZ * 0.5

	var vis := ColorRect.new()
	vis.color    = C_WALL
	vis.size     = SZ
	vis.position = pos
	vis.z_index  = 0
	vis.z_as_relative = false
	add_child(vis)

	var top := ColorRect.new()
	top.color    = C_WALL_TOP
	top.size     = Vector2(SZ.x, 5)
	top.position = pos
	top.z_index  = 1
	top.z_as_relative = false
	add_child(top)

	var sb  := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask  = 0
	var cs  := CollisionShape2D.new()
	var shp := RectangleShape2D.new()
	shp.size    = SZ
	cs.shape    = shp
	cs.position = centre
	sb.add_child(cs)
	add_child(sb)

# ── NPCs ──────────────────────────────────────────────────────────────────────
func _build_npcs() -> void:
	for n in NPCS:
		_npc(n["pos"], n["name"], n["desc"], n["color"], n["action"])

func _npc(pos: Vector2, npc_name: String, desc: String,
		col: Color, action: String) -> void:
	# Body
	var npc_body := ColorRect.new()
	npc_body.size     = Vector2(28, 40)
	npc_body.color    = col
	npc_body.position = pos - Vector2(14, 40)
	npc_body.z_as_relative = false
	add_child(npc_body)

	# Head
	var head := ColorRect.new()
	head.size     = Vector2(22, 22)
	head.color    = col.lightened(0.25)
	head.position = pos - Vector2(11, 62)
	head.z_as_relative = false
	add_child(head)

	# Name label (always visible)
	var name_lbl := Label.new()
	name_lbl.text = npc_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", col.lightened(0.4))
	name_lbl.size     = Vector2(160, 20)
	name_lbl.position = pos - Vector2(80, 82)
	name_lbl.z_index  = 10
	name_lbl.z_as_relative = false
	add_child(name_lbl)

	# Interaction zone
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 1
	area.position        = pos
	var cs  := CollisionShape2D.new()
	var shp := CircleShape2D.new()
	shp.radius = 80.0
	cs.shape   = shp
	area.add_child(cs)
	add_child(area)

	area.body_entered.connect(func(ent: Node2D) -> void:
		if ent.is_in_group("player"):
			_near_action = action
			_show_prompt(desc, pos))

	area.body_exited.connect(func(ent: Node2D) -> void:
		if ent.is_in_group("player"):
			_near_action = ""
			_hide_prompt())

# ── Blacksmith overlay ───────────────────────────────────────────────────────
func _open_blacksmith() -> void:
	_smith_open = true
	if _smith_layer == null:
		_smith_layer = CanvasLayer.new()
		_smith_layer.layer = 30
		add_child(_smith_layer)
	_refresh_blacksmith()

func _close_blacksmith() -> void:
	_smith_open = false
	if _smith_layer:
		for c in _smith_layer.get_children():
			c.queue_free()

func _refresh_blacksmith() -> void:
	if _smith_layer == null: return
	for c in _smith_layer.get_children():
		c.queue_free()

	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_smith_layer.add_child(dim)

	# Panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.07, 0.12, 0.97)
	ps.border_color = Color(0.75, 0.50, 0.15)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(10)
	ps.content_margin_left   = 28
	ps.content_margin_right  = 28
	ps.content_margin_top    = 22
	ps.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", ps)
	_smith_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚒  BLACKSMITH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.25))
	vbox.add_child(title)

	# Forge coin display
	var gold_lbl := Label.new()
	gold_lbl.text = "⚒  %d  forge coin%s  (earned by defeating bosses)" \
		% [GameManager.forge_coins, "s" if GameManager.forge_coins != 1 else ""]
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(gold_lbl)

	var sep := HSeparator.new()
	var sep_sty := StyleBoxFlat.new()
	sep_sty.bg_color = Color(0.75, 0.50, 0.15, 0.4)
	sep_sty.content_margin_top = 1
	sep.add_theme_stylebox_override("separator", sep_sty)
	vbox.add_child(sep)

	# Upgrade rows
	for upg in UPGRADES:
		vbox.add_child(_upgrade_row(upg))

	# Reset all upgrades button
	var reset_btn := Button.new()
	reset_btn.text = "↺  Reset All Upgrades  (refund coins)"
	reset_btn.custom_minimum_size = Vector2(0, 40)
	reset_btn.add_theme_font_size_override("font_size", 13)
	_style_btn(reset_btn, Color(0.14, 0.06, 0.06), Color(0.55, 0.18, 0.18), Color(0.90, 0.55, 0.55))
	reset_btn.pressed.connect(func(): _sfx_confirm(); _reset_upgrades())
	reset_btn.mouse_entered.connect(_sfx_hover)
	vbox.add_child(reset_btn)

	# Close hint
	var close_lbl := Label.new()
	close_lbl.text = "[ E / Esc  to close ]"
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_font_size_override("font_size", 12)
	close_lbl.add_theme_color_override("font_color", Color(0.40, 0.44, 0.55))
	vbox.add_child(close_lbl)

func _upgrade_row(upg: Dictionary) -> HBoxContainer:
	var id    : String = upg["id"]
	var level : int    = GameManager.get("perm_" + id)
	var maxlv : int    = upg["max"]
	var cost  : int    = upg["costs"][level] if level < maxlv else 0
	var maxed : bool   = level >= maxlv

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Icon + name column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [upg["icon"], upg["name"]]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upg["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	info.add_child(desc_lbl)

	# Level pips
	var pip_lbl := Label.new()
	var pips := ""
	for i in maxlv:
		pips += "■ " if i < level else "□ "
	pip_lbl.text = pips.strip_edges() + "  Lv %d/%d" % [level, maxlv]
	pip_lbl.add_theme_font_size_override("font_size", 12)
	pip_lbl.add_theme_color_override("font_color",
		Color(0.95, 0.72, 0.25) if not maxed else Color(0.30, 1.0, 0.52))
	info.add_child(pip_lbl)

	row.add_child(info)

	# Buy button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 42)
	btn.add_theme_font_size_override("font_size", 13)
	if maxed:
		btn.text = "✅  MAXED"
		btn.disabled = true
		_style_btn(btn, Color(0.08, 0.14, 0.08), Color(0.22, 0.55, 0.22), Color(0.30, 1.0, 0.52))
	elif GameManager.forge_coins >= cost:
		btn.text = "Buy  —  %d⚒" % cost
		_style_btn(btn, Color(0.08, 0.10, 0.06), Color(0.55, 0.42, 0.10), Color(1.0, 0.85, 0.3))
		btn.pressed.connect(func(): _sfx_confirm(); _buy_upgrade(id))
		btn.mouse_entered.connect(_sfx_hover)
	else:
		btn.text = "%d⚒  needed" % cost
		btn.disabled = true
		_style_btn(btn, Color(0.10, 0.08, 0.08), Color(0.35, 0.18, 0.10), Color(0.55, 0.40, 0.25))

	row.add_child(btn)
	return row

func _buy_upgrade(id: String) -> void:
	var upg   : Dictionary = UPGRADES.filter(func(u): return u["id"] == id)[0]
	var level : int        = GameManager.get("perm_" + id)
	if level >= upg["max"]: return
	var cost : int = upg["costs"][level]
	if GameManager.spend_forge_coins(cost):
		GameManager.set("perm_" + id, level + 1)
		GameManager.save_meta()
		_refresh_blacksmith()

func _reset_upgrades() -> void:
	# Calculate total coins spent across all upgrades and refund them
	var refund : int = 0
	for upg in UPGRADES:
		var level : int = GameManager.get("perm_" + upg["id"])
		for i in range(level):
			refund += upg["costs"][i]
		GameManager.set("perm_" + upg["id"], 0)
	GameManager.forge_coins += refund
	GameManager.save_meta()
	_refresh_blacksmith()

func _style_btn(btn: Button, bg: Color, border: Color, text_col: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = bg; sn.border_color = border
	sn.set_border_width_all(2); sn.set_corner_radius_all(6)
	sn.content_margin_left = 14; sn.content_margin_right  = 14
	sn.content_margin_top  =  8; sn.content_margin_bottom =  8
	var sh := sn.duplicate()
	sh.bg_color = bg.lightened(0.15); sh.border_color = border.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_stylebox_override("focus",   sn)
	btn.add_theme_color_override("font_color",       text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

# ── Prompt ────────────────────────────────────────────────────────────────────
func _show_prompt(text: String, world_pos: Vector2) -> void:
	if _prompt_lbl == null: return
	_prompt_lbl.text     = text
	_prompt_lbl.position = world_pos - Vector2(100, 112)
	_prompt_lbl.visible  = true

func _hide_prompt() -> void:
	if _prompt_lbl != null:
		_prompt_lbl.visible = false

func _go(action: String) -> void:
	match action:
		"dungeon":
			_near_action = ""
			_hide_prompt()
			GameManager.hub_player_pos = Vector2.ZERO
			GameManager.reset()
			SceneLoader.goto("res://scenes/dungeon.tscn")
		"collection":
			_near_action = ""
			_hide_prompt()
			if _player:
				GameManager.hub_player_pos = _player.global_position
			SceneLoader.goto("res://scenes/meta_shop.tscn")
		"blacksmith":
			# Don't clear _near_action — the overlay closes in-place so E
			# must still work to reopen it without leaving the NPC zone.
			_open_blacksmith()

# ── Player ────────────────────────────────────────────────────────────────────
func _spawn_player() -> void:
	_player = PlayerScene.instantiate()
	_player.global_position = GameManager.hub_player_pos \
		if GameManager.hub_player_pos != Vector2.ZERO \
		else Vector2(ROOM_W * 0.5, ROOM_H * 0.75)
	add_child(_player)

	# Disable shooting in the hub
	var weapon := _player.get_node_or_null("WeaponAuto")
	if weapon:
		weapon.process_mode = Node.PROCESS_MODE_DISABLED

	# Floating world-space prompt that hovers above NPCs
	_prompt_lbl = Label.new()
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 14)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
	_prompt_lbl.size    = Vector2(200, 24)
	_prompt_lbl.visible = false
	_prompt_lbl.z_index = 20
	_prompt_lbl.z_as_relative = false
	add_child(_prompt_lbl)

	# Camera follows player, clamped to room
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed   = 7.0
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = int(ROOM_W)
	cam.limit_bottom = int(ROOM_H)
	_player.add_child(cam)
	cam.make_current()

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)

	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.05, 0.07, 0.12, 0.88)
	sty.border_color = Color(0.75, 0.62, 0.10, 0.55)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	sty.content_margin_left   = 12
	sty.content_margin_right  = 12
	sty.content_margin_top    =  6
	sty.content_margin_bottom =  6

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", sty)
	cl.add_child(panel)

	var lbl := Label.new()
	lbl.text = "⚒  %d forge coin%s" \
		% [GameManager.forge_coins, "s" if GameManager.forge_coins != 1 else ""]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	panel.add_child(lbl)

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
