extends Node2D

var drill = null
var grid = null
var hud = null
var camera = null
var upgrade_shop = null

func _ready():
	var gs = get_node("/root/GameState")
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
	
	# Much deeper darkness for high contrast
	var canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(0.06, 0.06, 0.09, 1) 
	add_child(canvas_modulate)

func _process(delta):
	if drill and camera:
		var target_y = drill.position.y
		camera.position.y = lerp(camera.position.y, target_y, 5.0 * delta)

		if grid:
			var depth = drill.position.y * 0.05
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
	shop_layer.layer = 5
	shop_layer.name = "ShopLayer"
	add_child(shop_layer)

	shop_layer.add_child(upgrade_shop)

func show_game_over(reason: String):
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 10
	overlay_layer.name = "GameOverLayer"
	add_child(overlay_layer)

	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.name = "GameOverOverlay"
	overlay_layer.add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -250)
	panel.size = Vector2(400, 500)
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	panel.add_child(title)

	var reason_label = Label.new()
	if reason == "overheated":
		reason_label.text = "DRILL OVERHEATED!"
	else:
		reason_label.text = "DRILL BROKEN!"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 28)
	panel.add_child(reason_label)

	var gs = get_node_or_null("/root/GameState")
	var sm = get_node_or_null("/root/SaveManager")
	if gs and sm:
		sm.update_best_depth(gs.depth)
		sm.add_coins(gs.coins)

		var depth_label = Label.new()
		depth_label.text = "Depth: %d m" % int(gs.depth)
		depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(depth_label)

		var coins_label = Label.new()
		coins_label.text = "Coins: %d" % gs.coins
		coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(coins_label)

		var best_label = Label.new()
		best_label.text = "Best: %d m" % int(sm.save_data.get("best_depth", 0))
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(best_label)

	var restart_btn = Button.new()
	restart_btn.text = "RESTART"
	restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	panel.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	panel.add_child(menu_btn)