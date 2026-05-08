extends Node

var camera: Camera2D

func shake(intensity: float, duration: float = 0.2):
	if camera:
		var original_pos = camera.offset
		var tween = create_tween()
		for i in range(5):
			var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(camera, "offset", offset, duration / 5.0)
		tween.tween_property(camera, "offset", original_pos, 0.1)

func spawn_floating_text(pos: Vector2, text: String, color: Color):
	var hud = get_node_or_null("/root/Main/HUD")
	if hud and hud.has_method("spawn_bright_text"):
		# Convert global game pos to screen pos for HUD
		var cam = get_viewport().get_camera_2d()
		if cam:
			var screen_pos = (pos - cam.get_screen_center_position()) + Vector2(540, 960)
			hud.spawn_bright_text(screen_pos, text, color)
			return

	# Fallback if HUD not ready
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	get_tree().current_scene.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", pos.y - 100, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0, 1.0)
	tween.tween_callback(label.queue_free)

func spawn_explosion(pos: Vector2):
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 30
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 250.0
	particles.color = Color(1, 0.5, 0.2)
	get_tree().current_scene.add_child(particles)
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

func spawn_explosion_flash(_pos: Vector2):
	# Create a bright flash overlay on the HUD layer
	var hud = get_node_or_null("/root/Main/HUD")
	if not hud: return
	
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 0.8, 0.6) # Bright yellowish white
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)
