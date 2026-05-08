extends Control

var save_manager = null
var gs = null

@onready var cards_container = VBoxContainer.new()
@onready var coin_label = Label.new()

func _ready():
	save_manager = get_node_or_null("/root/SaveManager")
	gs = get_node_or_null("/root/GameState")
	
	_build_ui()
	_refresh_shop()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main layout
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 40)
	main_margin.add_theme_constant_override("margin_right", 40)
	main_margin.add_theme_constant_override("margin_top", 60)
	main_margin.add_theme_constant_override("margin_bottom", 60)
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	main_margin.add_child(main_vbox)
	
	# Header (Title + Coins)
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "PERMANENT UPGRADES"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	coin_label.add_theme_font_size_override("font_size", 50)
	header.add_child(coin_label)
	
	# Scroll area for upgrades
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 25)
	scroll.add_child(cards_container)
	
	# Back to Menu button
	var back_btn = Button.new()
	back_btn.text = "◀ BACK TO BASE"
	back_btn.custom_minimum_size = Vector2(0, 110)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.35)
	style.corner_radius_top_left = 20; style.corner_radius_bottom_right = 20
	style.border_width_bottom = 8; style.border_color = Color(0.1, 0.15, 0.25)
	back_btn.add_theme_stylebox_override("normal", style)
	back_btn.add_theme_font_size_override("font_size", 44)
	back_btn.pressed.connect(_on_back_pressed)
	main_vbox.add_child(back_btn)

func _refresh_shop():
	if not save_manager or not gs: return
	
	# Update coins
	coin_label.text = "💰 " + str(save_manager.save_data.get("total_coins", 0))
	
	# Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	
	var perms = gs.PERM_UPGRADES
	for key in perms:
		var data = perms[key]
		var level = save_manager.get_permanent_upgrade_level(key)
		var max_level = data["max_level"]
		var is_maxed = level >= max_level
		var cost = 0 if is_maxed else data["costs"][level]
		
		var card = _create_card(key, data, level, max_level, cost, is_maxed)
		cards_container.add_child(card)

	# -- DIVIDER --
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 4)
	div.color = Color(0.3, 0.3, 0.4)
	cards_container.add_child(div)
	
	var cons_title = Label.new()
	cons_title.text = "TACTICAL CONSUMABLES"
	cons_title.add_theme_font_size_override("font_size", 42)
	cons_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	cards_container.add_child(cons_title)

	# -- CONSUMABLES --
	var cons = gs.CONSUMABLES
	for key in cons:
		var data = cons[key]
		var owned = save_manager.get_item_count(key)
		var cost = data["cost"]
		var card = _create_consumable_card(key, data, owned, cost)
		cards_container.add_child(card)

func _create_card(key: String, data: Dictionary, level: int, max_level: int, cost: int, is_maxed: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.corner_radius_top_left = 30; style.corner_radius_bottom_right = 30
	style.border_width_left = 4; style.border_width_top = 4; style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(0.9, 0.6, 0.1) if not is_maxed else Color(0.3, 0.8, 0.3)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 160)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25); margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 25); margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 25)
	margin.add_child(hbox)
	
	# Name & Desc VBox
	var info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_box)
	
	var name_lbl = Label.new()
	name_lbl.text = data["name"].to_upper() + " (Lv. " + str(level) + "/" + str(max_level) + ")"
	name_lbl.add_theme_font_size_override("font_size", 34)
	if is_maxed: name_lbl.modulate = Color(0.4, 1.0, 0.4)
	info_box.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.modulate = Color(1, 1, 1, 0.6)
	info_box.add_child(desc_lbl)
	
	# Buy Button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 90)
	var b_style = StyleBoxFlat.new()
	b_style.corner_radius_top_left = 20; b_style.corner_radius_bottom_right = 20
	b_style.border_width_bottom = 6
	btn.add_theme_font_size_override("font_size", 28)
	
	if is_maxed:
		b_style.bg_color = Color(0.2, 0.5, 0.2)
		b_style.border_color = Color(0.1, 0.3, 0.1)
		btn.text = "MAXED OUT"
		btn.disabled = true
	else:
		b_style.bg_color = Color(0.8, 0.4, 0.1)
		b_style.border_color = Color(0.5, 0.2, 0.0)
		btn.text = "UPGRADE\n💰 " + str(cost)
		var total_coins = save_manager.save_data.get("total_coins", 0)
		if total_coins < cost:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		else:
			btn.pressed.connect(func(): _buy_upgrade(key, level, cost))
	
	btn.add_theme_stylebox_override("normal", b_style)
	hbox.add_child(btn)
	
	return card

func _buy_upgrade(key: String, current_level: int, cost: int):
	if save_manager.purchase_permanent_upgrade(key, current_level + 1, cost):
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_upgrade_sound()
		_refresh_shop()

func _create_consumable_card(key: String, data: Dictionary, owned: int, cost: int) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = 30; style.corner_radius_bottom_right = 30
	style.border_width_left = 4; style.border_width_top = 4; style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(0.4, 0.8, 1.0)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 160)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25); margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 25); margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 25)
	margin.add_child(hbox)
	
	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 70)
	hbox.add_child(icon_lbl)
	
	# Name & Desc VBox
	var info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_box)
	
	var name_lbl = Label.new()
	name_lbl.text = data["name"].to_upper() + " (OWNED: " + str(owned) + ")"
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	info_box.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.modulate = Color(1, 1, 1, 0.6)
	info_box.add_child(desc_lbl)
	
	# Buy Button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 90)
	var b_style = StyleBoxFlat.new()
	b_style.corner_radius_top_left = 20; b_style.corner_radius_bottom_right = 20
	b_style.border_width_bottom = 6
	btn.add_theme_font_size_override("font_size", 28)
	
	b_style.bg_color = Color(0.2, 0.5, 0.8)
	b_style.border_color = Color(0.1, 0.3, 0.5)
	btn.text = "BUY\n💰 " + str(cost)
	var total_coins = save_manager.save_data.get("total_coins", 0)
	if total_coins < cost:
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5)
	else:
		btn.pressed.connect(func(): _buy_consumable(key, cost))
	
	btn.add_theme_stylebox_override("normal", b_style)
	hbox.add_child(btn)
	
	return card

func _buy_consumable(key: String, cost: int):
	if save_manager.spend_coins(cost):
		save_manager.add_item(key, 1)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_upgrade_sound()
		_refresh_shop()

func _on_back_pressed():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_button_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
