extends Node2D

enum RoomType {START, NORMAL, TREASURE, SHOP, BOSS}

const DIRS = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0,  1),
	"east":  Vector2i(1,  0),
	"west":  Vector2i(-1, 0),
}


const TILE     = 64   # 16-px sprite × scale-4 TileMapLayer = 64 px/tile
const ROOM_IW  = 14   # inner width  in tiles
const ROOM_IH  = 8    # inner height in tiles
const WALL_T   = 3    # wall thickness each side in tiles
const COR_LEN  = 10   # gap between rooms in tiles (10 × 64 = 640 px)
const COR_W    = 2    # corridor / door width in tiles

const CELL_W  = (ROOM_IW + WALL_T * 2) * TILE   # 20 × 64 = 1280
const CELL_H  = (ROOM_IH + WALL_T * 2) * TILE   # 14 × 64 =  896
const STEP_X  = CELL_W + COR_LEN * TILE          # 1280 + 640 = 1920
const STEP_Y  = CELL_H + COR_LEN * TILE          #  896 + 640 = 1536

const EnemySpider   = preload("res://scenes/enemy_spider.tscn")
const EnemyShooter  = preload("res://scenes/enemy_shooter.tscn")
const BossScene     = preload("res://scenes/boss_enemy.tscn")
const BossLaserScene = preload("res://scenes/boss_laser.tscn")
const XPGem      = preload("res://scenes/xp_gem.tscn")
const CoinScene  = preload("res://scenes/coin.tscn")

# ═════════════════════════════════════════════════════════════════════════════
# ROOM LIBRARY
# Each entry maps a door-config key → array of scene paths.
# The key is the room's open directions sorted alphabetically and joined by ",".
# Add more paths to any array to register extra variants — one is picked at random.
#
# Room prefab contract (all scenes must follow this):
#   ExitNorth / ExitSouth / ExitEast / ExitWest  (Node2D children of root)
#     └─ Seal  : shown when that exit has no neighbour (painted dead-end wall)
#     └─ Lock  : visible=false by default; shown while enemies are alive
#                must contain a StaticBody2D child for physics blocking
# ═════════════════════════════════════════════════════════════════════════════
const ROOM_LIBRARY: Dictionary = {
	# ── Special rooms (matched by RoomType, not door config) ─────────────────
	"start":    ["res://scenes/rooms/start/room_start_1.tscn"],
	"boss":     ["res://scenes/rooms/boss/room_boss_1.tscn"],
	"shop":     ["res://scenes/rooms/shop/room_shop_1.tscn"],
	"treasure": ["res://scenes/rooms/treasure/room_treasure_1.tscn"],

	# ── Normal rooms — always use the 4-door template; Seals close unused exits
	"normal":   ["res://scenes/rooms/4door/room_4door_1.tscn",
				 "res://scenes/rooms/4door/room_4door_2.tscn"],
}

signal minimap_updated   # emitted whenever a room is visited or cleared

var rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i.ZERO
var room_nodes: Dictionary = {}
var door_locks: Dictionary = {}    # gp → Array[Node]  (Lock nodes from room prefab)
var door_triggers: Dictionary = {} # gp → Array[Area2D] (teleport triggers at each exit)
var room_instances: Dictionary = {} # gp → Node2D  (the instanced room prefab, for finding pre-placed nodes)
var enemies_alive: int = 0
var _enemies_spawning: int = 0  # how many still pending spawn
var is_room_cleared: bool = false
var _nearby_shop_slot: Dictionary = {}
var _door_cooldown: float = 0.0   # seconds remaining before door triggers are active again

func _ready():
	add_to_group("map_manager")
	var pl = get_tree().get_first_node_in_group("player")
	if pl: pl.visible = false
	_generate_map()
	await get_tree().process_frame
	_build_world()
	await get_tree().process_frame
	pl = get_tree().get_first_node_in_group("player")
	if pl:
		pl.global_position = _room_center(Vector2i.ZERO)
		pl.visible = true
	_enter_room(Vector2i.ZERO)

func _unhandled_input(event):
	if _nearby_shop_slot.is_empty(): return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		_buy_from_shop(_nearby_shop_slot)
		get_viewport().set_input_as_handled()

func _room_origin(gp: Vector2i) -> Vector2:
	if room_nodes.has(gp): return room_nodes[gp].position
	return Vector2(gp.x * STEP_X, gp.y * STEP_Y)

func _room_center(gp: Vector2i) -> Vector2:
	return _room_inner_rect(gp).get_center()

func _room_inner_rect(gp: Vector2i) -> Rect2:
	var o  = _room_origin(gp)
	var sc = 1.0
	if room_instances.has(gp): sc = room_instances[gp].scale.x
	var wt = WALL_T * TILE * sc
	var iw = ROOM_IW * TILE * sc
	var ih = ROOM_IH * TILE * sc
	return Rect2(o.x + wt, o.y + wt, iw, ih)

# Returns true when placing a room at np would NOT create a diagonal adjacency
# with any existing room.  Diagonally-adjacent non-connected rooms can produce
# world-space wall overlap when a large scene (boss / treasure) is instantiated.
func _grid_no_diagonal_conflict(np: Vector2i) -> bool:
	for diag in [Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]:
		if rooms.has(np + diag):
			return false
	return true

# Returns true when gp has NO non-connected room in any of the 8 surrounding cells.
# Used to find the best position for large room types (boss, treasure).
func _grid_8dir_clearance(gp: Vector2i) -> bool:
	var doors: Dictionary = rooms[gp].get("doors", {})
	var connected: Dictionary = {}
	for dn in doors:
		connected[gp + DIRS[dn] * int(doors[dn])] = true
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			var nb := gp + Vector2i(dx, dy)
			if rooms.has(nb) and not connected.has(nb):
				return false
	return true

