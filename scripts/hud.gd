extends CanvasLayer

@onready var depth_label: Label = $MarginContainer/VBoxContainer/TopStats/DepthLabel
@onready var coins_label: Label = $MarginContainer/VBoxContainer/TopStats/CoinsLabel
@onready var heat_bar: ProgressBar = $MarginContainer/VBoxContainer/HeatBox/HeatBar
@onready var heat_label: Label = $MarginContainer/VBoxContainer/HeatBox/HeatValue
@onready var dura_bar: ProgressBar = $MarginContainer/VBoxContainer/DuraBox/DuraBar
@onready var dura_label: Label = $MarginContainer/VBoxContainer/DuraBox/DuraValue

var gs = null

func _ready():
	_setup_bar_styles()
	gs = get_node_or_null("/root/GameState")
	if gs:
		gs.heat_changed.connect(_on_heat_changed)
		gs.durability_changed.connect(_on_durability_changed)
		gs.coins_changed.connect(_on_coins_changed)
		gs.depth_changed.connect(_on_depth_changed)
		_update_initial_values()

func _setup_bar_styles():
	var heat_bg = StyleBoxFlat.new()
	heat_bg.bg_color = Color(0.1, 0.1, 0.15, 1)
	heat_bg.border_width_left = 2; heat_bg.border_width_top = 2
	heat_bg.border_width_right = 2; heat_bg.border_width_bottom = 2
	heat_bg.border_color = Color(0.05, 0.05, 0.1, 1)
	heat_bg.corner_radius_top_left = 8; heat_bg.corner_radius_top_right = 8
	heat_bg.corner_radius_bottom_left = 8; heat_bg.corner_radius_bottom_right = 8
	heat_bar.add_theme_stylebox_override("background", heat_bg)
	
	var heat_fill = StyleBoxFlat.new()
	heat_fill.bg_color = Color(0.9, 0.3, 0.1, 1) # Orange/Red
	heat_fill.corner_radius_top_left = 8; heat_fill.corner_radius_top_right = 8
	heat_fill.corner_radius_bottom_left = 8; heat_fill.corner_radius_bottom_right = 8
	heat_bar.add_theme_stylebox_override("fill", heat_fill)
	heat_bar.custom_minimum_size = Vector2(0, 16)
	
	var dura_bg = heat_bg.duplicate()
	dura_bar.add_theme_stylebox_override("background", dura_bg)
	
	var dura_fill = heat_fill.duplicate()
	dura_fill.bg_color = Color(0.2, 0.5, 0.9, 1) # Blue
	dura_bar.add_theme_stylebox_override("fill", dura_fill)
	dura_bar.custom_minimum_size = Vector2(0, 16)

func _update_initial_values():
	if not gs:
		return
	_on_depth_changed(gs.depth)
	_on_coins_changed(gs.coins)
	_on_heat_changed(gs.heat, gs.max_heat)
	_on_durability_changed(gs.durability, gs.max_durability)

func _on_depth_changed(value: float):
	if is_instance_valid(depth_label):
		depth_label.text = "Depth: %d m" % int(value)

func _on_heat_changed(value: float, max_val: float):
	if is_instance_valid(heat_label):
		heat_label.text = "%d/%d" % [int(value), int(max_val)]
	if is_instance_valid(heat_bar) and max_val > 0:
		heat_bar.value = (value / max_val) * 100

func _on_durability_changed(value: float, max_val: float):
	if is_instance_valid(dura_label):
		dura_label.text = "%d/%d" % [int(value), int(max_val)]
	if is_instance_valid(dura_bar) and max_val > 0:
		dura_bar.value = (value / max_val) * 100

func _on_coins_changed(value: int):
	if is_instance_valid(coins_label):
		coins_label.text = "Coins: %d" % value