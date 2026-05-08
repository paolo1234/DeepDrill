extends Control

var can_start = false

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()
	
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("set_touch_visible"):
		hud.set_touch_visible(false)
	
	# Prevent accidental click
	await get_tree().create_timer(0.8).timeout
	can_start = true

func _setup_ui():
	# 1. Glassmorphism Background
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# 2. Main Content Card
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	style.set_corner_radius_all(50)
	style.border_width_left = 6; style.border_width_top = 6; style.border_width_right = 6; style.border_width_bottom = 12
	style.border_color = Color(0.2, 0.6, 1.0)
	style.shadow_size = 40; style.shadow_color = Color(0, 0, 0, 0.6)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(700, 850)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-350, -425)
	add_child(card)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 50)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50); margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 50); margin.add_theme_constant_override("margin_bottom", 50)
	card.add_child(margin)
	margin.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "DRILL OPERATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.modulate = Color(0.2, 0.7, 1.0)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Steps with Premium Style
	_add_premium_step(vbox, "🕹️", "NAVIGATION", "Tap SIDES or use ARROWS to steer the drill.")
	_add_premium_step(vbox, "⛏️", "AUTO-DIG", "The drill mines automatically when you hit blocks.")
	_add_premium_step(vbox, "⚡", "DANGER", "Avoid overheating! Watch the red HEAT bar.")
	_add_premium_step(vbox, "🛒", "STATIONS", "Find upgrade shops every 300m to survive.")

	vbox.add_child(Control.new()) # Spacer

	var tap_hint = Label.new()
	tap_hint.text = ">> TAP TO BEGIN MISSION <<"
	tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_hint.add_theme_font_size_override("font_size", 28)
	tap_hint.modulate = Color(1, 1, 1, 0.8)
	vbox.add_child(tap_hint)
	
	var t = create_tween().set_loops()
	t.tween_property(tap_hint, "modulate:a", 0.3, 0.6)
	t.tween_property(tap_hint, "modulate:a", 1.0, 0.6)

func _add_premium_step(parent, icon, title, desc):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 35)
	parent.add_child(hbox)
	
	var i_lbl = Label.new()
	i_lbl.text = icon
	i_lbl.add_theme_font_size_override("font_size", 70)
	hbox.add_child(i_lbl)
	
	var v = VBoxContainer.new()
	hbox.add_child(v)
	
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.modulate = Color(0.9, 0.9, 1.0)
	v.add_child(t)
	
	var d = Label.new()
	d.text = desc
	d.add_theme_font_size_override("font_size", 20)
	d.modulate = Color(0.6, 0.7, 0.8)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(400, 0)
	v.add_child(d)

func _input(event):
	if not can_start: return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_start()

func _start():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_button_click()
	var gs = get_node_or_null("/root/GameState")
	if gs: gs.game_active = true
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("set_touch_visible"):
		hud.set_touch_visible(true)
	queue_free()
