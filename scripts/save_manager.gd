extends Node

const SAVE_PATH = "user://deepdrill_save.cfg"

var save_data = {
	"total_coins": 0,
	"best_depth": 0.0,
	"permanent_upgrades": {},
	"inventory": {},
	"settings": {"music": 1.0, "sfx": 1.0}
}

func _ready():
	load_game()

func save_game():
	var config = ConfigFile.new()
	for key in save_data.keys():
		config.set_value("Save", key, save_data[key])
	var err = config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save game data! Code: " + str(err))

func load_game():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		for key in save_data.keys():
			if config.has_section_key("Save", key):
				save_data[key] = config.get_value("Save", key)

func add_coins(amount: int):
	save_data["total_coins"] += amount
	save_game()

func spend_coins(amount: int) -> bool:
	if save_data["total_coins"] >= amount:
		save_data["total_coins"] -= amount
		save_game()
		return true
	return false

func update_best_depth(depth: float):
	if depth > save_data["best_depth"]:
		save_data["best_depth"] = depth
		save_game()

func get_permanent_upgrade_level(upgrade_id: String) -> int:
	return save_data["permanent_upgrades"].get(upgrade_id, 0)

func purchase_permanent_upgrade(upgrade_id: String, level: int, cost: int) -> bool:
	if spend_coins(cost):
		save_data["permanent_upgrades"][upgrade_id] = level
		save_game()
		return true
	return false

func get_item_count(item_id: String) -> int:
	return save_data.get("inventory", {}).get(item_id, 0)

func add_item(item_id: String, amount: int = 1):
	if not save_data.has("inventory"):
		save_data["inventory"] = {}
	save_data["inventory"][item_id] = save_data["inventory"].get(item_id, 0) + amount
	save_game()

func use_item(item_id: String) -> bool:
	if get_item_count(item_id) > 0:
		save_data["inventory"][item_id] -= 1
		save_game()
		return true
	return false