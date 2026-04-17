extends Control

const CHARACTERS = [
	{
		"id": "warrior",
		"name": "⚔️ Warrior",
		"desc": "High HP and resilience.\nPassive: Takes 20% less damage.",
		"max_health": 160,
		"move_speed": 170.0,
		"damage": 10,
		"attack_speed": 0.9,
		"pickup_radius": 80.0,
		"lifesteal": 0,
		"luck": 0.0,
		"passive": "tank"
	},
	{
		"id": "hunter",
		"name": "🏹 Hunter",
		"desc": "Fast with long range.\nPassive: +50% bullet range.",
		"max_health": 80,
		"move_speed": 270.0,
		"damage": 12,
		"attack_speed": 1.3,
		"pickup_radius": 120.0,
		"lifesteal": 0,
		"luck": 0.5,
		"passive": "ranger"
	},
	{
		"id": "mage",
		"name": "🧙 Mage",
		"desc": "High damage glass cannon.\nPassive: +50% attack speed.",
		"max_health": 70,
		"move_speed": 200.0,
		"damage": 20,
		"attack_speed": 1.8,
		"pickup_radius": 100.0,
		"lifesteal": 0,
		"luck": 0.0,
		"passive": "rapid"
	},
]

func _ready():
	$VBox/Title.text = "⚔️ SELECT YOUR CHARACTER"
	$VBox/BackButton.pressed.connect(func():
		SceneLoader.goto("res://scenes/main_menu.tscn"))
	$VBox/BackButton.mouse_entered.connect(func(): _play_hover())
	for ch in CHARACTERS:
		var btn = Button.new()
		btn.text = "%s\n%s" % [ch.name, ch.desc]
		btn.custom_minimum_size = Vector2(320, 120)
		btn.mouse_entered.connect(func(): _play_hover())
		btn.pressed.connect(func(): _select(ch))
		$VBox/CharRow.add_child(btn)

func _select(ch: Dictionary):
	_play_confirm()
	GameManager.selected_character = ch
	GameManager.reset_run()
	# Apply character base stats + permanent bonuses
	GameManager.p_max_health = ch.max_health + GameManager.perm_bonus_hp
	GameManager.p_current_health = GameManager.p_max_health
	GameManager.p_move_speed = ch.move_speed + GameManager.perm_bonus_speed
	GameManager.p_damage = ch.damage + GameManager.perm_bonus_damage
	GameManager.p_attack_speed = ch.attack_speed
	GameManager.p_pickup_radius = ch.pickup_radius
	GameManager.p_lifesteal = ch.lifesteal
	GameManager.p_luck = ch.luck + GameManager.perm_bonus_luck
	await get_tree().create_timer(0.1).timeout
	SceneLoader.goto("res://scenes/part_select.tscn")

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
