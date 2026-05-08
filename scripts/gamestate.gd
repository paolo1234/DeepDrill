extends Node

signal heat_changed(value, max_val)
signal durability_changed(value, max_val)
signal coins_changed(value)
signal game_over(reason)
signal upgrade_shop_requested
signal depth_changed(value)

# --- Run state ---
var depth: float = 0.0
var heat: float = 0.0
var max_heat: float = 100.0
var durability: float = 100.0
var max_durability: float = 100.0
var coins: int = 0

func set_depth(val: float):
	depth = val
	depth_changed.emit(depth)

var heat_resistance: float = 0.0
var cooling_bonus: float = 0.0
var wear_reduction: float = 0.0
var coin_multiplier: float = 1.0

var base_cooling_rate: float = 0.5
var last_upgrade_depth: float = 0.0
var next_upgrade_depth: float = 100.0

var game_active: bool = true
var run_upgrades: Dictionary = {}

# --- Upgrade definitions ---
const UPGRADES = {
	"heat_shield": {"name": "Heat Shield", "icon": "🛡", "max_level": 5, "base_cost": 50, "scaling": 1.8, "effect": "heat_resistance", "desc": "-10% heat per block"},
	"cooling_fan": {"name": "Cooling Fan", "icon": "❄", "max_level": 5, "base_cost": 40, "scaling": 1.6, "effect": "cooling_bonus", "desc": "+15% cooling rate"},
	"reinforced_bit": {"name": "Reinforced Bit", "icon": "🔧", "max_level": 5, "base_cost": 60, "scaling": 2.0, "effect": "wear_reduction", "desc": "-12% wear per block"},
	"speed_boost": {"name": "Speed Boost", "icon": "⚡", "max_level": 3, "base_cost": 30, "scaling": 1.5, "effect": "speed", "desc": "+10% drill speed"},
	"coin_magnet": {"name": "Coin Magnet", "icon": "🧲", "max_level": 3, "base_cost": 45, "scaling": 1.7, "effect": "coin_boost", "desc": "+20% coin value"},
	"deep_scanner": {"name": "Deep Scanner", "icon": "📡", "max_level": 3, "base_cost": 80, "scaling": 2.0, "effect": "vision", "desc": "See 5 rows ahead"},
	"emergency_repair": {"name": "Emergency Repair", "icon": "🔩", "max_level": 2, "base_cost": 100, "scaling": 2.5, "effect": "repair", "desc": "Restore 30 durability"},
	"heat_vent": {"name": "Heat Vent", "icon": "🌬", "max_level": 2, "base_cost": 80, "scaling": 2.0, "effect": "instant_cool", "desc": "Remove 40 heat"},
}

# --- Permanent upgrade definitions ---
const PERM_UPGRADES = {
	"perm_heat_shield": {"name": "Starting Heat Shield", "max_level": 3, "costs": [200, 500, 1200], "desc": "Start with Heat Shield Lv(n)"},
	"perm_durability": {"name": "Starting Durability+", "max_level": 3, "costs": [150, 400, 1000], "desc": "+20 max durability per lvl"},
	"perm_cooling": {"name": "Starting Cooling+", "max_level": 3, "costs": [180, 450, 1100], "desc": "+10% base cooling per lvl"},
	"perm_lucky": {"name": "Lucky Drill", "max_level": 3, "costs": [300, 800, 2000], "desc": "+5% rare block chance per lvl"},
	"perm_coin_boost": {"name": "Coin Boost", "max_level": 3, "costs": [250, 600, 1500], "desc": "+10% all coins per lvl"},
}

func reset():
	set_depth(0.0)
	heat = 0.0
	max_heat = 100.0
	durability = 100.0
	max_durability = 100.0
	coins = 0
	heat_resistance = 0.0
	cooling_bonus = 0.0
	wear_reduction = 0.0
	coin_multiplier = 1.0
	base_cooling_rate = 0.5
	last_upgrade_depth = 0.0
	next_upgrade_depth = 100.0
	game_active = true
	run_upgrades.clear()
	# Apply permanent upgrades
	_apply_permanent_upgrades()
	
	heat_changed.emit(heat, max_heat)
	durability_changed.emit(durability, max_durability)
	coins_changed.emit(coins)

