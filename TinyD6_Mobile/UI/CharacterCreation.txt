extends Control

@onready var skill_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/SkillRow/ValueLabel
@onready var stamina_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/StaminaRow/ValueLabel
@onready var luck_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/LuckRow/ValueLabel
@onready var patience_value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/PatienceRow/ValueLabel

@onready var skill_roll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/SkillRow/RollButton
@onready var stamina_roll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/StaminaRow/RollButton
@onready var luck_roll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/LuckRow/RollButton
@onready var patience_roll_button: Button = $PanelContainer/MarginContainer/VBoxContainer/StatsContainer/PatienceRow/RollButton

@onready var begin_adventure_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BeginAdventureButton
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel

const ICON_DICE = preload("res://Art/dice.png")
const ICON_SWORD = preload("res://Art/sword.png")

var _rolled_stats: Dictionary = {
	"skill": false,
	"stamina": false,
	"luck": false,
	"patience": false
}

func _ready() -> void:
	if title_label:
		title_label.text = StoryManager.get_adventure_title()
		
	# Assign PNG texture icons to roll buttons
	skill_roll_button.icon = ICON_DICE
	stamina_roll_button.icon = ICON_DICE
	luck_roll_button.icon = ICON_DICE
	patience_roll_button.icon = ICON_DICE
	begin_adventure_button.icon = ICON_SWORD
		
	# Initialize initial display states
	skill_value_label.text = "--"
	stamina_value_label.text = "--"
	luck_value_label.text = "--"
	patience_value_label.text = "--"
	
	# Begin Adventure Button starts hidden and disabled
	begin_adventure_button.visible = false
	begin_adventure_button.disabled = true
	
	# Connect button signals
	skill_roll_button.pressed.connect(_on_roll_skill_pressed)
	stamina_roll_button.pressed.connect(_on_roll_stamina_pressed)
	luck_roll_button.pressed.connect(_on_roll_luck_pressed)
	patience_roll_button.pressed.connect(_on_roll_patience_pressed)
	begin_adventure_button.pressed.connect(_on_begin_adventure_pressed)
	
	# Setup D-Pad / Keyboard explicit focus neighbors
	_setup_focus_neighbors()
	
	# UX Rule: Grab focus on first available roll button
	skill_roll_button.grab_focus()

func _setup_focus_neighbors() -> void:
	# Establish vertical navigation loop for keyboard & D-Pad
	skill_roll_button.focus_neighbor_top = patience_roll_button.get_path()
	skill_roll_button.focus_neighbor_bottom = stamina_roll_button.get_path()
	
	stamina_roll_button.focus_neighbor_top = skill_roll_button.get_path()
	stamina_roll_button.focus_neighbor_bottom = luck_roll_button.get_path()
	
	luck_roll_button.focus_neighbor_top = stamina_roll_button.get_path()
	luck_roll_button.focus_neighbor_bottom = patience_roll_button.get_path()
	
	patience_roll_button.focus_neighbor_top = luck_roll_button.get_path()
	patience_roll_button.focus_neighbor_bottom = begin_adventure_button.get_path()
	
	begin_adventure_button.focus_neighbor_top = patience_roll_button.get_path()
	begin_adventure_button.focus_neighbor_bottom = skill_roll_button.get_path()

func _on_roll_skill_pressed() -> void:
	if _rolled_stats["skill"]:
		return
	skill_roll_button.disabled = true
	await _animate_roll_ticking(skill_value_label, 7, 12)
	var final_val: int = PlayerStats.roll_initial_skill()
	skill_value_label.text = str(final_val)
	_rolled_stats["skill"] = true
	_check_and_focus_next()

func _on_roll_stamina_pressed() -> void:
	if _rolled_stats["stamina"]:
		return
	stamina_roll_button.disabled = true
	await _animate_roll_ticking(stamina_value_label, 14, 24)
	var final_val: int = PlayerStats.roll_initial_stamina()
	stamina_value_label.text = str(final_val)
	_rolled_stats["stamina"] = true
	_check_and_focus_next()

func _on_roll_luck_pressed() -> void:
	if _rolled_stats["luck"]:
		return
	luck_roll_button.disabled = true
	await _animate_roll_ticking(luck_value_label, 7, 12)
	var final_val: int = PlayerStats.roll_initial_luck()
	luck_value_label.text = str(final_val)
	_rolled_stats["luck"] = true
	_check_and_focus_next()

func _on_roll_patience_pressed() -> void:
	if _rolled_stats["patience"]:
		return
	patience_roll_button.disabled = true
	await _animate_roll_ticking(patience_value_label, 1, 6)
	var final_val: int = PlayerStats.roll_initial_patience()
	patience_value_label.text = str(final_val)
	_rolled_stats["patience"] = true
	_check_and_focus_next()

## Number-ticking visual animation (0.3 seconds of rapid random display before settling)
func _animate_roll_ticking(target_label: Label, min_val: int, max_val: int) -> void:
	var total_ticks: int = 8
	var tick_interval: float = 0.3 / float(total_ticks)
	for i in range(total_ticks):
		target_label.text = str(randi_range(min_val, max_val))
		await get_tree().create_timer(tick_interval).timeout

func _check_and_focus_next() -> void:
	if not _rolled_stats["skill"] and not skill_roll_button.disabled:
		skill_roll_button.grab_focus()
	elif not _rolled_stats["stamina"] and not stamina_roll_button.disabled:
		stamina_roll_button.grab_focus()
	elif not _rolled_stats["luck"] and not luck_roll_button.disabled:
		luck_roll_button.grab_focus()
	elif not _rolled_stats["patience"] and not patience_roll_button.disabled:
		patience_roll_button.grab_focus()
	else:
		_reveal_begin_quest()

func _reveal_begin_quest() -> void:
	begin_adventure_button.visible = true
	begin_adventure_button.disabled = false
	begin_adventure_button.grab_focus()

func _on_begin_adventure_pressed() -> void:
	print("[CharacterCreation] Adventure Begun! Hero registered with stats:")
	print("  - Skill: %d" % PlayerStats.skill)
	print("  - Stamina: %d" % PlayerStats.stamina)
	print("  - Luck: %d" % PlayerStats.luck)
	print("  - Heroic Patience: %d (rolled on single 1d6)" % PlayerStats.patience)
	
	if StoryManager and StoryManager.has_method("start_adventure"):
		StoryManager.start_adventure()
		
	get_tree().change_scene_to_file("res://UI/DialogueUI.tscn")