func _generate_map():
	rooms.clear()
	rooms[Vector2i(0,0)] = {
		"type": RoomType.START, "cleared": true,
		"visited": true, "activated": true, "shop_items": null
	}

	# ── Grow the map ──────────────────────────────────────────────────────────
	# For each iteration, only consider bases that have at least one free
	# neighbour to grow into.  For a dist=2 step, both the intermediate cell
	# AND the target cell must be empty — otherwise the corridor would pass
	# through an occupied grid square and create an illegal overlap.
	#
	# Minimum guarantee: every floor must contain all 4 special room types
	# (Start, Boss, Treasure, Shop) PLUS at least 5 normal rooms → 9 total.
	const MIN_ROOMS   := 9    # hard floor: 1 start + boss + treasure + shop + 5 normal
	const _MIN_NORMALS := 5    # normal rooms required after specials are removed

	var target  = randi_range(maxi(MIN_ROOMS, 10), 16)
	var direct  = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	# Cap total iterations so unlucky diagonal-conflict runs can't spin indefinitely.
	# Each successful placement consumes one "budget"; failed attempts (continue) are
	# cheap but bounded.  target * 20 gives generous headroom without risk of a freeze.
	var _iters := 0
	const MAX_ITERS := 320   # 16 (max target) × 20

	while rooms.size() < target and _iters < MAX_ITERS:
		_iters += 1
		# Collect every base that has at least one valid placement.
		var growable: Array = []
		for pos in rooms.keys():
			for d in direct:
				var nb1: Vector2i = pos + d
				if not rooms.has(nb1):
					growable.append(pos)
					break   # one free direction is enough to qualify this base
		if growable.is_empty(): break   # map is fully surrounded — stop early

		var base: Vector2i = growable[randi() % growable.size()]

		# Build two placement lists:
		#   clean  — no diagonal adjacency to existing rooms (safe for large room scenes)
		#   risky  — would sit diagonally next to an existing room (may overlap for large rooms)
		# We prefer clean positions; fall back to risky only when no clean ones exist.
		# If both lists are empty for this base, skip it (try another base next iteration).
		var clean_placements: Array = []
		var risky_placements: Array = []
		for d in direct:
			var nb1: Vector2i = base + d
			var nb2: Vector2i = base + d * 2
			if not rooms.has(nb1):
				# step-1 candidate
				if _grid_no_diagonal_conflict(nb1):
					clean_placements.append(nb1)
				else:
					risky_placements.append(nb1)
				# step-2 candidate (corridor gap at nb1 must also be empty)
				if not rooms.has(nb2):
					if _grid_no_diagonal_conflict(nb2):
						clean_placements.append(nb2)
					else:
						risky_placements.append(nb2)

		var placements: Array = clean_placements if not clean_placements.is_empty() \
								else risky_placements
		if placements.is_empty(): continue   # no valid direction — skip this base

		var np: Vector2i = placements[randi() % placements.size()]
		rooms[np] = {"type": RoomType.NORMAL, "cleared": false,
					 "visited": false, "activated": false, "shop_items": null}

	# ── Minimum-rooms guarantee ────────────────────────────────────────────────
	# If the map got surrounded before reaching MIN_ROOMS (can happen on unlucky
	# diagonal-avoidance runs), keep growing without the diagonal-conflict filter
	# until we hit the hard minimum.  This ensures every floor always has enough
	# rooms to place Boss + Treasure + Shop + 5 normal rooms.
	while rooms.size() < MIN_ROOMS:
		var growable: Array = []
		for pos in rooms.keys():
			for d in direct:
				if not rooms.has(pos + d):
					growable.append(pos)
					break
		if growable.is_empty(): break   # completely surrounded — give up

		var base: Vector2i = growable[randi() % growable.size()]
		var fallback: Array = []
		for d in direct:
			var nb1: Vector2i = base + d
			var nb2: Vector2i = base + d * 2
			if not rooms.has(nb1):
				fallback.append(nb1)
				if not rooms.has(nb2):
					fallback.append(nb2)
		if fallback.is_empty(): continue

		var np: Vector2i = fallback[randi() % fallback.size()]
		rooms[np] = {"type": RoomType.NORMAL, "cleared": false,
					 "visited": false, "activated": false, "shop_items": null}

	# ── BFS connectivity — must handle 2-step gaps ────────────────────────────
	# Two rooms are connected at dist=2 only when the intermediate cell is empty
	# (if it were occupied the connection would go through that room instead).
	var reachable: Dictionary = {}
	var queue: Array = [Vector2i.ZERO]
	reachable[Vector2i.ZERO] = true
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for dn in DIRS:
			var nb1: Vector2i = cur + DIRS[dn]
			var nb2: Vector2i = cur + DIRS[dn] * 2
			if rooms.has(nb1) and not reachable.has(nb1):
				reachable[nb1] = true
				queue.append(nb1)
			# 2-step connection only valid when the intermediate cell is empty
			if rooms.has(nb2) and not rooms.has(nb1) and not reachable.has(nb2):
				reachable[nb2] = true
				queue.append(nb2)
	for pos in rooms.keys().duplicate():
		if not reachable.has(pos):
			rooms.erase(pos)

	# ── Post-prune minimum guarantee ─────────────────────────────────────────
	# BFS pruning can reduce below MIN_ROOMS on rare seeds — grow more if needed.
	while rooms.size() < MIN_ROOMS:
		var growable: Array = []
		for pos in rooms.keys():
			for d in direct:
				if not rooms.has(pos + d):
					growable.append(pos)
					break
		if growable.is_empty(): break
		var base: Vector2i = growable[randi() % growable.size()]
		var candidates: Array = []
		for d in direct:
			var nb: Vector2i = base + d
			if not rooms.has(nb):
				candidates.append(nb)
		if candidates.is_empty(): continue
		var np: Vector2i = candidates[randi() % candidates.size()]
		rooms[np] = {"type": RoomType.NORMAL, "cleared": false,
					 "visited": false, "activated": false, "shop_items": null}

	# ── Build doors dict (stores the distance 1 or 2 for each open exit) ─────
	# dist=1 → rooms are directly adjacent; dist=2 → one empty cell gap between them.
	# The start room is not allowed a north exit by design.
	for pos in rooms.keys():
		var doors = {}
		for dn in DIRS:
			if pos == Vector2i.ZERO and dn == "north":
				continue
			var nb1: Vector2i = pos + DIRS[dn]
			var nb2: Vector2i = pos + DIRS[dn] * 2
			if rooms.has(nb1):
				# Prevent south-pointing rooms from connecting back to start
				if nb1 == Vector2i.ZERO and dn == "south":
					continue
				doors[dn] = 1
			elif rooms.has(nb2):
				if nb2 == Vector2i.ZERO and dn == "south":
					continue
				doors[dn] = 2
		rooms[pos]["doors"] = doors

	# ── Door-graph reachability check ────────────────────────────────────────
	# The grid-BFS above uses raw adjacency.  Door-building has exclusions
	# (e.g. start has no north exit) that can leave rooms with no physical path.
	# Walk the actual door graph from start and drop anything unreachable.
	var door_reach: Dictionary = {}
	var dq: Array = [Vector2i.ZERO]
	door_reach[Vector2i.ZERO] = true
	while not dq.is_empty():
		var cur: Vector2i = dq.pop_front()
		for dn in rooms[cur].get("doors", {}):
			var nb: Vector2i = cur + DIRS[dn] * int(rooms[cur]["doors"][dn])
			if rooms.has(nb) and not door_reach.has(nb):
				door_reach[nb] = true
				dq.append(nb)
	for pos in rooms.keys().duplicate():
		if not door_reach.has(pos):
			rooms.erase(pos)

	# Rebuild doors after the purge (removed rooms leave stale entries on neighbours)
	for pos in rooms.keys():
		var doors2 = {}
		for dn in DIRS:
			if pos == Vector2i.ZERO and dn == "north": continue
			var nb1: Vector2i = pos + DIRS[dn]
			var nb2: Vector2i = pos + DIRS[dn] * 2
			if rooms.has(nb1):
				if nb1 == Vector2i.ZERO and dn == "south": continue
				doors2[dn] = 1
			elif rooms.has(nb2):
				if nb2 == Vector2i.ZERO and dn == "south": continue
				doors2[dn] = 2
		rooms[pos]["doors"] = doors2

	# Grow back to minimum if the door-purge dropped below it.
	# Never grow north of start to avoid the same isolation problem.
	while rooms.size() < MIN_ROOMS:
		var growable2: Array = []
		for pos in rooms.keys():
			for d in direct:
				var nb: Vector2i = pos + d
				if not rooms.has(nb) and not (pos == Vector2i.ZERO and d == Vector2i(0, -1)):
					growable2.append(pos)
					break
		if growable2.is_empty(): break
		var base2: Vector2i = growable2[randi() % growable2.size()]
		var cands2: Array = []
		for d in direct:
			var nb: Vector2i = base2 + d
			if not rooms.has(nb) and not (base2 == Vector2i.ZERO and d == Vector2i(0, -1)):
				cands2.append(nb)
		if cands2.is_empty(): continue
		var np2: Vector2i = cands2[randi() % cands2.size()]
		rooms[np2] = {"type": RoomType.NORMAL, "cleared": false,
					  "visited": false, "activated": false, "shop_items": null}
		# Build doors for the new room and update its neighbours immediately
		for pos in rooms.keys():
			var doors2 = {}
			for dn in DIRS:
				if pos == Vector2i.ZERO and dn == "north": continue
				var nb1: Vector2i = pos + DIRS[dn]
				var nb2: Vector2i = pos + DIRS[dn] * 2
				if rooms.has(nb1):
					if nb1 == Vector2i.ZERO and dn == "south": continue
					doors2[dn] = 1
				elif rooms.has(nb2):
					if nb2 == Vector2i.ZERO and dn == "south": continue
					doors2[dn] = 2
			rooms[pos]["doors"] = doors2

	# ── Separate dead-ends (1 door) from throughways (2+ doors) ──────────────
	# Done after doors dict so 2-step connections are counted correctly.
	var dead_ends: Array   = []
	var throughways: Array = []
	for pos in rooms.keys():
		if pos == Vector2i.ZERO: continue
		if rooms[pos]["doors"].size() == 1:
			dead_ends.append(pos)
		else:
			throughways.append(pos)

	# Sort dead-ends by manhattan distance, furthest first.
	dead_ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x) + abs(a.y) > abs(b.x) + abs(b.y))

	# Throughways are shuffled for variety; sorted furthest-first as fallback.
	throughways.shuffle()

	# ── Assign special room types ─────────────────────────────────────────────
	# Boss must be the dead-end furthest from (0,0).  Among dead-ends with equal
	# distance, prefer one that has no non-connected 8-directional neighbours
	# so the large boss room scene has space without overlapping other rooms.
	if dead_ends.size() > 0:
		# dead_ends is sorted furthest-first; pick the furthest one with clearance,
		# or fall back to dead_ends[0] if none have clearance.
		var boss_gp: Vector2i = dead_ends[0]
		for candidate in dead_ends:
			if _grid_8dir_clearance(candidate):
				boss_gp = candidate
				break
		rooms[boss_gp]["type"] = RoomType.BOSS
		dead_ends.erase(boss_gp)
	else:
		# No dead-ends: pick the non-start room with the greatest manhattan dist
		var all_non_start: Array = rooms.keys().filter(func(p): return p != Vector2i.ZERO)
		all_non_start.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return abs(a.x) + abs(a.y) > abs(b.x) + abs(b.y))
		if all_non_start.size() > 0:
			rooms[all_non_start[0]]["type"] = RoomType.BOSS
			throughways.erase(all_non_start[0])

	# Remaining specials go to dead-ends first, then throughways.
	# Treasure and Shop are always placed — they are required every floor.
	# Treasure prefers a position with 8-directional clearance (large room).
	var remaining: Array = dead_ends + throughways

	# -- Treasure (required) --
	if remaining.size() > 0:
		var treasure_gp: Vector2i = remaining[0]
		for candidate in remaining:
			if _grid_8dir_clearance(candidate):
				treasure_gp = candidate
				break
		rooms[treasure_gp]["type"] = RoomType.TREASURE
		remaining.erase(treasure_gp)
	# else: map degenerated below minimum — treasure omitted (shouldn't happen with MIN_ROOMS)

	# -- Shop (required) --
	if remaining.size() > 0:
		rooms[remaining[0]]["type"] = RoomType.SHOP
		remaining.remove_at(0)
	# else: same degenerate fallback

	# Any rooms still in 'remaining' keep RoomType.NORMAL — that's at least 5
	# when MIN_ROOMS is respected (9 total − start − boss − treasure − shop = 5).

func _build_world():
	# Y-sort the scene root so the player and room sprites sort by Y position
	get_tree().current_scene.y_sort_enabled = true

	for gp in rooms.keys():
		_build_room(gp)

	_realign_rooms()       # reposition rooms so doors physically align
	_resolve_overlaps()    # push non-connected rooms apart if their AABBs still touch

	# Ensure z-sorting is correct for all rooms after final placement
	for gp in rooms.keys():
		if room_instances.has(gp):
			_setup_zsort(gp, room_instances[gp])

	_setup_door_teleports()

