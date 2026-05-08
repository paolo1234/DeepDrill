extends Node2D

const DRILL_WIDTH = 54.0
const DRILL_HEIGHT = 80.0

var gs = null
var target_col: int = 3
var move_speed: float = 300.0
var current_x: float = 0.0

var drill_anim_timer: float = 0.0
var drill_anim_frame: int = 0
var drill_y_offset: float = 0.0
var is_drilling: bool = false
var frenzy_mode: bool = false

# Touch Controls
var touch_start_pos: Vector2 = Vector2.ZERO
var swipe_threshold: float = 40.0

func _ready():
	gs = get_node("/root/GameState")
	if gs:
		gs.game_over.connect(_on_game_over)
		gs.frenzy_started.connect(func(): frenzy_mode = true)
		gs.frenzy_ended.connect(func(): frenzy_mode = false)
	
	target_col = 3
	current_x = _col_to_x(target_col)
	position = Vector2(current_x, 0) # Start at Y=0
	_setup_lighting()

func _setup_lighting():
	var light = PointLight2D.new()
	light.color = Color(1.0, 0.9, 0.7)
	light.energy = 1.7
	light.texture_scale = 1.8
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.z_index = 10
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0, 0, 0, 0))
	
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.9, 0.5)
	tex.width = 1024
	tex.height = 1024
	
	light.texture = tex
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(light)

func _process(delta):
	if not gs or not gs.game_active:
		return
		
	# Keyboard and Virtual Button support
	if Input.is_action_just_pressed("ui_left"):
		target_col = max(0, target_col - 1)
	elif Input.is_action_just_pressed("ui_right"):
		target_col = min(6, target_col + 1)
	
	current_x = lerp(current_x, _col_to_x(target_col), 15.0 * delta)
	position.x = current_x

	# Very subtle tilt logic to avoid motion sickness
	var target_rot = (target_col - 3) * 0.04 
	rotation = lerp_angle(rotation, target_rot, 5.0 * delta)
	
	# Smoke particles if high heat
	if gs.heat > gs.max_heat * 0.7:
		if fmod(Time.get_ticks_msec() * 0.001, 0.2) < 0.05:
			_spawn_smoke_particle()

	# Update grid references and movement
	var grid_node = get_node_or_null("../Grid")
	if grid_node:
		var row = grid_node.get_row_at_y(position.y + DRILL_HEIGHT/2.0 + 5)
		var block = grid_node.get_block_at_row_col(row, target_col)
		is_drilling = (block != null and not block.get("is_dug", false))

		var final_speed = move_speed
		if is_drilling: final_speed *= 0.4
		if frenzy_mode: final_speed *= 2.5
		
		if is_drilling:
			drill_y_offset += final_speed * delta
			if drill_y_offset >= 20.0:
				drill_y_offset = 0.0
				_mine_block(grid_node, row)
			
			var effects = get_node_or_null("/root/Effects")
			if effects: effects.shake(1.2 if frenzy_mode else 0.5)
		else:
			position.y += final_speed * delta
			gs.set_depth(position.y * 0.05) # Sync depth with METERS
			if not frenzy_mode:
				gs.passive_cooling(delta)

	drill_anim_timer += delta
	queue_redraw()

func _mine_block(grid, row):
	var block = grid.get_block_at_row_col(row, target_col)
	if block:
		var damage = 0.25
		if frenzy_mode: damage = 1.0
		block["health"] -= damage
		
		if block["health"] <= 0:
			block["is_dug"] = true
			_on_block_broken(block, Vector2(target_col * 154.0 + 77, row * 120.0 + 60), row)

