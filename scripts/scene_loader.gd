extends CanvasLayer
# ═══════════════════════════════════════════════════════════════════════════
# SCENE LOADER  —  autoload singleton
#
# Usage (from any script):
#   SceneLoader.goto("res://scenes/dungeon.tscn")
#
# Loads the target scene on a background thread, shows an animated loading
# overlay with a progress bar, then switches when ready.
# ═══════════════════════════════════════════════════════════════════════════

# Only show the overlay if loading takes longer than this — fast scenes skip it entirely.
const SHOW_THRESHOLD := 0.18
# Once shown, keep it visible for at least this long so it doesn't flash.
const MIN_SHOW_SEC   := 0.30

const TIPS := [
	"Enemies grow stronger with every floor.",
	"Collect coins — they don't follow you to the next room.",
	"Hold TAB to view the full dungeon map.",
	"The boss room is always the furthest dead end.",
	"Sky Strike bullets fall from above and pass through walls.",
	"Chain Bolt jumps to nearby enemies after hitting one.",
	"Stack weapon parts to build powerful combos.",
	"Cleared rooms are brighter on the minimap.",
	"The laser deals instant damage — upgrade its power stat.",
	"Visit the shop to spend your coins before each boss.",
	"Cluster bombs detonate after a short delay.",
	"Orbital Burst fires bullets in all directions at once.",
]

# ── State ───────────────────────────────────────────────────────────────────
var _target   : String  = ""
var _loading  : bool    = false
var _res_done : bool    = false   # resource finished loading
var _elapsed  : float   = 0.0

# ── UI nodes ────────────────────────────────────────────────────────────────
var _bar      : ProgressBar
var _dot_lbl  : Label
var _tip_lbl  : Label
var _dot_t    : float = 0.0
var _dot_n    : int   = 0
var _spin_t   : float = 0.0
var _spinner  : Label
var _shown    : bool  = false   # true once the overlay has become visible
var _shown_at : float = 0.0     # elapsed time when overlay first appeared

# ── Init ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

# ── Public API ───────────────────────────────────────────────────────────────
func goto(path: String) -> void:
	if _loading:
		return
	_target  = path
	_loading = true
	_res_done  = false
	_elapsed = 0.0
	_dot_t   = 0.0
	_dot_n   = 0
	_spin_t  = 0.0
	_bar.value    = 0.0
	_dot_lbl.text = "Loading"
	_tip_lbl.text = TIPS[randi() % TIPS.size()]
	_shown        = false
	_shown_at     = 0.0
	# Don't show yet — we'll reveal only if loading takes too long
	visible = false
	ResourceLoader.load_threaded_request(path)

# ── Per-frame ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _loading:
		return

	_elapsed += delta

	# ── Animated dots ────────────────────────────────────────────────────
	_dot_t += delta
	if _dot_t >= 0.32:
		_dot_t  = 0.0
		_dot_n  = (_dot_n + 1) % 4
		_dot_lbl.text = "Loading" + ".".repeat(_dot_n)

	# ── Spinner ───────────────────────────────────────────────────────────
	_spin_t += delta * 4.0
	var frames := ["◐", "◓", "◑", "◒"]
	_spinner.text = frames[int(_spin_t) % 4]

	# ── Show overlay only once loading is taking a noticeable time ───────
	if not _shown and _elapsed >= SHOW_THRESHOLD and not _res_done:
		_shown    = true
		_shown_at = _elapsed
		visible   = true

	# ── Poll threaded load ────────────────────────────────────────────────
	if not _res_done:
		var progress : Array = []
		var status := ResourceLoader.load_threaded_get_status(_target, progress)
		if progress.size() > 0:
			_bar.value = progress[0] * 100.0
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_bar.value = 100.0
				_res_done  = true
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("SceneLoader: failed to load '%s'" % _target)
				_loading = false
				visible  = false

	# ── Switch when ready ─────────────────────────────────────────────────
	# If overlay was never shown: switch immediately.
	# If overlay was shown: wait for the minimum display duration.
	if _res_done:
		var min_elapsed = _shown_at + MIN_SHOW_SEC if _shown else 0.0
		if _elapsed >= min_elapsed:
			_switch()

# ── Private ───────────────────────────────────────────────────────────────────
func _switch() -> void:
	_loading = false
	var packed : PackedScene = ResourceLoader.load_threaded_get(_target)
	get_tree().paused = false
	get_tree().change_scene_to_packed(packed)
	visible = false

# ── UI construction ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Root control that fills the viewport so children have a proper rect
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	# Full-screen background
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09, 1.00)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	# CenterContainer places the column exactly at screen centre
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	# Centre column — fixed width; height grows with content
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(520.0, 0.0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)

	# ── Game title ───────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "REPS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	col.add_child(title)

	# ── Spinner + "Loading…" row ─────────────────────────────────────────
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	_spinner = Label.new()
	_spinner.text = "◐"
	_spinner.add_theme_font_size_override("font_size", 20)
	_spinner.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	row.add_child(_spinner)

	_dot_lbl = Label.new()
	_dot_lbl.text = "Loading"
	_dot_lbl.add_theme_font_size_override("font_size", 18)
	_dot_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.88))
	row.add_child(_dot_lbl)

	# ── Progress bar ─────────────────────────────────────────────────────
	var bar_wrap := PanelContainer.new()
	bar_wrap.add_theme_stylebox_override("panel", _make_bar_bg())
	col.add_child(bar_wrap)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value     = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_bar.add_theme_stylebox_override("background", _make_bar_bg())
	_bar.add_theme_stylebox_override("fill",       _make_bar_fill())
	bar_wrap.add_child(_bar)

	# ── Separator ─────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.18, 0.22, 0.35, 0.70)
	ssb.content_margin_top = 1; ssb.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", ssb)
	col.add_child(sep)

	# ── Tip text ─────────────────────────────────────────────────────────
	var tip_hdr := Label.new()
	tip_hdr.text = "TIP"
	tip_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_hdr.add_theme_font_size_override("font_size", 11)
	tip_hdr.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0, 0.80))
	col.add_child(tip_hdr)

	_tip_lbl = Label.new()
	_tip_lbl.text = ""
	_tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_lbl.add_theme_font_size_override("font_size", 14)
	_tip_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
	col.add_child(_tip_lbl)

# ── StyleBox helpers ──────────────────────────────────────────────────────────
func _make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.20)
	sb.set_corner_radius_all(4)
	return sb

func _make_bar_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.72, 0.38)
	sb.set_corner_radius_all(4)
	return sb