# ── Room / tunnel pickers ─────────────────────────────────────────────────────

# Returns the door-config key for a room: sorted directions joined by ","
# e.g. {north, east} → "east,north"
func _doors_key(gp: Vector2i) -> String:
	var dirs: Array = rooms[gp]["doors"].keys()
	dirs.sort()
	return ",".join(dirs)

# Returns a random PackedScene from ROOM_LIBRARY matching this room's config.
# Special room types are matched by name; normal rooms by door config.
func _pick_room_scene(gp: Vector2i) -> PackedScene:
	var rt  = rooms[gp]["type"]
	var key: String
	match rt:
		RoomType.START:    key = "start"
		RoomType.BOSS:     key = "boss"
		RoomType.SHOP:     key = "shop"
		RoomType.TREASURE: key = "treasure"
		_:                 key = "normal"

	var paths: Array = ROOM_LIBRARY.get(key, [])
	var valid: Array = paths.filter(func(p: String) -> bool: return ResourceLoader.exists(p))
	if valid.is_empty():
		push_warning("MapManager: no room scene for config '%s'" % key)
		return null
	return load(valid[randi() % valid.size()])

# ── Room builder ──────────────────────────────────────────────────────────────
func _build_room(gp: Vector2i):
	var rt = rooms[gp]["type"]
	var initial_pos = Vector2(float(gp.x) * STEP_X, float(gp.y) * STEP_Y)

	var rnode = Node2D.new()
	rnode.name = "Room_%d_%d" % [gp.x, gp.y]
	rnode.y_sort_enabled = true
	rnode.position = initial_pos
	get_tree().current_scene.add_child(rnode)
	room_nodes[gp] = rnode

	# Pick and instance a matching prefab from the library
	var inst: Node2D = null
	var packed = _pick_room_scene(gp)
	if packed:
		inst = packed.instantiate()
		inst.position = Vector2.ZERO   # rnode.position carries the world offset
		rnode.add_child(inst)
		room_instances[gp] = inst

	if inst:
		_setup_exits(gp, inst)   # show/hide Seal on unused exits
		_collect_locks(gp, inst) # register Lock nodes for combat door-lock
		# _setup_zsort called later in _build_world after _realign_rooms()

	_add_room_trigger(gp, rnode)

	match rt:
		RoomType.TREASURE: _spawn_treasure(rnode, gp)
		RoomType.SHOP:     _spawn_shop(rnode, gp)

# ── Exit / seal setup ─────────────────────────────────────────────────────────
# In your room prefab, add these children:
#   ExitNorth, ExitSouth, ExitEast, ExitWest  (Node2D)
#     └─ Seal  — shown when no neighbour in that direction (the dead-end wall piece)
#     └─ Lock  — shown while room is active; should contain a StaticBody2D child

func _setup_exits(gp: Vector2i, inst: Node2D):
	var doors = rooms[gp]["doors"]
	var exit_map = {
		"north": "ExitNorth", "south": "ExitSouth",
		"east":  "ExitEast",  "west":  "ExitWest",
	}
	for dn in exit_map:
		var exit = inst.get_node_or_null(exit_map[dn])
		if exit == null: continue
		var has_door = doors.has(dn)
		var seal = exit.get_node_or_null("Seal")
		if seal:
			seal.visible = not has_door
		# Always disable Lock collision on sealed exits (no connected room)
		if not has_door:
			var lock = exit.get_node_or_null("Lock")
			if lock:
				for child in lock.get_children():
					if child is StaticBody2D:
						child.collision_layer = 0

func _collect_locks(gp: Vector2i, inst: Node2D):
	var locks: Array = []
	var exit_map = {
		"north": "ExitNorth", "south": "ExitSouth",
		"east":  "ExitEast",  "west":  "ExitWest",
	}
	for dn in rooms[gp]["doors"]:
		var exit = inst.get_node_or_null(exit_map[dn])
		if exit == null: continue
		var lock = exit.get_node_or_null("Lock")
		if lock:
			locks.append(lock)
	door_locks[gp] = locks

# ── Z-sort setup ──────────────────────────────────────────────────────────────
# The player's z_index = int(global_position.y) every frame.
# Room object layers get z_as_relative=false so their z_index is absolute.
# Sortable layers (Container, Box, Objects) use their REAL bottom-edge world Y
# as z_index — scanned from actual tile data so it's always accurate.
#
#   Floor / Wall → fixed extremes (always below / always above player)
#   Everything else → sort against player by tile base Y
func _setup_zsort(gp: Vector2i, inst: Node2D):
	var o        = _room_origin(gp)
	var top_y    = clampi(int(o.y) - 1,     -4096, 4096)
	var bottom_y = clampi(int(o.y + CELL_H) + 1, -4096, 4096)

	# Names that are always behind everything (floors)
	var floor_names  := ["Floor"]
	# Names that are always in front of everything (walls)
	var wall_names   := ["Wall", "Walls"]
	# Names that y-sort against the player
	var object_names := ["Box", "Container", "Objects", "Decorations", "Chips"]

	for child in inst.get_children():
		if not (child is TileMapLayer or child is Node2D): continue
		child.z_as_relative = false

		if child.name in floor_names:
			# Use the absolute minimum z_index so floors are ALWAYS behind every entity,
			# even when the room is placed far from the origin and top_y would clamp to 4096.
			child.z_index = -4096
		elif child.name in wall_names:
			child.z_index = top_y   # walls behind entities; south-wall overlap handled by entity Y-sort
		elif child.name == "Door":
			child.z_index = bottom_y  # door sprites render in front
		elif child.name in object_names and child is TileMapLayer:
			# Split into one node per connected object so each gets its own z_index
			_split_tilemap_by_object(child, inst)

# Returns the world Y of the bottom edge of the lowest tile row in a TileMapLayer.
# This is the correct sort origin — where the player's feet would be when
# standing directly in front of (below) the object.
func _tilemap_base_world_y(layer: TileMapLayer) -> int:
	var rect = layer.get_used_rect()          # bounding rect in tile coords
	if rect.size == Vector2i.ZERO:
		return int(layer.global_position.y)

	# Centre of the bottom tile row in the tilemap's LOCAL space
	var bottom_row  = rect.position.y + rect.size.y - 1
	var sample_cell = Vector2i(rect.position.x, bottom_row)
	var local_center: Vector2 = layer.map_to_local(sample_cell)

	# Bottom EDGE of that tile = centre + half a tile height in local space
	var tile_h: float = 16.0   # default; updated if tile_set is available
	if layer.tile_set:
		tile_h = float(layer.tile_set.tile_size.y)
	local_center.y += tile_h * 0.5

	# to_global accounts for the layer's position, rotation, and scale
	return int(layer.to_global(local_center).y)

# Splits a TileMapLayer that contains multiple separate objects into individual
# child TileMapLayers — one per connected group of tiles — so each object gets
# its own z_index and sorts against the player independently.
#
# "Connected" uses 8-directional adjacency so diagonally-touching tiles stay
# together (handles pixel-art objects that touch only at corners).
func _split_tilemap_by_object(layer: TileMapLayer, parent: Node2D):
	var cells: Array = layer.get_used_cells()
	if cells.is_empty(): return

	# Build a fast lookup set
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	# Find all connected components with a BFS flood-fill
	var visited: Dictionary = {}
	var components: Array   = []
	var neighbors_8 := [
		Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1),
	]
	for cell in cells:
		if cell in visited: continue
		var group: Array = []
		var queue: Array = [cell]
		visited[cell]    = true
		while queue.size() > 0:
			var cur: Vector2i = queue.pop_front()
			group.append(cur)
			for nb_offset in neighbors_8:
				var nb = cur + nb_offset
				if nb in cell_set and not nb in visited:
					visited[nb] = true
					queue.append(nb)
		components.append(group)

	# If only one object, just set z_index directly — no split needed
	if components.size() == 1:
		layer.z_as_relative = false
		layer.z_index       = _tilemap_base_world_y(layer)
		return

	# Multiple objects → create one new TileMapLayer per component
	for i in range(components.size()):
		var group: Array = components[i]
		var part         = TileMapLayer.new()
		part.name        = "%s_%d" % [layer.name, i]
		part.tile_set    = layer.tile_set
		part.position    = layer.position
		part.scale       = layer.scale
		part.z_as_relative = false
		parent.add_child(part)  # add first so to_global() works in _tilemap_base_world_y

		for cell in group:
			part.set_cell(cell,
				layer.get_cell_source_id(cell),
				layer.get_cell_atlas_coords(cell),
				layer.get_cell_alternative_tile(cell))

		part.z_index = _tilemap_base_world_y(part)

		# Erase these tiles from the original layer
		for cell in group:
			layer.erase_cell(cell)

	# Original layer is now empty — remove it
	layer.queue_free()

# ── Door teleport system ──────────────────────────────────────────────────────
# Instead of corridor scenes, each open exit gets a thin Area2D trigger.
# Touching it teleports the player to just inside the connected room.

