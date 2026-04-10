extends Node

const ITEMS = [
	# COMMON
	{"id":"iron_heart","name":"Iron Heart","desc":"+1 Max HP  +2 Armor","rarity":"common","max_health":1,"armor":2},
	{"id":"swift_boots","name":"Swift Boots","desc":"+50 Move Speed","rarity":"common","speed":50.0},
	{"id":"magnet","name":"Magnet","desc":"+80 Pickup Range","rarity":"common","pickup_radius":80.0},
	{"id":"bandage","name":"Bandage","desc":"+1 Max HP","rarity":"common","max_health":1},
	{"id":"gloves","name":"Combat Gloves","desc":"+15 Damage","rarity":"common","damage":15},
	{"id":"energy_drink","name":"Energy Drink","desc":"+0.3 Attack Speed","rarity":"common","attack_speed":0.3},
	# UNCOMMON
	{"id":"cursed_eye","name":"Cursed Eye","desc":"+25 Dmg  +0.4 Atk Spd","rarity":"uncommon","damage":25,"attack_speed":0.4},
	{"id":"ancient_tome","name":"Ancient Tome","desc":"+20 Dmg  +0.6 Atk Spd","rarity":"uncommon","attack_speed":0.6,"damage":20},
	{"id":"berserker","name":"Berserker Ring","desc":"+60 Dmg  -1 Max HP","rarity":"uncommon","damage":60,"max_health":-1},
	{"id":"heavy_armor","name":"Heavy Armor","desc":"+5 Armor  -30 Speed","rarity":"uncommon","armor":5,"speed":-30.0},
	{"id":"chain_boots","name":"Chain Boots","desc":"+80 Speed  +1 Armor","rarity":"uncommon","speed":80.0,"armor":1},
	{"id":"hunters_mark","name":"Hunter's Mark","desc":"+35 Dmg  +50 Pickup","rarity":"uncommon","damage":35,"pickup_radius":50.0},
	# RARE
	{"id":"void_crystal","name":"Void Crystal","desc":"+30 Dmg  +1 Pierce","rarity":"rare","damage":30,"pierce_bonus":1},
	{"id":"golden_idol","name":"Golden Idol","desc":"+50 Dmg  +2 Armor","rarity":"rare","damage":50,"armor":2},
	{"id":"vampiric","name":"Vampiric Blade","desc":"+30 Dmg  Heal 5 on kill","rarity":"rare","damage":30,"lifesteal":5},
	{"id":"adrenaline","name":"Adrenaline","desc":"+1.0 Atk Speed","rarity":"rare","attack_speed":1.0},
	{"id":"iron_will","name":"Iron Will","desc":"+2 Max HP  +3 Armor","rarity":"rare","max_health":2,"armor":3},
	{"id":"shadow_cloak","name":"Shadow Cloak","desc":"+80 Speed  +0.5 Atk Spd","rarity":"rare","speed":80.0,"attack_speed":0.5},
	{"id":"titan_heart","name":"Titan Heart","desc":"+2 Max HP  +4 Armor","rarity":"rare","max_health":2,"armor":4},
	{"id":"death_spiral","name":"Death Spiral","desc":"+80 Dmg  +0.8 Atk Spd","rarity":"rare","damage":80,"attack_speed":0.8},
]

func get_random_items(count: int) -> Array:
	var result = []
	var attempts = 0
	# Get luck from player
	var luck = GameManager.p_luck
	while result.size() < count and attempts < 100:
		attempts += 1
		var roll = randf()
		var rarity = ""
		# Base: Common 60%, Uncommon 30%, Rare 10%
		# Each luck point: +2% rare, +3% uncommon
		var rare_chance = 0.10 + (luck * 0.02)
		var uncommon_chance = 0.40 + (luck * 0.03)
		if roll < rare_chance:
			rarity = "rare"
		elif roll < uncommon_chance:
			rarity = "uncommon"
		else:
			rarity = "common"
		var pool = ITEMS.filter(func(i): return i.rarity == rarity)
		if pool.is_empty(): continue
		var item = pool[randi() % pool.size()]
		if not result.any(func(r): return r.id == item.id):
			result.append(item)
	return result

func get_items_by_rarity(rarity: String) -> Array:
	return ITEMS.filter(func(i): return i.rarity == rarity)
