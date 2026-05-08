extends Node2D

var drill = null
var grid = null
var hud = null
var camera = null
var upgrade_shop = null
var gs = null

func _ready():
	gs = get_node("/root/GameState")
	if gs:
		gs.reset()
		gs.game_active = false
		gs.game_over.connect(_on_game_over)
		gs.upgrade_shop_requested.connect(_on_upgrade_shop_requested)

	var grid_scene = preload("res://scenes/grid.tscn")
	grid = grid_scene.instantiate()
	add_child(grid)

	var drill_scene = preload("res://scenes/drill.tscn")
	drill = drill_scene.instantiate()
	drill.position = Vector2(1080.0 / 2.0 - 24, 300)
	add_child(drill)

	camera = Camera2D.new()
	camera.position = Vector2(540, 300)
	camera.zoom = Vector2(1.0, 1.0)
	add_child(camera)
	
	if get_node_or_null("/root/Effects"):
		get_node("/root/Effects").camera = camera

	_create_background()

	var hud_scene = preload("res://ui/hud.tscn")
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	
	var tutorial_scene = preload("res://scenes/tutorial_overlay.tscn")
	var tutorial = tutorial_scene.instantiate()
	var tutorial_layer = CanvasLayer.new()
	tutorial_layer.layer = 10
	tutorial_layer.name = "TutorialLayer"
	add_child(tutorial_layer)
	tutorial_layer.add_child(tutorial)

func _create_background():
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	bg_layer.name = "BackgroundLayer"
	add_child(bg_layer)

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.102, 0.102, 0.18, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	
	# Much deeper darkness for high contrast, but safe for mobile screens
	var canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(0.25, 0.25, 0.35, 1) 
	add_child(canvas_modulate)
	
	_create_vignette()

func _create_vignette():
	var layer = CanvasLayer.new()
	layer.layer = 2 # Below UI (which is 5+), above Game (which is 0)
	layer.name = "VignetteLayer"
	add_child(layer)
	
	var rect = TextureRect.new()
	rect.name = "Vignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(rect)
	
	var tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.5))
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.8, 0.8)
	rect.texture = tex

func _process(delta):
	if drill and camera:
		var target_y = drill.position.y
		camera.position.y = lerp(camera.position.y, target_y, 5.0 * delta)

		if grid:
			grid.update_grid(drill.position.y)
			var depth = drill.position.y * 0.05
			if gs:
				gs.depth = depth
			_update_background_color(depth)

func _update_background_color(depth: float):
	var bg_layer = get_node_or_null("BackgroundLayer")
	if not bg_layer: return
	var bg = bg_layer.get_node_or_null("Background")
	if not bg: return
	
	var tier = 1
	if depth >= 800:
		tier = 5
	elif depth >= 500:
		tier = 4
	elif depth >= 300:
		tier = 3
	elif depth >= 100:
		tier = 2
	
	var tier_colors = {
		1: Color(0.36, 0.20, 0.09),
		2: Color(0.23, 0.23, 0.23),
		3: Color(0.42, 0.31, 0.11),
		4: Color(0.10, 0.16, 0.29),
		5: Color(0.23, 0.06, 0.06)
	}
	bg.color = tier_colors[tier]

func _on_game_over(reason: String):
	if drill:
		drill.set_process(false)
		drill.set_physics_process(false)
	show_game_over(reason)

func _on_upgrade_shop_requested():
	if upgrade_shop:
		return
	
	var shop_scene = preload("res://scenes/upgrade_shop.tscn")
	upgrade_shop = shop_scene.instantiate()
	
	var shop_layer = CanvasLayer.new()
	shop_layer.layer = 50 # Above vignette (2), below game over (100)
	shop_layer.name = "ShopLayer"
	add_child(shop_layer)

	shop_layer.add_child(upgrade_shop)

func show_game_over(reason: String):
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100 # Topmost
	overlay_layer.name = "GameOverLayer"
	add_child(overlay_layer)

	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(overlay)

	# Blur/Darken Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	# Main Panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	style.border_width_left = 4; style.border_width_top = 4
	style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.3, 0.1, 1.0) # Industrial Orange
	style.corner_radius_top_left = 20; style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20; style.corner_radius_bottom_left = 20
	style.shadow_size = 20; style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(450, 550)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-225, -275)
	overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "MISSION FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(1, 0.3, 0.1)
	vbox.add_child(title)

	var reason_label = Label.new()
	reason_label.text = "DRILL OVERHEATED" if reason == "overheated" else "CHASSIS DESTROYED"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(reason_label)

	vbox.add_child(HSeparator.new())

	# Stats
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 40)
	stats_grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(stats_grid)

	var sm = get_node_or_null("/root/SaveManager")
	
	_add_stat_row(stats_grid, "📏 Depth", str(int(gs.depth)) + " m")
	_add_stat_row(stats_grid, "💰 Coins", str(gs.coins))
	if sm:
		sm.update_best_depth(gs.depth)
		sm.add_coins(gs.coins)
		_add_stat_row(stats_grid, "🏆 Best", str(int(sm.save_data.get("best_depth", 0))) + " m")

	vbox.add_child(Control.new()) # Spacer

	# Buttons
	var restart_btn = Button.new()
	restart_btn.text = "REPAIR & RESTART"
	restart_btn.custom_minimum_size = Vector2(0, 60)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.6, 0.3, 1)
	btn_style.corner_radius_top_left = 10; btn_style.corner_radius_bottom_right = 10
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	vbox.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "ABANDON MISSION"
	menu_btn.flat = true
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(menu_btn)

func _add_stat_row(parent, label_text, value_text):
	var l = Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)
	
	var v = Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 18)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(v)