# ── Door-aligned room placement ───────────────────────────────────────────────
# BFS from start, repositioning each room so its entry door lines up
# with the previous room's exit door + COR_LEN*TILE gap.
func _realign_rooms():
	var opp = {"north":"south","south":"north","east":"west","west":"east"}
	var dir_v = {"north":Vector2(0,-1),"south":Vector2(0,1),
				"east":Vector2(1,0),"west":Vector2(-1,0)}

	var visited: Dictionary = {Vector2i.ZERO: true}
	var queue: Array = [Vector2i.ZERO]

	while queue.size() > 0:
		var gp: Vector2i = queue.pop_front()
		for dn in rooms[gp]["doors"]:
			var dist: int     = rooms[gp]["doors"][dn]
			var dest: Vector2i = gp + DIRS[dn] * dist
			if visited.has(dest): continue
			visited[dest] = true
			queue.append(dest)

			var inst      = room_instances.get(gp)
			var dest_inst = room_instances.get(dest)
			if inst == null or dest_inst == null: continue

			var src_exit  = inst.get_node_or_null("Exit" + dn.capitalize())
			var dst_exit  = dest_inst.get_node_or_null("Exit" + opp[dn].capitalize())
			if src_exit == null or dst_exit == null: continue

			var src_trig  = src_exit.get_node_or_null("DoorTrigger")
			var dst_trig  = dst_exit.get_node_or_null("DoorTrigger")
			if src_trig == null or dst_trig == null: continue

			# Gap = how far each room's outer wall extends past its door trigger
			# + a walkable corridor of COR_LEN tiles (scaled by dist for long corridors).
			# This prevents wall tiles from two different rooms from overlapping.
			var src_reach    = _wall_outreach(inst,      src_trig, dn)
			var dst_reach    = _wall_outreach(dest_inst, dst_trig, opp[dn])
			var gap          = dir_v[dn] * (src_reach + float(COR_LEN * TILE * dist) + dst_reach)
			var target_world = src_trig.global_position + gap

			# How far is dst_trig from its rnode (at current initial position)
			var trig_offset  = dst_trig.global_position - room_nodes[dest].global_position

			# Reposition so dst_trig lands at target_world
			room_nodes[dest].position = target_world - trig_offset

			# Lock the perpendicular axis so rooms stay on the same grid line.
			# North/south neighbours share the same X as the source room;
			# east/west neighbours share the same Y.
			match dn:
				"north", "south":
					room_nodes[dest].position.x = room_nodes[gp].position.x
				"east", "west":
					room_nodes[dest].position.y = room_nodes[gp].position.y

# Returns the distance (px) from a door trigger's world position to the outer
# face of the wall tiles in direction `dn` (the side facing the corridor).
# This is measured from the actual Wall/Walls TileMapLayer in the room scene,
# so custom-sized rooms (boss, treasure, etc.) are handled automatically.
# Falls back to the WALL_T constant if no wall layer is found.
func _wall_outreach(inst: Node2D, trig: Area2D, dn: String) -> float:
	var wall: TileMapLayer = null
	for child in inst.get_children():
		if child is TileMapLayer and child.name in ["Wall", "Walls"]:
			wall = child
			break
	if wall == null or wall.tile_set == null:
		return float(WALL_T * TILE)

	var cells = wall.get_used_cells()
	if cells.is_empty(): return float(WALL_T * TILE)

	var ts = wall.tile_set.tile_size   # tile size in local pixels, e.g. (16,16)
	var tw = trig.global_position

	match dn:
		"east":
			var max_wx := -INF
			for c in cells:
				var wx = wall.to_global(wall.map_to_local(c) + Vector2(ts.x * 0.5, 0.0)).x
				if wx > max_wx: max_wx = wx
			return max(0.0, max_wx - tw.x)
		"west":
			var min_wx := INF
			for c in cells:
				var wx = wall.to_global(wall.map_to_local(c) + Vector2(-ts.x * 0.5, 0.0)).x
				if wx < min_wx: min_wx = wx
			return max(0.0, tw.x - min_wx)
		"south":
			var max_wy := -INF
			for c in cells:
				var wy = wall.to_global(wall.map_to_local(c) + Vector2(0.0, ts.y * 0.5)).y
				if wy > max_wy: max_wy = wy
			return max(0.0, max_wy - tw.y)
		"north":
			var min_wy := INF
			for c in cells:
				var wy = wall.to_global(wall.map_to_local(c) + Vector2(0.0, -ts.y * 0.5)).y
				if wy < min_wy: min_wy = wy
			return max(0.0, tw.y - min_wy)

	return float(WALL_T * TILE)

# ── World-space AABB from wall tiles ─────────────────────────────────────────
# Returns the tight bounding box of the outermost wall-tile edges in world space.
# Used for overlap detection after room placement.  Falls back to _room_inner_rect
# + wall thickness when no Wall layer is present.
func _room_world_rect(gp: Vector2i) -> Rect2:
	var inst = room_instances.get(gp)
	var rnode = room_nodes.get(gp)
	if inst == null or rnode == null:
		return _room_inner_rect(gp).grow(WALL_T * TILE)

	var wall: TileMapLayer = null
	for child in inst.get_children():
		if child is TileMapLayer and child.name in ["Wall", "Walls"]:
			wall = child
			break

	if wall == null or wall.tile_set == null or wall.get_used_cells().is_empty():
		return _room_inner_rect(gp).grow(WALL_T * TILE)

	var ts   = wall.tile_set.tile_size
	var hw   = ts.x * 0.5
	var hh   = ts.y * 0.5
	var min_x :=  INF;  var max_x := -INF
	var min_y :=  INF;  var max_y := -INF
	for c in wall.get_used_cells():
		var wpos = wall.to_global(wall.map_to_local(c))
		if wpos.x - hw < min_x: min_x = wpos.x - hw
		if wpos.x + hw > max_x: max_x = wpos.x + hw
		if wpos.y - hh < min_y: min_y = wpos.y - hh
		if wpos.y + hh > max_y: max_y = wpos.y + hh
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

# ── Post-placement overlap resolution ────────────────────────────────────────
# After _realign_rooms() positions rooms, some large custom rooms (boss, treasure)
# may still have wall-tile AABBs that overlap a non-connected neighbour.
# This pass iterates all room pairs and pushes overlapping rooms apart along
# their separation axis until every pair is clear.
# A small margin (TILE pixels) is kept between any two rooms.
const OVERLAP_MARGIN    := 2    # extra tiles of clearance between non-connected rooms
const OVERLAP_MAX_ITER  := 50   # more iterations so complex clusters converge

func _resolve_overlaps():
	var gps: Array = rooms.keys()
	var margin := float(OVERLAP_MARGIN * TILE)
	var changed := true
	var iter := 0
	while changed and iter < OVERLAP_MAX_ITER:
		changed = false
		iter += 1
		for i in gps.size():
			for j in range(i + 1, gps.size()):
				var gp_a: Vector2i = gps[i]
				var gp_b: Vector2i = gps[j]

				var rect_a := _room_world_rect(gp_a)
				var rect_b := _room_world_rect(gp_b)

				# Connected rooms are normally spaced by _realign_rooms, so skip
				# them here UNLESS their bounding boxes actually intersect.
				# Intersection means _realign_rooms partially failed for this pair
				# (e.g. a room was repositioned by a different BFS parent and ended
				# up inside a connected neighbour) — push them apart anyway.
				if _rooms_connected(gp_a, gp_b) and not rect_a.intersects(rect_b):
					continue

				var expanded_a := rect_a.grow(margin * 0.5)
				var expanded_b := rect_b.grow(margin * 0.5)
				if not expanded_a.intersects(expanded_b): continue

				# Compute overlap on each axis and push along the smaller one.
				var cx_a := rect_a.get_center().x
				var cx_b := rect_b.get_center().x
				var cy_a := rect_a.get_center().y
				var cy_b := rect_b.get_center().y

				var overlap_x: float = (rect_a.size.x + rect_b.size.x) * 0.5 + margin - abs(cx_a - cx_b)
				var overlap_y: float = (rect_a.size.y + rect_b.size.y) * 0.5 + margin - abs(cy_a - cy_b)

				# Push along the axis with least overlap.
				# For non-connected rooms: move only room_b (BFS order means room_a
				# has stable door-alignment and should anchor in place).
				# For connected rooms that are actually intersecting: split the push
				# symmetrically so neither room's door-alignment is unfairly distorted.
				var push: Vector2
				if overlap_x < overlap_y:
					push = Vector2(overlap_x if cx_b >= cx_a else -overlap_x, 0.0)
				else:
					push = Vector2(0.0, overlap_y if cy_b >= cy_a else -overlap_y)

				if _rooms_connected(gp_a, gp_b):
					# Symmetric split — both rooms move half the push
					room_nodes[gp_a].position -= push * 0.5
					room_nodes[gp_b].position += push * 0.5
				else:
					room_nodes[gp_b].position += push
				changed = true

# Returns true when gp_a and gp_b share a direct door connection (dist 1 or 2).
func _rooms_connected(gp_a: Vector2i, gp_b: Vector2i) -> bool:
	if not rooms.has(gp_a): return false
	for dn in rooms[gp_a]["doors"]:
		var dist: int = rooms[gp_a]["doors"][dn]
		if gp_a + DIRS[dn] * dist == gp_b: return true
	return false

func _setup_door_teleports():
	var opposite = {"north": "south", "south": "north", "east": "west", "west": "east"}
	for gp in rooms.keys():
		door_triggers[gp] = []
		for dn in rooms[gp]["doors"]:
			var dist: int   = rooms[gp]["doors"][dn]
			var nbr: Vector2i = gp + DIRS[dn] * dist
			_add_door_trigger(gp, dn, nbr, opposite[dn])

