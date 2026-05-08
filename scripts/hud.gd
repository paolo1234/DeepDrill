extends CanvasLayer

var gs = null
var pause_menu: Control = null

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

func _setup_hud():
	# 1. DEPTH PILL (TOP CENTER)
	var depth_pill = _create_pill_container(Vector2(540, 70), Color(0.1, 0.5, 1.0))
	add_child(depth_pill)
	var dl_icon = Label.new(); dl_icon.text = "📏"; dl_icon.position = Vector2(15, 8); dl_icon.add_theme_font_size_override("font_size", 30); depth_pill.add_child(dl_icon)
	var dl = Label.new(); dl.name = "DepthLabel"; dl.text = "0 m"; dl.add_theme_font_size_override("font_size", 34)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; depth_pill.add_child(dl); dl.position = Vector2(60, 8); dl.size = Vector2(110, 44)

	# 2. COINS PILL (TOP RIGHT)
	var coin_pill = _create_pill_container(Vector2(920, 70), Color(1.0, 0.8, 0.2))
	add_child(coin_pill)
	var cl_icon = Label.new(); cl_icon.text = "💰"; cl_icon.position = Vector2(15, 8); cl_icon.add_theme_font_size_override("font_size", 30); coin_pill.add_child(cl_icon)
	var cl = Label.new(); cl.name = "CoinLabel"; cl.text = "0"; cl.add_theme_font_size_override("font_size", 34)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; coin_pill.add_child(cl); cl.position = Vector2(60, 8); cl.size = Vector2(100, 44)

	# 3. STATUS BARS (TOP LEFT - Vertical Stack)
	_create_status_bar("DuraBar", Vector2(160, 70), Color(0.2, 0.9, 0.4), "⚡")
	_create_status_bar("HeatBar", Vector2(160, 160), Color(1.0, 0.3, 0.1), "🔥")

	# 4. PAUSE BUTTON (TOP RIGHT CORNER)
	_create_premium_pause_btn(Vector2(1020, 180))

func _create_pill_container(pos: Vector2, color: Color) -> Panel:
	var p = Panel.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	s.set_corner_radius_all(30)
	s.border_width_left = 3; s.border_width_top = 3; s.border_width_right = 3; s.border_width_bottom = 3
	s.border_color = color
	s.shadow_size = 10; s.shadow_color = Color(color.r, color.g, color.b, 0.3)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(180, 60)
	p.position = pos - Vector2(90, 30)
	return p

func _create_status_bar(bar_name: String, pos: Vector2, color: Color, icon: String):
	var container = Control.new(); container.name = bar_name; container.position = pos - Vector2(100, 40); add_child(container)
	var bg = Panel.new(); var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.02, 0.02, 0.05, 0.95); bs.set_corner_radius_all(30); bs.border_width_left = 3; bs.border_width_top = 3; bs.border_width_right = 3; bs.border_width_bottom = 3; bs.border_color = color.lerp(Color.BLACK, 0.5); bg.add_theme_stylebox_override("panel", bs); bg.size = Vector2(250, 60); container.add_child(bg)
	var bar = ProgressBar.new(); bar.name = "Bar"; bar.show_percentage = true; bar.size = Vector2(240, 50); bar.position = Vector2(5, 5); var fs = StyleBoxFlat.new(); fs.bg_color = color; fs.set_corner_radius_all(25); var bks = StyleBoxFlat.new(); bks.bg_color = Color(0, 0, 0, 0); bar.add_theme_stylebox_override("fill", fs); bar.add_theme_stylebox_override("background", bks); bar.add_theme_font_size_override("font_size", 22); container.add_child(bar)
	var circle = Panel.new(); var cs = StyleBoxFlat.new(); cs.bg_color = Color(0.05, 0.05, 0.1, 1.0); cs.border_width_left = 3; cs.border_width_top = 3; cs.border_width_right = 3; cs.border_width_bottom = 3; cs.border_color = color; cs.set_corner_radius_all(35); circle.add_theme_stylebox_override("panel", cs); circle.size = Vector2(70, 70); circle.position = Vector2(-35, -5); container.add_child(circle)
	var il = Label.new(); il.text = icon; il.add_theme_font_size_override("font_size", 34); il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; il.size = Vector2(70, 70); circle.add_child(il)

func _create_touch_controls():
	var left = _create_pop_control_btn("◀", Vector2(180, 1650), Color(0.1, 0.6, 1.0))
	left.button_down.connect(func(): Input.action_press("ui_left"))
	left.button_up.connect(func(): Input.action_release("ui_left"))
	add_child(left)
	
	var right = _create_pop_control_btn("▶", Vector2(900, 1650), Color(0.1, 0.6, 1.0))
	right.button_down.connect(func(): Input.action_press("ui_right"))
	right.button_up.connect(func(): Input.action_release("ui_right"))
	add_child(right)

func _create_pop_control_btn(txt: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new(); btn.text = txt; btn.custom_minimum_size = Vector2(180, 180); btn.position = pos - Vector2(90, 90)
	
	var normal = StyleBoxFlat.new(); normal.bg_color = Color(color.r, color.g, color.b, 0.2); normal.set_corner_radius_all(90); normal.border_width_left = 4; normal.border_width_top = 4; normal.border_width_right = 4; normal.border_width_bottom = 10; normal.border_color = color
	var hover = normal.duplicate(); hover.bg_color = Color(color.r, color.g, color.b, 0.4); hover.border_color = Color(1,1,1,0.8)
	var pressed = normal.duplicate(); pressed.bg_color = Color(color.r, color.g, color.b, 0.6); pressed.border_width_bottom = 4; pressed.content_margin_top = 6
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 80)
	return btn

