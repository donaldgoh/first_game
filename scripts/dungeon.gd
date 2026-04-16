extends Node2D

const InventoryUI = preload("res://scripts/inventory_ui.gd")

var shake_amount: float = 0.0
var camera: Camera2D = null

func _ready():
	GameManager.game_started = true
	GameManager.game_over.connect(_on_game_over)
	await get_tree().process_frame
	camera = get_node_or_null("Player/Camera2D")

	# Spawn the inventory CanvasLayer
	var inv = InventoryUI.new()
	inv.name = "InventoryUI"
	add_child(inv)

func _process(delta):
	if shake_amount > 0:
		shake_amount -= delta * 5.0
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount) * 8,
				randf_range(-shake_amount, shake_amount) * 8)
	else:
		if camera: camera.offset = Vector2.ZERO

func shake(amount: float = 1.0):
	shake_amount = amount

func show_notification(text: String, color: Color):
	var pl = get_tree().get_first_node_in_group("player")
	var base = pl.global_position + Vector2(-200, -120) if pl else Vector2(440, 240)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 100
	lbl.position = base
	lbl.custom_minimum_size = Vector2(400, 80)
	add_child(lbl)
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(lbl, "position:y", lbl.position.y - 100, 1.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(lbl.queue_free)

func _on_game_over():
	shake(2.0)
	await get_tree().create_timer(1.5).timeout
	SceneLoader.goto("res://scenes/game_over.tscn")
	
