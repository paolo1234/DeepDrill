extends Node

signal ad_completed(ad_type: String, success: bool)

var _ad_cooldowns: Dictionary = {}
var _game_over_count: int = 0

func show_rewarded(ad_type: String, callback: Callable) -> void:
    print("[AD] Rewarded ad requested: ", ad_type)
    await get_tree().create_timer(0.5).timeout
    callback.call(true)
    ad_completed.emit(ad_type, true)

func show_banner() -> void:
    print("[AD] Banner shown")

func hide_banner() -> void:
    print("[AD] Banner hidden")

func show_interstitial() -> void:
    _game_over_count += 1
    if _game_over_count % 3 == 0:
        print("[AD] Interstitial shown")

func can_use_rewarded(ad_type: String) -> bool:
    return not _ad_cooldowns.has(ad_type)

func mark_used(ad_type: String) -> void:
    _ad_cooldowns[ad_type] = true

func reset_cooldowns() -> void:
    _ad_cooldowns.clear()