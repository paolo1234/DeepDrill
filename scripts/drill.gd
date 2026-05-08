extends Node2D

const COLS = 7
const COL_WIDTH = 154.0
const GRID_OFFSET_X = 0.0
const BASE_SPEED = 85.0
const DRILL_WIDTH = 80.0
const DRILL_HEIGHT = 100.0

var speed: float = BASE_SPEED
var target_col: int = 3
var current_x: float = 0.0
var grid_ref: Node2D = null
var gs: Node = null
var speed_penalty: float = 0.0

# Visual
var drill_anim_frame: int = 0
var drill_anim_timer: float = 0.0
var spark_particles: Array = []

var frenzy_count: int = 0
var frenzy_timer: float = 0.0
var frenzy_mode: bool = false
var last_mine_time: float = 0.0

func _ready():
	gs = get_node("/root/GameState")
	if gs:
		gs.game_over.connect(_on_game_over)
	target_col = 3
	current_x = _col_to_x(target_col)
	position.x = current_x
	_setup_lighting()

func _setup_lighting():
	var light = PointLight2D.new()
	light.color = Color(1.0, 0.9, 0.7)
	light.energy = 1.7 # More punchy
	light.texture_scale = 1.8 # Slightly wider
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.z_index = 10 # Ensure it's above the drill body
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1)) # Center: White
	gradient.set_color(1, Color(0, 0, 0, 0)) # Edge: Transparent
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.9, 0.5) # Soft edge within bounds
	tex.width = 1024 # Massive resolution for smoothness
	tex.height = 1024
	
	light.texture = tex
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(light)

func _col_to_x(col: int) -> float:
	return GRID_OFFSET_X + col * COL_WIDTH + COL_WIDTH / 2.0

var is_drilling: bool = false

func _process(delta):
	if not gs or not gs.game_active:
		return

	if frenzy_mode:
		frenzy_timer -= delta
		if frenzy_timer <= 0:
			frenzy_mode = false
			frenzy_count = 0
	elif Time.get_ticks_msec() / 1000.0 - last_mine_time > 4.0:
		frenzy_count = 0

	var speed_mult = 1.0 + gs.depth / 1500.0
	if frenzy_mode: speed_mult *= 1.5
	speed = BASE_SPEED * speed_mult
	
	if speed_penalty > 0:
		speed_penalty = max(0.0, speed_penalty - delta * 2.0)
	var final_speed = speed * max(0.3, 1.0 - speed_penalty)

	if not grid_ref:
		grid_ref = get_parent().get_node_or_null("Grid")

	is_drilling = false
	var target_x = _col_to_x(target_col)
	var lateral_speed = 10.0
	if grid_ref and _check_side_collision(target_x):
		lateral_speed = 3.0
		is_drilling = true
	
	current_x = lerp(current_x, target_x, lateral_speed * delta)
	position.x = current_x

	if grid_ref:
		grid_ref.update_grid(position.y)
		
		# Upgrade Shop Trigger
		if gs and gs.game_active:
			gs.check_upgrade_shop()

		var collision_targets = _get_all_collision_targets()
		
		if not collision_targets.is_empty():
			is_drilling = true
			for target in collision_targets:
				_process_drilling(target, delta)
			position.x += randf_range(-3, 3)
			position.y += randf_range(-1, 1)
			var effects = get_node_or_null("/root/Effects")
			if effects: effects.shake(1.0 if frenzy_mode else 0.4)
		else:
			position.y += final_speed * delta
			gs.set_depth(gs.depth + final_speed * delta * 0.05)
			if not frenzy_mode:
				gs.passive_cooling(delta)

	drill_anim_timer += delta
	var anim_speed = 0.02 if is_drilling else 0.08
	if frenzy_mode: anim_speed *= 0.5
	if drill_anim_timer >= anim_speed:
		drill_anim_timer = 0.0
		drill_anim_frame = (drill_anim_frame + 1) % 4
		queue_redraw()

	_update_particles(delta)
	if is_drilling or frenzy_mode:
		_spawn_drill_sparks()

