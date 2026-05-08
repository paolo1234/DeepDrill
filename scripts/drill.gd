extends Node2D

const COLS = 7
const COL_WIDTH = 154.0
const GRID_OFFSET_X = 0.0
const BASE_SPEED = 80.0
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
var drill_texture: Texture2D

func _ready():
	gs = get_node("/root/GameState")
	if gs:
		gs.game_over.connect(_on_game_over)
	target_col = 3
	current_x = _col_to_x(target_col)
	position.x = current_x
	call_deferred("_spawn_start_text")
	
	_setup_lighting()

func _setup_lighting():
	var light = PointLight2D.new()
	light.color = Color(1.0, 0.85, 0.6)
	light.energy = 1.2
	light.texture_scale = 3.5
	light.blend_mode = Light2D.BLEND_MODE_ADD
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.7, Color(0.2, 0.2, 0.2, 1))
	gradient.add_point(1.0, Color(0, 0, 0, 1))
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = 256
	tex.height = 256
	
	light.texture = tex
	add_child(light)

func _spawn_start_text():
	var effects = get_node_or_null("/root/Effects")
	if effects:
		effects.spawn_floating_text(position - Vector2(0, 60), "DRILL!\nSwipe L/R", Color(1, 1, 1))

func _col_to_x(col: int) -> float:
	return GRID_OFFSET_X + col * COL_WIDTH + COL_WIDTH / 2.0

var is_drilling: bool = false
var current_drill_target = null
var frenzy_count: int = 0
var frenzy_timer: float = 0.0
var frenzy_mode: bool = false
var last_mine_time: float = 0.0

