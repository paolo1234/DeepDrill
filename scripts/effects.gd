extends Node

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var camera: Camera2D = null

func _process(delta):
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
	
	# Center the text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if parent:
		parent.add_child(label)
	else:
		get_tree().current_scene.add_child(label)
		
	label.global_position = pos - Vector2(label.size.x / 2.0, label.size.y / 2.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	# Float up
	tween.tween_property(label, "global_position:y", label.global_position.y - 60.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Jiggle slightly for heat/wear
	if color == Color.RED or color == Color.LIGHT_SLATE_GRAY:
		var jiggle = create_tween().set_loops(4)
		jiggle.tween_property(label, "position:x", label.position.x + 10, 0.1)
		jiggle.tween_property(label, "position:x", label.position.x - 10, 0.1)
	
	tween.chain().tween_callback(label.queue_free)