func _create_premium_pause_btn(pos: Vector2):
	var btn = Button.new(); btn.position = pos - Vector2(40, 40); btn.custom_minimum_size = Vector2(80, 80)
	var normal = StyleBoxFlat.new(); normal.bg_color = Color(0.1, 0.4, 0.8, 0.8); normal.set_corner_radius_all(40); normal.border_width_left = 3; normal.border_width_top = 3; normal.border_width_right = 3; normal.border_width_bottom = 3; normal.border_color = Color(0.3, 0.8, 1.0)
	var hover = normal.duplicate(); hover.bg_color = Color(0.2, 0.5, 0.9, 0.9); hover.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", normal); btn.add_theme_stylebox_override("hover", hover)
	btn.pressed.connect(_toggle_pause); add_child(btn)
	var ic = Label.new(); ic.text = "⏸"; ic.add_theme_font_size_override("font_size", 40); ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; ic.size = Vector2(80, 80); btn.add_child(ic)

func _toggle_pause():
	if has_node("/root/AudioManager"): get_node("/root/AudioManager").play_button_click()
	if pause_menu != null: _close_pause_menu()
	else: _open_pause_menu()

func _open_pause_menu():
	get_tree().paused = true
	pause_menu = Control.new(); pause_menu.name = "PauseMenu"; pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(pause_menu)
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0.75); bg.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.add_child(bg)
	var panel = PanelContainer.new(); var s = StyleBoxFlat.new(); s.bg_color = Color(0.1, 0.12, 0.2, 0.98); s.set_corner_radius_all(50); s.border_width_left = 6; s.border_width_top = 6; s.border_width_right = 6; s.border_width_bottom = 12; s.border_color = Color(0.2, 0.7, 1.0); s.shadow_size = 50; panel.add_theme_stylebox_override("panel", s); panel.custom_minimum_size = Vector2(650, 800); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-325, -400); pause_menu.add_child(panel)
	var m = MarginContainer.new(); m.add_theme_constant_override("margin_left", 50); m.add_theme_constant_override("margin_right", 50); m.add_theme_constant_override("margin_top", 50); m.add_theme_constant_override("margin_bottom", 50); panel.add_child(m)
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 45); m.add_child(vb)
	var t = Label.new(); t.text = "PAUSED"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 72); t.modulate = Color(0.4, 0.8, 1.0); vb.add_child(t)
	vb.add_child(_create_volume_row("🎵 MUSIC", "Music")); vb.add_child(_create_volume_row("🔊 SFX", "SFX"))
	vb.add_child(Control.new())
	var resume_btn = _create_pop_btn_styled("RESUME MISSION", Color(0.2, 0.7, 0.3)); resume_btn.pressed.connect(_close_pause_menu); vb.add_child(resume_btn)
	var quit_btn = _create_pop_btn_styled("ABANDON MISSION", Color(0.8, 0.2, 0.2)); quit_btn.pressed.connect(_quit_to_menu); vb.add_child(quit_btn)

func _create_pop_btn_styled(txt: String, color: Color) -> Button:
	var btn = Button.new(); btn.text = txt; btn.custom_minimum_size = Vector2(0, 110)
	var n = StyleBoxFlat.new(); n.bg_color = color; n.set_corner_radius_all(30); n.border_width_bottom = 10; n.border_color = color.darkened(0.4)
	var h = n.duplicate(); h.bg_color = color.lightened(0.2); h.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", n); btn.add_theme_stylebox_override("hover", h); btn.add_theme_font_size_override("font_size", 40); return btn

func _close_pause_menu():
	get_tree().paused = false
	if pause_menu: pause_menu.queue_free(); pause_menu = null

func _quit_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _create_volume_row(label: String, bus_name: String) -> VBoxContainer:
	var row = VBoxContainer.new(); var l = Label.new(); l.text = label; l.add_theme_font_size_override("font_size", 28); row.add_child(l)
	var slider = HSlider.new(); slider.min_value = 0; slider.max_value = 1.0; slider.step = 0.05; var bi = AudioServer.get_bus_index(bus_name); slider.value = db_to_linear(AudioServer.get_bus_volume_db(bi)); slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(bi, linear_to_db(v))); row.add_child(slider); return row

func spawn_bright_text(pos: Vector2, txt: String, color: Color):
	var lbl = Label.new(); lbl.text = txt; lbl.add_theme_font_size_override("font_size", 42); lbl.add_theme_color_override("font_color", color); lbl.add_theme_color_override("font_outline_color", Color.BLACK); lbl.add_theme_constant_override("outline_size", 10); add_child(lbl)
	lbl.global_position = pos; var tw = create_tween().set_parallel(true); tw.tween_property(lbl, "global_position:y", pos.y - 180, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT); tw.tween_property(lbl, "modulate:a", 0.0, 1.5); tw.chain().tween_callback(lbl.queue_free)

func _on_heat_changed(val, max_val):
	var b = get_node_or_null("HeatBar/Bar"); if b: b.value = (val / max_val) * 100
func _on_durability_changed(val, max_val):
	var b = get_node_or_null("DuraBar/Bar"); if b: b.value = (val / max_val) * 100
func _on_coins_changed(val):
	var l = get_node_or_null("CoinPill/CoinLabel"); if l: l.text = str(val)
func _on_depth_changed(val):
	var l = get_node_or_null("DepthPill/DepthLabel"); if l: l.text = "%d m" % int(val)
