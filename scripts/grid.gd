extends Node2D

const COLS = 7
const COL_WIDTH = 154.0
const ROW_HEIGHT = 120.0
const GRID_OFFSET_X = 0.0
const VISIBLE_ROWS = 20
const BUFFER_ROWS = 10

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

var blocks_texture: Texture2D

func _ready():
	rng.randomize()
	for i in range(VISIBLE_ROWS + BUFFER_ROWS):
		generate_row(i)

func get_tier(depth: float) -> int:
	if depth < 100: return 1
	elif depth < 300: return 2
	elif depth < 500: return 3
	elif depth < 800: return 4
	else: return 5

func generate_row(idx: int) -> Array:
	var depth = idx * ROW_HEIGHT * 0.05
	var tier = get_tier(depth)
	var weights = TIER_WEIGHTS[tier]
	var row = []

	# No more guaranteed paths. The player MUST drill.
	# We only leave very rare 1-block openings.
	
	for c in range(COLS):
		var roll = rng.randf()
		
		# More generous spacing (20% empty/gas)
		if roll < 0.2:
			if rng.randf() < 0.2:
				row.append({"type": 7, "is_dug": false, "health": 0.1, "max_health": 0.1, "color": Color(0.2, 0.8, 0.2, 0.4)}) # GAS
			else:
				row.append(null) # Empty
			continue

		# TNT chance (rare but helpful)
		if roll > 0.98:
			row.append({"type": 8, "is_dug": false, "health": 0.5, "max_health": 0.5, "color": Color(1, 0, 0), "coins": 10}) # TNT
			continue

		var block_type = 1 
		var accum = 0.0
		# Adjust weights to be more forgiving in tiers
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
	var block = {"type": type, "is_dug": false, "health": 1.0, "max_health": 1.0}
	match type:
		1: # Dirt
			block["color"] = Color(0.45, 0.3, 0.15)
			block["heat"] = 2; block["wear"] = 0.5; block["coins"] = 1
			block["health"] = 0.2; block["max_health"] = 0.2
		2: # Stone
			block["color"] = Color(0.5, 0.5, 0.5)
			block["heat"] = 5; block["wear"] = 2.0; block["coins"] = 3
			block["health"] = 1.2; block["max_health"] = 1.2
		3: # Granite
			block["color"] = Color(0.3, 0.3, 0.35)
			block["heat"] = 10; block["wear"] = 5.0; block["coins"] = 8
			block["health"] = 3.0; block["max_health"] = 3.0
		4: # Gold
			block["color"] = Color(1, 0.8, 0.2)
			block["heat"] = -5; block["wear"] = 0.5; block["coins"] = 25
			block["health"] = 0.5; block["max_health"] = 0.5
		5: # Diamond
			block["color"] = Color(0.3, 0.9, 1.0)
			block["heat"] = -20; block["wear"] = 1.0; block["coins"] = 100
			block["health"] = 1.0; block["max_health"] = 1.0
		6: # Lava
			block["color"] = Color(1, 0.3, 0)
			block["heat"] = 40; block["wear"] = 0; block["coins"] = 0
			block["health"] = 0.1; block["max_health"] = 0.1
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
	var top_screen_y = camera_y - 1000
	var start_row = max(0, int(top_screen_y / ROW_HEIGHT))
	var end_row = min(grid.size(), int((camera_y + 1200) / ROW_HEIGHT))

	for row_idx in range(start_row, end_row):
		var y = row_idx * ROW_HEIGHT
		var depth = row_idx * ROW_HEIGHT * 0.05
		var tier = get_tier(depth)
		var bg_color = TIER_COLORS[tier]
		bg_color = bg_color.darkened(fmod(row_idx * 0.02, 0.1))
		draw_rect(Rect2(0, y, COLS * COL_WIDTH, ROW_HEIGHT), bg_color, true)

	for row_idx in range(start_row, end_row):
		var row = grid[row_idx]
		var y = row_idx * ROW_HEIGHT

		for col in range(COLS):
			var block = row[col]
			if block and block["type"] != 0 and not block["is_dug"]:
				var x = col * COL_WIDTH
				var padding = 2.0
				var rect = Rect2(x + padding, y + padding, COL_WIDTH - padding * 2, ROW_HEIGHT - padding * 2)
				var base_c = block["color"]
				
				# Premium Cartoon Bevel Effect
				draw_rect(rect, base_c.darkened(0.5), true) # Deep shadow
				var body_rect = Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y - 6)
				draw_rect(body_rect, base_c, true) # Main color
				var highlight_rect = Rect2(body_rect.position.x, body_rect.position.y, body_rect.size.x, 4)
				draw_rect(highlight_rect, base_c.lightened(0.4), true) # Top highlight
				
				# Block-specific decorations
				match block["type"]:
					1: # Dirt
						for i in range(3):
							var dx = x + padding + 10 + i * 40
							var dy = y + padding + 10 + fmod(i * 17, ROW_HEIGHT - 20)
							draw_rect(Rect2(dx, dy, 8, 8), base_c.darkened(0.3), true)
					2: # Stone
						draw_line(Vector2(x + 15, y + 15), Vector2(x + COL_WIDTH - 25, y + ROW_HEIGHT - 25), base_c.darkened(0.3), 4.0)
					3: # Granite
						draw_rect(Rect2(x+15, y+15, 20, 20), base_c.darkened(0.4), true)
						draw_rect(Rect2(x+COL_WIDTH-45, y+ROW_HEIGHT-45, 25, 25), base_c.darkened(0.4), true)
					4: # Gold
						for i in range(3):
							var sx = x + 30 + i * 40
							var sy = y + 20 + fmod(i * 13, 30)
							draw_rect(Rect2(sx, sy, 18, 18), Color(1, 1, 0.4), true)
							draw_rect(Rect2(sx+4, sy+4, 6, 6), Color(1, 1, 1), true) # Sparkle
					5: # Diamond
						var cx = x + COL_WIDTH / 2
						var cy = y + ROW_HEIGHT / 2
						var p = PackedVector2Array([Vector2(cx, cy-30), Vector2(cx+25, cy), Vector2(cx, cy+30), Vector2(cx-25, cy)])
						draw_colored_polygon(p, Color(0.2, 1, 1))
						draw_circle(Vector2(cx-8, cy-8), 6, Color(1,1,1))
					6: # Lava
						var time = Time.get_ticks_msec() * 0.002 + float(row_idx)
						for i in range(4):
							var bx = x + 30 + fmod(i * 50 + time * 20, COL_WIDTH - 60)
							var by = y + 20 + fmod(i * 25, ROW_HEIGHT - 40)
							var bsize = 8 + sin(time + i) * 4
							draw_circle(Vector2(bx, by), bsize, Color(1, 0.8, 0.2))
					8: # TNT
						var cx = x + COL_WIDTH / 2
						var cy = y + ROW_HEIGHT / 2
						# 3 red cylinders
						for i in range(-1, 2):
							var stick_rect = Rect2(cx + i*14 - 6, cy - 20, 12, 40)
							draw_rect(stick_rect, Color(0.8, 0.1, 0.1), true)
							draw_rect(stick_rect, Color(0, 0, 0), false, 1.5)
						# White strap
						draw_rect(Rect2(cx-20, cy-5, 40, 6), Color(0.9, 0.9, 0.9), true)
						# Fuse
						draw_line(Vector2(cx+5, cy-20), Vector2(cx+15, cy-35), Color(0.4, 0.3, 0.2), 3.0)
						if fmod(Time.get_ticks_msec() * 0.01, 1.0) > 0.5:
							draw_circle(Vector2(cx+15, cy-35), 4, Color(1, 0.8, 0.2))
				
				# CRACKS based on health
				var health_pct = block["health"] / block["max_health"]
				if health_pct < 0.8:
					var crack_c = Color(0, 0, 0, 0.4)
					draw_line(Vector2(x + 20, y + 20), Vector2(x + 60, y + 50), crack_c, 3.0)
				if health_pct < 0.5:
					var crack_c = Color(0, 0, 0, 0.5)
					draw_line(Vector2(x + 100, y + 30), Vector2(x + 40, y + 90), crack_c, 3.0)
				if health_pct < 0.2:
					var crack_c = Color(0, 0, 0, 0.6)
					draw_line(Vector2(x + 30, y + 100), Vector2(x + 120, y + 40), crack_c, 3.0)
