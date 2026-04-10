extends Node

signal xp_changed(current, required)
signal level_up(level)
signal gold_changed(amount)
signal inventory_changed
@warning_ignore("UNUSED_SIGNAL")
signal game_over

# Run stats
var player_level: int = 1
var current_xp: int = 0
var xp_to_next: int = 100
var gold: int = 0
var floor_number: int = 1
var enemies_killed: int = 0
var time_alive: float = 0.0
var game_started: bool = false

# Player persistent stats per run
var p_max_health: int = 6   # stored as half-hearts (6 = 3 full hearts)
var p_current_health: int = 6
var p_move_speed: float = 320.0
var p_damage: int = 10
var p_attack_speed: float = 1.0
var p_pickup_radius: float = 80.0
var p_armor: int = 0
var p_lifesteal: int = 0
var p_luck: float = 0.0

# Selected character
var selected_character: Dictionary = {}

# Weapon parts
var unlocked_parts: Array  = []
var active_part: String    = ""

# Inventory — parts collected this run
var inventory_parts: Array = []          # part IDs in the bag (unequipped)
var equipped_parts: Array  = ["","",""]  # 3 equipped slots; "" = empty
var inventory_open: bool   = false       # true while the inventory UI is visible

# Lifetime gold (used for unlocking weapon parts)
var lifetime_gold: int = 0

func _ready():
	load_meta()

func _process(delta):
	if game_started:
		time_alive += delta

func add_xp(amount: int):
	current_xp += amount
	emit_signal("xp_changed", current_xp, xp_to_next)
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		player_level += 1
		xp_to_next = int(xp_to_next * 1.25)
		emit_signal("level_up", player_level)

func add_gold(amount: int):
	gold += amount
	lifetime_gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func spend_lifetime_gold(amount: int) -> bool:
	if lifetime_gold >= amount:
		lifetime_gold -= amount
		save_meta()
		return true
	return false

func on_enemy_killed():
	enemies_killed += 1

func reset_run():
	player_level = 1
	current_xp = 0
	xp_to_next = 100
	gold = 0
	floor_number = 1
	enemies_killed = 0
	time_alive = 0.0
	game_started = true
	active_part = ""
	inventory_parts = []
	equipped_parts  = ["", "", ""]
	inventory_open  = false

func reset():
	reset_run()
	p_max_health = 6   # 3 full hearts
	p_current_health = p_max_health
	p_move_speed = 320.0
	p_damage = 10
	p_attack_speed = 1.0
	p_pickup_radius = 80.0
	p_armor = 0
	p_lifesteal = 0
	p_luck = 0.0

# ── Inventory helpers ─────────────────────────────────────────────────────────

func add_part_to_inventory(id: String):
	inventory_parts.append(id)
	emit_signal("inventory_changed")

# Equip the part at inventory_parts[inv_index] into the given slot (0-2).
# If the slot is already occupied, the old part is swapped back to inventory.
func equip_part(inv_index: int, slot: int):
	if inv_index < 0 or inv_index >= inventory_parts.size(): return
	if slot < 0 or slot >= equipped_parts.size(): return
	var id = inventory_parts[inv_index]
	if equipped_parts[slot] != "":
		inventory_parts.append(equipped_parts[slot])   # push old part back
	inventory_parts.remove_at(inv_index)
	equipped_parts[slot] = id
	emit_signal("inventory_changed")

# Remove the part from an equipped slot and return it to inventory.
func unequip_slot(slot: int):
	if slot < 0 or slot >= equipped_parts.size(): return
	if equipped_parts[slot] == "": return
	inventory_parts.append(equipped_parts[slot])
	equipped_parts[slot] = ""
	emit_signal("inventory_changed")

# Merge all equipped parts into a single WeaponPart.
# Multipliers are multiplied together; flat bonuses and specials are accumulated.
# Returns null when no parts are equipped.
func get_combined_part() -> WeaponPart:
	var parts: Array = []
	for id in equipped_parts:
		if id != "":
			var p = WeaponPartsDatabase.get_by_id(id)
			if p: parts.append(p)
	if parts.is_empty(): return null

	var c = WeaponPart.new()
	c.id   = "combined"
	c.name = "Combined"
	c.spread_count = 1

	for p in parts:
		c.damage_mult       *= p.damage_mult
		c.fire_rate_mult    *= p.fire_rate_mult
		c.bullet_speed_mult *= p.bullet_speed_mult
		c.bullet_range_mult *= p.bullet_range_mult
		c.pierce_bonus      += p.pierce_bonus
		c.bounce_bonus      += p.bounce_bonus
		if p.spread_count > c.spread_count:
			c.spread_count = p.spread_count
			c.spread_angle = p.spread_angle
		if p.homing:
			c.homing = true
			c.homing_strength = max(c.homing_strength, p.homing_strength)
		if p.explode_radius > c.explode_radius:
			c.explode_radius = p.explode_radius
		if p.is_laser:         c.is_laser = true
		if p.sky_strike:       c.sky_strike = true
		c.chain_count         += p.chain_count
		if p.split_on_hit:     c.split_on_hit = true
		if p.delayed_detonate: c.delayed_detonate = true
	return c

func save_meta():
	var f = FileAccess.open("user://meta.dat", FileAccess.WRITE)
	if f:
		f.store_var({
			"lifetime_gold": lifetime_gold,
			"unlocked_parts": unlocked_parts,
		})
		f.close()

func load_meta():
	if not FileAccess.file_exists("user://meta.dat"): return
	var f = FileAccess.open("user://meta.dat", FileAccess.READ)
	if f:
		var data = f.get_var()
		f.close()
		if data:
			lifetime_gold  = data.get("lifetime_gold", 0)
			unlocked_parts = data.get("unlocked_parts", [])
