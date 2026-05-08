extends Node2D

const COLS = 7
const COL_WIDTH = 154.0  # 1080 / 7 = ~154
const GRID_OFFSET_X = 0.0
const BASE_SPEED = 80.0
const DRILL_WIDTH = 48.0
const DRILL_HEIGHT = 64.0

var speed: float = BASE_SPEED
var target_col: int = 3
var current_x: float = 0.0
var grid_ref: Node2D = null
var gs: Node = null
var _last_drilled_row: int = -1

# Visual
var drill_anim_frame: int = 0
var drill_anim_timer: float = 0.0
var spark_particles: Array = []

func _ready():
	gs = get_node("/root/GameState")
	if gs:
		gs.game_over.connect(_on_game_over)
	target_col = 3
	current_x = _col_to_x(target_col)
	position.x = current_x

func _col_to_x(col: int) -> float:
	return GRID_OFFSET_X + col * COL_WIDTH + COL_WIDTH / 2.0

func _process(delta):
	if not gs or not gs.game_active:
		return

	# Speed increases with depth
	var speed_mult = 1.0 + gs.depth / 1000.0
	speed = BASE_SPEED * speed_mult
	
	# Move down
	position.y += speed * delta
	gs.set_depth(gs.depth + speed * delta * 0.05)  # ~1m per 20px
	gs.passive_cooling(delta)

	# Handle smooth horizontal movement
	var target_x = _col_to_x(target_col)
	current_x = lerp(current_x, target_x, 12.0 * delta)
	position.x = current_x

	# Try to get grid reference
	if not grid_ref:
		grid_ref = get_parent().get_node_or_null("Grid")

	# Drill blocks at current position
	if grid_ref:
		grid_ref.update_grid(position.y)
		_try_drill_block()

	# Upgrade shop check
	gs.check_upgrade_shop()

	# Animate drill
	drill_anim_timer += delta
	if drill_anim_timer >= 0.08:
		drill_anim_timer = 0.0
		drill_anim_frame = (drill_anim_frame + 1) % 4
		queue_redraw()

	# Update spark particles
	_update_particles(delta)

func _unhandled_input(event):
	if not gs or not gs.game_active:
		return

	if event is InputEventScreenTouch and event.pressed:
		var half = get_viewport_rect().size.x / 2.0
		if event.position.x < half:
			target_col = max(0, target_col - 1)
		else:
			target_col = min(COLS - 1, target_col + 1)
	elif event.is_action_pressed("ui_left"):
		target_col = max(0, target_col - 1)
	elif event.is_action_pressed("ui_right"):
		target_col = min(COLS - 1, target_col + 1)

func _try_drill_block():
	if not grid_ref or not gs.game_active:
		return
	# Get the row at drill's bottom
	var drill_bottom_y = position.y + DRILL_HEIGHT / 2.0
	var row_idx = grid_ref.get_row_at_y(drill_bottom_y)
	
	if row_idx == _last_drilled_row:
		return  # Already drilled this row
	_last_drilled_row = row_idx

	# Drill current column and adjacent
	var block = grid_ref.get_block_at_row_col(row_idx, target_col)
	if block and not block.get("is_dug", false):
		_drill_block(block, row_idx, target_col)

func _drill_block(block: Dictionary, row: int, col: int):
	if block == null or block.get("is_dug", false):
		return
	block["is_dug"] = true
	
	# Apply effects
	gs.add_heat(block.get("heat", 0))
	gs.add_wear(block.get("wear", 0))
	gs.add_coins(block.get("coins", 0))
	
	# Spawn break particles
	if grid_ref:
		var block_color = block.get("color", Color.WHITE)
		_spawn_break_particles(col, row, block_color)

	grid_ref.queue_redraw()

func _spawn_break_particles(col: int, row: int, color: Color):
	for i in range(6):
		var particle = {
			"x": position.x + randf_range(-20, 20),
			"y": position.y + DRILL_HEIGHT / 2.0 + randf_range(-10, 10),
			"vx": randf_range(-120, 120),
			"vy": randf_range(-200, -50),
			"life": 0.5,
			"max_life": 0.5,
			"color": color,
			"size": randf_range(3, 8)
		}
		spark_particles.append(particle)

