extends CanvasLayer

var gs = null
var pause_menu: Control = null
var touch_controls: Control = null
var consumables_vbox: VBoxContainer = null

func set_touch_visible(p_visible: bool):
	if touch_controls: touch_controls.visible = p_visible

func set_hud_visible(p_visible: bool):
	visible = p_visible

func _ready():
	# Ensure UI is always on top and ignore world lighting
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	for child in get_children():
		child.queue_free()
	
	gs = get_node("/root/GameState")
	if gs:
		gs.heat_changed.connect(_on_heat_changed)
		gs.durability_changed.connect(_on_durability_changed)
		gs.coins_changed.connect(_on_coins_changed)
		gs.depth_changed.connect(_on_depth_changed)
	
	_setup_hud()
	_create_touch_controls()
	
	# Initial refresh
	if gs:
		_on_coins_changed(gs.coins)
		_on_depth_changed(gs.depth)
		_on_heat_changed(gs.heat, gs.max_heat)
		_on_durability_changed(gs.durability, gs.max_durability)

func _setup_hud():
	# 1. DEPTH PILL (TOP CENTER)
	var depth_pill = _create_pill("DepthPill", Vector2(540, 80), Color(0.1, 0.5, 1.0), "📏", "0 m")
	add_child(depth_pill)
	# Force center align using pivot
	depth_pill.position = Vector2(540 - depth_pill.size.x / 2, 70)

	# 2. COINS PILL (TOP RIGHT)
	var coin_pill = _create_pill("CoinPill", Vector2(1010, 80), Color(1.0, 0.8, 0.2), "💰", "0")
	add_child(coin_pill)
	# Align to right edge with 70px margin
	coin_pill.position = Vector2(1010 - coin_pill.size.x, 70)

	# 3. STATUS BARS (TOP LEFT)
	_create_status_bar("DuraBar", Vector2(150, 80), Color(0.2, 0.9, 0.4), "⚡")
	_create_status_bar("HeatBar", Vector2(150, 180), Color(1.0, 0.3, 0.1), "🔥")

	# 4. PAUSE BUTTON (TOP RIGHT)
	_create_premium_pause_btn(Vector2(950, 240))

	# 5. CONSUMABLES INVENTORY BAR
	_create_consumables_bar()

func _create_consumables_bar():
	consumables_vbox = VBoxContainer.new()
	consumables_vbox.position = Vector2(910, 400) # Below pause button
	consumables_vbox.add_theme_constant_override("separation", 25)
	add_child(consumables_vbox)
	_refresh_consumables()

func _refresh_consumables():
	for child in consumables_vbox.get_children():
		child.queue_free()
	
	var sm = get_node_or_null("/root/SaveManager")
	if not sm: return
	
	for item_id in gs.CONSUMABLES.keys():
		var count = sm.get_item_count(item_id)
		if count > 0:
			var btn = _create_consumable_btn(item_id, count)
			consumables_vbox.add_child(btn)

func _create_consumable_btn(item_id: String, count: int) -> Button:
	var data = gs.CONSUMABLES[item_id]
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(140, 140)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	s.set_corner_radius_all(30)
	s.border_width_left = 3; s.border_width_top = 3; s.border_width_right = 3; s.border_width_bottom = 3
	s.border_color = Color(0.4, 0.7, 1.0)
	btn.add_theme_stylebox_override("normal", s)
	
	var icon = Label.new()
	icon.text = data["icon"]
	icon.add_theme_font_size_override("font_size", 60)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(icon)
	
	var badge = Label.new()
	badge.text = "x" + str(count)
	badge.add_theme_font_size_override("font_size", 34)
	badge.add_theme_color_override("font_color", Color(1, 1, 0.2))
	badge.position = Vector2(80, 90) # Bottom right corner
	btn.add_child(badge)
	
	btn.pressed.connect(func(): _on_consumable_pressed(item_id))
	return btn

func _on_consumable_pressed(item_id: String):
	if gs.trigger_consumable(item_id):
		_refresh_consumables()

func _create_pill(node_name: String, pos: Vector2, color: Color, icon: String, text: String) -> PanelContainer:
	var p = PanelContainer.new()
	p.name = node_name
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	s.set_corner_radius_all(40)
	s.border_width_left = 4; s.border_width_top = 4; s.border_width_right = 4; s.border_width_bottom = 4
	s.border_color = color
	p.add_theme_stylebox_override("panel", s)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	p.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	
	var ic = Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 40)
	hbox.add_child(ic)
	
	var lbl = Label.new()
	lbl.name = "ValueLabel"
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 44)
	hbox.add_child(lbl)
	
	# Force size calculation so we can position it correctly
	p.reset_size()
	return p

