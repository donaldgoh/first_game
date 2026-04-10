extends Control
# ═══════════════════════════════════════════════════════════════════════════
# FULL MAP OVERLAY
# Shown while TAB is held — a large, centred panel displaying every known
# room in the dungeon.  Release TAB to dismiss.
#
# Drop this script on a Control node inside a CanvasLayer (layer ≥ 10)
# in dungeon.tscn.  Nothing else needs to be configured.
# ═══════════════════════════════════════════════════════════════════════════

# ── Room cell dimensions (pixels, before scaling) ─────────────────────────
const ROOM_W    := 42
const ROOM_H    := 28
const COR_THICK := 7
const COR_LEN   := 12
const PADDING   := 28
const STEP_X    := ROOM_W + COR_LEN   # 54
const STEP_Y    := ROOM_H + COR_LEN   # 40

# Maximum panel size as a fraction of the viewport
const MAX_FRAC_X := 0.76
const MAX_FRAC_Y := 0.74

# ── Colour palette ─────────────────────────────────────────────────────────
const COL_OVERLAY       := Color(0.00, 0.00, 0.00, 0.72)
const COL_PANEL_BG      := Color(0.05, 0.05, 0.09, 0.97)
const COL_PANEL_BORDER  := Color(0.30, 0.30, 0.40, 1.00)
const COL_PANEL_SHADOW  := Color(0.00, 0.00, 0.00, 0.45)
const COL_BORDER        := Color(0.28, 0.28, 0.34, 0.95)
const COL_CURRENT       := Color(1.00, 1.00, 1.00, 1.00)
const COL_CLEARED       := Color(0.55, 0.55, 0.60, 0.95)
const COL_UNCLEARED     := Color(0.22, 0.22, 0.26, 0.90)
const COL_START         := Color(0.30, 0.90, 0.45, 0.95)
const COL_BOSS          := Color(0.90, 0.20, 0.20, 0.95)
const COL_SHOP          := Color(1.00, 0.80, 0.20, 0.95)
const COL_TREASURE      := Color(0.25, 0.85, 1.00, 0.95)
const COL_COR           := Color(0.40, 0.40, 0.46, 0.88)
const COL_COR_UNK       := Color(0.26, 0.26, 0.30, 0.55)
const COL_UNKNOWN       := Color(0.13, 0.13, 0.17, 0.70)
const COL_TITLE         := Color(0.80, 0.80, 0.90, 1.00)
const COL_HINT          := Color(0.50, 0.50, 0.58, 0.80)

# ── State ──────────────────────────────────────────────────────────────────
var _mm: Node         = null
var _open: bool       = false
var _blink: float     = 0.0  # seconds, drives current-room pulsing

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	_mm = get_tree().get_first_node_in_group("map_manager")
	if _mm:
		_mm.minimap_updated.connect(queue_redraw)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and not event.echo:
		var was_open := _open
		_open = event.pressed
		if _open != was_open:
			queue_redraw()

func _process(delta: float) -> void:
	if not _open:
		return
	_blink += delta
	if _blink >= 1.0:
		_blink -= 1.0
	queue_redraw()

