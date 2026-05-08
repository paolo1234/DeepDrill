extends CanvasLayer

var gs = null
var heat_label_new = null
var dura_label_new = null
var depth_label_new = null
var coins_label_new = null

func _ready():
	# Hide legacy UI elements
	if has_node("MarginContainer"):
		$MarginContainer.hide()
	
	# Create Custom Premium HUD Layout
	_create_premium_hud()
	_create_mobile_controls()
	
	gs = get_node_or_null("/root/GameState")
	if gs:
		gs.heat_changed.connect(_on_heat_changed)
		gs.durability_changed.connect(_on_durability_changed)
		gs.coins_changed.connect(_on_coins_changed)
		gs.depth_changed.connect(_on_depth_changed)

func _create_premium_hud():
	var root = Control.new()
	root.name = "PremiumHUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Cards (Pills)
	var heat_card = _create_stat_card(Vector2(20, 20), "🌡️", Color(1.0, 0.4, 0.2))
	heat_label_new = heat_card.get_node("Margin/ValueLabel")
	root.add_child(heat_card)

	var depth_card = _create_stat_card(Vector2(get_viewport().get_visible_rect().size.x / 2 - 110, 20), "📏", Color(0.4, 0.4, 0.5))
	depth_label_new = depth_card.get_node("Margin/ValueLabel")
	root.add_child(depth_card)

	var dura_card = _create_stat_card(Vector2(20, get_viewport().get_visible_rect().size.y - 100), "🔧", Color(0.2, 0.6, 1.0))
	dura_label_new = dura_card.get_node("Margin/ValueLabel")
	root.add_child(dura_card)

	var coins_card = _create_stat_card(Vector2(get_viewport().get_visible_rect().size.x / 2 - 110, get_viewport().get_visible_rect().size.y - 100), "💰", Color(1.0, 0.8, 0.2))
	coins_label_new = coins_card.get_node("Margin/ValueLabel")
	root.add_child(coins_card)

func _create_stat_card(pos: Vector2, icon: String, color: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	pc.position = pos
	pc.custom_minimum_size = Vector2(220, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.corner_radius_top_left = 30; style.corner_radius_top_right = 30
	style.corner_radius_bottom_right = 30; style.corner_radius_bottom_left = 30
	style.border_width_bottom = 4; style.border_color = color
	style.content_margin_left = 15; style.content_margin_right = 15
	pc.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.name = "Margin"
	pc.add_child(margin)
	
	var label = Label.new()
	label.name = "ValueLabel"
	label.text = icon + " --"
	label.add_theme_font_size_override("font_size", 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	
	return pc

func _create_mobile_controls():
	var controls = Control.new()
	controls.name = "MobileControls"
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)

	# Navigation
	var btn_left = Button.new()
	btn_left.text = "◀"
	btn_left.custom_minimum_size = Vector2(160, 160)
	btn_left.position = Vector2(50, get_viewport().get_visible_rect().size.y - 210)
	_style_round_btn(btn_left, Color(0.3, 0.3, 0.3, 0.4))
	btn_left.pressed.connect(func(): _sim_key("ui_left"))
	controls.add_child(btn_left)

	var btn_right = Button.new()
	btn_right.text = "▶"
	btn_right.custom_minimum_size = Vector2(160, 160)
	btn_right.position = Vector2(get_viewport().get_visible_rect().size.x - 210, get_viewport().get_visible_rect().size.y - 210)
	_style_round_btn(btn_right, Color(0.3, 0.3, 0.3, 0.4))
	btn_right.pressed.connect(func(): _sim_key("ui_right"))
	controls.add_child(btn_right)

	# Pause
	var btn_pause = Button.new()
	btn_pause.text = "⏸"
	btn_pause.custom_minimum_size = Vector2(100, 100)
	btn_pause.position = Vector2(get_viewport().get_visible_rect().size.x - 120, 20)
	_style_round_btn(btn_pause, Color(0.4, 0.4, 0.5, 0.6))
	btn_pause.pressed.connect(_on_pause_pressed)
	controls.add_child(btn_pause)

func _style_round_btn(btn: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 100; style.corner_radius_top_right = 100
	style.corner_radius_bottom_right = 100; style.corner_radius_bottom_left = 100
	style.border_width_left = 4; style.border_width_top = 4; style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(1, 1, 1, 0.15)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 48)

func _sim_key(action: String):
	var ev = InputEventAction.new()
	ev.action = action; ev.pressed = true; Input.parse_input_event(ev)
	var ev_up = InputEventAction.new()
	ev_up.action = action; ev_up.pressed = false; Input.parse_input_event(ev_up)

func _on_pause_pressed():
	if gs: gs.game_active = !gs.game_active

func _on_heat_changed(val, max_val):
	if heat_label_new:
		heat_label_new.text = "🌡️ %d%%" % int((val/max_val)*100 if max_val > 0 else 0)

func _on_durability_changed(val, max_val):
	if dura_label_new:
		dura_label_new.text = "🔧 %d%%" % int((val/max_val)*100 if max_val > 0 else 0)

func _on_coins_changed(new_coins: int):
	if coins_label_new:
		coins_label_new.text = "💰 %d" % new_coins

func _on_depth_changed(new_depth: float):
	if depth_label_new:
		depth_label_new.text = "📏 %d m" % int(new_depth)
