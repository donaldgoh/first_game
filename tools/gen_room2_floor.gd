@tool
extends EditorScript

## Run this once from Godot: Script menu → Run (Ctrl+Shift+X)
## It gives room_4door_2.tscn a unique floor layout distinct from room_4door_1.
## Room 2 uses a concentric-ring pattern with floor5 (dark) center,
## floor3 (mid) ring, and default floor_tile outer ring.

func _run() -> void:
	var packed_scene := ResourceLoader.load(
		"res://scenes/rooms/4door/room_4door_2.tscn") as PackedScene
	if packed_scene == null:
		push_error("gen_room2_floor: could not load room_4door_2.tscn")
		return

	var root := packed_scene.instantiate()
	var floor_layer := root.get_node("Floor") as TileMapLayer
	if floor_layer == null:
		push_error("gen_room2_floor: Floor node not found")
		root.queue_free()
		return

	# Gather the set of tile positions from the existing layout
	# (they define the room's walkable shape — we keep positions, change textures)
	var cells := floor_layer.get_used_cells()

	# Find bounding box centre so the pattern is centred in the room
	var min_x := 9999; var max_x := -9999
	var min_y := 9999; var max_y := -9999
	for c in cells:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
		if c.y < min_y: min_y = c.y
		if c.y > max_y: max_y = c.y

	var cx := (min_x + max_x) / 2.0
	var cy := (min_y + max_y) / 2.0

	# TileSet sources (same as room_4door_1 TileSet_xaf8e):
	#   0 = floor_tile  1 = floor2  2 = floor3  3 = floor4
	#   4 = floor5      5 = floor6  6 = floor7
	#
	# Room 2 pattern: concentric rings based on Chebyshev distance from centre
	#   dist 0-3  → source 5 (floor6, darkest)
	#   dist 4-7  → source 2 (floor3, mid-tone)
	#   dist 8-11 → source 4 (floor5, mid-light)
	#   dist 12+  → source 0 (floor_tile, default edge)
	# Atlas coords are varied within each source for organic look.

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # fixed seed → deterministic, reproducible

	for cell in cells:
		var dx := cell.x - cx
		var dy := cell.y - cy
		var dist := int(max(abs(dx), abs(dy)))  # Chebyshev distance

		var source_id: int
		if dist <= 3:
			source_id = 5   # floor6  — dark centre pool
		elif dist <= 7:
			source_id = 2   # floor3  — mid ring
		elif dist <= 11:
			source_id = 4   # floor5  — outer ring
		else:
			source_id = 0   # floor_tile — edges

		# Use random atlas coords for texture variation within the source
		var ax := rng.randi_range(0, 3)
		var ay := rng.randi_range(0, 3)
		floor_layer.set_cell(cell, source_id, Vector2i(ax, ay))

	# Save the modified scene
	var new_packed := PackedScene.new()
	new_packed.pack(root)
	var err := ResourceSaver.save(new_packed, "res://scenes/rooms/4door/room_4door_2.tscn")
	if err == OK:
		print("[gen_room2_floor] Saved — room_4door_2 now has a unique floor layout.")
	else:
		push_error("[gen_room2_floor] Save failed (error %d)" % err)

	root.queue_free()
