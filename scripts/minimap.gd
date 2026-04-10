extends Control
# Minimap display radius (in grid cells, Manhattan distance)
const MINIMAP_RADIUS := 3 # 3 means 7x7 square
const MINIMAP_SIZE := MINIMAP_RADIUS * 2 + 1
# ═══════════════════════════════════════════════════════════════════════════════
# MINIMAP  —  Gungeon-style room map
#
# Add this script to a Control node inside a CanvasLayer in dungeon.tscn.
# The node draws itself; nothing else needs to be configured.
#
# Room appearance:
#   current room   → bright white
#   cleared normal → medium grey
#   uncleared      → dim grey outline only
#   BOSS           → red tint
#   SHOP           → yellow tint
#   TREASURE       → cyan tint
#   START          → green tint
#   unvisited      → hidden (Gungeon style — only shows explored rooms)
#
# Corridors are drawn as thin filled rectangles connecting rooms.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Tunables ──────────────────────────────────────────────────────────────────
const ROOM_W    := 26     # minimap pixels per room cell (width)
const ROOM_H    := 18     # minimap pixels per room cell (height)
const COR_THICK := 5      # corridor thickness in pixels
const COR_LEN   := 8      # corridor gap length in pixels
const PADDING   := 10     # border padding inside the background panel
const STEP_X    := ROOM_W + COR_LEN
const STEP_Y    := ROOM_H + COR_LEN

# Colours
const COL_CURRENT   := Color(1.00, 1.00, 1.00, 1.00)
const COL_CLEARED   := Color(0.55, 0.55, 0.60, 0.90)
const COL_UNCLEARED := Color(0.25, 0.25, 0.28, 0.80)
const COL_START     := Color(0.30, 0.90, 0.45, 0.90)
const COL_BOSS      := Color(0.90, 0.20, 0.20, 0.90)
const COL_SHOP      := Color(1.00, 0.80, 0.20, 0.90)
const COL_TREASURE  := Color(0.25, 0.85, 1.00, 0.90)
const COL_BG        := Color(0.05, 0.05, 0.08, 0.80)
const COL_BORDER    := Color(0.25, 0.25, 0.30, 0.90)
const COL_COR       := Color(0.40, 0.40, 0.45, 0.85)
const COL_COR_UNK   := Color(0.28, 0.28, 0.32, 0.55)  # corridor to unknown room
const COL_UNKNOWN   := Color(0.15, 0.15, 0.18, 0.60)  # unknown room outline

var _mm: Node = null   # map_manager reference

func _ready():
	# Fill the full screen so _draw() can place the panel anywhere via absolute coords.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	_mm = get_tree().get_first_node_in_group("map_manager")
	if _mm:
		_mm.minimap_updated.connect(queue_redraw)
	queue_redraw()

