extends Node

## CombatEngine Singleton
## Manages simultaneous Fighting Fantasy round resolution, wounding, and decaying Luck tests for Tiny D6 Engine.

signal combat_started(enemy_name: String, enemy_skill: int, enemy_stamina: int)
signal round_resolved(round_data: Dictionary)
signal luck_test_resolved(luck_data: Dictionary)
signal combat_ended(victory: bool)

var in_combat: bool = false
var enemy_name: String = ""
var enemy_skill: int = 0
var enemy_stamina: int = 0
var max_enemy_stamina: int = 0
var round_count: int = 0
var last_round_winner: String = "" # "player", "enemy", or "draw"
var victory_target_section = "7"
var defeat_target_section = "6"

## Initializes a combat encounter
func start_combat(p_enemy_name: String, p_enemy_skill: int, p_enemy_stamina: int, p_victory_section = "7", p_defeat_section = "6") -> void:
	in_combat = true
	enemy_name = p_enemy_name
	enemy_skill = p_enemy_skill
	enemy_stamina = p_enemy_stamina
	max_enemy_stamina = p_enemy_stamina
	round_count = 0
	last_round_winner = ""
	victory_target_section = p_victory_section
	defeat_target_section = p_defeat_section
	
	print("[CombatEngine] Combat started against %s (Skill: %d, Stamina: %d)" % [enemy_name, enemy_skill, enemy_stamina])
	combat_started.emit(enemy_name, enemy_skill, enemy_stamina)

## Rolls a simultaneous combat round (Player AS vs Enemy AS) with individual dice breakdown
func roll_round() -> Dictionary:
	if not in_combat:
		return {}
		
	round_count += 1
	var player_dice_1 = randi_range(1, 6)
	var player_dice_2 = randi_range(1, 6)
	var player_dice_sum = player_dice_1 + player_dice_2
	var player_as = PlayerStats.skill + player_dice_sum
	
	var enemy_dice_1 = randi_range(1, 6)
	var enemy_dice_2 = randi_range(1, 6)
	var enemy_dice_sum = enemy_dice_1 + enemy_dice_2
	var enemy_as = enemy_skill + enemy_dice_sum
	
	var winner = "draw"
	if player_as > enemy_as:
		winner = "player"
	elif enemy_as > player_as:
		winner = "enemy"
		
	last_round_winner = winner
	
	var round_data = {
		"round": round_count,
		"player_dice": [player_dice_1, player_dice_2],
		"player_skill": PlayerStats.skill,
		"player_as": player_as,
		"enemy_dice": [enemy_dice_1, enemy_dice_2],
		"enemy_skill": enemy_skill,
		"enemy_as": enemy_as,
		"winner": winner
	}
	
	print("[CombatEngine] Round %d: Player rolls [%d,%d]+%d=%d vs %s rolls [%d,%d]+%d=%d -> Winner: %s" % [
		round_count, player_dice_1, player_dice_2, PlayerStats.skill, player_as,
		enemy_name, enemy_dice_1, enemy_dice_2, enemy_skill, enemy_as, winner
	])
	round_resolved.emit(round_data)
	return round_data

## Applies standard base wounding (2 damage to loser, 0 on draw)
func apply_base_wounding() -> Dictionary:
	var damage_dealt = 0
	if last_round_winner == "player":
		damage_dealt = 2
		enemy_stamina = max(0, enemy_stamina - 2)
	elif last_round_winner == "enemy":
		damage_dealt = 2
		PlayerStats.current_stamina = max(0, PlayerStats.current_stamina - 2)
		
	var result = {
		"winner": last_round_winner,
		"damage": damage_dealt,
		"tested_luck": false,
		"player_stamina": PlayerStats.current_stamina,
		"enemy_stamina": enemy_stamina
	}
	
	_check_combat_termination()
	return result

## Resolves high-stakes Combat Luck Test with Decaying Luck Rule & individual die breakdown
func test_luck_on_wounding() -> Dictionary:
	var luck_target = PlayerStats.current_luck
	# Decaying Luck Rule: Deduct 1 point from player's current Luck stat after test
	PlayerStats.current_luck = max(0, PlayerStats.current_luck - 1)
	
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	var luck_roll = d1 + d2
	var is_lucky = luck_roll <= luck_target
	
	var damage_dealt = 0
	if last_round_winner == "player":
		if is_lucky:
			damage_dealt = 4
		else:
			damage_dealt = 1
		enemy_stamina = max(0, enemy_stamina - damage_dealt)
	elif last_round_winner == "enemy":
		if is_lucky:
			damage_dealt = 1
		else:
			damage_dealt = 3
		PlayerStats.current_stamina = max(0, PlayerStats.current_stamina - damage_dealt)
		
	var result = {
		"winner": last_round_winner,
		"tested_luck": true,
		"luck_target": luck_target,
		"luck_dice": [d1, d2],
		"luck_roll": luck_roll,
		"is_lucky": is_lucky,
		"damage": damage_dealt,
		"player_stamina": PlayerStats.current_stamina,
		"enemy_stamina": enemy_stamina
	}
	
	print("[CombatEngine] Luck Test: Rolled [%d,%d]=%d vs Luck %d -> %s! Damage: %d" % [
		d1, d2, luck_roll, luck_target, "LUCKY" if is_lucky else "UNLUCKY", damage_dealt
	])
	luck_test_resolved.emit(result)
	_check_combat_termination()
	return result

func _check_combat_termination() -> bool:
	if PlayerStats.current_stamina <= 0:
		in_combat = false
		print("[CombatEngine] Combat terminated: Player Defeated! Transitioning to Section '%s'" % str(defeat_target_section))
		combat_ended.emit(false)
		if StoryManager and StoryManager.has_method("go_to_section"):
			StoryManager.go_to_section(str(defeat_target_section))
		return true
	elif enemy_stamina <= 0:
		in_combat = false
		print("[CombatEngine] Combat terminated: Player Victorious! Transitioning to Section '%s'" % str(victory_target_section))
		combat_ended.emit(true)
		if StoryManager and StoryManager.has_method("go_to_section"):
			StoryManager.go_to_section(str(victory_target_section))
		return true
	return false
