extends Control

var can_start = false

func _ready():
	# Make tap label pulse
	var tween = create_tween().set_loops()
	var tap_label = $CenterContainer/PanelContainer/Margin/VBox/TapLabel
	tween.tween_property(tap_label, "modulate:a", 0.3, 0.8)
	tween.tween_property(tap_label, "modulate:a", 1.0, 0.8)
	
	# Prevent instant start from bleed input
	await get_tree().create_timer(0.5).timeout
	can_start = true

func _gui_input(event):
	if not can_start: return
	if event is InputEventScreenTouch and event.pressed:
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()

func _start():
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.game_active = true
	queue_free()