func _update_particles(delta):
	var to_remove = []
	for i in range(spark_particles.size()):
		var p = spark_particles[i]
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["vy"] += 400 * delta  # gravity
		p["life"] -= delta
		if p["life"] <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		spark_particles.remove_at(to_remove[i])
	if spark_particles.size() > 0:
		queue_redraw()

	# Spawn drill sparks
	if gs and gs.game_active and randf() < 0.3:
		var spark = {
			"x": position.x + randf_range(-10, 10),
			"y": position.y + DRILL_HEIGHT / 2.0,
			"vx": randf_range(-60, 60),
			"vy": randf_range(-100, -30),
			"life": 0.3,
			"max_life": 0.3,
			"color": Color(1, 0.8, 0.2, 1),
			"size": randf_range(2, 4)
		}
		spark_particles.append(spark)

func _draw():
	# Draw drill body
	var body_rect = Rect2(-DRILL_WIDTH / 2, -DRILL_HEIGHT / 2, DRILL_WIDTH, DRILL_HEIGHT * 0.6)
	var body_color = Color(0.6, 0.6, 0.7)
	draw_rect(body_rect, body_color, true)
	
	# Metallic highlight
	var highlight = Rect2(-DRILL_WIDTH / 2 + 4, -DRILL_HEIGHT / 2 + 4, 8, DRILL_HEIGHT * 0.5)
	draw_rect(highlight, Color(0.8, 0.8, 0.9, 0.5), true)
	
	# Draw drill bit (triangle, rotates)
	var bit_top_y = DRILL_HEIGHT * 0.1
	var bit_bottom_y = DRILL_HEIGHT / 2
	var bit_width = DRILL_WIDTH / 2
	
	# Animated rotation effect via alternating bit shape
	var offset = sin(drill_anim_frame * PI / 2.0) * 3
	var bit_points = PackedVector2Array([
		Vector2(-bit_width / 2 + offset, bit_top_y),
		Vector2(bit_width / 2 + offset, bit_top_y),
		Vector2(offset * 0.5, bit_bottom_y)
	])
	draw_colored_polygon(bit_points, Color(0.8, 0.7, 0.2))
	
	# Drill bit lines (teeth)
	for i in range(3):
		var y = bit_top_y + (bit_bottom_y - bit_top_y) * (i + 1) / 4.0
		var w = bit_width / 2 * (1.0 - float(i + 1) / 4.0)
		draw_line(Vector2(-w + offset * 0.5, y), Vector2(w + offset * 0.5, y), Color(0.6, 0.5, 0.1), 2.0)
	
	# Draw heat glow when hot
	if gs and gs.max_heat > 0:
		var heat_pct = gs.heat / gs.max_heat
		if heat_pct > 0.5:
			var glow_alpha = (heat_pct - 0.5) * 2.0 * 0.4
			var glow_rect = Rect2(-DRILL_WIDTH / 2 - 4, -DRILL_HEIGHT / 2 - 4, DRILL_WIDTH + 8, DRILL_HEIGHT + 8)
			draw_rect(glow_rect, Color(1, 0.2, 0, glow_alpha), true)
	
	# Draw damage cracks when durability is low
	if gs and gs.max_durability > 0:
		var dura_pct = gs.durability / gs.max_durability
		if dura_pct < 0.5:
			var crack_alpha = (1.0 - dura_pct * 2) * 0.8
			draw_line(Vector2(-10, -20), Vector2(5, -5), Color(0.3, 0.3, 0.3, crack_alpha), 2.0)
			draw_line(Vector2(5, -5), Vector2(-5, 10), Color(0.3, 0.3, 0.3, crack_alpha), 2.0)
			draw_line(Vector2(8, -15), Vector2(15, 5), Color(0.3, 0.3, 0.3, crack_alpha), 2.0)

	# Draw particles
	for p in spark_particles:
		var alpha = p["life"] / p["max_life"]
		var color = p["color"]
		color.a = alpha
		var world_x = p["x"] - position.x
		var world_y = p["y"] - position.y
		draw_circle(Vector2(world_x, world_y), p["size"], color)

func _on_game_over(reason: String):
	set_process(false)
	# Explosion effect
	for i in range(20):
		var particle = {
			"x": position.x + randf_range(-30, 30),
			"y": position.y + randf_range(-30, 30),
			"vx": randf_range(-200, 200),
			"vy": randf_range(-200, 200),
			"life": 1.0,
			"max_life": 1.0,
			"color": Color(1, 0.5, 0) if reason == "overheated" else Color(0.5, 0.5, 0.5),
			"size": randf_range(4, 10)
		}
		spark_particles.append(particle)
	
	# Small tween to fade out the drill body
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	
	# Process particles a bit longer
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func():
		_update_particles(0.05)
		if spark_particles.is_empty():
			timer.stop()
	)
