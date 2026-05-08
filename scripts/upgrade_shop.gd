extends Control

var available_upgrades: Array = []
var free_upgrade: String = ""
var purchasable_upgrades: Array = []

func _ready():
	_pause_game()
	_setup_ui()

func _pause_game():
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.game_active = false

func _setup_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -350)
	panel.size = Vector2(500, 700)
	panel.add_theme_constant_override("separation", 20)
	add_child(panel)

	var title = Label.new()
	title.text = "UPGRADE STATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	panel.add_child(title)

	var gs = get_node_or_null("/root/GameState")
	var depth_label = Label.new()
	depth_label.text = "Depth: %d m" % int(gs.depth if gs else 0)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(depth_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	panel.add_child(spacer)

	_get_upgrade_offers()

	var free_card = _create_upgrade_card(free_upgrade, true)
	panel.add_child(free_card)

	for upgrade_id in purchasable_upgrades:
		var card = _create_upgrade_card(upgrade_id, false)
		panel.add_child(card)

	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE DRILLING"
	continue_btn.custom_minimum_size = Vector2(200, 60)
	continue_btn.add_theme_font_size_override("font_size", 24)
	continue_btn.pressed.connect(_on_continue_pressed)
	panel.add_child(continue_btn)

func _get_upgrade_offers():
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return

	available_upgrades = gs.get_random_upgrades(3)
	if available_upgrades.size() > 0:
		free_upgrade = available_upgrades[0]
		purchasable_upgrades = available_upgrades.slice(1, available_upgrades.size())
	else:
		free_upgrade = "heat_shield"
		purchasable_upgrades = ["cooling_fan"]

func _create_upgrade_card(upgrade_id: String, is_free: bool) -> VBoxContainer:
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 5)

	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(450, 120)
	bg.color = Color(0.15, 0.15, 0.25, 1)
	card.add_child(bg)

	var name_label = Label.new()
	name_label.text = _get_upgrade_name(upgrade_id)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.position = Vector2(10, 10)
	bg.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = _get_upgrade_desc(upgrade_id)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	desc_label.position = Vector2(10, 40)
	bg.add_child(desc_label)

	var btn = Button.new()
	btn.position = Vector2(10, 75)
	btn.custom_minimum_size = Vector2(200, 35)

	var gs = get_node_or_null("/root/GameState")
	var level = 0
	if gs:
		level = gs.run_upgrades.get(upgrade_id, 0)

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

	bg.add_child(btn)

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