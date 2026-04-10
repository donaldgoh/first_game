class_name WeaponPart
extends Resource

# ═══════════════════════════════════════════════════════════════════════════════
# WeaponPart — one modular weapon chip.
#
# To add a new part: open weapon_parts_database.gd and append one entry.
# Every field here has a safe default so parts only need to set what they change.
# ═══════════════════════════════════════════════════════════════════════════════

enum Rarity { COMMON, UNCOMMON, RARE }

@export var id:    String = ""
@export var name:  String = ""
@export var desc:  String = ""
@export var cost:  int    = 50
@export var rarity: Rarity = Rarity.COMMON

# ── Stat multipliers (applied multiplicatively when parts stack) ───────────────
@export var damage_mult:       float = 1.0
@export var fire_rate_mult:    float = 1.0
@export var bullet_speed_mult: float = 1.0
@export var bullet_range_mult: float = 1.0

# ── Flat bonuses ──────────────────────────────────────────────────────────────
@export var pierce_bonus:  int   = 0
@export var bounce_bonus:  int   = 0
@export var spread_count:  int   = 1      # total pellets per shot (1 = no spread)
@export var spread_angle:  float = 0.0   # degrees total fan width

# ── Special behaviours (boolean flags) ────────────────────────────────────────
@export var homing:          bool  = false
@export var homing_strength: float = 3.0
@export var explode_radius:  float = 0.0  # 0 = no explosion

# ── Special fire modes ────────────────────────────────────────────────────────
@export var is_laser:         bool = false  # instant beam, no projectile
@export var sky_strike:       bool = false  # bullets fall from sky at cursor
@export var chain_count:      int  = 0      # on hit, jump to N more enemies
@export var split_on_hit:     bool = false  # splits into 3 shards on final pierce
@export var delayed_detonate: bool = false  # slows then explodes at range end