func _create_status_bar(bar_name: String, pos: Vector2, color: Color, icon: String):
	var container = Control.new()
	container.name = bar_name
	container.position = pos
	add_child(container)
	
	# The background track for the bar
	var bg = Panel.new()
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.02, 0.02, 0.05, 0.9)
	bs.set_corner_radius_all(30)
	bs.border_width_left = 3; bs.border_width_top = 3; bs.border_width_right = 3; bs.border_width_bottom = 3
	bs.border_color = color.lerp(Color.BLACK, 0.5)
	bg.add_theme_stylebox_override("panel", bs)
	bg.size = Vector2(280, 60)
	container.add_child(bg)
	
	# The actual filling progress bar
	var bar = ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = true
	bar.size = Vector2(210, 48)
	bar.position = Vector2(60, 6) # Shifted right to avoid overlapping the circle
	var fs = StyleBoxFlat.new()
	fs.bg_color = color
	fs.set_corner_radius_all(24)
	var bks = StyleBoxFlat.new()
	bks.bg_color = Color(0, 0, 0, 0) # Hidden background
	bar.add_theme_stylebox_override("fill", fs)
	bar.add_theme_stylebox_override("background", bks)
	bar.add_theme_font_size_override("font_size", 24)
	container.add_child(bar)
	
	# The circle icon that sits on the left edge
	var circle = Panel.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.05, 0.05, 0.1, 1.0)
	cs.border_width_left = 4; cs.border_width_top = 4; cs.border_width_right = 4; cs.border_width_bottom = 4
	cs.border_color = color
	cs.set_corner_radius_all(42)
	circle.add_theme_stylebox_override("panel", cs)
	circle.size = Vector2(84, 84)
	circle.position = Vector2(-25, -12) # Protrudes slightly out of the bar
	container.add_child(circle)
	
	var il = Label.new()
	il.text = icon
	il.add_theme_font_size_override("font_size", 44)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	il.size = Vector2(84, 84)
	circle.add_child(il)

func _create_touch_controls():
	touch_controls = Control.new(); touch_controls.name = "TouchControls"; add_child(touch_controls)
	
	var left = _create_pop_control_btn("◀", Vector2(200, 1680), Color(0.2, 0.6, 1.0))
	left.button_down.connect(func(): Input.action_press("ui_left"))
	left.button_up.connect(func(): Input.action_release("ui_left"))
	touch_controls.add_child(left)
	
	var right = _create_pop_control_btn("▶", Vector2(880, 1680), Color(0.2, 0.6, 1.0))
	right.button_down.connect(func(): Input.action_press("ui_right"))
	right.button_up.connect(func(): Input.action_release("ui_right"))
	touch_controls.add_child(right)

func _create_pop_control_btn(txt: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new(); btn.text = txt; btn.custom_minimum_size = Vector2(220, 220); btn.position = pos - Vector2(110, 110)
	var s = StyleBoxFlat.new(); s.bg_color = Color(color.r, color.g, color.b, 0.15); s.set_corner_radius_all(110); s.border_width_left = 6; s.border_width_top = 6; s.border_width_right = 6; s.border_width_bottom = 6; s.border_color = color; s.shadow_size = 20; s.shadow_color = Color(color.r, color.g, color.b, 0.2)
	var h = s.duplicate(); h.bg_color = Color(color.r, color.g, color.b, 0.3); h.border_color = Color.WHITE
	var p = s.duplicate(); p.bg_color = Color(color.r, color.g, color.b, 0.5); p.shadow_size = 5
	btn.add_theme_stylebox_override("normal", s); btn.add_theme_stylebox_override("hover", h); btn.add_theme_stylebox_override("pressed", p); btn.add_theme_font_size_override("font_size", 90)
	return btn

func _create_premium_pause_btn(pos: Vector2):
	var btn = Button.new(); btn.position = pos - Vector2(55, 55); btn.custom_minimum_size = Vector2(110, 110)
	var s = StyleBoxFlat.new(); s.bg_color = Color(0.1, 0.1, 0.15, 0.9); s.set_corner_radius_all(55); s.border_width_left = 4; s.border_width_top = 4; s.border_width_right = 4; s.border_width_bottom = 4; s.border_color = Color(0.4, 0.7, 1.0)
	btn.add_theme_stylebox_override("normal", s); btn.pressed.connect(_toggle_pause); add_child(btn)
	var ic = Label.new(); ic.text = "⏸"; ic.add_theme_font_size_override("font_size", 60); ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ic.size = Vector2(110, 110); btn.add_child(ic)

func _toggle_pause():
	if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_button_click()
	if pause_menu != null: _close_pause_menu()
	else: _open_pause_menu()

func _open_pause_menu():
	get_tree().paused = true
	if touch_controls: touch_controls.visible = false
	pause_menu = Control.new(); pause_menu.name = "PauseMenu"; pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(pause_menu)
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0.8); bg.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.add_child(bg)
	var panel = PanelContainer.new(); var s = StyleBoxFlat.new(); s.bg_color = Color(0.1, 0.12, 0.2, 0.98); s.set_corner_radius_all(50); s.border_width_left = 6; s.border_width_top = 6; s.border_width_right = 6; s.border_width_bottom = 12; s.border_color = Color(0.2, 0.7, 1.0); s.shadow_size = 50; panel.add_theme_stylebox_override("panel", s); panel.custom_minimum_size = Vector2(750, 900); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-375, -450); pause_menu.add_child(panel)
	var m = MarginContainer.new(); m.add_theme_constant_override("margin_left", 60); m.add_theme_constant_override("margin_right", 60); m.add_theme_constant_override("margin_top", 60); m.add_theme_constant_override("margin_bottom", 60); panel.add_child(m)
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 55); m.add_child(vb)
	var t = Label.new(); t.text = "MISSION PAUSED"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 64); t.modulate = Color(0.4, 0.8, 1.0); vb.add_child(t)
	vb.add_child(_create_volume_row("🎵 MUSIC", "Music")); vb.add_child(_create_volume_row("🔊 SFX", "SFX"))
	vb.add_child(Control.new())
	var resume_btn = _create_pop_btn_styled("RESUME MISSION", Color(0.2, 0.7, 0.3)); resume_btn.pressed.connect(_close_pause_menu); vb.add_child(resume_btn)
	var quit_btn = _create_pop_btn_styled("ABANDON MISSION", Color(0.8, 0.2, 0.2)); quit_btn.pressed.connect(_quit_to_menu); vb.add_child(quit_btn)