func _add_door_trigger(gp: Vector2i, dn: String, dest_gp: Vector2i, dest_dn: String):
	var inst      = room_instances.get(gp)
	var dest_inst = room_instances.get(dest_gp)

	# Use only pre-placed DoorTrigger Area2D inside Exit{Dir}/DoorTrigger
	var area: Area2D = null
	if inst:
		var exit_node = inst.get_node_or_null("Exit" + dn.capitalize())
		if exit_node:
			var pre = exit_node.get_node_or_null("DoorTrigger")
			if pre is Area2D: area = pre

	if area == null:
		return  # No pre-placed trigger — skip this door

	area.collision_layer = 0
	area.collision_mask  = 1
	area.monitoring  = true
	area.monitorable = false

	# ── Arrival: just inside the destination door trigger, pushed inward ────
	var dsc  = 1.0 if dest_inst == null else dest_inst.scale.x
	var dT   = float(TILE) * dsc
	var _arrive: Vector2

	# Try to land the player right next to the matching DoorTrigger in the
	# destination room so they appear at the door they walked through.
	var dest_exit_node = null
	if dest_inst:
		dest_exit_node = dest_inst.get_node_or_null("Exit" + dest_dn.capitalize())
	var dest_trigger: Area2D = null
	if dest_exit_node:
		var pre = dest_exit_node.get_node_or_null("DoorTrigger")
		if pre is Area2D:
			dest_trigger = pre

	if dest_trigger != null:
		# For horizontal doors (east/west) the trigger Y may not be centred,
		# so use the room's vertical centre for Y and the trigger's X + offset.
		# For vertical doors (north/south) mirror the same logic on the X axis.
		var room_center := _room_center(dest_gp)
		match dest_dn:
			"east":
				_arrive =Vector2(dest_trigger.global_position.x - dT * 0.5, room_center.y)
			"west":
				_arrive =Vector2(dest_trigger.global_position.x + dT * 0.5, room_center.y)
			"north":
				_arrive =Vector2(room_center.x, dest_trigger.global_position.y + dT * 0.5)
			"south":
				_arrive =Vector2(room_center.x, dest_trigger.global_position.y - dT * 0.5)
			_:
				_arrive =room_center
	else:
		# Fallback: one tile inside the inner rect edge
		var dir = _room_inner_rect(dest_gp)
		match dest_dn:
			"north": _arrive =Vector2(dir.get_center().x, dir.position.y + dT)
			"south": _arrive =Vector2(dir.get_center().x, dir.end.y   - dT)
			"east":  _arrive =Vector2(dir.end.x - dT,     dir.get_center().y)
			"west":  _arrive =Vector2(dir.position.x + dT, dir.get_center().y)
			_: _arrive =_room_center(dest_gp)

	door_triggers[gp].append(area)

	var cap_dest_gp = dest_gp
	var cap_dn      = dn   # direction the player is travelling through

	area.body_entered.connect(func(body):
		if not body.is_in_group("player"): return
		if _door_cooldown > 0.0: return
		_door_cooldown = 0.1

		# Compute arrival from the destination room's inner rect so the player
		# always lands inside the playable floor, never in a wall tile.
		var ir  : Rect2  = _room_inner_rect(cap_dest_gp)
		# Small inset so the player is clearly on the floor (half a tile).
		var pad : float  = float(TILE) * 0.5
		var final_pos : Vector2

		match cap_dn:
			"east":   # exited east → arrive just inside west wall of dest
				final_pos = Vector2(
					ir.position.x + pad,
					clampf(body.global_position.y, ir.position.y + pad, ir.end.y - pad))
			"west":   # exited west → arrive just inside east wall of dest
				final_pos = Vector2(
					ir.end.x - pad,
					clampf(body.global_position.y, ir.position.y + pad, ir.end.y - pad))
			"north":  # exited north → arrive just inside south wall of dest
				final_pos = Vector2(
					clampf(body.global_position.x, ir.position.x + pad, ir.end.x - pad),
					ir.end.y - pad)
			"south":  # exited south → arrive just inside north wall of dest
				final_pos = Vector2(
					clampf(body.global_position.x, ir.position.x + pad, ir.end.x - pad),
					ir.position.y + pad)
			_:
				final_pos = ir.get_center()

		body.global_position = final_pos
		call_deferred("_enter_room", cap_dest_gp))

func _add_room_trigger(gp: Vector2i, parent: Node2D):
	var ir   = _room_inner_rect(gp)
	var area = Area2D.new()
	area.name = "RoomTrigger"
	area.collision_layer = 0
	area.collision_mask  = 1
	area.monitoring  = true
	area.monitorable = false
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new()
	shp.size = ir.size
	col.shape = shp
	area.position = ir.get_center() - parent.position  # local space
	area.add_child(col)
	parent.add_child(area)
	var captured = gp
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			call_deferred("_enter_room", captured))

# Lock / unlock exits: show Lock nodes for visual feedback and disable/enable
# door teleport triggers so the player can't escape mid-combat.
func _lock_doors(gp: Vector2i):
	for lock in door_locks.get(gp, []):
		lock.visible = true
		for child in lock.get_children():
			if child is StaticBody2D:
				child.collision_layer = 1
	for trigger in door_triggers.get(gp, []):
		trigger.set_deferred("monitoring", false)

func _unlock_doors(gp: Vector2i):
	for lock in door_locks.get(gp, []):
		lock.visible = false
		for child in lock.get_children():
			if child is StaticBody2D:
				child.collision_layer = 0
	for trigger in door_triggers.get(gp, []):
		trigger.set_deferred("monitoring", true)

func _enter_room(gp: Vector2i):
	if rooms[gp].get("activated", false): return
	current_room_pos = gp
	rooms[gp]["visited"]   = true
	rooms[gp]["activated"] = true
	emit_signal("minimap_updated")
	_check_boss_proximity(gp)
	is_room_cleared = rooms[gp].get("cleared", false)
	if is_room_cleared: return

	var rt = rooms[gp]["type"]
	match rt:
		RoomType.START:
			rooms[gp]["cleared"] = true
			is_room_cleared = true
		RoomType.NORMAL:
			_lock_doors(gp)
			_spawn_enemies(gp)
		RoomType.BOSS:
			_lock_doors(gp)
			_spawn_boss(gp)
		RoomType.TREASURE, RoomType.SHOP:
			rooms[gp]["cleared"] = true
			is_room_cleared = true

func _check_boss_proximity(gp: Vector2i) -> void:
	# Skip if this room IS the boss room
	if rooms[gp].get("type") == RoomType.BOSS: return
	# Check all 4 cardinal neighbours
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var nb = gp + dir
		if rooms.has(nb) and rooms[nb].get("type") == RoomType.BOSS:
			_show_boss_warning()
			return

func _show_boss_warning() -> void:
	var lbl = Label.new()
	lbl.text = "👹  A powerful presence lurks nearby..."
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0

	var canvas = CanvasLayer.new()
	canvas.layer = 10
	canvas.add_child(lbl)
	get_tree().current_scene.add_child(canvas)

	# Position label in the upper-center area of the screen
	lbl.position = Vector2(-300, -180)
	lbl.custom_minimum_size = Vector2(600, 40)

	var tween = canvas.create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(2.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(canvas.queue_free)

func _process(delta):
	if _door_cooldown > 0.0:
		_door_cooldown -= delta
	# Track which room the player is currently in for minimap
	var pl = get_tree().get_first_node_in_group("player")
	if pl:
		for gp in rooms.keys():
			if _room_inner_rect(gp).has_point(pl.global_position):
				if gp != current_room_pos:
					current_room_pos = gp
					emit_signal("minimap_updated")

const ENEMY_MIN_PLAYER_DIST = 250.0   # pixels — enemies won't spawn closer than this

func _spawn_enemies(gp: Vector2i):
	var ir     = _room_inner_rect(gp)
	var center = ir.get_center()
	var count  = 5 + GameManager.floor_number * 4
	var delay  = max(0.04, 0.18 - GameManager.floor_number * 0.01)
	_enemies_spawning += count
	for _i in count:
		await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self): return
		var pl = get_tree().get_first_node_in_group("player")
		var angle = randf() * TAU
		var dist  = randf_range(150, min(300, ir.size.x * 0.35))
		var pos   = center + Vector2(cos(angle), sin(angle)) * dist
		# Push the spawn point away from the player if it lands too close.
		if pl:
			var to_player = pl.global_position - pos
			var d = to_player.length()
			if d < ENEMY_MIN_PLAYER_DIST and d > 0.0:
				var away = (center - pl.global_position).normalized()
				dist = randf_range(
					max(150, ENEMY_MIN_PLAYER_DIST),
					min(300, ir.size.x * 0.35)
				)
				pos = center + away.rotated(randf_range(-0.8, 0.8)) * dist
		# Clamp inside the room's inner rect with one tile of wall clearance.
		var safe = ir.grow(-float(TILE))
		pos = Vector2(clamp(pos.x, safe.position.x, safe.end.x),
					  clamp(pos.y, safe.position.y, safe.end.y))
		# Pick enemy type — shooters become more common on higher floors
		var shooter_chance = clamp((GameManager.floor_number - 1) * 0.20, 0.0, 0.60)
		var scene = EnemyShooter if randf() < shooter_chance else EnemySpider
		var e = scene.instantiate()
		e.global_position = pos
		e.enemy_died.connect(_on_enemy_died.bind(gp))
		get_tree().current_scene.add_child(e)
		enemies_alive += 1
		_enemies_spawning -= 1
		# Elite variant — bigger, faster, tougher; chance grows per floor (cap 45 %)
		var elite_chance = clamp(0.10 + (GameManager.floor_number - 1) * 0.06, 0.0, 0.45)
		if randf() < elite_chance:
			e.max_health    = int(e.max_health * 2.2)
			e.current_health = e.max_health
			e.damage        = int(e.damage * 1.6)
			e.move_speed    *= 1.4
			var v = e.get_node_or_null("Visual")
			if v:
				v.modulate = Color(1.0, 0.55, 0.1)   # orange tint = elite
				v.scale    = Vector2(1.5, 1.5)

