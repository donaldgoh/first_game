extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# WeaponPartsDatabase
#
# Add a new part by appending a WeaponPart block below — that's it.
# No other file needs to change.
# ═══════════════════════════════════════════════════════════════════════════════

func all() -> Array[WeaponPart]:
	return [
		_make("piercing",  "Piercing Shot",   "Bullets pierce 2 extra enemies.",        60,  WeaponPart.Rarity.COMMON,   {pierce_bonus=2}),
		_make("spread",    "Spread Shot",      "Fires 3 bullets in a fan.",              80,  WeaponPart.Rarity.UNCOMMON, {spread_count=3, spread_angle=30.0}),
		_make("swift",     "Swift Rounds",     "Bullets travel 60% faster.",             50,  WeaponPart.Rarity.COMMON,   {bullet_speed_mult=1.6}),
		_make("longrange", "Sniper Round",     "Bullets travel 80% further.",            50,  WeaponPart.Rarity.COMMON,   {bullet_range_mult=1.8}),
		_make("homing",    "Seeker Round",     "Bullets home in on enemies.",            120, WeaponPart.Rarity.RARE,     {homing=true, homing_strength=4.0}),
		_make("bouncing",  "Bouncing Shot",    "Bullets bounce once off walls.",         100, WeaponPart.Rarity.UNCOMMON, {bounce_bonus=1}),
		_make("heavy",     "Heavy Slug",       "+80% damage, -30% speed.",               90,  WeaponPart.Rarity.UNCOMMON, {damage_mult=1.8, bullet_speed_mult=0.7}),
		_make("rapid",     "Rapid Fire",       "+50% fire rate.",                        70,  WeaponPart.Rarity.COMMON,   {fire_rate_mult=1.5}),
		_make("explosive", "Explosive Round",  "Bullets explode on impact.",             150, WeaponPart.Rarity.RARE,     {explode_radius=80.0}),
		_make("shotgun",   "Shotgun Blast",    "Fires 5 pellets, lower speed.",          110, WeaponPart.Rarity.UNCOMMON, {spread_count=5, spread_angle=45.0, bullet_speed_mult=0.8}),
		_make("vampiric",  "Vampiric Round",   "+60% damage, -20% fire rate.",           100, WeaponPart.Rarity.RARE,     {damage_mult=1.6, fire_rate_mult=0.8}),
		# ── Special mechanic parts ────────────────────────────────────────────────
		_make("laser",    "Laser Beam",      "Fires an instant beam that hits all enemies in a line.",     150, WeaponPart.Rarity.RARE,     {is_laser=true}),
		_make("skyfall",  "Sky Strike",      "Bullets fall from the sky above your cursor.",               140, WeaponPart.Rarity.RARE,     {sky_strike=true, damage_mult=1.3}),
		_make("chain",    "Chain Bolt",      "Each hit fires a bolt to the next nearest enemy (×2).",      110, WeaponPart.Rarity.UNCOMMON, {chain_count=2}),
		_make("splitter", "Splitter Chip",   "On final pierce, bullet splits into 3 shards.",              100, WeaponPart.Rarity.UNCOMMON, {split_on_hit=true}),
		_make("cluster",  "Cluster Bomb",    "Slow bullet that detonates with massive AoE at range end.",  160, WeaponPart.Rarity.RARE,     {delayed_detonate=true, bullet_speed_mult=0.45, explode_radius=100.0}),
		_make("orbital",  "Orbital Burst",   "Fires 8 bullets in all directions at once. Low fire rate.",  130, WeaponPart.Rarity.UNCOMMON, {spread_count=8, spread_angle=315.0, fire_rate_mult=0.5}),
	]

# ── Lookup helpers ────────────────────────────────────────────────────────────
func get_by_id(id: String) -> WeaponPart:
	for p in all():
		if p.id == id: return p
	return null

func get_unlocked(unlocked_ids: Array) -> Array[WeaponPart]:
	var result: Array[WeaponPart] = []
	for p in all():
		if p.id in unlocked_ids: result.append(p)
	return result

func get_locked(unlocked_ids: Array) -> Array[WeaponPart]:
	var result: Array[WeaponPart] = []
	for p in all():
		if not (p.id in unlocked_ids): result.append(p)
	return result

# ── Internal builder — keeps the table above readable ────────────────────────
func _make(id: String, pname: String, desc: String,
		cost: int, rarity: WeaponPart.Rarity, overrides: Dictionary) -> WeaponPart:
	var p       = WeaponPart.new()
	p.id        = id
	p.name      = pname
	p.desc      = desc
	p.cost      = cost
	p.rarity    = rarity
	for key in overrides:
		p.set(key, overrides[key])
	return p