func _draw():
	if _mm == null or _mm.rooms.is_empty():
		return

	var rooms       = _mm.rooms
	var current_pos = _mm.current_room_pos

	# Fixed square minimap centered on player
	var panel_w = MINIMAP_SIZE * STEP_X - COR_LEN + PADDING * 2
	var panel_h = MINIMAP_SIZE * STEP_Y - COR_LEN + PADDING * 2

	# Top-right corner of the actual viewport, with a comfortable margin
	var vp  = get_viewport_rect().size
	var ox  = vp.x - panel_w - 20
	var oy  = 20

	# The top-left grid cell to draw (so player is always centered)
	var grid_min_x = current_pos.x - MINIMAP_RADIUS
	var grid_min_y = current_pos.y - MINIMAP_RADIUS

	# ── Background panel ───────────────────────────────────────────────────────
	draw_rect(Rect2(ox - 1, oy - 1, panel_w + 2, panel_h + 2), COL_BORDER)
	draw_rect(Rect2(ox,     oy,     panel_w,     panel_h),     COL_BG)

	# ── Corridors + unknown room hints (drawn under rooms) ────────────────────
	for gp in rooms.keys():
		# Only draw corridors from rooms the player has visited
		var dx = gp.x - current_pos.x
		var dy = gp.y - current_pos.y
		var in_radius = abs(dx) <= MINIMAP_RADIUS and abs(dy) <= MINIMAP_RADIUS
		var visited   = rooms[gp].get("visited", false)
		if not ((in_radius and visited)):
			continue

		var doors = rooms[gp].get("doors", {})
		var rx = ox + PADDING + (gp.x - grid_min_x) * STEP_X
		var ry = oy + PADDING + (gp.y - grid_min_y) * STEP_Y

		for dn in doors:
			var dist: int = doors[dn]
			var neighbor_gp: Vector2i
			match dn:
				"east":  neighbor_gp = Vector2i(gp.x + dist, gp.y)
				"west":  neighbor_gp = Vector2i(gp.x - dist, gp.y)
				"south": neighbor_gp = Vector2i(gp.x, gp.y + dist)
				"north": neighbor_gp = Vector2i(gp.x, gp.y - dist)

			if not rooms.has(neighbor_gp): continue

			var nbr_visited = rooms[neighbor_gp].get("visited", false)
			var ndx = neighbor_gp.x - current_pos.x
			var ndy = neighbor_gp.y - current_pos.y
			var nbr_in_radius = abs(ndx) <= MINIMAP_RADIUS and abs(ndy) <= MINIMAP_RADIUS

			var nbr_visible = nbr_in_radius

			if not nbr_visible: continue

			# Choose corridor colour: dim if leading to an unvisited room
			var cor_col = COL_COR if (nbr_visited) else COL_COR_UNK

			match dn:
				"east":
					var cw = COR_LEN + (dist - 1) * STEP_X
					draw_rect(Rect2(rx + ROOM_W, ry + (ROOM_H - COR_THICK) / 2.0,
						cw, COR_THICK), cor_col)
				"west":
					var cw = COR_LEN + (dist - 1) * STEP_X
					draw_rect(Rect2(rx - cw, ry + (ROOM_H - COR_THICK) / 2.0,
						cw, COR_THICK), cor_col)
				"south":
					var ch = COR_LEN + (dist - 1) * STEP_Y
					draw_rect(Rect2(rx + (ROOM_W - COR_THICK) / 2.0, ry + ROOM_H,
						COR_THICK, ch), cor_col)
				"north":
					var ch = COR_LEN + (dist - 1) * STEP_Y
					draw_rect(Rect2(rx + (ROOM_W - COR_THICK) / 2.0, ry - ch,
						COR_THICK, ch), cor_col)

			# Draw a faint "?" box for the unvisited neighbour so the player knows
			# a room exists there without revealing its type.
			if not nbr_visited and nbr_visible:
				var nrx = ox + PADDING + (neighbor_gp.x - grid_min_x) * STEP_X
				var nry = oy + PADDING + (neighbor_gp.y - grid_min_y) * STEP_Y
				var unk_rect = Rect2(nrx, nry, ROOM_W, ROOM_H)
				draw_rect(unk_rect, COL_UNKNOWN)
				draw_rect(unk_rect, COL_COR_UNK, false, 1.0)
				draw_string(ThemeDB.fallback_font,
					Vector2(nrx + ROOM_W * 0.5 - 3, nry + ROOM_H * 0.5 + 4),
					"?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.6, 0.7))

	# ── Rooms (drawn on top) ──────────────────────────────────────────────────
	for gp in rooms.keys():
		var dx = gp.x - current_pos.x
		var dy = gp.y - current_pos.y
		if abs(dx) > MINIMAP_RADIUS or abs(dy) > MINIMAP_RADIUS or not rooms[gp].get("visited", false):
			continue
		var rx   = ox + PADDING + (gp.x - grid_min_x) * STEP_X
		var ry   = oy + PADDING + (gp.y - grid_min_y) * STEP_Y
		var rect = Rect2(rx, ry, ROOM_W, ROOM_H)

		var col: Color
		if gp == current_pos:
			col = COL_CURRENT
		else:
			match rooms[gp].get("type", 1):
				0: col = COL_START
				2: col = COL_TREASURE
				3: col = COL_SHOP
				4: col = COL_BOSS
				_: col = COL_CLEARED if rooms[gp].get("cleared", false) else COL_UNCLEARED

		draw_rect(rect, col)
		draw_rect(rect, COL_BORDER, false, 1.0)   # outline

		# Small letter badge for special rooms
		if gp != current_pos:
			var badge := ""
			match rooms[gp].get("type", 1):
				2: badge = "T"
				3: badge = "$"
				4: badge = "B"
			if badge != "":
				draw_string(ThemeDB.fallback_font,
					Vector2(rx + 3, ry + ROOM_H - 3),
					badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0, 0, 0, 0.85))