func _spawn_boss(gp: Vector2i):
	# Use the actual wall-tile bounds so large boss rooms are centred correctly.
	var center = _room_world_rect(gp).get_center()
	var pool := [BossScene, BossLaserScene]
	var b  = pool[randi() % pool.size()].instantiate()
	b.global_position = center + Vector2(0, -100)
	b.z_as_relative = false
	b.z_index = clampi(int(b.global_position.y), -4095, 4095)
	b.enemy_died.connect(_on_enemy_died.bind(gp))
	get_tree().current_scene.add_child(b)
	enemies_alive += 1

func _on_enemy_died(pos: Vector2, xp: int, gold: int, gp: Vector2i):
	enemies_alive -= 1

	# Spawn XP gem
	var gem = XPGem.instantiate()
	gem.xp_value        = xp
	gem.global_position = pos
	get_tree().current_scene.call_deferred("add_child", gem)

	# Spawn coins — 40% chance per gold_value to drop a coin
	for i in gold:
		if randf() < 0.4:
			var coin = CoinScene.instantiate()
			coin.gold_value = 1
			var angle := randf() * TAU
			var radius := randf_range(10.0, 36.0)
			coin.global_position = pos + Vector2(cos(angle), sin(angle)) * radius
			get_tree().current_scene.call_deferred("add_child", coin)

	if enemies_alive <= 0 and _enemies_spawning <= 0:
		call_deferred("_on_room_cleared", gp)

func _on_room_cleared(gp: Vector2i):
	rooms[gp]["cleared"] = true
	is_room_cleared = true
	_unlock_doors(gp)
	emit_signal("minimap_updated")
	var rt = rooms[gp]["type"]
	var dungeon = get_tree().current_scene
	if rt == RoomType.NORMAL:
		if dungeon.has_method("show_notification"):
			dungeon.show_notification("ROOM CLEARED!", Color(0.3, 1, 0.3))
		if dungeon.has_method("shake"): dungeon.shake(0.8)
	elif rt == RoomType.BOSS:
		if dungeon.has_method("show_notification"):
			dungeon.show_notification("BOSS DEFEATED!", Color(1, 0.8, 0.0))
		if dungeon.has_method("shake"): dungeon.shake(2.0)
		await get_tree().create_timer(1.0).timeout
		_spawn_portal(gp)

func _spawn_portal(gp: Vector2i):
	# Place portal at the actual centre of the boss room (wall-tile bounds).
	var center = _room_world_rect(gp).get_center()

	# ── Animated portal visual ────────────────────────────────────────────────
	var portal = ColorRect.new()
	portal.color    = Color(0.4, 0.0, 0.8)
	portal.size     = Vector2(96, 96)
	portal.position = center - Vector2(48, 48)
	portal.name     = "Portal"
	get_tree().current_scene.add_child(portal)

	var tw = portal.create_tween()
	tw.set_loops()
	tw.tween_property(portal, "modulate:a", 0.35, 0.7)
	tw.tween_property(portal, "modulate:a", 1.00, 0.7)

	# Glow ring
	var glow = ColorRect.new()
	glow.color    = Color(0.6, 0.2, 1.0, 0.25)
	glow.size     = Vector2(140, 140)
	glow.position = center - Vector2(70, 70)
	get_tree().current_scene.add_child(glow)
	var gw = glow.create_tween()
	gw.set_loops()
	gw.tween_property(glow, "modulate:a", 0.08, 0.7)
	gw.tween_property(glow, "modulate:a", 0.35, 0.7)

	# ── Label ─────────────────────────────────────────────────────────────────
	var lbl = Label.new()
	lbl.text = "🌀  NEXT FLOOR"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(160, 34)
	lbl.position = center + Vector2(-80, -80)
	get_tree().current_scene.add_child(lbl)

	# ── Trigger area ──────────────────────────────────────────────────────────
	var area = Area2D.new()
	area.collision_layer = 0; area.collision_mask = 1; area.monitoring = true
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new(); shp.radius = 70.0
	col.shape = shp; area.position = center; area.add_child(col)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			SceneLoader.goto("res://scenes/shop.tscn"))
	get_tree().current_scene.add_child(area)

func _spawn_treasure(parent: Node2D, gp: Vector2i):
	var center = _room_inner_rect(gp).get_center() - room_nodes[gp].position
	_spawn_chest(parent, center)

func _spawn_chest(parent: Node2D, center: Vector2) -> void:
	# Pick a random weapon part — biased toward player's floor depth
	var all_parts = WeaponPartsDatabase.all()
	if all_parts.is_empty(): return

	# Weight rarer parts slightly more on deeper floors
	var weights: Array = []
	for p in all_parts:
		var w: float = 1.0
		match p.rarity:
			WeaponPart.Rarity.UNCOMMON: w = 1.0 + (GameManager.floor_number - 1) * 0.15
			WeaponPart.Rarity.RARE:     w = 0.4 + (GameManager.floor_number - 1) * 0.12
		weights.append(w)
	var total: float = 0.0
	for w in weights: total += w
	var roll := randf() * total
	var chosen: WeaponPart = all_parts[0]
	for i in all_parts.size():
		roll -= weights[i]
		if roll <= 0.0:
			chosen = all_parts[i]
			break

	var chest = load("res://scripts/chest.gd").new()
	chest.position = center
	parent.add_child(chest)
	chest.setup(chosen)

func _spawn_treasure_item(parent: Node2D, center: Vector2):
	var items = ItemDatabase.get_random_items(1)
	if items.is_empty(): return
	var item = items[0]
	var lbl = Label.new()
	lbl.text = "✨ %s\n%s\nWalk over to collect!" % [item.name, item.desc]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.position = center + Vector2(-150, -80)
	lbl.custom_minimum_size = Vector2(300, 80)
	parent.add_child(lbl)
	var icon = ColorRect.new()
	icon.color = Color(1, 0.8, 0.2)
	icon.size = Vector2(40, 40)
	icon.position = center - Vector2(20, 20)
	parent.add_child(icon)
	var area = Area2D.new()
	area.collision_layer = 0; area.collision_mask = 1; area.monitoring = true
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new(); shp.size = Vector2(80, 80)
	col.shape = shp; area.position = center; area.add_child(col)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			body.apply_item(item)
			lbl.text = "✅ Picked up %s!" % item.name
			icon.call_deferred("queue_free")
			area.call_deferred("queue_free"))
	parent.add_child(area)

func _spawn_treasure_chip(parent: Node2D, center: Vector2):
	# Pick a random weapon part weighted toward the player's floor depth.
	var all_parts = WeaponPartsDatabase.all()
	if all_parts.is_empty(): return
	var part: WeaponPart = all_parts[randi() % all_parts.size()]
	GameManager.mark_seen(part.id)   # player can now see this chip's silhouette in collection

	var chip_tex_map = {
		"common":   "res://images/common_chip.png",
		"uncommon": "res://images/uncommon_chip.png",
		"rare":     "res://images/rare_chip.png",
	}
	var rarity_str_map = {
		WeaponPart.Rarity.COMMON:   "common",
		WeaponPart.Rarity.UNCOMMON: "uncommon",
		WeaponPart.Rarity.RARE:     "rare",
	}
	var rarity_col_map = {
		WeaponPart.Rarity.COMMON:   Color(0.55, 0.55, 0.55),
		WeaponPart.Rarity.UNCOMMON: Color(0.15, 0.60, 1.00),
		WeaponPart.Rarity.RARE:     Color(1.00, 0.65, 0.05),
	}
	var rkey = rarity_str_map.get(part.rarity, "common")
	var rcol = rarity_col_map.get(part.rarity, Color.GRAY)

	# Chip sprite
	var chip_spr: Node2D = null
	var tex_path = chip_tex_map.get(rkey, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		chip_spr = Sprite2D.new()
		chip_spr.texture        = load(tex_path)
		chip_spr.scale          = Vector2(3, 3)
		chip_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chip_spr.position       = center
		parent.add_child(chip_spr)

	var lbl = Label.new()
	lbl.text = "🔧 %s\n%s\n[I] to manage chips" % [part.name, part.desc]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.position = center + Vector2(-150, -90)
	lbl.custom_minimum_size = Vector2(300, 80)
	parent.add_child(lbl)

	var rarity_lbl = Label.new()
	rarity_lbl.text = rkey.to_upper()
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	rarity_lbl.add_theme_color_override("font_color", rcol)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.position = center + Vector2(-60, 36)
	rarity_lbl.custom_minimum_size = Vector2(120, 20)
	parent.add_child(rarity_lbl)

	var area = Area2D.new()
	area.collision_layer = 0; area.collision_mask = 1; area.monitoring = true
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new(); shp.size = Vector2(80, 80)
	col.shape = shp; area.position = center; area.add_child(col)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			GameManager.add_part_to_inventory(part.id)
			lbl.text = "✅ Got %s!\nOpen inventory [I] to equip it." % part.name
			rarity_lbl.call_deferred("queue_free")
			if chip_spr: chip_spr.call_deferred("queue_free")
			area.call_deferred("queue_free"))
	parent.add_child(area)