func _process(delta):
	if not gs or not gs.game_active:
		return

	# Frenzy logic
	if frenzy_mode:
		frenzy_timer -= delta
		if frenzy_timer <= 0:
			frenzy_mode = false
			frenzy_count = 0
	elif Time.get_ticks_msec() / 1000.0 - last_mine_time > 3.0:
		frenzy_count = 0 # reset combo if too slow

	# Speed logic
	var speed_mult = 1.0 + gs.depth / 1000.0
	if frenzy_mode: speed_mult *= 1.5
	
	speed = BASE_SPEED * speed_mult
	
	if speed_penalty > 0:
		speed_penalty = max(0.0, speed_penalty - delta * 2.5)

	var final_speed = speed * max(0.2, 1.0 - speed_penalty)

	if not grid_ref:
		grid_ref = get_parent().get_node_or_null("Grid")

	# Movement logic
	is_drilling = false
	var target_x = _col_to_x(target_col)
	var lateral_speed = 12.0
	if grid_ref and _check_side_collision(target_x):
		lateral_speed = 2.0
		is_drilling = true
	
	current_x = lerp(current_x, target_x, lateral_speed * delta)
	position.x = current_x

	if grid_ref:
		grid_ref.update_grid(position.y)
		var collision_targets = _get_all_collision_targets()
		
		if not collision_targets.is_empty():
			is_drilling = true
			for target in collision_targets:
				_process_drilling(target, delta)
			
			position.x += randf_range(-4, 4)
			position.y += randf_range(-1, 1)
			
			var effects = get_node_or_null("/root/Effects")
			if effects:
				effects.shake(1.0 if frenzy_mode else 0.4)
		else:
			position.y += final_speed * delta
			gs.set_depth(gs.depth + final_speed * delta * 0.05)
			if not frenzy_mode:
				gs.passive_cooling(delta)

	# Animate drill
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
	# Check bottom
	var b_target = _check_vertical_collision()
	if b_target: targets.append(b_target)
	
	# Check sides for "lateral mining"
	var drill_rect = Rect2(position.x - DRILL_WIDTH/2.0, position.y - DRILL_HEIGHT/2.0, DRILL_WIDTH, DRILL_HEIGHT)
	var row = grid_ref.get_row_at_y(position.y)
	
	for c in [int((drill_rect.position.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH), 
			  int((drill_rect.position.x + drill_rect.size.x - grid_ref.GRID_OFFSET_X) / grid_ref.COL_WIDTH)]:
		var block = grid_ref.get_block_at_row_col(row, c)
		if block and not block.get("is_dug", false):
			var found = false
			for t in targets:
				if t["block"] == block: found = true; break
			if not found:
				targets.append({"block": block, "row": row, "col": c})
	return targets

func _spawn_drill_sparks():
	var spark = {
		"x": position.x + randf_range(-DRILL_WIDTH/2, DRILL_WIDTH/2),
		"y": position.y + DRILL_HEIGHT / 2.0,
		"vx": randf_range(-100, 100),
		"vy": randf_range(-150, -50),
		"life": 0.4,
		"max_life": 0.4,
		"color": Color(1, 0.9, 0.4, 1),
		"size": randf_range(3, 6)
	}
	spark_particles.append(spark)

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
	# Drilling damage based on speed and upgrades
	var damage = delta * (1.5 if frenzy_mode else 1.0) * (1.0 + gs.depth / 2000.0) 
	block["health"] -= damage
	
	if randf() < 0.2:
		_spawn_break_particles(target["col"], target["row"], block["color"])
		
	if block["health"] <= 0:
		_drill_block(block, target["row"], target["col"])

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
	# Deprecated by new collision logic but keeping signature if needed
	pass

func _drill_block(block: Dictionary, row: int, col: int):
	if block == null or block.get("is_dug", false):
		return
	
	block["is_dug"] = true
	
	# Frenzy progress
	last_mine_time = Time.get_ticks_msec() / 1000.0
	frenzy_count += 1
	if frenzy_count >= 10 and not frenzy_mode:
		frenzy_mode = true
		frenzy_timer = 5.0
		var effects = get_node_or_null("/root/Effects")
		if effects:
			effects.spawn_floating_text(position, "FRENZY!", Color.ORANGE_RED)
			effects.shake(2.0)
	
	# Collect rewards
	gs.add_coins(block.get("coins", 0))
	gs.add_heat(block.get("heat", 0))
	gs.add_wear(block.get("wear", 0))
	
	# Spawn particles
	_spawn_break_particles(col, row, block["color"])
	
	# Shake camera on break
	var effects = get_node_or_null("/root/Effects")
	if effects:
		effects.shake(1.5)
		
		var spawn_pos = position + Vector2(randf_range(-20, 20), -30)
		# Show heat/coins/wear as floating text
		if block.get("heat", 0) != 0:
			var h = block["heat"]
			var color = Color.RED if h > 0 else Color.CYAN
			effects.spawn_floating_text(spawn_pos, str(h) + " 🔥", color)
		if block.get("coins", 0) > 0:
			effects.spawn_floating_text(spawn_pos + Vector2(0, -25), "+" + str(block["coins"]) + " 🪙", Color.GOLD)
		
		# Screen shake and speed penalty for hard blocks
		var b_type = block.get("type", 1)
		if b_type in [2, 3, 5]: # Stone, Granite, Diamond
			effects.shake(b_type * 1.5)
			speed_penalty = min(0.8, speed_penalty + 0.3)
	
	# Spawn break particles
	if grid_ref:
		var block_color = block.get("color", Color.WHITE)
		_spawn_break_particles(col, row, block_color)

	grid_ref.queue_redraw()

func _spawn_break_particles(col: int, row: int, color: Color):
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 20
	p.lifetime = 0.35
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0
	p.spread = 180.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 150
	p.initial_velocity_max = 300
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = color
	
	get_tree().current_scene.add_child(p)
	p.global_position = position + Vector2(0, DRILL_HEIGHT/2.5)
	p.emitting = true
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(p.queue_free)

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
	# --- DRAWING A COOL CARTOON DRILL MECHA ---
	
	# 1. Tracks/Side Base
	var track_color = Color(0.2, 0.2, 0.25)
	draw_rect(Rect2(-DRILL_WIDTH/2 - 4, -DRILL_HEIGHT/4, 12, DRILL_HEIGHT/2), track_color, true) # Left track
	draw_rect(Rect2(DRILL_WIDTH/2 - 8, -DRILL_HEIGHT/4, 12, DRILL_HEIGHT/2), track_color, true) # Right track
	
	# 2. Main Body (Dome/Capsule)
	var body_color = Color(0.4, 0.4, 0.5)
	if frenzy_mode:
		body_color = Color(0.8, 0.9, 1.0)
	var body_pts = PackedVector2Array()
	for i in range(18):
		var ang = PI + (i * PI / 17.0)
		body_pts.append(Vector2(cos(ang) * DRILL_WIDTH/2, sin(ang) * DRILL_HEIGHT/2 - 5))
	body_pts.append(Vector2(DRILL_WIDTH/2, 5))
	body_pts.append(Vector2(-DRILL_WIDTH/2, 5))
	draw_colored_polygon(body_pts, body_color)
	
	# 3. Cockpit Window
	var window_pts = PackedVector2Array()
	for i in range(10):
		var ang = PI + (i * PI / 9.0)
		window_pts.append(Vector2(cos(ang) * DRILL_WIDTH/3, sin(ang) * DRILL_HEIGHT/4 - 10))
	draw_colored_polygon(window_pts, Color(0.3, 0.7, 0.9, 0.8))
	
	# 4. Drill Bit (Large Rotating Cone)
	var bit_top_y = 5
	var bit_bottom_y = DRILL_HEIGHT / 2 + 10
	var bit_width = DRILL_WIDTH * 0.8
	
	var anim_offset = fmod(Time.get_ticks_msec() * 0.01, 1.0)
	var bit_pts = PackedVector2Array([
		Vector2(-bit_width/2, bit_top_y),
		Vector2(bit_width/2, bit_top_y),
		Vector2(0, bit_bottom_y)
	])
	draw_colored_polygon(bit_pts, Color(0.7, 0.7, 0.75)) # Base silver
	
	# Spiral stripes for rotation effect
	for i in range(4):
		var y_start = bit_top_y + (bit_bottom_y - bit_top_y) * fmod(float(i)/4.0 + anim_offset, 1.0)
		var y_end = min(y_start + 8, bit_bottom_y)
		
		var w_s = bit_width/2 * (1.0 - (y_start - bit_top_y)/(bit_bottom_y - bit_top_y))
		var w_e = bit_width/2 * (1.0 - (y_end - bit_top_y)/(bit_bottom_y - bit_top_y))
		
		var stripe_pts = PackedVector2Array([
			Vector2(-w_s, y_start), Vector2(w_s, y_start),
			Vector2(w_e, y_end), Vector2(-w_e, y_end)
		])
		draw_colored_polygon(stripe_pts, Color(0.9, 0.8, 0.2)) # Yellow stripes
	
	# 5. Heat Glow / Damage
	if gs:
		var heat_pct = gs.heat / gs.max_heat
		if heat_pct > 0.6:
			draw_circle(Vector2(0,0), DRILL_WIDTH * heat_pct, Color(1, 0.2, 0, (heat_pct-0.6)*0.5))

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
