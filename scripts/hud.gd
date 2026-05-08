extends CanvasLayer

@onready var depth_label: Label = $MarginContainer/VBoxContainer/TopStats/DepthLabel
@onready var coins_label: Label = $MarginContainer/VBoxContainer/TopStats/CoinsLabel
@onready var heat_bar: ProgressBar = $MarginContainer/VBoxContainer/HeatBox/HeatBar
@onready var heat_label: Label = $MarginContainer/VBoxContainer/HeatBox/HeatValue
@onready var dura_bar: ProgressBar = $MarginContainer/VBoxContainer/DuraBox/DuraBar
@onready var dura_label: Label = $MarginContainer/VBoxContainer/DuraBox/DuraValue

var gs = null

func _ready():
	# Make HUD container transparent to mouse
	$MarginContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_bar_styles()
	_create_mobile_controls()
	
	gs = get_node_or_null("/root/GameState")
	if gs:
		gs.heat_changed.connect(_on_heat_changed)
		gs.durability_changed.connect(_on_durability_changed)
		gs.coins_changed.connect(_on_coins_changed)
		gs.depth_changed.connect(_on_depth_changed)
		_update_initial_values()

func _create_mobile_controls():
	var controls = Control.new()
	controls.name = "MobileControls"
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)

	# Left Button
	var btn_left = Button.new()
	btn_left.name = "BtnLeft"
	btn_left.text = " < "
	btn_left.custom_minimum_size = Vector2(180, 180)
	btn_left.position = Vector2(50, get_viewport().get_visible_rect().size.y - 250)
	_style_mobile_button(btn_left)
	btn_left.pressed.connect(func(): _on_virtual_key("ui_left"))
	controls.add_child(btn_left)

	# Right Button
	var btn_right = Button.new()
	btn_right.name = "BtnRight"
	btn_right.text = " > "
	btn_right.custom_minimum_size = Vector2(180, 180)
	btn_right.position = Vector2(get_viewport().get_visible_rect().size.x - 230, get_viewport().get_visible_rect().size.y - 250)
	_style_mobile_button(btn_right)
	btn_right.pressed.connect(func(): _on_virtual_key("ui_right"))
	controls.add_child(btn_right)

func _style_mobile_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.4) # Semi-transparent
	style.border_width_left = 3; style.border_width_top = 3
	style.border_width_right = 3; style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.5, 0.6, 0.6)
	style.corner_radius_top_left = 90; style.corner_radius_top_right = 90
	style.corner_radius_bottom_right = 90; style.corner_radius_bottom_left = 90
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 64)

func _on_virtual_key(action: String):
	# Simulate keyboard input for the drill
	var ev = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	# Release immediately
	var ev_up = InputEventAction.new()
	ev_up.action = action
	ev_up.pressed = false
	Input.parse_input_event(ev_up)

func _setup_bar_styles():
	var heat_bg = StyleBoxFlat.new()
	heat_bg.bg_color = Color(0.1, 0.1, 0.15, 1)
	heat_bg.border_width_left = 2; heat_bg.border_width_top = 2
	heat_bg.border_width_right = 2; heat_bg.border_width_bottom = 2
	heat_bg.border_color = Color(0.05, 0.05, 0.1, 1)
	heat_bg.corner_radius_top_left = 8; heat_bg.corner_radius_top_right = 8
	heat_bg.corner_radius_bottom_left = 8; heat_bg.corner_radius_bottom_right = 8
	heat_bar.add_theme_stylebox_override("background", heat_bg)
	
	var heat_fill = StyleBoxFlat.new()
	heat_fill.bg_color = Color(0.9, 0.3, 0.1, 1) # Orange/Red
	heat_fill.corner_radius_top_left = 8; heat_fill.corner_radius_top_right = 8
	heat_fill.corner_radius_bottom_left = 8; heat_fill.corner_radius_bottom_right = 8
	heat_bar.add_theme_stylebox_override("fill", heat_fill)
	heat_bar.custom_minimum_size = Vector2(0, 16)
	
	var dura_bg = heat_bg.duplicate()
	dura_bar.add_theme_stylebox_override("background", dura_bg)
	
	var dura_fill = heat_fill.duplicate()
	dura_fill.bg_color = Color(0.2, 0.5, 0.9, 1) # Blue
	dura_bar.add_theme_stylebox_override("fill", dura_fill)
	dura_bar.custom_minimum_size = Vector2(0, 16)

func _update_initial_values():
	if not gs:
		return
	_on_depth_changed(gs.depth)
	_on_coins_changed(gs.coins)
	_on_heat_changed(gs.heat, gs.max_heat)
	_on_durability_changed(gs.durability, gs.max_durability)

func _process(delta):
	if gs and gs.game_active:
		# Pulse heat bar if near overheating
		if gs.heat > gs.max_heat * 0.8:
			var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.01) * 0.5
			heat_bar.modulate = Color(1, 1, 1).lerp(Color(2, 0.5, 0.5), pulse)
			
			# Very subtle screen flash
			if fmod(Time.get_ticks_msec() * 0.005, 1.0) > 0.8:
				_flash_screen(Color(0.8, 0.1, 0.1, 0.1))
		else:
			heat_bar.modulate = Color(1, 1, 1)

func _flash_screen(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	get_tree().create_timer(0.1).timeout.connect(flash.queue_free)

func _on_depth_changed(value: float):
	if is_instance_valid(depth_label):
		depth_label.text = "Depth: %d m" % int(value)

func _on_heat_changed(value: float, max_val: float):
	if is_instance_valid(heat_label):
		heat_label.text = "%d/%d" % [int(value), int(max_val)]
	if is_instance_valid(heat_bar) and max_val > 0:
		heat_bar.value = (value / max_val) * 100

func _on_durability_changed(value: float, max_val: float):
	if is_instance_valid(dura_label):
		dura_label.text = "%d/%d" % [int(value), int(max_val)]
	if is_instance_valid(dura_bar) and max_val > 0:
		dura_bar.value = (value / max_val) * 100

func _on_coins_changed(value: int):
	if is_instance_valid(coins_label):
		coins_label.text = "Coins: %d" % value