func _on_block_broken(block: Dictionary, block_pos: Vector2, row: int):
	gs.add_coins(block.get("coins", 0))
	if not frenzy_mode:
		gs.add_heat(block.get("heat", 0))
		gs.add_wear(block.get("wear", 0))
	
	gs.increment_combo()
	var effects = get_node_or_null("/root/Effects")
	if effects:
		if gs.combo_counter > 1:
			effects.spawn_floating_text(block_pos, "COMBO x" + str(gs.combo_counter), Color.YELLOW if gs.combo_counter < 5 else Color.ORANGE_RED)
		
		if block.get("type") == 8: explode(block_pos)
		elif block.get("type") == 9: gs.trigger_frenzy()

	_spawn_break_particles(target_col, row, block.get("color", Color.WHITE))

func explode(pos: Vector2):
	var effects = get_node_or_null("/root/Effects")
	if effects:
		effects.shake(15.0)
		effects.spawn_explosion_flash(pos)
	
	var grid = get_node_or_null("../Grid")
	if grid:
		var row = grid.get_row_at_y(pos.y)
		var col = int(pos.x / 154.0)
		for r in range(row - 2, row + 3):
			for c in range(col - 2, col + 3):
				var b = grid.get_block_at_row_col(r, c)
				if b and not b.get("is_dug", false):
					b["is_dug"] = true
					gs.add_coins(b.get("coins", 0) / 2)

func _spawn_smoke_particle():
	var p = CPUParticles2D.new()
	p.position = position + Vector2(randf_range(-15, 15), -20)
	p.amount = 1
	p.one_shot = true
	p.direction = Vector2(0, -1)
	p.spread = 45.0
	p.gravity = Vector2(0, -200)
	p.initial_velocity_min = 50
	p.initial_velocity_max = 100
	p.scale_amount_min = 4
	p.scale_amount_max = 10
	p.color = Color(0.3, 0.3, 0.3, 0.6)
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _spawn_break_particles(col: int, row: int, color: Color):
	var p = CPUParticles2D.new()
	p.position = Vector2(col * 154.0 + 77, row * 120.0 + 60)
	p.amount = 12
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 400)
	p.initial_velocity_min = 150
	p.initial_velocity_max = 250
	p.scale_amount_min = 3
	p.scale_amount_max = 6
	p.color = color
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _draw():
	# Procedural Industrial Design (Restored)
	var body_color = Color(0.9, 0.45, 0.1) 
	if frenzy_mode: body_color = Color(0.3, 0.9, 1.0) # Neon Blue for Frenzy
	
	var metal_color = Color(0.4, 0.4, 0.45)
	
	# 1. Main Body (Capsule)
	draw_rect(Rect2(-24, -30, 48, 60), body_color, true)
	draw_circle(Vector2(0, -30), 24, body_color)
	
	# 2. Top "Head" (Dome)
	draw_circle(Vector2(0, -35), 18, metal_color)
	
	# 3. Cockpit Window
	draw_circle(Vector2(0, -20), 12, Color(0.2, 0.7, 1.0, 0.8)) 
	draw_circle(Vector2(-4, -24), 3, Color(1, 1, 1, 0.4)) 
	
	# 4. Side Thrusters/Joints
	draw_rect(Rect2(-32, 0, 8, 20), metal_color, true)
	draw_rect(Rect2(24, 0, 8, 20), metal_color, true)
	
	# 5. The Bit (Animated)
	var bit_offset = sin(drill_anim_timer * 60) * 5
	var bit_color = Color(0.6, 0.6, 0.6)
	if frenzy_mode: bit_color = Color(1, 1, 1)
	
	var bit_points = PackedVector2Array([
		Vector2(-20, 30),
		Vector2(20, 30),
		Vector2(0, 55 + bit_offset)
	])
	draw_colored_polygon(bit_points, bit_color)
	
	# Bit details (spirals)
	for i in range(3):
		var y_spiral = 35 + i * 6
		draw_line(Vector2(-15 + i*4, y_spiral), Vector2(15 - i*4, y_spiral), Color(0.3, 0.3, 0.3), 2.0)

func _col_to_x(col: int) -> float:
	return col * 154.0 + 77.0

func _on_game_over(_reason):
	set_process(false)