func _check_side_collision(t_x):
	var dir = sign(t_x - position.x)
	if abs(dir) < 0.1: return false
	var side_rect = Rect2(position.x + dir * DRILL_WIDTH/2.0, position.y - DRILL_HEIGHT/4.0, 5, DRILL_HEIGHT/2.0)
	var row = grid_ref.get_row_at_y(side_rect.position.y + side_rect.size.y/2.0)
	var col = int((side_rect.position.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH)
	var block = grid_ref.get_block_at_row_col(row, col)
	return block != null and not block.get("is_dug", false)

func _get_all_collision_targets():
	var targets = []
	var b_target = _check_vertical_collision()
	if b_target: targets.append(b_target)
	var drill_rect = Rect2(position.x - DRILL_WIDTH/2.0, position.y - DRILL_HEIGHT/2.0, DRILL_WIDTH, DRILL_HEIGHT)
	var row = grid_ref.get_row_at_y(position.y)
	for c in [int((drill_rect.position.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH), 
			  int((drill_rect.position.x + drill_rect.size.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH)]:
		var block = grid_ref.get_block_at_row_col(row, c)
		if block and not block.get("is_dug", false):
			var found = false
			for t in targets:
				if t["block"] == block: found = true; break
			if not found: targets.append({"block": block, "row": row, "col": c})
	return targets

func _check_vertical_collision():
	var drill_rect = Rect2(position.x - DRILL_WIDTH/2.0 + 10, position.y + DRILL_HEIGHT/3.0, DRILL_WIDTH - 20, 10)
	var row = grid_ref.get_row_at_y(drill_rect.position.y + drill_rect.size.y)
	var col = int((position.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH)
	var block = grid_ref.get_block_at_row_col(row, col)
	if block and not block.get("is_dug", false):
		return {"block": block, "row": row, "col": col}
	return null

func _process_drilling(target, delta):
	var block = target["block"]
	if block.get("type") == 7:
		gs.add_heat(30 * delta)
	var damage = delta * (1.6 if frenzy_mode else 1.0) * (1.0 + gs.depth / 2000.0) 
	block["health"] -= damage
	if block["health"] <= 0:
		_drill_block(block, target["row"], target["col"])

func _unhandled_input(event):
	if not gs or not gs.game_active: return
	if event is InputEventScreenTouch and event.pressed:
		var half = get_viewport_rect().size.x / 2.0
		if event.position.x < half: target_col = max(0, target_col - 1)
		else: target_col = min(COLS - 1, target_col + 1)
	elif event.is_action_pressed("ui_left"): target_col = max(0, target_col - 1)
	elif event.is_action_pressed("ui_right"): target_col = min(COLS - 1, target_col + 1)

func _drill_block(block: Dictionary, row: int, col: int):
	if block == null or block.get("is_dug", false): return
	block["is_dug"] = true
	if block.get("type") == 8:
		_trigger_tnt_explosion(row, col)
		return
	last_mine_time = Time.get_ticks_msec() / 1000.0
	frenzy_count += 1
	if frenzy_count >= 10 and not frenzy_mode:
		frenzy_mode = true
		frenzy_timer = 6.0
		var effects = get_node_or_null("/root/Effects")
		if effects:
			effects.spawn_floating_text(position, "FRENZY! 🔥", Color.ORANGE_RED)
			effects.shake(2.0)
	gs.add_coins(block.get("coins", 0))
	gs.add_heat(block.get("heat", 0))
	gs.add_wear(block.get("wear", 0))
	_spawn_break_particles(col, row, block.get("color", Color.WHITE))
	var effects = get_node_or_null("/root/Effects")
	if effects:
		effects.shake(1.5)
		var spawn_pos = position + Vector2(randf_range(-20, 20), -30)
		if block.get("heat", 0) != 0:
			var h = block["heat"]
			effects.spawn_floating_text(spawn_pos, str(h) + " 🔥", Color.RED if h > 0 else Color.CYAN)
		if block.get("coins", 0) > 0:
			effects.spawn_floating_text(spawn_pos + Vector2(0, -25), "+" + str(block["coins"]) + " 🪙", Color.GOLD)
	if grid_ref: grid_ref.queue_redraw()

func _trigger_tnt_explosion(row: int, col: int):
	var effects = get_node_or_null("/root/Effects")
	if effects:
		effects.shake(5.0)
		effects.spawn_floating_text(position, "BOOM! 💥", Color.ORANGE)
		if effects.has_method("spawn_explosion_flash"):
			effects.spawn_explosion_flash(position)
	
	for r in range(row - 2, row + 3): # Larger 5x5 blast
		for c in range(col - 2, col + 3):
			var b = grid_ref.get_block_at_row_col(r, c)
			if b and not b.get("is_dug", false):
				b["is_dug"] = true
				_spawn_break_particles(c, r, b.get("color", Color.WHITE))
				gs.add_coins(b.get("coins", 0))
	
	grid_ref.queue_redraw()

func _spawn_break_particles(_col: int, _row: int, color: Color):
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 15
	p.lifetime = 0.4
	p.color = color
	get_tree().current_scene.add_child(p)
	p.global_position = position + Vector2(0, DRILL_HEIGHT/2.5)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _spawn_drill_sparks():
	var spark = {"x": position.x + randf_range(-20, 20), "y": position.y + DRILL_HEIGHT/2.0, "vx": randf_range(-80, 80), "vy": randf_range(-120, -40), "life": 0.3, "max_life": 0.3, "color": Color(1, 0.8, 0.2), "size": randf_range(2, 4)}
	spark_particles.append(spark)

func _update_particles(delta):
	var to_remove = []
	for i in range(spark_particles.size()):
		var p = spark_particles[i]
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["vy"] += 400 * delta
		p["life"] -= delta
		if p["life"] <= 0: to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1): spark_particles.remove_at(to_remove[i])
	if spark_particles.size() > 0: queue_redraw()

func _draw():
	# 1. Side Boosters
	var track_c = Color(0.2, 0.2, 0.22)
	draw_rect(Rect2(-DRILL_WIDTH/2 - 6, -DRILL_HEIGHT/6, 12, DRILL_HEIGHT/3), track_c, true)
	draw_rect(Rect2(DRILL_WIDTH/2 - 6, -DRILL_HEIGHT/6, 12, DRILL_HEIGHT/3), track_c, true)
	
	# 2. Main Capsule Body
	var body_c = Color(0.85, 0.4, 0.15)
	if frenzy_mode: body_c = Color(0.9, 1.0, 1.0)
	var body_pts = PackedVector2Array()
	for i in range(21):
		var ang = PI + (i * PI / 20.0)
		body_pts.append(Vector2(cos(ang) * DRILL_WIDTH/2.2, sin(ang) * DRILL_HEIGHT/2.5 - 5))
	body_pts.append(Vector2(DRILL_WIDTH/2.2, 8)); body_pts.append(Vector2(-DRILL_WIDTH/2.2, 8))
	draw_colored_polygon(body_pts, body_c)
	draw_polyline(body_pts, body_c.darkened(0.4), 3.0)
	
	# 3. LEDs
	var led_c = Color.RED if gs.heat > 70 else Color.GREEN
	if fmod(Time.get_ticks_msec() * 0.005, 1.0) > 0.5:
		draw_circle(Vector2(-15, -15), 3, led_c); draw_circle(Vector2(15, -15), 3, led_c)
	
	# 4. Cockpit
	draw_circle(Vector2(0, -DRILL_HEIGHT/4.0), DRILL_WIDTH/4.5, Color(0.1, 0.4, 0.7, 0.6))
	
	# 5. Bit
	var bit_w = DRILL_WIDTH * 0.8
	var bit_pts = PackedVector2Array([Vector2(-bit_w/2.0, 8), Vector2(bit_w/2.0, 8), Vector2(0, DRILL_HEIGHT/2.0 + 12)])
	draw_colored_polygon(bit_pts, Color(0.4, 0.4, 0.45))
	draw_polyline(bit_pts, Color(0.1, 0.1, 0.1), 2.0)
	
	var anim = fmod(Time.get_ticks_msec() * 0.02, 1.0)
	for i in range(5):
		var y_rel = fmod(float(i)/5.0 + anim, 1.0)
		var y = 8 + (DRILL_HEIGHT/2.0 + 4) * y_rel
		var w = bit_w/2.0 * (1.0 - y_rel)
		draw_line(Vector2(-w, y), Vector2(w, y), Color(0, 0, 0, 0.5), 3.0)
	
	# Spark Particles
	for p in spark_particles:
		draw_circle(Vector2(p.x - position.x, p.y - position.y), p.size, p.color)

func _on_game_over(_reason: String):
	set_process(false)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
