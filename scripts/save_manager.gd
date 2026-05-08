extends Node

const SAVE_PATH = "user://save.json"

var save_data = {
    "total_coins": 0,
    "best_depth": 0.0,
    "permanent_upgrades": {},
    "settings": {"music": 1.0, "sfx": 1.0}
}

func _ready():
    load_game()

func save_game():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()

func load_game():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file:
            var json = JSON.parse_string(file.get_as_text())
            if json:
                save_data = json
            file.close()

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