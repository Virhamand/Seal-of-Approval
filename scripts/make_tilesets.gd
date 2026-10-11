extends SceneTree
## Builds outdoor_tileset.tres and interior_tileset.tres from the PNG atlases.
## Run:  godot --headless --path . --script res://tools/make_tilesets.gd

const N_TL := TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER
const N_TR := TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER
const N_BL := TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER
const N_BR := TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER

func _init() -> void:
	make_outdoor()
	make_interior()
	quit()

## Big tiles are drawn centred on their cell by default. Shift them so the
## cell you click is the object's top-left cell, like painting a 1x1 tile.
func anchor_top_left(td: TileData, size: Vector2i) -> void:
	td.texture_origin = Vector2i(-(size.x - 1) * 8, -(size.y - 1) * 8)

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

# ---------------------------------------------------------------- outdoor
func make_outdoor() -> void:
	var lay: Dictionary = read_json("res://tiles/outdoor_layout.json")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	var names := ["Sand", "Shallow Water", "Deep Water"]
	var colors := [Color("#e8c98a"), Color("#4fa3a5"), Color("#2f5f96")]
	for i in 3:
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, names[i])
		ts.set_terrain_color(0, i, colors[i])

	var src := TileSetAtlasSource.new()
	src.resource_name = "Beach"
	src.texture = load("res://tiles/outdoor_tileset.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	# Two wang blocks: [origin_row, terrain_for_bit0, terrain_for_bit1]
	for block in [[0, 0, 1], [4, 1, 2]]:
		for i in 16:
			var coords := Vector2i(i % 4, block[0] + i / 4)
			src.create_tile(coords)
			src.set_tile_animation_columns(coords, 0)
			src.set_tile_animation_separation(coords, Vector2i(3, 0))
			src.set_tile_animation_frames_count(coords, 4)
			for f in 4:
				src.set_tile_animation_frame_duration(coords, f, 0.3)
			var bits := [i & 1, (i >> 1) & 1, (i >> 2) & 1, (i >> 3) & 1]
			var t := []
			for b in bits:
				t.append(block[2] if b == 1 else block[1])
			var td := src.get_tile_data(coords, 0)
			td.terrain_set = 0
			var ones: int = bits.count(1)
			td.terrain = block[2] if ones >= 2 else block[1]
			td.set_terrain_peering_bit(N_TL, t[0])
			td.set_terrain_peering_bit(N_TR, t[1])
			td.set_terrain_peering_bit(N_BL, t[2])
			td.set_terrain_peering_bit(N_BR, t[3])
			# The all-shallow tile exists in both blocks; keep only one as the main pick.
			if block[0] == 0 and i == 15:
				td.probability = 0.0001

	# sand variants join the Sand terrain as random alternatives
	var vi := 0
	for c in lay["sand_variants"]:
		var coords := Vector2i(c[0], c[1])
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.terrain_set = 0
		td.terrain = 0
		for n in [N_TL, N_TR, N_BL, N_BR]:
			td.set_terrain_peering_bit(n, 0)
		td.probability = 1.0 if vi == 0 else 0.25
		vi += 1

	# decorations (place on a layer above the ground)
	var decor: Dictionary = lay["decor"]
	for name in decor:
		var d: Array = decor[name]
		src.create_tile(Vector2i(d[0], d[1]), Vector2i(d[2], d[3]))
		anchor_top_left(src.get_tile_data(Vector2i(d[0], d[1]), 0), Vector2i(d[2], d[3]))

	var err := ResourceSaver.save(ts, "res://tiles/outdoor_tileset.tres")
	print("outdoor tileset saved: ", err)

# ---------------------------------------------------------------- interior
const SOLID := ["wall", "wall_top", "kitchen", "decor"]
const SOLID_FURNITURE := ["table_small", "table_long", "table_wood", "counter_left", "counter_mid",
	"counter_right", "counter_register", "counter_single"]

func make_interior() -> void:
	var lay: Dictionary = read_json("res://tiles/interior_layout.json")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "Wall")
	ts.set_terrain_color(0, 0, Color("#d9c3a0"))
	# custom data so game code can ask "what is this tile?"
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var src := TileSetAtlasSource.new()
	src.resource_name = "Restaurant"
	src.texture = load("res://tiles/interior_tileset.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	for name in lay:
		var e: Array = lay[name]
		var coords := Vector2i(e[0], e[1])
		var size := Vector2i(e[2], e[3])
		src.create_tile(coords, size)
		var td := src.get_tile_data(coords, 0)
		td.set_custom_data("name", name)
		anchor_top_left(td, size)
		var cat: String = e[4]
		if cat in SOLID or name in SOLID_FURNITURE:
			# polygon is relative to the anchor cell's centre (matches anchor_top_left)
			var x1 := size.x * 16.0 - 8.0
			var y1 := size.y * 16.0 - 8.0
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(x1, -8), Vector2(x1, y1), Vector2(-8, y1)]))
		if cat == "wall_top":
			var m := int(name.substr(9))
			td.terrain_set = 0
			td.terrain = 0
			if not (m & 1): td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, 0)
			if not (m & 2): td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 0)
			if not (m & 4): td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 0)
			if not (m & 8): td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, 0)

	var err := ResourceSaver.save(ts, "res://tiles/interior_tileset.tres")
	print("interior tileset saved: ", err)