func _apply_permanent_upgrades():
	var sm = get_node_or_null("/root/SaveManager")
	if not sm:
		return
	var perms = sm.save_data.get("permanent_upgrades", {})
	var perm_heat = perms.get("perm_heat_shield", 0)
	if perm_heat > 0:
		heat_resistance = perm_heat * 0.1
		run_upgrades["heat_shield"] = perm_heat
	var perm_dura = perms.get("perm_durability", 0)
	if perm_dura > 0:
		max_durability += perm_dura * 20
		durability = max_durability
	var perm_cool = perms.get("perm_cooling", 0)
	if perm_cool > 0:
		base_cooling_rate *= (1.0 + perm_cool * 0.1)
	var perm_coin = perms.get("perm_coin_boost", 0)
	if perm_coin > 0:
		coin_multiplier = 1.0 + perm_coin * 0.1

func add_heat(value: float):
	if not game_active:
		return
	var depth_mult = 1.0 + depth / 500.0
	
	var final_value = 0.0
	if value > 0:
		final_value = value * depth_mult * (1.0 - heat_resistance)
	else:
		final_value = value # Cooling from minerals is fixed
		
	heat = clamp(heat + final_value, 0, max_heat)
	heat_changed.emit(heat, max_heat)
	if heat >= max_heat:
		game_active = false
		game_over.emit("overheated")

func add_wear(value: float):
	if not game_active:
		return
	var depth_mult = 1.0 + depth / 800.0
	var reduced_value = value * depth_mult * (1.0 - wear_reduction)
	durability = clamp(durability - reduced_value, 0, max_durability)
	durability_changed.emit(durability, max_durability)
	if durability <= 0:
		game_active = false
		game_over.emit("broken")

func add_coins(value: int):
	coins += int(value * coin_multiplier)
	coins_changed.emit(coins)

func passive_cooling(delta: float):
	if not game_active:
		return
	var cooling = base_cooling_rate * (1.0 + cooling_bonus) * delta
	heat = clamp(heat - cooling, 0, max_heat)
	heat_changed.emit(heat, max_heat)

func check_upgrade_shop():
	if depth >= next_upgrade_depth and game_active:
		next_upgrade_depth += 100
		upgrade_shop_requested.emit()

func apply_heat_resistance(level: int):
	heat_resistance = level * 0.1

func apply_cooling_bonus(level: int):
	cooling_bonus = level * 0.15

func apply_wear_reduction(level: int):
	wear_reduction = level * 0.12

func apply_coin_boost(level: int):
	coin_multiplier = 1.0 + level * 0.2

func get_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return 0
	var level = run_upgrades.get(upgrade_id, 0)
	var data = UPGRADES[upgrade_id]
	return int(data["base_cost"] * pow(data["scaling"], level))

func can_upgrade(upgrade_id: String) -> bool:
	if not UPGRADES.has(upgrade_id):
		return false
	var level = run_upgrades.get(upgrade_id, 0)
	return level < UPGRADES[upgrade_id]["max_level"]

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_upgrade(upgrade_id):
		return false
	var cost = get_upgrade_cost(upgrade_id)
	if coins >= cost:
		coins -= cost
		coins_changed.emit(coins)
		var new_level = run_upgrades.get(upgrade_id, 0) + 1
		run_upgrades[upgrade_id] = new_level
		apply_upgrade_effect(upgrade_id, new_level)
		return true
	return false

func apply_free_upgrade(upgrade_id: String) -> bool:
	if not can_upgrade(upgrade_id):
		return false
	var new_level = run_upgrades.get(upgrade_id, 0) + 1
	run_upgrades[upgrade_id] = new_level
	apply_upgrade_effect(upgrade_id, new_level)
	return true

func apply_upgrade_effect(upgrade_id: String, level: int):
	var effect = UPGRADES[upgrade_id]["effect"]
	match effect:
		"heat_resistance":
			apply_heat_resistance(level)
		"cooling_bonus":
			apply_cooling_bonus(level)
		"wear_reduction":
			apply_wear_reduction(level)
		"coin_boost":
			apply_coin_boost(level)
		"repair":
			durability = min(durability + 30, max_durability)
			durability_changed.emit(durability, max_durability)
		"instant_cool":
			heat = max(0, heat - 40)
			heat_changed.emit(heat, max_heat)

func get_random_upgrades(count: int = 3) -> Array:
	var available = []
	for key in UPGRADES.keys():
		if can_upgrade(key):
			available.append(key)
	available.shuffle()
	return available.slice(0, min(count, available.size()))

func continue_run():
	# Revive from game over
	heat = max_heat * 0.5
	durability = min(durability + 30, max_durability)
	game_active = true
	heat_changed.emit(heat, max_heat)
	durability_changed.emit(durability, max_durability)

func instant_cool_ad():
	heat = 0
	heat_changed.emit(heat, max_heat)