func _spawn_shop(parent: Node2D, gp: Vector2i):
	var room = rooms[gp]
	_nearby_shop_slot = {}
	if room["shop_items"] == null:
		room["shop_items"] = ItemDatabase.get_random_items(3)
		room["shop_bought"] = {}
	var items  = room["shop_items"]
	var bought = room["shop_bought"]
	var center = _room_inner_rect(gp).get_center() - room_nodes[gp].position

	var container_tex = load("res://images/shop_container.png")
	var chip_tex = {
		"common":   load("res://images/common_chip.png"),
		"uncommon": load("res://images/uncommon_chip.png"),
		"rare":     load("res://images/rare_chip.png"),
	}
	var costs = {"common": 10, "uncommon": 25, "rare": 45}

	# Rarity colours for card borders and text
	var rarity_border = {
		"common":   Color(0.38, 0.50, 0.65),
		"uncommon": Color(0.15, 0.55, 1.00),
		"rare":     Color(1.00, 0.72, 0.10),
	}
	var rarity_label_col = {
		"common":   Color(0.62, 0.70, 0.85),
		"uncommon": Color(0.30, 0.70, 1.00),
		"rare":     Color(1.00, 0.82, 0.25),
	}
	var rarity_names = {"common": "COMMON", "uncommon": "UNCOMMON", "rare": "RARE"}

	# ── Special slots: Heart / Key (50% chance each, placed below main items) ─
	_spawn_shop_special_slots(parent, center, room, gp)

	var offsets = [Vector2(-200, 0), Vector2(0, 0), Vector2(200, 0)]
	for i in items.size():
		if i >= offsets.size(): break
		var item      = items[i]
		var rarity    = item.get("rarity", "common") as String
		var cost      = costs.get(rarity, 15) as int
		var is_bought = bought.get(i, false) as bool
		var b_col     = rarity_border.get(rarity,   rarity_border["common"])   as Color
		var lc        = rarity_label_col.get(rarity, rarity_label_col["common"]) as Color

		var slot = Node2D.new()
		slot.position = center + offsets[i]
		parent.add_child(slot)

		# ── Sprite container ─────────────────────────────────────────────
		var ctr = Sprite2D.new()
		ctr.texture = container_tex; ctr.scale = Vector2(3, 3); ctr.centered = true
		ctr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ctr.modulate = Color(0.45, 0.45, 0.48, 0.70) if is_bought else Color.WHITE
		slot.add_child(ctr)

		var chip = Sprite2D.new()
		chip.texture = chip_tex.get(rarity, chip_tex["common"])
		chip.scale = Vector2(3, 3); chip.centered = true; chip.position = Vector2(0, -10)
		chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chip.modulate = Color(0.35, 0.35, 0.38, 0.45) if is_bought else Color.WHITE
		slot.add_child(chip)

		# ── Floor collision so player can't walk through the stand ────────
		var sb = StaticBody2D.new(); sb.position = Vector2(0, 57)
		var sc = CollisionShape2D.new(); var ss = RectangleShape2D.new()
		ss.size = Vector2(144, 30); sc.shape = ss; sb.add_child(sc); slot.add_child(sb)

		# ── Info card (shown on proximity) ────────────────────────────────
		# Build stat rows first so card height can adapt to stat count.
		var stat_lines := _item_stat_lines(item)
		var n_stats    := stat_lines.size()

		# height: 5 strip + 17 rarity + 22 name + 8 sep + n*20 stats + 8 sep + 22 price
		var card_w  := 240
		var card_h  := 82 + n_stats * 20
		var card_ox := -card_w / 2.0
		var card_oy := -(card_h + 88)

		# Card background
		var card_bg = ColorRect.new()
		card_bg.color    = Color(0.04, 0.05, 0.12, 0.96)
		card_bg.size     = Vector2(card_w, card_h)
		card_bg.position = Vector2(card_ox, card_oy)
		card_bg.visible  = is_bought
		slot.add_child(card_bg)

		# Rarity colour strip along the top
		var strip = ColorRect.new()
		strip.color    = b_col.darkened(0.25)
		strip.size     = Vector2(card_w, 5)
		strip.position = Vector2(card_ox, card_oy)
		strip.visible  = is_bought
		slot.add_child(strip)

		# Rarity badge
		var rarity_lbl = Label.new()
		rarity_lbl.text = rarity_names.get(rarity, "COMMON")
		rarity_lbl.add_theme_font_size_override("font_size", 10)
		rarity_lbl.add_theme_color_override("font_color", lc)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.position = Vector2(card_ox, card_oy + 6)
		rarity_lbl.custom_minimum_size = Vector2(card_w, 15)
		rarity_lbl.visible = false
		slot.add_child(rarity_lbl)

		# Item name
		var name_lbl = Label.new()
		name_lbl.text = "✅  Sold" if is_bought else item.name
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color",
			Color(0.45, 0.45, 0.50) if is_bought else Color(0.92, 0.95, 1.0))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(card_ox + 6, card_oy + 22)
		name_lbl.custom_minimum_size = Vector2(card_w - 12, 20)
		name_lbl.visible = is_bought
		slot.add_child(name_lbl)

		# Separator below name
		var stat_div = ColorRect.new()
		stat_div.color    = b_col.darkened(0.50)
		stat_div.size     = Vector2(card_w - 24, 1)
		stat_div.position = Vector2(card_ox + 12, card_oy + 44)
		stat_div.visible  = false
		slot.add_child(stat_div)

		# Per-stat rows — one label each, green for buffs, red for debuffs
		var stat_lbls: Array = []
		for si in n_stats:
			var sd  = stat_lines[si]
			var sl  = Label.new()
			sl.text = sd["text"]
			sl.add_theme_font_size_override("font_size", 13)
			sl.add_theme_color_override("font_color",
				Color(0.30, 0.90, 0.45) if sd["positive"] else Color(1.0, 0.35, 0.35))
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sl.position = Vector2(card_ox + 6, card_oy + 48 + si * 20)
			sl.custom_minimum_size = Vector2(card_w - 12, 18)
			sl.visible = false
			slot.add_child(sl)
			stat_lbls.append(sl)

		# Separator above price
		var price_div = ColorRect.new()
		price_div.color    = b_col.darkened(0.50)
		price_div.size     = Vector2(card_w - 24, 1)
		price_div.position = Vector2(card_ox + 12, card_oy + 50 + n_stats * 20)
		price_div.visible  = false
		slot.add_child(price_div)

		# Price
		var price_lbl = Label.new()
		price_lbl.text = "💰  %d g" % cost if not is_bought else ""
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.position = Vector2(card_ox + 6, card_oy + 54 + n_stats * 20)
		price_lbl.custom_minimum_size = Vector2(card_w - 12, 22)
		price_lbl.visible = false
		slot.add_child(price_lbl)

		# ── Buy prompt bar ────────────────────────────────────────────────
		var prompt_bg = ColorRect.new()
		prompt_bg.color    = b_col.darkened(0.45)
		prompt_bg.size     = Vector2(160, 30)
		prompt_bg.position = Vector2(-80, 86)
		prompt_bg.visible  = false
		slot.add_child(prompt_bg)

		var prompt_lbl = Label.new()
		prompt_lbl.text = "[ E ]  Buy" if not is_bought else ""
		prompt_lbl.add_theme_font_size_override("font_size", 14)
		prompt_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-80, 88)
		prompt_lbl.custom_minimum_size = Vector2(160, 26)
		prompt_lbl.visible = false
		slot.add_child(prompt_lbl)

		# ── Proximity trigger ─────────────────────────────────────────────
		var prox = Area2D.new()
		prox.collision_layer = 0; prox.collision_mask = 1
		prox.monitoring = true; prox.monitorable = false
		var pc = CollisionShape2D.new(); var ps = RectangleShape2D.new()
		ps.size = Vector2(200, 200); pc.shape = ps; prox.add_child(pc); slot.add_child(prox)

		var slot_data = {
			"item": item, "cost": cost, "room": room, "index": i,
			"bought": is_bought,
			"card_bg": card_bg, "strip": strip,
			"rarity_lbl": rarity_lbl, "name_lbl": name_lbl,
			"stat_lbls": stat_lbls, "stat_div": stat_div, "price_div": price_div,
			"price_lbl": price_lbl,
			"prompt_bg": prompt_bg, "prompt_lbl": prompt_lbl,
			"container": ctr, "chip": chip,
		}

		prox.body_entered.connect(func(body):
			if not body.is_in_group("player"): return
			if slot_data["bought"]: return
			_nearby_shop_slot = slot_data
			card_bg.visible    = true;  strip.visible      = true
			rarity_lbl.visible = true;  name_lbl.visible   = true
			stat_div.visible   = true;  price_div.visible  = true
			price_lbl.visible  = true
			for sl in slot_data["stat_lbls"]: sl.visible = true
			prompt_bg.visible  = true;  prompt_lbl.visible = true)

		prox.body_exited.connect(func(body):
			if not body.is_in_group("player"): return
			if _nearby_shop_slot.get("index", -1) == slot_data["index"]:
				_nearby_shop_slot = {}
			card_bg.visible    = slot_data["bought"]
			strip.visible      = slot_data["bought"]
			name_lbl.visible   = slot_data["bought"]
			rarity_lbl.visible = false; stat_div.visible   = false
			price_div.visible  = false; price_lbl.visible  = false
			for sl in slot_data["stat_lbls"]: sl.visible = false
			prompt_bg.visible  = false; prompt_lbl.visible = false)

