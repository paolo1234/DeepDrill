extends Node

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var camera: Camera2D = null

func _process(delta):
	if camera == null or not is_instance_valid(camera):
		var scene = get_tree().current_scene
		if scene:
			camera = scene.get_viewport().get_camera_2d()
	
	if shake_intensity > 0:
		shake_intensity = max(0.0, shake_intensity - shake_decay * delta)
		if camera and is_instance_valid(camera):
			camera.offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
	elif camera and is_instance_valid(camera):
		camera.offset = Vector2.ZERO

func shake(intensity: float):
	shake_intensity = max(shake_intensity, intensity)

func spawn_floating_text(pos: Vector2, text: String, color: Color, parent: Node2D = null):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if parent: parent.add_child(label)
	else: get_tree().current_scene.add_child(label)
	
	label.global_position = pos - Vector2(label.size.x / 2.0, label.size.y / 2.0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 80.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func spawn_explosion_flash(pos: Vector2):
	# 1. Full screen flash
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.9, 0.6, 0.6)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var canvas = CanvasLayer.new()
	canvas.add_child(flash)
	get_tree().current_scene.add_child(canvas)
	
	var tween = canvas.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.25)
	tween.tween_callback(canvas.queue_free)

	# 2. Shockwave Ring
	var sw = CPUParticles2D.new()
	sw.position = pos
	sw.amount = 1
	sw.one_shot = true
	sw.direction = Vector2.ZERO
	sw.spread = 0
	sw.gravity = Vector2.ZERO
	sw.initial_velocity_min = 0
	sw.scale_amount_min = 1.0
	sw.scale_amount_max = 1.0
	
	# We use a trick: draw a circle that expands via tween
	var ring = Node2D.new()
	ring.position = pos
	get_tree().current_scene.add_child(ring)
	
	var r_script = GDScript.new()
	r_script.source_code = "extends Node2D\nvar radius = 10.0\nvar alpha = 1.0\nfunc _process(delta):\n\tradius += 1200.0 * delta\n\talpha -= 2.5 * delta\n\tif alpha <= 0: queue_free()\n\tqueue_redraw()\nfunc _draw():\n\tdraw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1,1,1,alpha), 10.0)"
	ring.set_script(r_script)

	# 3. Heavy Explosion Particles
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 60
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 250
	p.initial_velocity_max = 500
	p.scale_amount_min = 15
	p.scale_amount_max = 40
	p.color_ramp = Gradient.new()
	p.color_ramp.add_point(0.0, Color(1, 1, 0.5, 1))
	p.color_ramp.add_point(0.15, Color(1, 0.4, 0.0, 1))
	p.color_ramp.add_point(0.5, Color(0.2, 0.2, 0.2, 0.8))
	p.color_ramp.add_point(1.0, Color(0, 0, 0, 0))
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)