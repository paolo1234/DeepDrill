extends Node

var camera: Camera2D = null
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var current_shake: Vector2 = Vector2.ZERO

var speed_lines_left: Line2D
var speed_lines_right: Line2D
var speed_line_timer: float = 0.0
var current_speed: float = 0.0

var heat_vignette: ColorRect
var heat_overlay_alpha: float = 0.0

var particles: Array = []

func _ready():
	_create_speed_lines()
	_create_heat_vignette()

func setup_camera(cam: Camera2D):
	camera = cam

func _create_speed_lines():
	speed_lines_left = Line2D.new()
	speed_lines_left.width = 3.0
	speed_lines_left.default_color = Color(1, 1, 1, 0.3)
	speed_lines_left.visible = false

	speed_lines_right = Line2D.new()
	speed_lines_right.width = 3.0
	speed_lines_right.default_color = Color(1, 1, 1, 0.3)
	speed_lines_right.visible = false

	var root = get_tree().root.get_node("main")
	if root:
		root.add_child(speed_lines_left)
		root.add_child(speed_lines_right)

func _create_heat_vignette():
	heat_vignette = ColorRect.new()
	heat_vignette.color = Color(1, 0, 0, 0)
	heat_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	heat_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var root = get_tree().root.get_node("main")
	if root:
		root.add_child(heat_vignette)

func _process(delta):
	_update_screen_shake(delta)
	_update_speed_lines(delta)
	_update_heat_vignette(delta)
	_update_particles(delta)

func screen_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration

func _update_screen_shake(delta):
	if shake_duration > 0 and camera:
		shake_duration -= delta
		current_shake = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera.offset = current_shake
		shake_intensity *= 0.9
		if shake_duration <= 0:
			camera.offset = Vector2.ZERO
			shake_intensity = 0

func update_drill_speed(speed: float):
	current_speed = speed

func _update_speed_lines(delta):
	if not speed_lines_left or not speed_lines_right:
		return

	var base_speed = 80.0
	if current_speed > base_speed * 1.5:
		var speed_factor = (current_speed / base_speed) - 1.0
		speed_lines_left.visible = true
		speed_lines_right.visible = true

		var left_points = PackedVector2Array()
		var right_points = PackedVector2Array()

		for i in range(5):
			var y_offset = i * 100 + fmod(Time.get_ticks_msec() * current_speed * 0.01, 100)
			left_points.append(Vector2(20, y_offset))
			right_points.append(Vector2(1060, y_offset))

		speed_lines_left.points = left_points
		speed_lines_right.points = right_points

		speed_lines_left.default_color.a = lerp(speed_lines_left.default_color.a, speed_factor * 0.3, delta * 5)
		speed_lines_right.default_color.a = speed_lines_left.default_color.a
	else:
		speed_lines_left.visible = false
		speed_lines_right.visible = false

func update_heat(heat_pct: float):
	heat_overlay_alpha = heat_pct

func _update_heat_vignette(delta):
	if heat_vignette:
		var target_alpha = 0.0
		if heat_overlay_alpha > 0.8:
			target_alpha = (heat_overlay_alpha - 0.8) * 2.0 * 0.5
		heat_vignette.color.a = lerp(heat_vignette.color.a, target_alpha, delta * 3)

func spawn_break_particles(position: Vector2, color: Color, count: int = 6):
	for i in range(count):
		var particle = {
			"position": position + Vector2(randf_range(-10, 10), randf_range(-5, 5)),
			"velocity": Vector2(randf_range(-150, 150), randf_range(-250, -50)),
			"life": 0.5,
			"max_life": 0.5,
			"color": color,
			"size": randf_range(3, 8)
		}
		particles.append(particle)

func _update_particles(delta):
	var to_remove = []
	for i in range(particles.size()):
		var p = particles[i]
		p.position += p.velocity * delta
		p.velocity.y += 400 * delta
		p.life -= delta
		if p.life <= 0:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		particles.remove_at(to_remove[i])

func cleanup():
	if speed_lines_left:
		speed_lines_left.queue_free()
	if speed_lines_right:
		speed_lines_right.queue_free()
	if heat_vignette:
		heat_vignette.queue_free()
	particles.clear()