# ── Drawing ────────────────────────────────────────────────────────────────
func _draw() -> void:
	if not _open or _mm == null or _mm.rooms.is_empty():
		return

	var rooms       : Dictionary = _mm.rooms
	var cur         : Vector2i   = _mm.current_room_pos
	var vp          : Vector2    = get_viewport_rect().size
	var font                     = ThemeDB.fallback_font

	# ── Compute bounding box of all rooms ────────────────────────────────
	var min_gx: int =  99999;  var max_gx: int = -99999
	var min_gy: int =  99999;  var max_gy: int = -99999
	for gp: Vector2i in rooms.keys():
		if gp.x < min_gx: min_gx = gp.x
		if gp.x > max_gx: max_gx = gp.x
		if gp.y < min_gy: min_gy = gp.y
		if gp.y > max_gy: max_gy = gp.y

	var grid_cols := max_gx - min_gx + 1
	var grid_rows := max_gy - min_gy + 1

	# ── Natural map size → scale to fit inside max fraction of viewport ───
	var nat_w: float = grid_cols * STEP_X - COR_LEN + PADDING * 2
	var nat_h: float = grid_rows * STEP_Y - COR_LEN + PADDING * 2
	var sc: float = minf(
		(vp.x * MAX_FRAC_X) / nat_w,
		(vp.y * MAX_FRAC_Y) / nat_h)
	sc = minf(sc, 1.0)   # never upscale — keeps it crisp at low room counts

	var panel_w := nat_w * sc
	var panel_h := nat_h * sc

	# ── Panel position — centred on screen ────────────────────────────────
	var px := (vp.x - panel_w) * 0.5
	var py := (vp.y - panel_h) * 0.5

	# Origin inside the panel (top-left of grid[0,0])
	var org_x := px + PADDING * sc
	var org_y := py + PADDING * sc

	# ── Full-screen dark tint ─────────────────────────────────────────────
	draw_rect(Rect2(0.0, 0.0, vp.x, vp.y), COL_OVERLAY)

	# ── Panel shadow ──────────────────────────────────────────────────────
	draw_rect(Rect2(px + 5.0, py + 5.0, panel_w, panel_h), COL_PANEL_SHADOW)

	# ── Panel frame & background ──────────────────────────────────────────
	draw_rect(Rect2(px - 2.0, py - 2.0, panel_w + 4.0, panel_h + 4.0), COL_PANEL_BORDER)
	draw_rect(Rect2(px, py, panel_w, panel_h), COL_PANEL_BG)

	# ── Title ─────────────────────────────────────────────────────────────
	var title := "  ─── DUNGEON MAP ───"
	draw_string(font,
		Vector2(px + panel_w * 0.5 - 60.0, py - 12.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_TITLE)

	# ── Cached scaled values ──────────────────────────────────────────────
	var rw  := ROOM_W    * sc
	var rh  := ROOM_H    * sc
	var ct  := COR_THICK * sc
	var cl  := COR_LEN   * sc
	var stx := STEP_X    * sc
	var sty := STEP_Y    * sc

	# ── Pass 1 : corridors + unknown room hints ────────────────────────────
	for gp: Vector2i in rooms.keys():
		if not rooms[gp].get("visited", false): continue

		var rx := org_x + (gp.x - min_gx) * stx
		var ry := org_y + (gp.y - min_gy) * sty

		var doors: Dictionary = rooms[gp].get("doors", {})
		for dn: String in doors:
			var dist: int = doors[dn]
			var nbr := _neighbor_gp(gp, dn, dist)
			if not rooms.has(nbr): continue

			var nbr_visited: bool = rooms[nbr].get("visited", false)
			var cor_col := COL_COR if nbr_visited else COL_COR_UNK

			match dn:
				"east":
					var cw := cl + (dist - 1) * stx
					draw_rect(Rect2(rx + rw, ry + (rh - ct) * 0.5, cw, ct), cor_col)
				"west":
					var cw := cl + (dist - 1) * stx
					draw_rect(Rect2(rx - cw, ry + (rh - ct) * 0.5, cw, ct), cor_col)
				"south":
					var ch := cl + (dist - 1) * sty
					draw_rect(Rect2(rx + (rw - ct) * 0.5, ry + rh, ct, ch), cor_col)
				"north":
					var ch := cl + (dist - 1) * sty
					draw_rect(Rect2(rx + (rw - ct) * 0.5, ry - ch, ct, ch), cor_col)

			# Unknown neighbour: faint box + "?" so the player sees a door leads
			# somewhere without knowing the room type.
			if not nbr_visited:
				var nrx := org_x + (nbr.x - min_gx) * stx
				var nry := org_y + (nbr.y - min_gy) * sty
				var unk := Rect2(nrx, nry, rw, rh)
				draw_rect(unk, COL_UNKNOWN)
				draw_rect(unk, COL_COR_UNK, false, 1.0)
				draw_string(font,
					Vector2(nrx + rw * 0.5 - 4.0, nry + rh * 0.5 + 5.0),
					"?", HORIZONTAL_ALIGNMENT_LEFT, -1,
					int(clamp(rh * 0.55, 8.0, 14.0)),
					Color(0.50, 0.50, 0.62, 0.75))

	# ── Pass 2 : rooms ────────────────────────────────────────────────────
	for gp: Vector2i in rooms.keys():
		if not rooms[gp].get("visited", false): continue

		var rx := org_x + (gp.x - min_gx) * stx
		var ry := org_y + (gp.y - min_gy) * sty
		var rect := Rect2(rx, ry, rw, rh)

		var is_cur := (gp == cur)
		var col: Color
		if is_cur:
			# Pulse: oscillate between bright and slightly dimmed
			var t := sin(_blink * TAU) * 0.5 + 0.5   # 0..1
			col = COL_CURRENT.lerp(Color(0.80, 0.90, 1.00, 0.90), t * 0.35)
		else:
			match rooms[gp].get("type", 1):
				0: col = COL_START
				2: col = COL_TREASURE
				3: col = COL_SHOP
				4: col = COL_BOSS
				_: col = COL_CLEARED if rooms[gp].get("cleared", false) else COL_UNCLEARED

		draw_rect(rect, col)
		draw_rect(rect, COL_BORDER, false, 1.0)

		# ── Badge letter ─────────────────────────────────────────────────
		var badge := ""
		if is_cur:
			badge = "★"
		else:
			match rooms[gp].get("type", 1):
				0: badge = "S"
				2: badge = "T"
				3: badge = "$"
				4: badge = "B"

		if badge != "":
			var fs := int(clamp(rh * 0.58, 8.0, 16.0))
			var badge_col := Color(0.0, 0.0, 0.0, 0.85) if is_cur \
							else Color(0.0, 0.0, 0.0, 0.75)
			draw_string(font,
				Vector2(rx + rw * 0.5 - fs * 0.3, ry + rh * 0.5 + fs * 0.35),
				badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, badge_col)

	# ── Legend ────────────────────────────────────────────────────────────
	_draw_legend(font, px, py + panel_h, vp)

	# ── Dismiss hint ──────────────────────────────────────────────────────
	draw_string(font,
		Vector2(vp.x * 0.5 - 55.0, py + panel_h + 18.0),
		"Release [TAB] to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_HINT)


func _draw_legend(font: Font, _px: float, panel_bottom: float, vp: Vector2) -> void:
	var items := [
		[COL_CURRENT,   "You (★)"],
		[COL_START,     "Start"],
		[COL_BOSS,      "Boss"],
		[COL_SHOP,      "Shop"],
		[COL_TREASURE,  "Treasure"],
		[COL_CLEARED,   "Cleared"],
		[COL_UNCLEARED, "Uncleared"],
	]
	# Centre the legend row under the panel
	var total_w := items.size() * 80.0 - 8.0
	var lx := vp.x * 0.5 - total_w * 0.5
	var ly := panel_bottom + 16.0

	for item: Array in items:
		draw_rect(Rect2(lx, ly - 9.0, 11.0, 9.0), item[0] as Color)
		draw_rect(Rect2(lx, ly - 9.0, 11.0, 9.0), COL_BORDER, false, 0.8)
		draw_string(font, Vector2(lx + 14.0, ly),
			item[1] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.75, 0.75, 0.82, 0.90))
		lx += 80.0


# ── Helpers ────────────────────────────────────────────────────────────────
func _neighbor_gp(gp: Vector2i, dir: String, dist: int) -> Vector2i:
	match dir:
		"east":  return Vector2i(gp.x + dist, gp.y)
		"west":  return Vector2i(gp.x - dist, gp.y)
		"south": return Vector2i(gp.x, gp.y + dist)
		"north": return Vector2i(gp.x, gp.y - dist)
	return gp
