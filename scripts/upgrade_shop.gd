extends Control

var available_upgrades: Array = []
var free_upgrade: String = ""
var purchasable_upgrades: Array = []

@onready var depth_label = $MarginContainer/VBoxContainer/DepthLabel
@onready var cards_container = $MarginContainer/VBoxContainer/CardsContainer
@onready var continue_btn = $MarginContainer/VBoxContainer/ContinueBtn

func _ready():
	_pause_game()
	
	continue_btn.pressed.connect(_on_continue_pressed)
	
	var gs = get_node_or_null("/root/GameState")
	if gs:
		depth_label.text = "Depth: %d m" % int(gs.depth)
	else:
		depth_label.text = "Depth: 0 m"
		
	_get_upgrade_offers()
	
	var free_card = _create_upgrade_card(free_upgrade, true)
	cards_container.add_child(free_card)

	for upgrade_id in purchasable_upgrades:
		var card = _create_upgrade_card(upgrade_id, false)
		cards_container.add_child(card)

func _pause_game():
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.game_active = false

func _get_upgrade_offers():
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		free_upgrade = "heat_shield"
		purchasable_upgrades = ["cooling_fan", "speed_boost"]
		return

	available_upgrades = gs.get_random_upgrades(3)
	if available_upgrades.size() > 0:
		free_upgrade = available_upgrades[0]
		purchasable_upgrades = available_upgrades.slice(1, available_upgrades.size())
	else:
		free_upgrade = "heat_shield"
		purchasable_upgrades = ["cooling_fan", "speed_boost"]

func _create_upgrade_card(upgrade_id: String, is_free: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 140)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var name_label = Label.new()
	name_label.text = _get_upgrade_name(upgrade_id)
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = _get_upgrade_desc(upgrade_id)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(desc_label)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 45)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.6, 0.2, 1) if is_free else Color(0.8, 0.6, 0.1, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 18)

	var gs = get_node_or_null("/root/GameState")
	if is_free:
		btn.text = "FREE - TAKE ONE"
		btn.pressed.connect(func(): _select_free_upgrade(upgrade_id))
	else:
		var cost = 0
		if gs:
			cost = gs.get_upgrade_cost(upgrade_id)
		btn.text = "BUY - %d coins" % cost
		btn.disabled = not gs or gs.coins < cost
		btn.pressed.connect(func(): _purchase_upgrade(upgrade_id))

	vbox.add_child(btn)

	return card

func _get_upgrade_name(upgrade_id: String) -> String:
	var names = {
		"heat_shield": "Heat Shield",
		"cooling_fan": "Cooling Fan",
		"reinforced_bit": "Reinforced Bit",
		"speed_boost": "Speed Boost",
		"coin_magnet": "Coin Magnet",
		"deep_scanner": "Deep Scanner",
		"emergency_repair": "Emergency Repair",
		"heat_vent": "Heat Vent"
	}
	return names.get(upgrade_id, upgrade_id)

func _get_upgrade_desc(upgrade_id: String) -> String:
	var descs = {
		"heat_shield": "-10% heat per block",
		"cooling_fan": "+15% cooling rate",
		"reinforced_bit": "-12% wear per block",
		"speed_boost": "+10% drill speed",
		"coin_magnet": "+20% coin value",
		"deep_scanner": "See 5 rows ahead",
		"emergency_repair": "Restore 30 durability",
		"heat_vent": "Remove 40 heat"
	}
	return descs.get(upgrade_id, "")

func _select_free_upgrade(upgrade_id: String):
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.apply_free_upgrade(upgrade_id)
		_on_continue_pressed()

func _purchase_upgrade(upgrade_id: String):
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.purchase_upgrade(upgrade_id):
		_on_continue_pressed()

func _on_continue_pressed():
	queue_free()
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.game_active = true