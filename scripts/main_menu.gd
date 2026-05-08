extends Control

var settings_panel: PanelContainer

func _ready():
	# Background style
	if has_node("ColorRect"):
		$ColorRect.color = Color(0.05, 0.08, 0.12, 1.0)
	
	_style_all_buttons(self )
	_create_settings_panel()

func _style_all_buttons(node: Node):
	for child in node.get_children():
		if child is Button:
			_apply_casual_btn_style(child)
		elif child.get_child_count() > 0:
			_style_all_buttons(child)

func _apply_casual_btn_style(btn: Button):
	var color = Color(0.2, 0.5, 0.9)
	var icon = "▶"
	
	var t = btn.text.to_upper()
	if "START" in t:
		color = Color(0.1, 0.5, 0.95)
		icon = "▶"
		btn.text = icon + " START DRILLING"
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.pressed.connect(_on_start_pressed)
	elif "SHOP" in t or "PERMANENT" in t:
		color = Color(0.95, 0.55, 0.1)
		icon = "💰"
		btn.text = icon + " UPGRADE SHOP"
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.pressed.connect(_on_shop_pressed)
	elif "SETTINGS" in t:
		color = Color(0.6, 0.4, 0.9)
		icon = "⚙"
		btn.text = icon + " SETTINGS"
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		btn.pressed.connect(_on_settings_pressed)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 35; style.corner_radius_top_right = 35
	style.corner_radius_bottom_right = 35; style.corner_radius_bottom_left = 35
	style.border_width_bottom = 12; style.border_color = color.darkened(0.4)
	style.shadow_size = 15; style.shadow_color = Color(0, 0, 0, 0.3)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 34)
	btn.custom_minimum_size.y = 100

func _create_settings_panel():
	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(500, 650)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_panel.visible = false
	add_child(settings_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 1)
	style.corner_radius_top_left = 50; style.corner_radius_top_right = 50
	style.corner_radius_bottom_right = 50; style.corner_radius_bottom_left = 50
	style.border_width_top = 15; style.border_color = Color(0.6, 0.4, 0.9)
	settings_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 35)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(title)
	
	_create_vol_slider(vbox, "MASTER VOLUME", 0)
	_create_vol_slider(vbox, "MUSIC VOLUME", 1)
	_create_vol_slider(vbox, "EFFECTS VOLUME", 2)
	
	var btn_close = Button.new()
	btn_close.text = "CLOSE"
	btn_close.custom_minimum_size = Vector2(350, 90)
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.4, 0.4, 0.4)
	c_style.corner_radius_top_left = 30; c_style.corner_radius_top_right = 30
	c_style.corner_radius_bottom_right = 30; c_style.corner_radius_bottom_left = 30
	btn_close.add_theme_stylebox_override("normal", c_style)
	btn_close.pressed.connect(func(): settings_panel.visible = false)
	vbox.add_child(btn_close)

func _create_vol_slider(parent: VBoxContainer, label: String, bus_idx: int):
	var cont = VBoxContainer.new()
	parent.add_child(cont)
	var lbl = Label.new()
	lbl.text = label; lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	cont.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = -60; slider.max_value = 0
	slider.value = AudioServer.get_bus_volume_db(bus_idx)
	slider.custom_minimum_size.x = 400
	slider.value_changed.connect(func(val): AudioServer.set_bus_volume_db(bus_idx, val))
	cont.add_child(slider)

func _on_settings_pressed():
	settings_panel.visible = true

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_shop_pressed():
	get_tree().change_scene_to_file("res://scenes/upgrade_shop.tscn")
