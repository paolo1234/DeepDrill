extends CanvasLayer

@onready var depth_label: Label = $MarginContainer/VBoxContainer/TopStats/DepthLabel
@onready var coins_label: Label = $MarginContainer/VBoxContainer/TopStats/CoinsLabel
@onready var heat_bar: ProgressBar = $MarginContainer/VBoxContainer/HeatBox/HeatBar
@onready var heat_label: Label = $MarginContainer/VBoxContainer/HeatBox/HeatValue
@onready var dura_bar: ProgressBar = $MarginContainer/VBoxContainer/DuraBox/DuraBar
@onready var dura_label: Label = $MarginContainer/VBoxContainer/DuraBox/DuraValue

var gs = null

func _ready():
	gs = get_node_or_null("/root/GameState")
	if gs:
		gs.heat_changed.connect(_on_heat_changed)
		gs.durability_changed.connect(_on_durability_changed)
		gs.coins_changed.connect(_on_coins_changed)
		gs.depth_changed.connect(_on_depth_changed)
		_update_initial_values()

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