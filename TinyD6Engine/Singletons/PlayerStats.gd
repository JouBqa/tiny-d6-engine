extends Node

# Attributes & Base Max Stats
var skill: int = 0
var current_skill: int = 0

var stamina: int = 0
var current_stamina: int = 0

var luck: int = 0
var current_luck: int = 0

var patience: int = 0
var current_patience: int = 0

# Inventory & Story Flags State Tracking
var inventory: Array[String] = []
var flags: Dictionary = {}

signal patience_depleted
signal stamina_depleted
signal stats_changed

## Inventory helper functions
func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

func add_item(item_id: String) -> void:
	if not inventory.has(item_id):
		inventory.append(item_id)
		stats_changed.emit()

func remove_item(item_id: String) -> void:
	if inventory.has(item_id):
		inventory.erase(item_id)
		stats_changed.emit()

## Story Flags helper functions
func set_flag(flag_id: String, value) -> void:
	flags[flag_id] = value
	stats_changed.emit()

func get_flag(flag_id: String, default_value = false):
	return flags.get(flag_id, default_value)

## Roll Initial Skill: (1d6 + 6)
func roll_initial_skill() -> int:
	var val: int = randi_range(1, 6) + 6
	skill = val
	current_skill = val
	stats_changed.emit()
	return val

## Roll Initial Stamina: (2d6 + 12)
func roll_initial_stamina() -> int:
	var val: int = randi_range(1, 6) + randi_range(1, 6) + 12
	stamina = val
	current_stamina = val
	stats_changed.emit()
	return val

## Roll Initial Luck: (1d6 + 6)
func roll_initial_luck() -> int:
	var val: int = randi_range(1, 6) + 6
	luck = val
	current_luck = val
	stats_changed.emit()
	return val

## Roll Initial Heroic Patience: (1d6)
## CRITICAL ENGINE RULE: Patience is rolled on a single 1d6 to represent the hero's extremely thin reserves of tolerance for bureaucracy.
func roll_initial_patience() -> int:
	var val: int = randi_range(1, 6)
	patience = val
	current_patience = val
	stats_changed.emit()
	return val

## Deducts Patience stat (minimum 0) and emits patience_depleted if 0 is reached
func deduct_patience(amount: int = 1) -> int:
	current_patience = max(0, current_patience - amount)
	stats_changed.emit()
	if current_patience <= 0:
		patience_depleted.emit()
	return current_patience

## Deducts Luck stat (minimum 0)
func deduct_luck(amount: int = 1) -> int:
	current_luck = max(0, current_luck - amount)
	stats_changed.emit()
	return current_luck

## Deducts Stamina stat (minimum 0) and emits stamina_depleted if 0 is reached
func deduct_stamina(amount: int = 1) -> int:
	current_stamina = max(0, current_stamina - amount)
	stats_changed.emit()
	if current_stamina <= 0:
		stamina_depleted.emit()
	return current_stamina

## Helper to check if all stats have been rolled (> 0)
func are_stats_rolled() -> bool:
	return skill > 0 and stamina > 0 and luck > 0 and patience > 0

## Reset stats to 0 (for clean run reset)
func reset_stats() -> void:
	skill = 0
	current_skill = 0
	stamina = 0
	current_stamina = 0
	luck = 0
	current_luck = 0
	patience = 0
	current_patience = 0
	inventory.clear()
	flags.clear()
	stats_changed.emit()
