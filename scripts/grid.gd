extends Node2D

const COLS = 7
const COL_WIDTH = 154.0  # 1080 / 7
const ROW_HEIGHT = 48.0
const VISIBLE_ROWS = 45
const BUFFER_ROWS = 15

var grid: Array = []
var rng = RandomNumberGenerator.new()
var camera_y: float = 0.0
var _rows_generated: int = 0
var last_path_center: int = 3

# Tier weights: [dirt, stone, granite, gold, diamond, lava]
const TIER_WEIGHTS = {
	1: [0.55, 0.25, 0.10, 0.08, 0.02, 0.0],
	2: [0.30, 0.28, 0.22, 0.12, 0.08, 0.0],
	3: [0.20, 0.22, 0.22, 0.22, 0.14, 0.0],
	4: [0.12, 0.18, 0.22, 0.15, 0.20, 0.13],
	5: [0.08, 0.12, 0.18, 0.12, 0.18, 0.32]
}

# Tier background colors
const TIER_COLORS = {
	1: Color(0.36, 0.20, 0.09),    # Topsoil brown
	2: Color(0.23, 0.23, 0.23),    # Bedrock dark gray
	3: Color(0.42, 0.31, 0.11),    # Gold vein amber
	4: Color(0.10, 0.16, 0.29),    # Crystal cave blue
	5: Color(0.23, 0.06, 0.06),    # Magma core red
}

func _ready():
	rng.randomize()
	# Pre-generate rows
	for i in range(VISIBLE_ROWS + BUFFER_ROWS):
		generate_row(i)

func get_tier(depth: float) -> int:
	if depth < 100: return 1
	elif depth < 300: return 2
	elif depth < 500: return 3
	elif depth < 800: return 4
	else: return 5

func generate_row(idx: int) -> Array:
	var depth = idx * ROW_HEIGHT * 0.05  # Convert row to depth meters
	var tier = get_tier(depth)
	var weights = TIER_WEIGHTS[tier]
	var row = []

	# Guarantee at least 2 empty/soft paths that connect to the previous row
	var empty_cols = []
	# The new path center must be within 1 column of the last path center
	var path_center = clampi(last_path_center + rng.randi_range(-1, 1), 1, COLS - 2)
	empty_cols.append(path_center)
	empty_cols.append(path_center - 1)
	empty_cols.append(path_center + 1)
	
	# Random chance to have an extra opening
	if rng.randf() < 0.3:
		empty_cols.append(rng.randi_range(0, COLS - 1))
	
	last_path_center = path_center

	# Every 5 rows: guaranteed gold/diamond cluster
	var cluster_col = -1
	if idx % 5 == 0 and idx > 0:
		cluster_col = rng.randi_range(0, COLS - 1)
		while cluster_col in empty_cols:
			cluster_col = rng.randi_range(0, COLS - 1)

	for c in range(COLS):
		if c in empty_cols:
			row.append(null)  # empty/path
			continue
		if c == cluster_col:
			# Gold or diamond cluster
			if depth > 300 and rng.randf() < 0.4:
				row.append(_create_block(5))  # Diamond
			else:
				row.append(_create_block(4))  # Gold
			continue

		var roll = rng.randf()
		var block_type = 1  # default to dirt
		var accum = 0.0
		for i in range(weights.size()):
			accum += weights[i]
			if roll <= accum:
				block_type = i + 1
				break
		row.append(_create_block(block_type))

	grid.append(row)
	_rows_generated += 1
	return row

func _create_block(type: int) -> Dictionary:
	var block = {"type": type, "is_dug": false, "break_anim": 0.0}
	match type:
		1: # Dirt
			block["color"] = Color(0.545, 0.412, 0.078)
			block["heat"] = 1; block["wear"] = 1; block["coins"] = 1
		2: # Stone
			block["color"] = Color(0.502, 0.502, 0.502)
			block["heat"] = 3; block["wear"] = 2; block["coins"] = 3
		3: # Granite
			block["color"] = Color(0.29, 0.29, 0.29)
			block["heat"] = 5; block["wear"] = 4; block["coins"] = 5
		4: # Gold
			block["color"] = Color(1, 0.843, 0)
			block["heat"] = 2; block["wear"] = 1; block["coins"] = 15
		5: # Diamond
			block["color"] = Color(0, 1, 1)
			block["heat"] = 6; block["wear"] = 3; block["coins"] = 50
		6: # Lava
			block["color"] = Color(1, 0.27, 0)
			block["heat"] = 25; block["wear"] = 0; block["coins"] = 0
	return block

