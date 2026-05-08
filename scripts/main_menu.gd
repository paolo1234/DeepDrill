extends Control

var sm = null

@onready var main_panel = $MainPanel
@onready var shop_panel = $ShopPanel
@onready var settings_panel = $SettingsPanel
@onready var best_depth_label = $MainPanel/VBoxContainer/StatsPanel/BestDepthLabel
@onready var total_coins_label = $MainPanel/VBoxContainer/StatsPanel/TotalCoinsLabel
@onready var shop_coins_label = $ShopPanel/Margin/VBox/ShopCoinsLabel
@onready var shop_items_vbox = $ShopPanel/Margin/VBox/ScrollContainer/ShopItemsVBox

func _ready():
	sm = get_node_or_null("/root/SaveManager")
	update_stats()
	_populate_shop()
	_style_menu()

func _style_menu():
	# Recursively style ALL buttons in the menu
	_style_all_buttons(self)

func _style_all_buttons(node: Node):
	if node is Button:
		_apply_casual_btn_style(node)
	for child in node.get_children():
		_style_all_buttons(child)

func _apply_casual_btn_style(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.4) # Fresh Green
	style.corner_radius_top_left = 30; style.corner_radius_top_right = 30
	style.corner_radius_bottom_right = 30; style.corner_radius_bottom_left = 30
	style.border_width_bottom = 8; style.border_color = Color(0.1, 0.4, 0.3) # 3D effect
	
	var style_p = style.duplicate()
	style_p.border_width_bottom = 2; style_p.bg_color = Color(0.15, 0.5, 0.35)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_font_size_override("font_size", 32)

func update_stats():
	if not sm:
		return
	var best = int(sm.save_data.get("best_depth", 0))
	var coins = sm.save_data.get("total_coins", 0)
	
	if is_instance_valid(best_depth_label):
		best_depth_label.text = "Best Depth: %d m" % best
	if is_instance_valid(total_coins_label):
		total_coins_label.text = "Total Coins: %d" % coins
	if is_instance_valid(shop_coins_label):
		shop_coins_label.text = "Coins: %d" % coins

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_shop_pressed():
	main_panel.hide()
	shop_panel.show()

func _on_close_shop_pressed():
	shop_panel.hide()
	main_panel.show()

func _on_settings_pressed():
	main_panel.hide()
	settings_panel.show()

func _on_close_settings_pressed():
	settings_panel.hide()
	main_panel.show()

func _populate_shop():
	if not sm: return
	
	# Clear existing items
	for child in shop_items_vbox.get_children():
		child.queue_free()
		
	var upgrades = [
		{"id": "perm_heat_shield", "name": "Starting Heat Shield", "desc": "Start with Heat Shield Lv(n)", "costs": [200, 500, 1200]},
		{"id": "perm_durability", "name": "Starting Durability+", "desc": "+20 max durability per lvl", "costs": [150, 400, 1000]},
		{"id": "perm_cooling", "name": "Starting Cooling+", "desc": "+10% base cooling per lvl", "costs": [180, 450, 1100]},
		{"id": "perm_lucky", "name": "Lucky Drill", "desc": "+5% rare block chance per lvl", "costs": [300, 800, 2000]},
		{"id": "perm_coin_boost", "name": "Coin Boost", "desc": "+10% all coins per lvl", "costs": [250, 600, 1500]}
	]
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.2, 0.3)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	
	for u in upgrades:
		_add_permanent_upgrade_card(u["id"], u["name"], u["desc"], u["costs"], style_box)

func _add_permanent_upgrade_card(upgrade_id: String, upgrade_name: String, desc: String, costs: Array, style: StyleBoxFlat):
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var vbox_left = VBoxContainer.new()
	vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_left)
	
	var name_label = Label.new()
	name_label.text = upgrade_name
	name_label.add_theme_font_size_override("font_size", 22)
	vbox_left.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox_left.add_child(desc_label)
	
	var current_level = sm.get_permanent_upgrade_level(upgrade_id)
	var max_level = costs.size()
	
	var level_label = Label.new()
	level_label.text = "Level: %d/%d" % [current_level, max_level]
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.modulate = Color(0.4, 0.8, 1.0)
	vbox_left.add_child(level_label)
	
	var vbox_right = VBoxContainer.new()
	vbox_right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox_right)
	
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 50)
	buy_btn.add_theme_font_size_override("font_size", 18)
	
	if current_level >= max_level:
		buy_btn.text = "MAXED"
		buy_btn.disabled = true
	else:
		var cost = costs[current_level]
		buy_btn.text = "BUY: %d" % cost
		if sm.save_data.get("total_coins", 0) < cost:
			buy_btn.disabled = true
		else:
			buy_btn.pressed.connect(func(): _buy_permanent_upgrade(upgrade_id, current_level, cost))
	
	vbox_right.add_child(buy_btn)
	shop_items_vbox.add_child(panel)

func _buy_permanent_upgrade(upgrade_id: String, current_level: int, cost: int):
	if sm.spend_coins(cost):
		sm.purchase_permanent_upgrade(upgrade_id, current_level + 1, cost)
		update_stats()
		_populate_shop()