func _spawn_shop_special_slots(parent: Node2D, center: Vector2, room: Dictionary, _gp: Vector2i):
	if not room.has("special_bought"):
		room["special_bought"] = {}
		room["has_heart"] = randf() < 0.5
		room["has_key"]   = randf() < 0.5

	var specials := []
	if room["has_heart"]: specials.append({"kind": "heart", "label": "❤ Half Heart", "desc": "+1 Max HP", "cost": 20, "color": Color(0.85, 0.20, 0.25)})
	if room["has_key"]:   specials.append({"kind": "key",   "label": "🔑 Key",        "desc": "Opens a chest", "cost": 18, "color": Color(0.90, 0.78, 0.15)})

	var sx_offsets = [Vector2(-100, 130), Vector2(100, 130)]
	for i in specials.size():
		var sp       = specials[i]
		var is_bought = room["special_bought"].get(sp["kind"], false)
		var b_col    = sp["color"] as Color
		var slot     = Node2D.new()
		slot.position = center + sx_offsets[i]
		parent.add_child(slot)

		var container_tex = load("res://images/shop_container.png")
		var ctr = Sprite2D.new()
		ctr.texture = container_tex; ctr.scale = Vector2(3, 3); ctr.centered = true
		ctr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ctr.modulate = Color(0.45, 0.45, 0.48, 0.70) if is_bought else Color.WHITE
		slot.add_child(ctr)

		var sb = StaticBody2D.new(); sb.position = Vector2(0, 57)
		var sc2 = CollisionShape2D.new(); var ss = RectangleShape2D.new()
		ss.size = Vector2(144, 30); sc2.shape = ss; sb.add_child(sc2); slot.add_child(sb)

		var card_w := 200; var card_h := 90
		var card_ox := -card_w / 2.0; var card_oy := -(card_h + 88)

		var card_bg = ColorRect.new()
		card_bg.color = Color(0.04, 0.05, 0.12, 0.96)
		card_bg.size = Vector2(card_w, card_h); card_bg.position = Vector2(card_ox, card_oy)
		card_bg.visible = is_bought; slot.add_child(card_bg)

		var strip = ColorRect.new()
		strip.color = b_col.darkened(0.25); strip.size = Vector2(card_w, 5)
		strip.position = Vector2(card_ox, card_oy); strip.visible = is_bought; slot.add_child(strip)

		var name_lbl = Label.new()
		name_lbl.text = "✅  Sold" if is_bought else sp["label"]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.45,0.45,0.50) if is_bought else Color(0.92,0.95,1.0))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(card_ox + 6, card_oy + 10); name_lbl.custom_minimum_size = Vector2(card_w - 12, 20)
		name_lbl.visible = is_bought; slot.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = sp["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.position = Vector2(card_ox + 6, card_oy + 36); desc_lbl.custom_minimum_size = Vector2(card_w - 12, 18)
		desc_lbl.visible = false; slot.add_child(desc_lbl)

		var price_lbl = Label.new()
		price_lbl.text = "💰  %d g" % sp["cost"] if not is_bought else ""
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.position = Vector2(card_ox + 6, card_oy + 60); price_lbl.custom_minimum_size = Vector2(card_w - 12, 22)
		price_lbl.visible = false; slot.add_child(price_lbl)

		var prompt_bg = ColorRect.new()
		prompt_bg.color = b_col.darkened(0.45); prompt_bg.size = Vector2(160, 30)
		prompt_bg.position = Vector2(-80, 86); prompt_bg.visible = false; slot.add_child(prompt_bg)

		var prompt_lbl = Label.new()
		prompt_lbl.text = "[ E ]  Buy" if not is_bought else ""
		prompt_lbl.add_theme_font_size_override("font_size", 14)
		prompt_lbl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-80, 88); prompt_lbl.custom_minimum_size = Vector2(160, 26)
		prompt_lbl.visible = false; slot.add_child(prompt_lbl)

		var prox = Area2D.new()
		prox.collision_layer = 0; prox.collision_mask = 1
		prox.monitoring = true; prox.monitorable = false
		var pc = CollisionShape2D.new(); var ps = RectangleShape2D.new()
		ps.size = Vector2(200, 200); pc.shape = ps; prox.add_child(pc); slot.add_child(prox)

		var slot_data = {
			"kind": sp["kind"], "cost": sp["cost"], "room": room,
			"bought": is_bought, "b_col": b_col,
			"card_bg": card_bg, "strip": strip, "name_lbl": name_lbl,
			"desc_lbl": desc_lbl, "price_lbl": price_lbl,
			"prompt_bg": prompt_bg, "prompt_lbl": prompt_lbl, "container": ctr,
		}

		prox.body_entered.connect(func(body):
			if not body.is_in_group("player"): return
			if slot_data["bought"]: return
			_nearby_shop_slot = slot_data
			card_bg.visible = true; strip.visible = true; name_lbl.visible = true
			desc_lbl.visible = true; price_lbl.visible = true
			prompt_bg.visible = true; prompt_lbl.visible = true)

		prox.body_exited.connect(func(body):
			if not body.is_in_group("player"): return
			if _nearby_shop_slot.get("kind", "") == slot_data["kind"]:
				_nearby_shop_slot = {}
			card_bg.visible = slot_data["bought"]; strip.visible = slot_data["bought"]
			name_lbl.visible = slot_data["bought"]
			desc_lbl.visible = false; price_lbl.visible = false
			prompt_bg.visible = false; prompt_lbl.visible = false)

# Converts an item's numeric fields into display rows for the shop card.
# Each entry: { text, positive } — positive drives the colour (green/red).
func _item_stat_lines(item: Dictionary) -> Array:
	var lines := []
	# [ key, display_name, kind ]
	# kind: "int" | "float" | "life"
	# forced_pos: true = always green, null = derive from sign of value
	var defs := [
		["damage",        "Damage",        "int",   true ],
		["max_health",    "Max HP",        "int",   null ],
		["speed",         "Move Speed",    "int",   null ],
		["attack_speed",  "Atk Speed",     "float", true ],
		["pickup_radius", "Pickup Range",  "int",   true ],
		["lifesteal",     "Lifesteal",     "life",  true ],
		["pierce_bonus",  "Pierce",        "int",   true ],
	]
	for d in defs:
		var key: String = d[0]
		if not item.has(key): continue
		var val        = item[key]
		var lbl: String = d[1]
		var kind: String = d[2]
		var forced_pos  = d[3]   # null or true

		var positive: bool = (forced_pos == null and float(val) >= 0.0) or (forced_pos == true)
		var sign_str := "+" if float(val) >= 0.0 else ""
		var val_str: String
		match kind:
			"float": val_str = sign_str + ("%.1f" % float(val))
			"life":  val_str = "+%d HP/kill" % int(val)
			_:       val_str = sign_str + str(int(val))

		var arrow := "▲" if positive else "▼"
		lines.append({"text": "%s %s   %s" % [arrow, lbl, val_str], "positive": positive})
	return lines

func _buy_from_shop(slot: Dictionary):
	if slot.get("bought", false): return
	if not GameManager.spend_gold(slot["cost"]):
		# Flash the prompt red to signal "not enough gold"
		var pl : Label = slot["prompt_lbl"]
		var pb : ColorRect = slot["prompt_bg"]
		var orig_text  := pl.text
		var orig_color := pb.color
		pl.text   = "Not enough gold!"
		pl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		pb.color  = Color(0.25, 0.04, 0.04, 0.92)
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(pl):
			pl.text = orig_text
			pl.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
			pb.color = orig_color
		return
	var pl_node = get_tree().get_first_node_in_group("player")

	# Handle special slots (heart / key)
	if slot.has("kind"):
		match slot["kind"]:
			"heart":
				GameManager.p_max_health += 1
				GameManager.p_current_health = min(GameManager.p_current_health + 1, GameManager.p_max_health)
				if pl_node:
					pl_node.max_health = GameManager.p_max_health
					pl_node.current_health = GameManager.p_current_health
					pl_node.emit_signal("health_changed", pl_node.current_health, pl_node.max_health)
			"key":
				GameManager.add_key()
		slot["room"]["special_bought"][slot["kind"]] = true
	else:
		if pl_node: pl_node.apply_item(slot["item"])
		slot["room"]["shop_bought"][slot["index"]] = true

	slot["bought"] = true
	# Update visuals to sold state
	slot["name_lbl"].text = "✅  Sold"
	slot["name_lbl"].add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	if slot.has("stat_lbls"):
		for sl in slot["stat_lbls"]: sl.visible = false
	if slot.has("stat_div"):   slot["stat_div"].visible  = false
	if slot.has("price_div"):  slot["price_div"].visible = false
	if slot.has("desc_lbl"):   slot["desc_lbl"].visible  = false
	slot["price_lbl"].visible  = false
	slot["prompt_bg"].visible  = false
	slot["prompt_lbl"].visible = false
	slot["card_bg"].visible    = true
	slot["strip"].visible      = true
	slot["name_lbl"].visible   = true
	slot["container"].modulate = Color(0.45, 0.45, 0.48, 0.70)
	if slot.has("chip"): slot["chip"].modulate = Color(0.35, 0.35, 0.38, 0.45)
	_nearby_shop_slot = {}

func open_doors(): pass