func update_grid(drill_y: float):
	camera_y = drill_y
	# Generate more rows if needed
	var needed_row = int(drill_y / ROW_HEIGHT) + VISIBLE_ROWS + BUFFER_ROWS
	while grid.size() < needed_row:
		generate_row(grid.size())
	queue_redraw()

func get_row_at_y(world_y: float) -> int:
	return int(world_y / ROW_HEIGHT)

func get_block_at_row_col(row: int, col: int):
	if row >= 0 and row < grid.size() and col >= 0 and col < COLS:
		return grid[row][col]
	return null

func _draw():
	var start_row = max(0, int(camera_y / ROW_HEIGHT) - 5)
	var end_row = min(grid.size(), start_row + VISIBLE_ROWS + 10)

	# Draw background tiers
	for row_idx in range(start_row, end_row):
		var y = row_idx * ROW_HEIGHT - camera_y + 600  # offset so drill is at ~30% from bottom
		if y < -100 or y > 2200:
			continue
		var depth = row_idx * ROW_HEIGHT * 0.05
		var tier = get_tier(depth)
		var bg_color = TIER_COLORS[tier]
		# Slight variation per row
		bg_color = bg_color.darkened(fmod(row_idx * 0.02, 0.1))
		draw_rect(Rect2(0, y, COLS * COL_WIDTH, ROW_HEIGHT), bg_color, true)

	# Draw blocks
	for row_idx in range(start_row, end_row):
		var row = grid[row_idx]
		var y = row_idx * ROW_HEIGHT - camera_y + 600

		if y < -100 or y > 2200:
			continue

		for col in range(COLS):
			var block = row[col]
			if block and block["type"] != 0 and not block["is_dug"]:
				var x = col * COL_WIDTH
				var padding = 2.0
				var rect = Rect2(x + padding, y + padding, COL_WIDTH - padding * 2, ROW_HEIGHT - padding * 2)
				
				# Main block fill
				draw_rect(rect, block["color"], true)
				
				# Border (darker)
				draw_rect(rect, block["color"].darkened(0.3), false, 3.0)
				
				# Block-specific decorations
				match block["type"]:
					1: # Dirt - small dots
						for i in range(3):
							var dx = x + padding + 10 + i * 40
							var dy = y + padding + 10 + fmod(i * 17, 25)
							draw_circle(Vector2(dx, dy), 3, block["color"].darkened(0.2))
					2: # Stone - crack lines
						draw_line(Vector2(x + 15, y + 10), Vector2(x + COL_WIDTH - 25, y + ROW_HEIGHT - 15), block["color"].lightened(0.15), 1.5)
						draw_line(Vector2(x + COL_WIDTH - 20, y + 8), Vector2(x + 20, y + ROW_HEIGHT - 10), block["color"].lightened(0.1), 1.0)
					3: # Granite - diagonal lines
						for i in range(4):
							var lx = x + padding + i * 35
							draw_line(Vector2(lx, y + padding), Vector2(lx + 20, y + ROW_HEIGHT - padding), block["color"].lightened(0.1), 1.5)
					4: # Gold - sparkle dots
						for i in range(4):
							var sx = x + 15 + fmod(i * 37, COL_WIDTH - 30)
							var sy = y + 10 + fmod(i * 13, ROW_HEIGHT - 20)
							draw_circle(Vector2(sx, sy), 4, Color(1, 1, 0.7, 0.8))
					5: # Diamond - star shape
						var cx = x + COL_WIDTH / 2
						var cy = y + ROW_HEIGHT / 2
						var star_size = min(COL_WIDTH, ROW_HEIGHT) * 0.25
						draw_line(Vector2(cx - star_size, cy), Vector2(cx + star_size, cy), Color(1, 1, 1, 0.7), 2.0)
						draw_line(Vector2(cx, cy - star_size), Vector2(cx, cy + star_size), Color(1, 1, 1, 0.7), 2.0)
						draw_line(Vector2(cx - star_size * 0.7, cy - star_size * 0.7), Vector2(cx + star_size * 0.7, cy + star_size * 0.7), Color(0.8, 1, 1, 0.5), 1.5)
						draw_line(Vector2(cx + star_size * 0.7, cy - star_size * 0.7), Vector2(cx - star_size * 0.7, cy + star_size * 0.7), Color(0.8, 1, 1, 0.5), 1.5)
					6: # Lava - animated bubbles
						var time = float(row_idx) * 0.3
						for i in range(3):
							var bx = x + 20 + fmod(i * 47 + time * 10, COL_WIDTH - 40)
							var by = y + 12 + fmod(i * 19, ROW_HEIGHT - 24)
							var bsize = 5 + sin(time + i) * 2
							draw_circle(Vector2(bx, by), bsize, Color(1, 0.6, 0, 0.6))
