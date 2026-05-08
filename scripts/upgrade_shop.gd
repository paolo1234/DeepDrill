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
		depth_label.text = "UPGRADE STATION - %d m" % int(gs.depth)
	else:
		depth_label.text = "UPGRADE STATION"
		
	_get_upgrade_offers()
	_populate_cards()

func _pause_game():
	var gs = get_node_or_null("/root/GameState")
	if gs: gs.game_active = false

func _get_upgrade_offers():
	var gs = get_node_or_null("/root/GameState")
	if not gs: return

	available_upgrades = gs.get_random_upgrades(3)
	
	var is_lucky_day = randf() < 0.1
	var should_be_free = (gs.depth < 350) or is_lucky_day
	
	if should_be_free and available_upgrades.size() > 0:
		free_upgrade = available_upgrades[0]
		purchasable_upgrades = available_upgrades.slice(1)
	else:
		free_upgrade = "" 
		purchasable_upgrades = available_upgrades

func _populate_cards():
	for child in cards_container.get_children():
		child.queue_free()
		
	if free_upgrade != "":
		cards_container.add_child(_create_upgrade_card(free_upgrade, true))

	for upgrade_id in purchasable_upgrades:
		cards_container.add_child(_create_upgrade_card(upgrade_id, false))

func _create_upgrade_card(upgrade_id: String, is_free: bool) -> PanelContainer:
	var gs = get_node_or_null("/root/GameState")
	var card_data = gs.UPGRADES[upgrade_id] if gs else {}
	
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	style.corner_radius_top_left = 30; style.corner_radius_top_right = 30
	style.corner_radius_bottom_right = 30; style.corner_radius_bottom_left = 30
	style.border_width_left = 6; style.border_width_top = 6; style.border_width_right = 6; style.border_width_bottom = 6
	style.border_color = Color(0.1, 0.8, 0.4) if is_free else Color(0.2, 0.6, 1.0)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(350, 180)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20); margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20); margin.add_theme_constant_override("margin_bottom", 20)
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 25)
	margin.add_child(hbox)

	var icon_lbl = Label.new()
	icon_lbl.text = card_data.get("icon", "📦")
	icon_lbl.add_theme_font_size_override("font_size", 70)
	hbox.add_child(icon_lbl)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox)

	var name_label = Label.new()
	name_label.text = card_data.get("name", "Unknown").to_upper()
	name_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = card_data.get("desc", "")
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(desc_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 70)
	var btn_color = Color(0.1, 0.7, 0.3) if is_free else Color(0.1, 0.4, 0.9)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = btn_color
	btn_style.corner_radius_top_left = 20; btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20; btn_style.corner_radius_bottom_left = 20
	btn_style.border_width_bottom = 8; btn_style.border_color = btn_color.darkened(0.4)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_font_size_override("font_size", 24)

	if is_free:
		btn.text = "FREE CLAIM"
		btn.pressed.connect(func(): _select_free_upgrade(upgrade_id))
	else:
		var cost = gs.get_upgrade_cost(upgrade_id) if gs else 999
		btn.text = "BUY: %d 💰" % cost
		btn.disabled = not gs or gs.coins < cost
		btn.pressed.connect(func(): _purchase_upgrade(upgrade_id))

	vbox.add_child(btn)
	return card

func _select_free_upgrade(upgrade_id: String):
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.apply_free_upgrade(upgrade_id)
		_on_continue_pressed()

func _purchase_upgrade(upgrade_id: String):
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.purchase_upgrade(upgrade_id):
		# ONE CHOICE ONLY: CLOSE SHOP AFTER PURCHASE
		_on_continue_pressed()

func _on_continue_pressed():
	queue_free()
	var gs = get_node_or_null("/root/GameState")
	if gs: gs.game_active = true