func _close_pause_menu():
	get_tree().paused = false
	if touch_controls: touch_controls.visible = true
	if pause_menu: pause_menu.queue_free(); pause_menu = null

func _create_volume_row(label: String, bus_name: String) -> VBoxContainer:
	var row = VBoxContainer.new(); row.add_theme_constant_override("separation", 20)
	var l = Label.new(); l.text = label; l.add_theme_font_size_override("font_size", 32); row.add_child(l)
	var slider = HSlider.new(); slider.custom_minimum_size.y = 80; slider.min_value = 0; slider.max_value = 1.0; slider.step = 0.05
	var grabber_icon = GradientTexture2D.new(); grabber_icon.width = 44; grabber_icon.height = 44; var g = Gradient.new(); g.set_color(0, Color.WHITE); g.set_color(1, Color.WHITE); grabber_icon.gradient = g; grabber_icon.fill = GradientTexture2D.FILL_RADIAL; grabber_icon.fill_from = Vector2(0.5, 0.5)
	slider.add_theme_icon_override("grabber", grabber_icon); slider.add_theme_icon_override("grabber_highlight", grabber_icon)
	var bi = AudioServer.get_bus_index(bus_name); slider.value = db_to_linear(AudioServer.get_bus_volume_db(bi)); slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(bi, linear_to_db(v)))
	row.add_child(slider); return row

func _create_pop_btn_styled(txt: String, color: Color) -> Button:
	var btn = Button.new(); btn.text = txt; btn.custom_minimum_size = Vector2(0, 130)
	var n = StyleBoxFlat.new(); n.bg_color = color; n.set_corner_radius_all(30); n.border_width_bottom = 12; n.border_color = color.darkened(0.4)
	var h = n.duplicate(); h.bg_color = color.lightened(0.2); h.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", n); btn.add_theme_stylebox_override("hover", h); btn.add_theme_font_size_override("font_size", 44); return btn

func _quit_to_menu():
	var sm = get_node_or_null("/root/SaveManager")
	if sm and gs:
		sm.update_best_depth(gs.depth)
		sm.add_coins(gs.coins)
		# Clear current run coins so we don't save them twice if something else triggers
		gs.coins = 0 
		
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func spawn_bright_text(pos: Vector2, txt: String, color: Color):
	var lbl = Label.new(); lbl.text = txt; lbl.add_theme_font_size_override("font_size", 42); lbl.add_theme_color_override("font_color", color); lbl.add_theme_color_override("font_outline_color", Color.BLACK); lbl.add_theme_constant_override("outline_size", 10); add_child(lbl)
	lbl.global_position = pos; var tw = create_tween().set_parallel(true); tw.tween_property(lbl, "global_position:y", pos.y - 180, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(lbl, "modulate:a", 0.0, 1.5); tw.chain().tween_callback(lbl.queue_free)

func _on_heat_changed(val, max_val):
	var b = get_node_or_null("HeatBar/Bar"); if b: b.value = (val / max_val) * 100
func _on_durability_changed(val, max_val):
	var b = get_node_or_null("DuraBar/Bar"); if b: b.value = (val / max_val) * 100
func _on_coins_changed(val):
	var pill = find_child("CoinPill", true, false)
	if pill:
		var lbl = pill.find_child("ValueLabel", true, false)
		if lbl: lbl.text = str(val)
func _on_depth_changed(val):
	var pill = find_child("DepthPill", true, false)
	if pill:
		var lbl = pill.find_child("ValueLabel", true, false)
		if lbl: lbl.text = "%d m" % int(val)
